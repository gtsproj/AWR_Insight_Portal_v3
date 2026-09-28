"""
modules/mssql/sqlwr_io_profile_parser.py

Parses the SQLWR report's IO Profile section (one row per database file,
top 15 by total I/O) into mssql_sqlwr_io_profile.

The report's own "Database" column is stored as io_database_name -- the
table's separate database_name column is the report-level database (from the
Database Summary), a different thing that every parsed table carries.
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
logger = get_logger("sqlwr_io_profile_parser")

SECTION_HEADING = "IO Profile"
TABLE_NAME = "mssql_sqlwr_io_profile"


def _text(value):
    """Cell text, or None for an empty/NaN cell."""
    s = str(value).strip()
    return None if s == "" or s.lower() == "nan" else s


def parse_io_profile(filepath: str, pg_conn=None) -> list:
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
        io_db = _text(row.get("Database"))
        file_name = _text(row.get("File"))
        if io_db is None and file_name is None:
            continue
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "io_database_name": io_db,
            "file_name": file_name,
            "reads_per_sec": clean_number(row.get("Reads/s")),
            "writes_per_sec": clean_number(row.get("Writes/s")),
            "mb_read": clean_number(row.get("MB Read")),
            "mb_written": clean_number(row.get("MB Written")),
            "avg_read_latency_ms": clean_number(row.get("Avg Read Latency (ms)")),
            "avg_write_latency_ms": clean_number(row.get("Avg Write Latency (ms)")),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_io_profile(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "io_database_name", "file_name",
                 "reads_per_sec", "writes_per_sec", "mb_read", "mb_written",
                 "avg_read_latency_ms", "avg_write_latency_ms", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_io_profile(parse_io_profile(_target))
    else:
        logger.error("No filepath provided")
