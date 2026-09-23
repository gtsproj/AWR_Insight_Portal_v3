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


def _build_database_summary(begin_info: dict, db_name: str = None) -> str:
    rows = [(db_name or "(not collected)", begin_info["host_name"], begin_info["instance_name"],
              begin_info.get("sql_version") or "(not collected)",
              begin_info.get("sql_edition") or "(not collected)")]
    return ('<h3>Database Summary</h3>\n'
            + _table(["DB Name", "Host Name", "Instance", "Version", "Edition"], rows,
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
                          elapsed_seconds: float, top_sql: list) -> str:
    """
    Batch Requests/sec, SQL Compilations/sec, and similar rate counters
    from mssql_perf_counters -- delta between the two snapshots divided
    by elapsed_seconds, matching Oracle Load Profile's own "Per Second"
    framing exactly (Redo size/sec, Logical reads/sec, etc.).

    Log-specific IOPS/throughput rows come from mssql_file_io_delta,
    filtered to file_type_desc='LOG' -- the same file-type
    classification IO Profile itself relies on. Number of Executions
    and Total DB Time are TOTALS across the window (not per-second
    rates, matching how they're usually asked for), not deltas of a
    perf counter.

    Total DB Time is an explicit APPROXIMATION, labeled as such --
    MSSQL has no single native counter equivalent to Oracle's DB Time
    (total session-active time, CPU + non-idle waits, summed across
    concurrent sessions). Approximated here as non-benign wait time
    (the same total the Wait Classes section already computes) plus
    total SQL CPU time from Query Store's top_sql -- a reasonable,
    honestly-labeled stand-in for "total time spent doing work",
    not a claim of exact equivalence to Oracle's own metric.
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
                SELECT snapshot_id, SUM(cntr_value) FROM mssql_perf_counters
                WHERE snapshot_id IN (%s, %s) AND object_name LIKE %s AND counter_name = %s
                GROUP BY snapshot_id
            """, (begin_snap, end_snap, f"%{obj_suffix.split(':')[1]}", counter))
            vals = {r[0]: r[1] for r in cur.fetchall()}
            if begin_snap in vals and end_snap in vals and elapsed_seconds > 0:
                delta = vals[end_snap] - vals[begin_snap]
                per_sec = delta / elapsed_seconds
                rows.append((f"{label}:", f"{per_sec:.1f}"))

    # Log-specific IOPS/throughput, from mssql_file_io_delta deltas
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT e.file_type_desc,
                   SUM(e.num_of_reads - COALESCE(b.num_of_reads, 0)) AS reads,
                   SUM(e.num_of_bytes_read - COALESCE(b.num_of_bytes_read, 0)) AS bytes_read,
                   SUM(e.num_of_writes - COALESCE(b.num_of_writes, 0)) AS writes,
                   SUM(e.num_of_bytes_written - COALESCE(b.num_of_bytes_written, 0)) AS bytes_written
            FROM mssql_file_io_delta e
            LEFT JOIN mssql_file_io_delta b
                   ON b.snapshot_id = %s AND b.database_name = e.database_name AND b.file_id = e.file_id
            WHERE e.snapshot_id = %s
            GROUP BY e.file_type_desc
        """, (begin_snap, end_snap))
        io_by_type = {t: (float(r or 0), float(br or 0), float(w or 0), float(bw or 0))
                      for t, r, br, w, bw in cur.fetchall()}

    if elapsed_seconds > 0:
        log_reads, log_bytes_read, log_writes, log_bytes_written = io_by_type.get(
            "LOG", (0.0, 0.0, 0.0, 0.0))
        rows.append(("Log Read IOPS:", f"{log_reads / elapsed_seconds:.1f}"))
        rows.append(("Log Read KB/sec:", f"{log_bytes_read / 1024 / elapsed_seconds:.1f}"))
        rows.append(("Log Write IOPS:", f"{log_writes / elapsed_seconds:.1f}"))
        rows.append(("Log Writes KB/sec:", f"{log_bytes_written / 1024 / elapsed_seconds:.1f}"))

        total_bytes = sum(br + bw for _, br, _, bw in io_by_type.values())
        rows.append(("Throughput (MB/sec, all files):", f"{total_bytes / 1024 / 1024 / elapsed_seconds:.2f}"))

    total_executions = sum(r["executions"] for r in top_sql)
    rows.append(("Number of Executions (total, this window):", f"{total_executions}"))

    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT SUM(e.wait_time_ms - COALESCE(b.wait_time_ms, 0))
            FROM mssql_wait_stats_delta e
            LEFT JOIN mssql_wait_stats_delta b ON b.snapshot_id = %s AND b.wait_type = e.wait_type
            WHERE e.snapshot_id = %s AND e.wait_type != ALL(%s)
        """, (begin_snap, end_snap, list(BENIGN_WAIT_TYPES)))
        non_benign_wait_ms = float(cur.fetchone()[0] or 0)
    total_cpu_s = sum(r["cpu_time_s"] for r in top_sql)
    db_time_s = (non_benign_wait_ms / 1000.0) + total_cpu_s
    rows.append(("Total DB Time (s) [approximated: non-benign wait + SQL CPU time]:",
                 f"{db_time_s:.1f}"))

    if not rows:
        rows = [("(no perf counter deltas available for this snapshot pair)", "")]
    return ('<h3>Load Profile</h3>\n'
            + _table(["Stat Name", "Per Second"], rows))


