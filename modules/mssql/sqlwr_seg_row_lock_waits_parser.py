"""
modules/mssql/sqlwr_seg_row_lock_waits_parser.py

Parses the SQLWR report's Top Objects by Row Lock Waits section (one row per
table/index that had row-lock waits: wait count and total wait ms) into
mssql_sqlwr_seg_row_lock_waits.

This section is legitimately empty in any window with no row-lock contention
(the report then shows a "(no row lock waits recorded ...)" placeholder row),
so an empty result here is normal, not an error.

The report's own "Database" column is stored as seg_database_name, kept
distinct from the table's report-level database_name.
"""

import sys
import warnings

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, get_section_table,
    is_section_missing_or_empty, insert_records, row_hash, clean_number,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_seg_row_lock_waits_parser")

SECTION_HEADING = "Top Objects by Row Lock Waits"
TABLE_NAME = "mssql_sqlwr_seg_row_lock_waits"


def _text(value):
    s = str(value).strip()
    return None if s == "" or s.lower() == "nan" else s


def parse_seg_row_lock_waits(filepath: str, pg_conn=None) -> list:
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
        seg_db = _text(row.get("Database"))
        obj = _text(row.get("Object"))
        if seg_db is None and obj is None:
            continue
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "seg_database_name": seg_db,
            "object_name": obj,
            "index_name": _text(row.get("Index")),
            "segment_type": _text(row.get("Segment Type")),
            "row_lock_waits": clean_number(row.get("Row Lock Waits")),
            "row_lock_wait_ms": clean_number(row.get("Row Lock Wait (ms)")),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_seg_row_lock_waits(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "seg_database_name",
                 "object_name", "index_name", "segment_type", "row_lock_waits",
                 "row_lock_wait_ms", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_seg_row_lock_waits(parse_seg_row_lock_waits(_target))
    else:
        logger.error("No filepath provided")
