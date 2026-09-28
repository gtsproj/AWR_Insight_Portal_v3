"""
modules/mssql/sqlwr_tempdb_tasks_parser.py

Parses the SECOND table of the SQLWR report's "TempDB Usage" section -- the
currently-executing tasks that are allocating TempDB space right now (at most 15 shown)
-- into mssql_sqlwr_tempdb_tasks. The first table (sessions) is handled by
sqlwr_tempdb_sessions_parser.py; the two tables are independent, and either can be a
"no data" placeholder while the other has rows.

POINT-IN-TIME section: read at the END snapshot only -- not a delta and not a window.
It lists what was executing at the instant of the end snapshot, so an empty table means
"no task was allocating TempDB at that instant", NOT "none did during the window" -- and
is by far the usual state. snapshot_time is that instant. begin_snapshot_id still keys the
report (begin -> end); the raw sample sits under the END snapshot_id. To reach it, join
mssql_dmv_snapshot on (instance_id, snapshot_time). See
Documentation/MSSQL_SQLWR_Parsed_Tables_Conventions.md.

Duplicates, and a known limit upstream of this parser
-----------------------------------------------------
The report shows one row per (session, request). The collector stores at most ONE row per
(snapshot, session, request) -- a unique constraint with ON CONFLICT DO NOTHING -- so the
report cannot currently contain two rows with the same session and request, and rows
identical in every value cannot arise. assign_row_hashes() is still applied as a guard so
that, if that ever changed, repeated rows would be numbered instead of silently dropped.

KNOWN LIMIT (collector, not this parser): sys.dm_db_task_space_usage returns one row per
TASK (per exec_context_id), and a parallel query runs several tasks under the SAME
(session, request). The collector inserts each task's row with ON CONFLICT DO NOTHING, so
only the first task returned for a request is kept and the other workers' allocations are
discarded. The Allocated / Deallocated figures for a parallel request are therefore ONE
worker's share, understated relative to the request total. Summing the DMV per
(session_id, request_id) at collection time would fix it. Until then, read these numbers
as a lower bound for parallel requests.

Only internal-object allocations are listed (engine work areas: sorts, hash spills,
worktables), in MB to two decimals. request_id is 0 for a session's first request.
"""

import sys
import warnings

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, get_section_tables,
    is_section_missing_or_empty, subtable_is_empty, read_raw_rows, insert_records,
    assign_row_hashes, clean_number,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_tempdb_tasks_parser")

SECTION_HEADING = "TempDB Usage"
TABLE_NAME = "mssql_sqlwr_tempdb_tasks"


def _int(value):
    n = clean_number(value)
    if n is None:
        return None
    return int(n) if float(n).is_integer() else n


def parse_tempdb_tasks(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)
    tables = get_section_tables(soup, SECTION_HEADING)
    if not tables:                                           # section absent from this (older) report
        is_section_missing_or_empty(None, SECTION_HEADING, TABLE_NAME)
        return []
    if len(tables) < 2:
        logger.warning(f"{SECTION_HEADING}: expected 2 tables, found {len(tables)} -- tasks table not parsed")
        return []
    if subtable_is_empty(tables[1], f"{SECTION_HEADING} (tasks table)", TABLE_NAME):
        return []

    own_conn = pg_conn is None
    if own_conn:
        from sqlwr_parser_utils import get_db_connection
        pg_conn = get_db_connection()
    try:
        instance_id = resolve_instance_id(pg_conn, metadata["host_name"], metadata["instance"])
    finally:
        if own_conn:
            pg_conn.close()

    if instance_id is None:
        logger.error(f"Could not resolve instance_id for host={metadata['host_name']!r} "
                     f"instance={metadata['instance']!r} -- skipping {SECTION_HEADING} (tasks)")
        return []

    records = []
    for row in read_raw_rows(tables[1]):
        session_id = _int(row.get("Session ID"))
        if session_id is None:
            continue
        records.append({
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "session_id": session_id,
            "request_id": _int(row.get("Request ID")),
            "allocated_mb": clean_number(row.get("Allocated (MB)")),
            "deallocated_mb": clean_number(row.get("Deallocated (MB)")),
            "begin_snapshot_id": metadata["begin_snap"],
        })
    assign_row_hashes(records)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} (tasks) record(s) from {filepath}")
    return records


def insert_tempdb_tasks(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "session_id", "request_id",
                 "allocated_mb", "deallocated_mb", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_tempdb_tasks(parse_tempdb_tasks(_target))
    else:
        logger.error("No filepath provided")