def _build_instance_efficiency(pg_conn, begin_snap: int, end_snap: int) -> str:
    """
    MSSQL's analog to Oracle's "Instance Efficiency Percentages
    (Target 100%)". Buffer Cache Hit Ratio is stored as SQL Server's
    own raw ratio-counter pair (a numerator and a "Base" denominator,
    Windows Perfmon's standard pattern for ratio counters) -- computed
    here by dividing them, the same as every other consumer of this
    counter (Perfmon, SSMS, Grafana) does. Page Life Expectancy is
    already a point-in-time value in seconds, not a ratio, and doesn't
    have a fixed "target 100%" the way the others do -- shown as its
    own row with its actual guidance (Microsoft's own long-standing
    rule of thumb) rather than forced into a percentage it isn't.
    Uses the END snapshot's values (a point-in-time read of server
    state), not a delta -- these are current server condition, not an
    activity rate the way Load Profile's counters are.
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT counter_name, cntr_value FROM mssql_perf_counters
            WHERE snapshot_id = %s AND counter_name IN (
                'Buffer cache hit ratio', 'Buffer cache hit ratio base',
                'Page life expectancy', 'Memory Grants Pending'
            )
        """, (end_snap,))
        vals = {name: value for name, value in cur.fetchall()}

    rows = []
    numerator = vals.get("Buffer cache hit ratio")
    denominator = vals.get("Buffer cache hit ratio base")
    if numerator is not None and denominator:
        rows.append(("Buffer Cache Hit Ratio", f"{100 * numerator / denominator:.2f}"))
    ple = vals.get("Page life expectancy")
    if ple is not None:
        rows.append(("Page Life Expectancy (s) [target: 300+ per Microsoft guidance]", f"{ple}"))
    grants_pending = vals.get("Memory Grants Pending")
    if grants_pending is not None:
        rows.append(("Memory Grants Pending [target: 0]", f"{grants_pending}"))
    if not rows:
        rows = [("(no efficiency counters available for this snapshot)", "")]
    return ('<h3>Instance Efficiency Percentages (Target 100%)</h3>\n'
            + _table(["Metric", "Value"], rows))


