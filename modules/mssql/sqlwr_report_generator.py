"""
modules/mssql/sqlwr_report_generator.py
==========================================
Generates a SQLWR (SQL Workload Repository) report -- the MSSQL
equivalent of an Oracle AWR report -- for two consecutive
mssql_dmv_snapshot rows. Matches the simple HTML structure of the
sample AWR reports in awr_reports/ (plain <h1>/<h2>/<h3> headers,
<table border="1"> with <th>/<td> rows, no CSS/JS) exactly, so the
existing parser patterns this project already uses can extend
naturally to a SQLWR parser built the same way.

Delta computation happens HERE, once, at report-generation time --
the same role Oracle's own awrrpt.sql plays before the AWR parser
ever runs. mssql_wait_stats_delta and friends store the RAW cumulative
value at each snapshot (a deliberate, documented choice -- Analysis
Model doc Section 4.2); this generator is what turns two consecutive
raw snapshots into the delta values the report actually shows.

Only DMV-sourced sections are built from two mssql_dmv_snapshot rows.
Query-Store-sourced sections (wait categories, top SQL by
elapsed/CPU/memory) are matched by TIME OVERLAP against
mssql_qs_interval, not by ID -- qs_interval_id and snapshot_id are
independent sequences that happen to run on the same clock-aligned
cadence (mssql_collector_scheduler.py), not the same numbering.

Usage:
    from sqlwr_report_generator import generate_sqlwr_report
    generate_sqlwr_report(pg_conn, instance_id, begin_snapshot_id,
                           end_snapshot_id, output_path)
"""

import sys
import os
import html

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rule_engine import BENIGN_WAIT_TYPES


def _esc(v) -> str:
    """HTML-escapes any value for safe table-cell insertion -- wait
    type names, SQL text, and object names are all attacker-uncontrolled
    but still arbitrary text from a live database; never trust it
    unescaped into HTML."""
    if v is None:
        return ""
    return html.escape(str(v))


def _table(headers: list, rows: list, summary: str = None) -> str:
    """Builds one <table border="1"> block matching the sample AWR
    reports' exact shape -- kept as one shared helper so every section
    renders identically rather than each one reinventing table markup."""
    summary_attr = f' summary="{_esc(summary)}"' if summary else ""
    out = [f'<table border="1"{summary_attr}><tr>']
    out.extend(f'<th>{_esc(h)}</th>' for h in headers)
    out.append('</tr>\n')
    for row in rows:
        out.append('<tr>')
        out.extend(f'<td>{_esc(c)}</td>' for c in row)
        out.append('</tr>\n')
    out.append('</table>\n')
    return "".join(out)


