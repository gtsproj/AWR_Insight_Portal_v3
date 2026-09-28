"""
modules/mssql/sqlwr_tempdb_sessions_parser.py

Parses the FIRST table of the SQLWR report's "TempDB Usage" section -- the top sessions by
TempDB space (at most 15 shown) -- into mssql_sqlwr_tempdb_sessions. The second table
(currently-executing tasks) is handled by sqlwr_tempdb_tasks_parser.py; the two tables are
independent, and either can be a "no data" placeholder while the other has rows.

POINT-IN-TIME section: read at the END snapshot only -- not a delta and not a window.
The values describe TempDB at the instant of the end snapshot, so snapshot_time is that
instant. begin_snapshot_id still keys the report (begin -> end); the raw sample sits under
the END snapshot_id. To reach it, join mssql_dmv_snapshot on (instance_id, snapshot_time).
See Documentation/MSSQL_SQLWR_Parsed_Tables_Conventions.md.

Notes
-----
* The figures are CUMULATIVE over each session's whole lifetime (allocations since the
  session connected), not what it is using right now -- hence "point-in-time" describes
  when the total was read, not a rate. A session id can be reused after a disconnect, so
  session_id identifies a session only within one report.
* user_objects_mb = explicit temp tables / table variables; internal_objects_mb = engine
  work areas (sorts, hash spills, worktables). Both are shown in MB to two decimals, i.e.
  8 KB pages * 8 / 1024, so a value below 0.005 MB shows as 0.00.
* login_name is NULL when the report shows it blank; it may contain a backslash
  (DOMAIN\\user, NT SERVICE\\...) which is stored as is.
"""

import sys
import warnings

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, get_section_tables,
    is_section_missing_or_empty, subtable_is_empty, read_raw_rows, insert_records,
    assign_row_hashes, clean_number, text_or_none,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_tempdb_sessions_parser")

SECTION_HEADING = "TempDB Usage"
TABLE_NAME = "mssql_sqlwr_tempdb_sessions"


def _int(value):
    n = clean_number(value)
    if n is None:
        return None
    return int(n) if float(n).is_integer() else n


def parse_tempdb_sessions(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)
    tables = get_section_tables(soup, SECTION_HEADING)
    if not tables:                                           # section absent from this (older) report
        is_section_missing_or_empty(None, SECTION_HEADING, TABLE_NAME)
        return []
    if subtable_is_empty(tables[0], f"{SECTION_HEADING} (sessions table)", TABLE_NAME):
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
                     f"instance={metadata['instance']!r} -- skipping {SECTION_HEADING} (sessions)")
        return []

    records = []
    for row in read_raw_rows(tables[0]):
        session_id = _int(row.get("Session ID"))
        if session_id is None:
            continue
        records.append({
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "session_id": session_id,
            "login_name": text_or_none(row.get("Login")),
            "user_objects_mb": clean_number(row.get("User Objects (MB)")),
            "internal_objects_mb": clean_number(row.get("Internal Objects (MB)")),
            "begin_snapshot_id": metadata["begin_snap"],
        })
    assign_row_hashes(records)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} (sessions) record(s) from {filepath}")
    return records


def insert_tempdb_sessions(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "session_id", "login_name",
                 "user_objects_mb", "internal_objects_mb", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_tempdb_sessions(parse_tempdb_sessions(_target))
    else:
        logger.error("No filepath provided")