def _build_wait_classes(pg_conn, instance_id: int, begin_snap: int, end_snap: int,
                          elapsed_seconds: float, top_n: int = 15) -> str:
    """
    Groups the same per-wait-type deltas _build_top_wait_types computes
    into wait_class buckets, via mssql_wait_event_master.wait_class --
    already populated from an earlier session (I/O, Lock, CPU, Memory,
    Parallelism, Transaction Log, Network, Preemptive, Internal, etc.),
    not invented here. A wait_type with no master-table match (not yet
    catalogued) is grouped under "Other/Uncategorized" rather than
    silently dropped -- honest about what isn't classified yet instead
    of hiding it from the total.
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT COALESCE(m.wait_class, 'Other/Uncategorized') AS wait_class,
                   SUM(e.wait_time_ms - COALESCE(b.wait_time_ms, 0)) AS delta_ms
            FROM mssql_wait_stats_delta e
            JOIN mssql_dmv_snapshot s ON e.snapshot_id = s.snapshot_id
            LEFT JOIN mssql_wait_stats_delta b
                   ON b.snapshot_id = %s AND b.wait_type = e.wait_type
            LEFT JOIN mssql_wait_event_master m
                   ON m.tier = 'wait_type' AND m.event_name = e.wait_type
            WHERE e.snapshot_id = %s AND s.instance_id = %s
              AND e.wait_type != ALL(%s)
            GROUP BY COALESCE(m.wait_class, 'Other/Uncategorized')
            HAVING SUM(e.wait_time_ms - COALESCE(b.wait_time_ms, 0)) > 0
            ORDER BY delta_ms DESC
            LIMIT %s
        """, (begin_snap, end_snap, instance_id, list(BENIGN_WAIT_TYPES), top_n))
        rows_raw = cur.fetchall()

    rows_raw = [(wait_class, float(ms)) for wait_class, ms in rows_raw]
    total_ms = sum(ms for _, ms in rows_raw) or 1
    rows = [
        (wait_class, f"{ms / 1000.0:.1f}", f"{100 * ms / total_ms:.1f}")
        for wait_class, ms in rows_raw
    ]
    if not rows:
        rows = [("(no wait class data for this snapshot pair)", "", "")]
    return ('<h3>Wait Classes by Total Wait Time</h3>\n'
            + _table(["Wait Class", "Time(s)", "% of Total"], rows,
                     "This table displays wait time grouped by wait class"))


def _build_memory_statistics(pg_conn, end_snap: int) -> str:
    """
    Host memory and SQL Server's own allocation/usage from
    mssql_config_snapshot (physical_memory_kb, max_server_memory_mb --
    static-ish server config, one row per database per snapshot so
    DISTINCT-first-row is fine) and mssql_memory_clerks (actual
    allocated pages, summed across every clerk -- the real "how much
    is SQL Server actually using right now" figure, MEMORYCLERK_SQLBUFFERPOOL
    plus every other clerk together). "Free within allocated" is
    max_server_memory - actual usage; can be negative if usage has
    exceeded the configured cap in practice (SQL Server enforces this
    loosely, not a hard wall) -- shown as-is rather than floored at
    zero, since a negative value is itself diagnostically meaningful.
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT max_server_memory_mb, physical_memory_kb FROM mssql_config_snapshot
            WHERE snapshot_id = %s LIMIT 1
        """, (end_snap,))
        cfg_row = cur.fetchone()
        cur.execute("""
            SELECT SUM(pages_kb) FROM mssql_memory_clerks WHERE snapshot_id = %s
        """, (end_snap,))
        used_kb_row = cur.fetchone()

    if not cfg_row:
        return ('<h3>Memory Statistics</h3>\n'
                + _table(["Metric", "Value (MB)"],
                         [("(no config snapshot available)", "")]))

    max_server_memory_mb, physical_memory_kb = cfg_row
    used_kb = float(used_kb_row[0]) if used_kb_row and used_kb_row[0] else 0.0
    host_memory_mb = float(physical_memory_kb or 0) / 1024.0
    allocated_mb = float(max_server_memory_mb) if max_server_memory_mb is not None else host_memory_mb
    used_mb = used_kb / 1024.0
    free_mb = allocated_mb - used_mb

    rows = [
        ("Host Physical Memory", f"{host_memory_mb:.0f}"),
        ("Memory Allocated to SQL Server (max_server_memory)", f"{allocated_mb:.0f}"),
        ("Actual Used by SQL Server (sum of memory clerks)", f"{used_mb:.0f}"),
        ("Free within Allocated", f"{free_mb:.0f}"),
    ]
    return ('<h3>Memory Statistics</h3>\n'
            + _table(["Metric", "Value (MB)"], rows,
                     "This table displays host and SQL Server memory allocation/usage"))