def _get_snapshot_info(pg_conn, snapshot_id: int) -> dict:
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT s.snapshot_id, s.snapshot_time, s.instance_id,
                   m.host_name, m.instance_name, m.sql_version, m.sql_edition
            FROM mssql_dmv_snapshot s
            JOIN mssql_instance_master m ON s.instance_id = m.id
            WHERE s.snapshot_id = %s
        """, (snapshot_id,))
        row = cur.fetchone()
    if not row:
        raise ValueError(f"snapshot_id {snapshot_id} not found in mssql_dmv_snapshot")
    return {
        "snapshot_id": row[0], "snapshot_time": row[1], "instance_id": row[2],
        "host_name": row[3], "instance_name": row[4],
        "sql_version": row[5], "sql_edition": row[6],
    }


def _build_database_summary(begin_info: dict) -> str:
    rows = [(begin_info["host_name"], begin_info["instance_name"],
              begin_info.get("sql_version") or "(not collected)",
              begin_info.get("sql_edition") or "(not collected)")]
    return ('<h3>Database Summary</h3>\n'
            + _table(["Host Name", "Instance", "Version", "Edition"], rows,
                     "This table displays database instance information"))


def _build_snapshot_summary(begin_info: dict, end_info: dict) -> str:
    rows = [
        ("Begin Snap", begin_info["snapshot_id"], begin_info["snapshot_time"]),
        ("End Snap", end_info["snapshot_id"], end_info["snapshot_time"]),
    ]
    return ('<h3>Snapshot Summary</h3>\n'
            + _table(["Snap", "Snapshot ID", "Snapshot Time"], rows,
                     "This table displays snapshot information"))


def _build_load_profile(pg_conn, instance_id: int, begin_snap: int, end_snap: int,
                          elapsed_seconds: float) -> str:
    """
    Batch Requests/sec, SQL Compilations/sec, and similar rate counters
    from mssql_perf_counters -- delta between the two snapshots divided
    by elapsed_seconds, matching Oracle Load Profile's own "Per Second"
    framing exactly (Redo size/sec, Logical reads/sec, etc.).
    """
    wanted = [
        ("SQLServer:SQL Statistics", "Batch Requests/sec", "Batch Requests"),
        ("SQLServer:SQL Statistics", "SQL Compilations/sec", "SQL Compilations"),
        ("SQLServer:SQL Statistics", "SQL Re-Compilations/sec", "SQL Re-Compilations"),
        ("SQLServer:Databases", "Transactions/sec", "Transactions"),
        ("SQLServer:Buffer Manager", "Page reads/sec", "Page Reads"),
        ("SQLServer:Buffer Manager", "Page writes/sec", "Page Writes"),
    ]
    rows = []
    with pg_conn.cursor() as cur:
        for obj_suffix, counter, label in wanted:
            cur.execute("""
                SELECT snapshot_id, cntr_value FROM mssql_perf_counters
                WHERE snapshot_id IN (%s, %s) AND object_name LIKE %s AND counter_name = %s
                ORDER BY snapshot_id
            """, (begin_snap, end_snap, f"%{obj_suffix.split(':')[1]}", counter))
            vals = {r[0]: r[1] for r in cur.fetchall()}
            if begin_snap in vals and end_snap in vals and elapsed_seconds > 0:
                delta = vals[end_snap] - vals[begin_snap]
                per_sec = delta / elapsed_seconds
                rows.append((f"{label}:", f"{per_sec:.1f}"))
    if not rows:
        rows = [("(no perf counter deltas available for this snapshot pair)", "")]
    return ('<h3>Load Profile</h3>\n'
            + _table(["Stat Name", "Per Second"], rows))


def _build_top_wait_types(pg_conn, instance_id: int, begin_snap: int, end_snap: int,
                            elapsed_seconds: float, top_n: int = 15) -> str:
    """
    Delta computation happens HERE -- current minus previous per
    wait_type, the same role Oracle's own report generator plays.
    Reuses BENIGN_WAIT_TYPES from rule_engine.py rather than
    duplicating that list -- the same exclusions that already apply
    to rule evaluation apply here, so the report and the
    recommendations agree on what counts as noise.
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT wait_type, wait_time_ms FROM mssql_wait_stats_delta WHERE snapshot_id = %s
        """, (begin_snap,))
        begin_vals = dict(cur.fetchall())
        cur.execute("""
            SELECT wait_type, wait_time_ms FROM mssql_wait_stats_delta WHERE snapshot_id = %s
        """, (end_snap,))
        end_vals = dict(cur.fetchall())

    deltas = []
    for wait_type, end_ms in end_vals.items():
        if wait_type in BENIGN_WAIT_TYPES:
            continue
        begin_ms = begin_vals.get(wait_type, 0)
        delta_ms = end_ms - begin_ms
        if delta_ms > 0:
            deltas.append((wait_type, delta_ms))
    deltas.sort(key=lambda x: x[1], reverse=True)
    total_ms = sum(d[1] for d in deltas) or 1

    rows = []
    for wait_type, delta_ms in deltas[:top_n]:
        pct = (delta_ms / total_ms) * 100
        rows.append((wait_type, f"{delta_ms/1000:.1f}", f"{pct:.1f}%"))
    if not rows:
        rows = [("(no significant non-benign wait activity in this window)", "", "")]
    return (f'<h3>Top {top_n} Wait Types by Total Wait Time</h3>\n'
            + _table(["Wait Type", "Time(s)", "% of Total"], rows))


def _build_blocking_summary(pg_conn, instance_id: int, end_snap: int) -> str:
    """
    Point-in-time, not a delta -- blocking is a live snapshot of who
    was blocked, by whom, at the moment the END snapshot was taken
    (same reasoning already documented on mssql_blocking_snapshot
    itself and in evaluate_blocking_rules).
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT session_id, blocking_session_id, wait_type, wait_time_ms,
                   resource_type, blocked_object_name, database_name
            FROM mssql_blocking_snapshot
            WHERE snapshot_id = %s AND blocking_session_id > 0
            ORDER BY wait_time_ms DESC
        """, (end_snap,))
        rows_raw = cur.fetchall()
    rows = [(r[0], r[1], r[2], f"{(r[3] or 0)/1000:.1f}", r[4], r[5] or "", r[6])
            for r in rows_raw]
    if not rows:
        rows = [("(no blocking observed at end-snapshot time)", "", "", "", "", "", "")]
    return ('<h3>Blocking Summary (at End Snapshot)</h3>\n'
            + _table(["Session", "Blocked By", "Wait Type", "Wait Time(s)",
                      "Resource Type", "Object", "Database"], rows))


def generate_sqlwr_report(pg_conn, instance_id: int, begin_snapshot_id: int,
                            end_snapshot_id: int, output_path: str) -> str:
    """
    Main entry point. begin_snapshot_id == end_snapshot_id is valid --
    matches Oracle's own single-report convention (Ganesh's own
    framing: "the begin_snap represents the entire report") -- though
    in practice a delta needs two DIFFERENT raw values, so a
    single-snapshot report will show zero deltas everywhere rather
    than erroring, the same way an Oracle report for a snap range with
    no elapsed time would show all-zero rates.

    Returns the output_path written.
    """
    begin_info = _get_snapshot_info(pg_conn, begin_snapshot_id)
    end_info = _get_snapshot_info(pg_conn, end_snapshot_id)

    if begin_info["instance_id"] != end_info["instance_id"]:
        raise ValueError("begin and end snapshot belong to different instances")

    elapsed_seconds = (end_info["snapshot_time"] - begin_info["snapshot_time"]).total_seconds()
    if elapsed_seconds < 0:
        raise ValueError("end_snapshot_id is earlier than begin_snapshot_id")

    title = (f"SQLWR Report \u2014 {begin_info['host_name']}\\{begin_info['instance_name']} "
             f"Snap {begin_snapshot_id}-{end_snapshot_id}")

    sections = [
        _build_database_summary(begin_info),
        _build_snapshot_summary(begin_info, end_info),
        _build_load_profile(pg_conn, instance_id, begin_snapshot_id, end_snapshot_id, elapsed_seconds),
        _build_top_wait_types(pg_conn, instance_id, begin_snapshot_id, end_snapshot_id, elapsed_seconds),
        _build_blocking_summary(pg_conn, instance_id, end_snapshot_id),
    ]

    html_doc = (
        "<!DOCTYPE html>\n\n"
        f"<html><head><title>{_esc(title)}</title></head><body>\n"
        f"<h1>SQL WORKLOAD REPOSITORY report for<br/>"
        f"Instance: {_esc(begin_info['host_name'])}\\{_esc(begin_info['instance_name'])} "
        f"Snap: {begin_snapshot_id}\u2013{end_snapshot_id}</h1>\n"
        "<h2>Main Report</h2>\n"
        + "".join(sections)
        + "</body></html>\n"
    )

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_doc)

    return output_path


def auto_generate_sqlwr_reports(pg_conn, instance_id: int, output_dir: str) -> dict:
    """
    Called after each collection cycle (from mssql_collector_scheduler.py).
    Finds every mssql_dmv_snapshot for this instance that doesn't yet
    have a mssql_sqlwr_report row where it's the END of the pair, and
    for each one, generates a report against the immediately preceding
    snapshot -- UNLESS a SQL Server restart is detected between them
    (or restart status can't be confirmed), in which case that pair is
    recorded as skipped_restart rather than generating a meaningless
    report, and the current snapshot effectively becomes the new
    starting point for the next pair.

    The very first snapshot ever taken for an instance has no
    predecessor at all -- correctly produces zero reports until a
    second snapshot exists, matching "reports start from the 2nd
    snapshot onwards."

    Restart handling deliberately conservative: sqlserver_start_time
    being NULL on either snapshot (collection failure, or a snapshot
    taken before this column existed) is treated the same as a
    CONFIRMED restart -- skip rather than risk a nonsense negative-
    delta report. A skipped pair can always be revisited manually
    later; a silently wrong report showing negative wait times cannot
    un-mislead whoever already read it.

    Returns {"generated": [...], "skipped_restart": [...], "failed": [...]}
    -- lists of (begin_snapshot_id, end_snapshot_id) tuples.
    """
    result = {"generated": [], "skipped_restart": [], "failed": []}

    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT snapshot_id, sqlserver_start_time FROM mssql_dmv_snapshot
            WHERE instance_id = %s
              AND snapshot_id NOT IN (
                  SELECT end_snapshot_id FROM mssql_sqlwr_report WHERE instance_id = %s
              )
            ORDER BY snapshot_id ASC
        """, (instance_id, instance_id))
        pending_snapshots = cur.fetchall()

    for end_snapshot_id, end_start_time in pending_snapshots:
        with pg_conn.cursor() as cur:
            cur.execute("""
                SELECT snapshot_id, sqlserver_start_time FROM mssql_dmv_snapshot
                WHERE instance_id = %s AND snapshot_id < %s
                ORDER BY snapshot_id DESC LIMIT 1
            """, (instance_id, end_snapshot_id))
            prev = cur.fetchone()

        if not prev:
            # First snapshot ever for this instance -- no predecessor,
            # nothing to report yet. Not an error, not recorded at all
            # (so it's picked up correctly once a real successor exists).
            continue

        begin_snapshot_id, begin_start_time = prev

        restart_detected = (
            begin_start_time is None or end_start_time is None
            or begin_start_time != end_start_time
        )

        if restart_detected:
            with pg_conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO mssql_sqlwr_report
                        (instance_id, begin_snapshot_id, end_snapshot_id, status, error_message, generated_at)
                    VALUES (%s, %s, %s, 'skipped_restart', %s, now())
                    ON CONFLICT (instance_id, begin_snapshot_id, end_snapshot_id) DO NOTHING
                """, (instance_id, begin_snapshot_id, end_snapshot_id,
                      "SQL Server restart detected (or start_time unknown) between these snapshots"))
            pg_conn.commit()
            result["skipped_restart"].append((begin_snapshot_id, end_snapshot_id))
            continue

        report_path = os.path.join(
            output_dir, f"sqlwr_{instance_id}_{begin_snapshot_id}_{end_snapshot_id}.html"
        )
        try:
            generate_sqlwr_report(pg_conn, instance_id, begin_snapshot_id, end_snapshot_id, report_path)
            with pg_conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO mssql_sqlwr_report
                        (instance_id, begin_snapshot_id, end_snapshot_id, report_path, status, generated_at)
                    VALUES (%s, %s, %s, %s, 'completed', now())
                    ON CONFLICT (instance_id, begin_snapshot_id, end_snapshot_id) DO NOTHING
                """, (instance_id, begin_snapshot_id, end_snapshot_id, report_path))
            pg_conn.commit()
            result["generated"].append((begin_snapshot_id, end_snapshot_id))
        except Exception as e:
            with pg_conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO mssql_sqlwr_report
                        (instance_id, begin_snapshot_id, end_snapshot_id, status, error_message, generated_at)
                    VALUES (%s, %s, %s, 'failed', %s, now())
                    ON CONFLICT (instance_id, begin_snapshot_id, end_snapshot_id) DO NOTHING
                """, (instance_id, begin_snapshot_id, end_snapshot_id, str(e)))
            pg_conn.commit()
            result["failed"].append((begin_snapshot_id, end_snapshot_id))

    return result


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Generate a SQLWR report for two consecutive DMV snapshots")
    parser.add_argument("--host", required=True)
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    parser.add_argument("--begin-snap", type=int, required=True)
    parser.add_argument("--end-snap", type=int, required=True)
    parser.add_argument("--output", default=None, help="Output HTML path (default: sqlwr_<host>_<begin>_<end>.html)")
    args = parser.parse_args()

    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'common'))
    from db import get_db_connection

    conn = get_db_connection()
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM mssql_instance_master WHERE host_name = %s AND instance_name = %s",
            (args.host, args.instance_name)
        )
        row = cur.fetchone()
    if not row:
        print(f"No registered instance found for {args.host}\\{args.instance_name}")
        return
    instance_id = row[0]

    output_path = args.output or f"sqlwr_{args.host}_{args.begin_snap}_{args.end_snap}.html"
    result = generate_sqlwr_report(conn, instance_id, args.begin_snap, args.end_snap, output_path)
    print(f"SQLWR report written to: {result}")


if __name__ == "__main__":
    main()
