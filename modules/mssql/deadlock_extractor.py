"""
modules/mssql/deadlock_extractor.py
=====================================
Extracts deadlock graphs from the system_health Extended Events
session and stores them in mssql_deadlock_events/mssql_deadlock_processes.

Reads from the session's FILE target, not the ring buffer -- confirmed
against a real SQL Server 2022 source (our exact version floor) that
the ring buffer reliably returns ZERO rows for xml_deadlock_report
events on 2022, even when the events are genuinely captured and
visible in the file target. Using the ring buffer, as this project's
own original design doc (Section 9.1.4) assumed, would have silently
produced empty results on every real run -- caught before writing
this collector, not after.

The path to the file target isn't hardcoded -- it's discovered
dynamically from sys.dm_xe_session_targets at collection time, then
used to build a wildcard pattern for sys.fn_xe_file_target_read_file,
so this works on any instance without configuration.

The extraction logic (XQuery structure, process shredding via
CROSS APPLY, victim/survivor classification, exact-DML-statement
fallback logic) is directly adapted from Ganesh's own three deadlock-
analysis scripts, not written from scratch -- those scripts were
already built, tested, and used for real RCA work on the production
MERC database. The deadlock_cause classification (Update/Exclusive
collision, Read-Write/RCSI conflict, missing-index table lock,
cross-resource cyclic lock) is his own CASE-statement logic,
reimplemented here in Python so it runs at collection time rather
than as a separate manual analysis step.

Licensing: checks is_db_type_licensed("mssql"), same gate as the
other two collectors.
"""

import os
import sys
import re

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'modules'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from logger_utils import get_logger
from utils import row_hash
from connection import mssql_connect, resolve_instance_id

logger = get_logger('mssql_deadlock_extractor')


def run_deadlock_collection(mssql_cfg: dict) -> dict:
    """
    Main entry point. Discovers the system_health file target's
    current path, reads every deadlock event from it (the file target
    retains history across a configurable rollover, unlike the ring
    buffer's limited in-memory window), classifies each event's root
    cause, and stores new events (row_hash-deduped against
    already-collected ones).

    Returns {"events_collected": N, "errors": [...]}.
    """
    from license_engine import is_db_type_licensed
    if not is_db_type_licensed("mssql"):
        logger.info("MS SQL Server not licensed -- skipping deadlock collection")
        return {"events_collected": 0, "errors": ["mssql not licensed"]}

    summary = {"events_collected": 0, "errors": []}

    host_name = mssql_cfg["host"]
    instance_name = mssql_cfg.get("instance_name", "MSSQLSERVER")

    try:
        instance_id = resolve_instance_id(host_name, instance_name)
    except Exception as e:
        logger.error(f"Instance resolution failed: {e}")
        summary["errors"].append(str(e))
        return summary

    try:
        conn = mssql_connect({**mssql_cfg, "database": mssql_cfg.get("database", "master")})
    except Exception as e:
        logger.error(f"Could not connect to instance: {e}")
        summary["errors"].append(f"connect failed: {e}")
        return summary

    try:
        wildcard_path = _discover_system_health_file_pattern(conn)
        if not wildcard_path:
            logger.warning("Could not discover system_health file target path -- "
                            "the session may be stopped or reconfigured")
            summary["errors"].append("system_health file target path not found")
            return summary

        events = _extract_deadlock_events(conn, wildcard_path)

        from db import get_db_connection
        pg_conn = get_db_connection()
        try:
            for event in events:
                if _store_deadlock_event(pg_conn, instance_id, event):
                    summary["events_collected"] += 1
            pg_conn.commit()
        except Exception:
            pg_conn.rollback()
            raise
        finally:
            pg_conn.close()

    except Exception as e:
        logger.error(f"Deadlock collection failed: {e}")
        summary["errors"].append(str(e))
    finally:
        try:
            conn.close()
        except Exception:
            pass

    return summary


