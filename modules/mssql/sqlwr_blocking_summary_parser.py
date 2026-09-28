"""
modules/mssql/sqlwr_blocking_summary_parser.py

Parses the SQLWR report's "Blocking Summary (at End Snapshot)" section (one row
per blocked session, longest wait first) into mssql_sqlwr_blocking_summary.

This section is a point-in-time picture, not a delta: it lists the sessions that
were blocked at the moment the END snapshot was taken, which is why
snapshot_time is the report's end-snapshot time. A blocking chain appears as
several rows (a session can be both blocked and a blocker). The section is empty
whenever nothing was blocked at that instant -- the normal case, so "nothing to
insert" is not a problem.

Column notes:
* session_id / blocked_by are integer session ids (SPIDs).
* blocked_object is the table the wait is on; it is empty (NULL) for waits that
  aren't on a nameable object. It carries no schema prefix (unlike the Top
  Objects sections, which show "dbo.name").
* blocked_database_name is the report row's own "Database" cell, kept separate
  from the table's report-level database_name.
"""

import sys
import warnings

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, get_section_table,
    is_section_missing_or_empty, insert_records, row_hash, clean_number,
    text_or_none as _text,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_blocking_summary_parser")

SECTION_HEADING = "Blocking Summary (at End Snapshot)"
TABLE_NAME = "mssql_sqlwr_blocking_summary"


def _int(value):
    """Whole-number cell -> int (session ids); anything non-numeric -> None."""
    n = clean_number(value)
    if n is None:
        return None
    return int(n) if float(n).is_integer() else n


def parse_blocking_summary(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)
    df = get_section_table(soup, SECTION_HEADING)
    if is_section_missing_or_empty(df, SECTION_HEADING, TABLE_NAME):
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
                     f"instance={metadata['instance']!r} -- skipping {SECTION_HEADING}")
        return []

    records = []
    for _, row in df.iterrows():
        session_id = _int(row.get("Session"))
        if session_id is None:
            continue
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "session_id": session_id,
            "blocked_by": _int(row.get("Blocked By")),
            "wait_type": _text(row.get("Wait Type")),
            "wait_time_s": clean_number(row.get("Wait Time(s)")),
            "resource_type": _text(row.get("Resource Type")),
            "blocked_object": _text(row.get("Object")),
            "blocked_database_name": _text(row.get("Database")),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_blocking_summary(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "session_id", "blocked_by",
                 "wait_type", "wait_time_s", "resource_type", "blocked_object",
                 "blocked_database_name", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_blocking_summary(parse_blocking_summary(_target))
    else:
        logger.error("No filepath provided")