def _build_io_profile(pg_conn, begin_snap: int, end_snap: int, elapsed_seconds: float,
                        top_n: int = 15) -> str:
    """
    File-level I/O from mssql_file_io_delta -- sys.dm_io_virtual_file_stats,
    the direct analog to Oracle's IOStat/tablespace-I/O sections.
    Ranked by total I/O stall time (reads + writes), the delta-per-
    second the same way every other rate section in this report works.
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT e.database_name, e.logical_file_name,
                   (e.num_of_reads - COALESCE(b.num_of_reads, 0)) AS reads,
                   (e.num_of_writes - COALESCE(b.num_of_writes, 0)) AS writes,
                   (e.num_of_bytes_read - COALESCE(b.num_of_bytes_read, 0)) AS bytes_read,
                   (e.num_of_bytes_written - COALESCE(b.num_of_bytes_written, 0)) AS bytes_written,
                   (e.io_stall_read_ms - COALESCE(b.io_stall_read_ms, 0)) AS read_stall_ms,
                   (e.io_stall_write_ms - COALESCE(b.io_stall_write_ms, 0)) AS write_stall_ms
            FROM mssql_file_io_delta e
            LEFT JOIN mssql_file_io_delta b
                   ON b.snapshot_id = %s AND b.database_name = e.database_name
                  AND b.file_id = e.file_id
            WHERE e.snapshot_id = %s
        """, (begin_snap, end_snap))
        rows_raw = cur.fetchall()

    ranked = sorted(rows_raw, key=lambda r: (r[6] or 0) + (r[7] or 0), reverse=True)[:top_n]
    rows = []
    for db, f, reads, writes, bread, bwrite, rstall, wstall in ranked:
        reads_s = (reads or 0) / elapsed_seconds if elapsed_seconds > 0 else 0
        writes_s = (writes or 0) / elapsed_seconds if elapsed_seconds > 0 else 0
        avg_read_ms = (rstall / reads) if reads else 0
        avg_write_ms = (wstall / writes) if writes else 0
        rows.append((
            db, f, f"{reads_s:.1f}", f"{writes_s:.1f}",
            f"{(bread or 0) / 1024 / 1024:.1f}", f"{(bwrite or 0) / 1024 / 1024:.1f}",
            f"{avg_read_ms:.2f}", f"{avg_write_ms:.2f}",
        ))
    if not rows:
        rows = [("(no I/O delta data for this snapshot pair)", "", "", "", "", "", "", "")]
    return ('<h3>IO Profile</h3>\n'
            + _table(["Database", "File", "Reads/s", "Writes/s", "MB Read", "MB Written",
                      "Avg Read Latency (ms)", "Avg Write Latency (ms)"],
                     rows, "This table displays file-level I/O activity"))