def _discover_system_health_file_pattern(conn) -> str:
    """
    Finds the system_health session's current file target path and
    derives a wildcard pattern (directory + 'system_health*.xel') for
    sys.fn_xe_file_target_read_file -- not hardcoded, works on any
    instance regardless of where SQL Server's log directory actually is.
    """
    with conn.cursor() as cur:
        cur.execute("""
            SELECT CAST(t.target_data AS XML).value('(EventFileTarget/File/@name)[1]', 'NVARCHAR(500)')
            FROM sys.dm_xe_sessions s
            JOIN sys.dm_xe_session_targets t ON s.address = t.event_session_address
            WHERE s.name = 'system_health' AND t.target_name = 'event_file'
        """)
        row = cur.fetchone()
    if not row or not row[0]:
        return None
    current_file = row[0]
    # current_file looks like 'D:\...\MSSQL\Log\system_health_0_133...xel' --
    # derive directory + wildcard so fn_xe_file_target_read_file picks up
    # every rolled-over file, not just the current one.
    last_sep = max(current_file.rfind('\\'), current_file.rfind('/'))
    if last_sep == -1:
        return None
    directory = current_file[:last_sep + 1]
    return directory + "system_health*.xel"


def _extract_deadlock_events(conn, wildcard_path: str) -> list:
    """
    Reads every deadlock event from the file target and shreds every
    participating process via CROSS APPLY -- adapted directly from
    Ganesh's third script, which explicitly handles more than 2
    processes per deadlock rather than assuming exactly 2.

    Returns a list of dicts: {"deadlock_time": ..., "victim_id": ...,
    "contested_table": ..., "contested_index": ..., "lock_mode_1": ...,
    "lock_mode_2": ..., "deadlock_graph_xml": ..., "processes": [...]}
    where each process dict has role/spid/client_app/login_name/
    host_name/isolation_level/tran_count/input_buffer/executing_proc/
    executing_line/exact_dml_statement/caller_proc/caller_line.
    """
    with conn.cursor() as cur:
        cur.execute("""
            ;WITH RawXML AS (
                SELECT CAST(event_data AS XML) AS xdoc
                FROM sys.fn_xe_file_target_read_file(?, NULL, NULL, NULL)
                WHERE object_name = 'xml_deadlock_report'
            ),
            DeadlockEvents AS (
                SELECT
                    xdoc.value('(event/@timestamp)[1]', 'DATETIME2') AS deadlock_time,
                    xdoc.query('(event/data[@name="xml_report"]/value/deadlock)[1]') AS dg
                FROM RawXML
            )
            SELECT
                de.deadlock_time,
                de.dg.value('(deadlock/victim-list/victimProcess/@id)[1]', 'VARCHAR(50)') AS victim_id,
                de.dg.value('(deadlock/resource-list/*/@objectname)[1]', 'VARCHAR(300)') AS contested_table,
                de.dg.value('(deadlock/resource-list/*/@indexname)[1]', 'VARCHAR(300)') AS contested_index,
                de.dg.value('(deadlock/resource-list//@mode)[1]', 'VARCHAR(20)') AS lock_mode_1,
                de.dg.value('(deadlock/resource-list//@mode)[2]', 'VARCHAR(20)') AS lock_mode_2,
                CAST(de.dg AS NVARCHAR(MAX)) AS deadlock_graph_xml,

                proc_node.process_xml.value('@id', 'VARCHAR(50)') AS process_id,
                proc_node.process_xml.value('@spid', 'INT') AS spid,
                proc_node.process_xml.value('@clientapp', 'VARCHAR(200)') AS client_app,
                proc_node.process_xml.value('@loginname', 'VARCHAR(100)') AS login_name,
                proc_node.process_xml.value('@hostname', 'VARCHAR(200)') AS host_name,
                proc_node.process_xml.value('@isolationlevel', 'VARCHAR(100)') AS isolation_level,
                proc_node.process_xml.value('@trancount', 'INT') AS tran_count,
                proc_node.process_xml.value('(inputbuf)[1]', 'NVARCHAR(MAX)') AS input_buffer,
                proc_node.process_xml.value('(executionStack/frame/@procname)[1]', 'VARCHAR(300)') AS frame1_procname,
                proc_node.process_xml.value('(executionStack/frame/@line)[1]', 'INT') AS frame1_line,
                proc_node.process_xml.value('string((executionStack/frame)[1])', 'NVARCHAR(MAX)') AS frame1_text,
                proc_node.process_xml.value('(executionStack/frame/@procname)[2]', 'VARCHAR(300)') AS frame2_procname,
                proc_node.process_xml.value('(executionStack/frame/@line)[2]', 'INT') AS frame2_line

            FROM DeadlockEvents de
            CROSS APPLY de.dg.nodes('deadlock/process-list/process') AS proc_node(process_xml)
            ORDER BY de.deadlock_time, process_id
        """, wildcard_path)
        rows = cur.fetchall()

    events = {}
    for r in rows:
        (deadlock_time, victim_id, contested_table, contested_index, lock_mode_1, lock_mode_2,
         deadlock_graph_xml, process_id, spid, client_app, login_name, host_name,
         isolation_level, tran_count, input_buffer, frame1_procname, frame1_line,
         frame1_text, frame2_procname, frame2_line) = r

        key = (deadlock_time, contested_table, contested_index)  # groups rows belonging to the same event
        if key not in events:
            events[key] = {
                "deadlock_time": deadlock_time, "victim_id": victim_id,
                "contested_table": contested_table, "contested_index": contested_index,
                "lock_mode_1": lock_mode_1, "lock_mode_2": lock_mode_2,
                "deadlock_graph_xml": deadlock_graph_xml, "processes": [],
            }

        exact_dml = (frame1_text or "").strip() or (input_buffer or "").strip()
        events[key]["processes"].append({
            "process_id": process_id,
            "role": "VICTIM" if process_id == victim_id else "SURVIVOR",
            "spid": spid, "client_app": client_app, "login_name": login_name,
            "host_name": host_name, "isolation_level": isolation_level,
            "tran_count": tran_count, "input_buffer": input_buffer,
            "executing_proc": frame1_procname, "executing_line": frame1_line,
            "exact_dml_statement": exact_dml,
            "caller_proc": frame2_procname, "caller_line": frame2_line,
        })

    return list(events.values())


