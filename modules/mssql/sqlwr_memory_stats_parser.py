"""
modules/mssql/sqlwr_memory_stats_parser.py

Parses the SQLWR report's Memory Statistics section (a 2-column
"Metric" / "Value (MB)" table) into mssql_sqlwr_memory_stats.

Stores values exactly as the report shows them. Note that when SQL Server's
max_server_memory is left at its default ("unlimited", 2147483647 MB), the
report's "Memory Allocated" and the derived "Free within Allocated" rows show
that sentinel-sized number rather than a real allocation -- that is a property
of the report's content, not something this parser should silently rewrite, so
anything reading this table (dashboards, materialized views) needs to treat
values at/near 2147483647 as "unlimited", not as megabytes.
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
logger = get_logger("sqlwr_memory_stats_parser")

SECTION_HEADING = "Memory Statistics"
TABLE_NAME = "mssql_sqlwr_memory_stats"


def parse_memory_stats(filepath: str, pg_conn=None) -> list:
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
        metric = str(row.get("Metric", "")).strip()
        if not metric or metric.lower() == "nan":
            continue
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "metric": metric,
            "value_mb": clean_number(row.get("Value (MB)")),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_memory_stats(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "metric",
                 "value_mb", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_memory_stats(parse_memory_stats(_target))
    else:
        logger.error("No filepath provided")