def _build_io_stalls_by_file_type(pg_conn, begin_snap: int, end_snap: int) -> str:
    """
    Datafile vs logfile I/O stalls -- the same mssql_file_io_delta
    deltas IO Profile computes per-file, aggregated by
    file_type_desc instead ('ROWS'/data files vs 'LOG'). Datafile
    stalls generally reflect buffer/read pressure (mirrored in the
    Wait Classes section's "Buffer IO" bucket); logfile stalls
    generally reflect write/commit pressure (mirrored in "Transaction
    Log"/WRITELOG there) -- this section is the file-level detail
    behind those two wait-class totals, not a replacement for them.
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT e.file_type_desc,
                   SUM(e.io_stall_read_ms - COALESCE(b.io_stall_read_ms, 0)) AS read_stall_ms,
                   SUM(e.io_stall_write_ms - COALESCE(b.io_stall_write_ms, 0)) AS write_stall_ms,
                   SUM(e.num_of_reads - COALESCE(b.num_of_reads, 0)) AS reads,
                   SUM(e.num_of_writes - COALESCE(b.num_of_writes, 0)) AS writes
            FROM mssql_file_io_delta e
            LEFT JOIN mssql_file_io_delta b
                   ON b.snapshot_id = %s AND b.database_name = e.database_name
                  AND b.file_id = e.file_id
            WHERE e.snapshot_id = %s
            GROUP BY e.file_type_desc
        """, (begin_snap, end_snap))
        rows_raw = cur.fetchall()

    rows = []
    for file_type, rstall, wstall, reads, writes in rows_raw:
        rstall, wstall = float(rstall or 0), float(wstall or 0)
        reads, writes = int(reads or 0), int(writes or 0)
        label = {"ROWS": "Datafile", "LOG": "Logfile"}.get(file_type, file_type or "Other")
        avg_read = rstall / reads if reads else 0
        avg_write = wstall / writes if writes else 0
        rows.append((label, f"{rstall:.0f}", f"{wstall:.0f}", f"{avg_read:.2f}", f"{avg_write:.2f}"))
    if not rows:
        rows = [("(no I/O delta data for this snapshot pair)", "", "", "", "")]
    return ('<h3>IO Stalls by File Type</h3>\n'
            + _table(["File Type", "Read Stall (ms)", "Write Stall (ms)",
                      "Avg Read Stall (ms)", "Avg Write Stall (ms)"],
                     rows, "This table displays I/O stall time grouped by datafile vs logfile"))