def classify_deadlock_cause(lock_mode_1: str, lock_mode_2: str, contested_index: str) -> str:
    """
    Same classification logic as Ganesh's own analysis script's
    Classified CTE, reimplemented in Python so it runs automatically
    at collection time. Categories and their meaning, unchanged from
    his original:
      - Update/Exclusive lock collision: both sides held/wanted U or X
      - Read-Write conflict (RCSI not enabled?): one side S, other X/U --
        classic reader-vs-writer deadlock, often avoidable with
        READ_COMMITTED_SNAPSHOT isolation
      - Table-level lock (missing covering index): no index involved at
        all, meaning the lock was table-level -- usually because no
        usable index existed for the query's access pattern
      - Cross-resource cyclic lock (tx order mismatch): none of the
        above -- most often two transactions touching the same
        resources in a different ORDER from each other
    """
    m1 = (lock_mode_1 or "").upper()
    m2 = (lock_mode_2 or "").upper()

    if m1 in ("U", "X") and m2 in ("U", "X"):
        return "Update/Exclusive lock collision"
    if (m1 == "S" and m2 in ("X", "U")) or (m1 in ("X", "U") and m2 == "S"):
        return "Read-Write conflict (RCSI not enabled?)"
    if not contested_index:
        return "Table-level lock (missing covering index)"
    return "Cross-resource cyclic lock (tx order mismatch)"


def _store_deadlock_event(pg_conn, instance_id: int, event: dict) -> bool:
    """Stores one deadlock event + its processes. Returns True if this
    was a genuinely new event (not already collected)."""
    deadlock_cause = classify_deadlock_cause(event["lock_mode_1"], event["lock_mode_2"], event["contested_index"])

    hash_input = {
        "deadlock_time": str(event["deadlock_time"]),
        "contested_table": event["contested_table"],
        "contested_index": event["contested_index"],
        "process_ids": ",".join(sorted(p["process_id"] or "" for p in event["processes"])),
    }
    event_hash = row_hash(hash_input)

    with pg_conn.cursor() as pg_cur:
        pg_cur.execute(
            "SELECT id FROM mssql_deadlock_events WHERE instance_id = %s AND row_hash = %s",
            (instance_id, event_hash)
        )
        if pg_cur.fetchone():
            return False  # already collected

        pg_cur.execute("""
            INSERT INTO mssql_deadlock_events
                (instance_id, deadlock_time, victim_process_id, process_count,
                 contested_table, contested_index, lock_mode_1, lock_mode_2,
                 deadlock_cause, deadlock_graph_xml, row_hash)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (instance_id, event["deadlock_time"], event["victim_id"], len(event["processes"]),
              event["contested_table"], event["contested_index"], event["lock_mode_1"],
              event["lock_mode_2"], deadlock_cause, event["deadlock_graph_xml"], event_hash))
        event_id = pg_cur.fetchone()[0]

        for p in event["processes"]:
            pg_cur.execute("""
                INSERT INTO mssql_deadlock_processes
                    (deadlock_event_id, process_id, role, spid, client_app, login_name,
                     host_name, isolation_level, tran_count, input_buffer,
                     executing_proc, executing_line, exact_dml_statement,
                     caller_proc, caller_line)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (event_id, p["process_id"], p["role"], p["spid"], p["client_app"], p["login_name"],
                  p["host_name"], p["isolation_level"], p["tran_count"], p["input_buffer"],
                  p["executing_proc"], p["executing_line"], p["exact_dml_statement"],
                  p["caller_proc"], p["caller_line"]))

    return True


# ══════════════════════════════════════════════════════════════════
# CLI ENTRY POINT
# ══════════════════════════════════════════════════════════════════

def _main():
    import argparse
    import getpass

    parser = argparse.ArgumentParser(
        description="MS SQL deadlock collector -- extracts deadlock graphs from the "
                     "system_health Extended Events session's file target."
    )
    parser.add_argument("--host", required=True, help="SQL Server host name/IP")
    parser.add_argument("--port", type=int, default=None, help="Port (omit for default 1433)")
    parser.add_argument("--instance-name", default="MSSQLSERVER",
                         help="Named instance (default: MSSQLSERVER, i.e. the default instance)")
    parser.add_argument("--trusted-connection", action="store_true",
                         help="Use Windows Authentication instead of a SQL Server login.")
    parser.add_argument("--username", default=None,
                         help="SQL Server login (SQL auth). Required unless --trusted-connection is set.")
    parser.add_argument("--password", default=None,
                         help="SQL Server password. Prompted securely if omitted.")
    args = parser.parse_args()

    if not args.trusted_connection and not args.username:
        parser.error("--username is required unless --trusted-connection is set")

    cfg = {"host": args.host, "instance_name": args.instance_name}
    if args.port:
        cfg["port"] = args.port
    if args.trusted_connection:
        cfg["trusted_connection"] = True
    else:
        password = args.password or getpass.getpass(f"Password for {args.username}@{args.host}: ")
        cfg["username"] = args.username
        cfg["password"] = password

    print(f"\n{'='*60}")
    print(f"MS SQL Deadlock Collector")
    print(f"{'='*60}")
    print(f"Host:      {args.host}")
    print(f"Instance:  {args.instance_name}")
    print(f"Auth:      {'Windows (trusted connection)' if args.trusted_connection else f'SQL Server login ({args.username})'}")
    print(f"{'='*60}\n")

    result = run_deadlock_collection(cfg)

    print(f"\n{'='*60}")
    print(f"RESULT")
    print(f"{'='*60}")
    print(f"New deadlock events collected: {result['events_collected']}")
    if result["errors"]:
        print(f"Errors:")
        for e in result["errors"]:
            print(f"  - {e}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    _main()