def _build_complete_sql_text(top_sql: list) -> str:
    """
    Full, untruncated SQL text for every query referenced (by SQL Id)
    in the SQL ordered by ... sections above -- matches Oracle AWR's
    own "Complete List of SQL Text" section, which exists specifically
    because those sections all truncate SQL Text to keep the tables
    readable.
    """
    seen = {}
    for r in top_sql:
        if r["sql_id"] not in seen:
            seen[r["sql_id"]] = r["sql_text"]
    rows = [(sql_id, text) for sql_id, text in seen.items()]
    if not rows:
        rows = [("(no SQL captured for this snapshot pair)", "")]
    return ('<h3>Complete List of SQL Text</h3>\n'
            + _table(["SQL Id", "SQL Text"], rows,
                     "This table displays the full text for each SQL Id referenced above"))


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

    top_deltas = deltas[:top_n]
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT event_name, wait_class FROM mssql_wait_event_master
            WHERE tier = 'wait_type' AND event_name = ANY(%s)
        """, ([w for w, _ in top_deltas],))
        wait_classes = dict(cur.fetchall())

    rows = []
    for wait_type, delta_ms in top_deltas:
        pct = (delta_ms / total_ms) * 100
        wait_class = wait_classes.get(wait_type) or "Other/Uncategorized"
        rows.append((wait_type, wait_class, f"{delta_ms/1000:.1f}", f"{pct:.1f}%"))
    if not rows:
        rows = [("(no significant non-benign wait activity in this window)", "", "", "")]
    return (f'<h3>Top {top_n} Wait Types by Total Wait Time</h3>\n'
            + _table(["Wait Type", "Wait Class", "Time(s)", "% of Total"], rows))


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


def _fetch_top_sql(pg_conn, instance_id: int, begin_time, end_time, limit: int = 15) -> list:
    """
    One shared query backing all four "SQL ordered by..." sections --
    each one just sorts and formats this same dataset differently,
    rather than four near-identical joins. Aggregates across every
    PLAN for the same query (a query can have more than one plan) and
    every Query Store INTERVAL that OVERLAPS the snapshot window at
    all (iv.start_time < end_time AND iv.end_time > begin_time) --
    NOT "start_time falls strictly inside the window". Query Store's
    own intervals run on an independent clock (set by
    INTERVAL_LENGTH_MINUTES, not synchronized to DMV snapshot times),
    so an interval that legitimately overlaps the window can easily
    have started before it -- a strict "start_time >= begin_time"
    filter (an earlier, real bug in this function, found from a real
    report where every SQL section came back completely empty despite
    genuine query activity and heavy wait time in the same window)
    silently excluded exactly that overlap case.

    Elapsed/CPU/logical-reads are TOTALS across executions in the
    window (matching Oracle's own Elapsed Time (s) column semantics --
    the total contribution of that SQL during the snapshot interval,
    not a per-execution average), computed as avg_duration_us *
    count_executions summed across plans/intervals, then converted to
    the unit each section displays in.

    If more than one database is present for this instance in the
    window, results are combined across all of them (each row still
    carries its own database_name for the caller to note) rather than
    split into a separate report per database -- Oracle AWR is
    inherently single-database per report, but this project's own
    instances can span several; ranking "top queries on this instance"
    together is a reasonable, honest simplification of that difference,
    not a silent one (each row keeps database_name so nothing is hidden).
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT
                q.qs_query_id,
                rs.database_name,
                qt.query_sql_text,
                MAX(q.object_name) AS object_name,
                SUM(rs.count_executions) AS total_executions,
                SUM(rs.avg_duration_us * rs.count_executions) AS total_elapsed_us,
                SUM(rs.avg_cpu_time_us * rs.count_executions) AS total_cpu_us,
                SUM(rs.avg_logical_io_reads * rs.count_executions) AS total_logical_reads,
                SUM(rs.avg_physical_io_reads * rs.count_executions) AS total_physical_reads,
                SUM(rs.avg_rowcount * rs.count_executions) AS total_rows
            FROM mssql_qs_runtime_stats rs
            JOIN mssql_qs_plan p
              ON rs.instance_id = p.instance_id AND rs.database_name = p.database_name
             AND rs.qs_plan_id = p.qs_plan_id
            JOIN mssql_qs_query q
              ON p.instance_id = q.instance_id AND p.database_name = q.database_name
             AND p.qs_query_id = q.qs_query_id
            JOIN mssql_qs_query_text qt
              ON q.instance_id = qt.instance_id AND q.database_name = qt.database_name
             AND q.qs_query_text_id = qt.qs_query_text_id
            JOIN mssql_qs_interval iv
              ON rs.instance_id = iv.instance_id AND rs.database_name = iv.database_name
             AND rs.qs_interval_id = iv.qs_interval_id
            WHERE rs.instance_id = %s
              AND iv.start_time < %s
              AND (iv.end_time IS NULL OR iv.end_time > %s)
              AND q.is_internal_query IS NOT TRUE
            GROUP BY q.qs_query_id, rs.database_name, qt.query_sql_text
        """, (instance_id, end_time, begin_time))
        rows = cur.fetchall()

    results = []
    for (qs_query_id, db_name, sql_text, object_name, executions, elapsed_us,
         cpu_us, logical_reads, physical_reads, total_rows) in rows:
        executions = int(executions or 0)
        elapsed_us = float(elapsed_us or 0)
        cpu_us = float(cpu_us or 0)
        total_rows = float(total_rows or 0)
        results.append({
            "sql_id": f"q{qs_query_id}",  # Query Store's own id, prefixed since
                                          # it's purely numeric and Oracle's sql_id
                                          # column/parsers expect a short token, not
                                          # necessarily numeric-looking
            "database_name": db_name,
            "sql_text": (sql_text or "").strip(),
            "object_name": (object_name or "").strip(),  # stored procedure / object this
                                                           # query belongs to, resolved by
                                                           # the collector from object_id
            "executions": executions,
            "elapsed_time_s": elapsed_us / 1_000_000.0,
            "elapsed_time_per_exec_s": (elapsed_us / executions / 1_000_000.0) if executions else 0.0,
            "cpu_time_s": cpu_us / 1_000_000.0,
            "logical_reads": float(logical_reads or 0),
            "reads_per_exec": (float(logical_reads or 0) / executions) if executions else 0.0,
            "physical_reads": float(physical_reads or 0),
            "rows_processed": total_rows,
            "rows_per_exec": (total_rows / executions) if executions else 0.0,
        })
    return results


def _sql_text_preview(sql_text: str, max_len: int = 30) -> str:
    """Matches the sample AWR reports' own truncate-with-ellipsis style
    for the SQL Text column (e.g. "SELECT output FROM TABLE( DBMS...")."""
    one_line = " ".join(sql_text.split())
    return one_line[:max_len] + "..." if len(one_line) > max_len else one_line


def _build_sql_ordered_by_elapsed_time(top_sql: list) -> str:
    total_elapsed = sum(r["elapsed_time_s"] for r in top_sql) or 1.0
    total_cpu = sum(r["cpu_time_s"] for r in top_sql) or 1.0
    ranked = sorted(top_sql, key=lambda r: r["elapsed_time_s"], reverse=True)[:15]
    rows = [(
        f'{r["elapsed_time_s"]:.2f}', r["executions"], f'{r["elapsed_time_per_exec_s"]:.2f}',
        f'{100 * r["elapsed_time_s"] / total_elapsed:.2f}',
        f'{100 * r["cpu_time_s"] / r["elapsed_time_s"]:.2f}' if r["elapsed_time_s"] else "0.00",
        "0.00",  # %IO -- MSSQL's wait-category granularity (mssql_qs_wait_stats) doesn't
                 # cleanly isolate I/O wait per query the way Oracle's ash/io breakdown does;
                 # left as an honest 0.00 rather than a fudged estimate
        r["sql_id"], r["database_name"], r["object_name"] or "(ad hoc / no object)",
        _sql_text_preview(r["sql_text"]),
    ) for r in ranked]
    return ('<h3>SQL ordered by Elapsed Time</h3>\n'
            + _table(["Elapsed Time (s)", "Executions", "Elapsed Time per Exec (s)",
                      "%Total", "%CPU", "%IO", "SQL Id", "SQL Module", "Stored Procedure", "SQL Text"],
                     rows, "This table displays top SQL by elapsed time"))


def _build_sql_ordered_by_cpu_time(top_sql: list) -> str:
    total_cpu = sum(r["cpu_time_s"] for r in top_sql) or 1.0
    ranked = sorted(top_sql, key=lambda r: r["cpu_time_s"], reverse=True)[:15]
    rows = [(
        f'{r["cpu_time_s"]:.2f}', r["executions"],
        f'{(r["cpu_time_s"] / r["executions"]):.2f}' if r["executions"] else "0.00",
        f'{100 * r["cpu_time_s"] / total_cpu:.2f}',
        f'{100 * r["cpu_time_s"] / r["elapsed_time_s"]:.2f}' if r["elapsed_time_s"] else "0.00",
        "0.00",  # %IO -- same honest limitation noted in the Elapsed Time section above
        f'{r["elapsed_time_s"]:.2f}',
        r["sql_id"], r["database_name"], r["object_name"] or "(ad hoc / no object)",
        _sql_text_preview(r["sql_text"]),
    ) for r in ranked]
    return ('<h3>SQL ordered by CPU Time</h3>\n'
            + _table(["CPU Time (s)", "Executions", "CPU per Exec (s)",
                      "%Total", "%CPU", "%IO", "Elapsed Time (s)", "SQL Id", "SQL Module",
                      "Stored Procedure", "SQL Text"],
                     rows, "This table displays top SQL by CPU time"))


def _build_sql_ordered_by_executions(top_sql: list) -> str:
    ranked = sorted(top_sql, key=lambda r: r["executions"], reverse=True)[:15]
    rows = [(
        r["executions"], f'{r["elapsed_time_s"]:.2f}',
        f'{100 * r["cpu_time_s"] / r["elapsed_time_s"]:.2f}' if r["elapsed_time_s"] else "0.00",
        "0.00",  # %IO -- same honest limitation noted in the Elapsed Time section above
        f'{r["rows_processed"]:.0f}', f'{r["rows_per_exec"]:.1f}',
        r["sql_id"], r["database_name"], r["object_name"] or "(ad hoc / no object)",
        _sql_text_preview(r["sql_text"]),
    ) for r in ranked]
    return ('<h3>SQL ordered by Executions</h3>\n'
            + _table(["Executions", "Elapsed Time (s)", "%CPU", "%IO",
                      "Rows Processed", "Rows per Exec", "SQL Id", "SQL Module",
                      "Stored Procedure", "SQL Text"],
                     rows, "This table displays top SQL by number of executions"))


def _build_sql_ordered_by_gets(top_sql: list) -> str:
    """MSSQL's avg_logical_io_reads (logical page reads) is the direct
    analog to Oracle's "Gets" (logical reads / buffer gets) here."""
    total_reads = sum(r["logical_reads"] for r in top_sql) or 1.0
    total_elapsed = sum(r["elapsed_time_s"] for r in top_sql) or 1.0
    ranked = sorted(top_sql, key=lambda r: r["logical_reads"], reverse=True)[:15]
    rows = [(
        f'{r["logical_reads"]:.0f}', r["executions"], f'{r["reads_per_exec"]:.1f}',
        f'{100 * r["logical_reads"] / total_reads:.2f}',
        f'{100 * r["elapsed_time_s"] / total_elapsed:.2f}',
        f'{100 * r["cpu_time_s"] / r["elapsed_time_s"]:.2f}' if r["elapsed_time_s"] else "0.00",
        "0.00",
        r["sql_id"], r["database_name"], r["object_name"] or "(ad hoc / no object)",
        _sql_text_preview(r["sql_text"]),
    ) for r in ranked]
    return ('<h3>SQL ordered by Gets</h3>\n'
            + _table(["Buffer Gets", "Executions", "Gets per Exec", "%Total",
                      "Elapsed Time (s)", "%CPU", "%IO", "SQL Id", "SQL Module",
                      "Stored Procedure", "SQL Text"],
                     rows, "This table displays top SQL by logical reads (buffer gets)"))


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

    top_sql = _fetch_top_sql(pg_conn, instance_id, begin_info["snapshot_time"], end_info["snapshot_time"])
    db_names = sorted(set(r["database_name"] for r in top_sql))
    db_name_for_summary = db_names[0] if len(db_names) == 1 else (
        ", ".join(db_names) if db_names else None
    )

    sections = [
        _build_database_summary(begin_info, db_name_for_summary),
        _build_snapshot_summary(begin_info, end_info),
        _build_load_profile(pg_conn, instance_id, begin_snapshot_id, end_snapshot_id, elapsed_seconds, top_sql),
        _build_instance_efficiency(pg_conn, begin_snapshot_id, end_snapshot_id),
        _build_wait_classes(pg_conn, instance_id, begin_snapshot_id, end_snapshot_id, elapsed_seconds),
        _build_top_wait_types(pg_conn, instance_id, begin_snapshot_id, end_snapshot_id, elapsed_seconds),
        _build_memory_statistics(pg_conn, end_snapshot_id),
        _build_io_profile(pg_conn, begin_snapshot_id, end_snapshot_id, elapsed_seconds),
        _build_io_stalls_by_file_type(pg_conn, begin_snapshot_id, end_snapshot_id),
        _build_sql_ordered_by_elapsed_time(top_sql),
        _build_sql_ordered_by_cpu_time(top_sql),
        _build_sql_ordered_by_gets(top_sql),
        _build_sql_ordered_by_executions(top_sql),
        _build_blocking_summary(pg_conn, instance_id, end_snapshot_id),
        _build_complete_sql_text(top_sql),
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
