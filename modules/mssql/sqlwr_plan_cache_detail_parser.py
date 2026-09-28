"""
modules/mssql/sqlwr_plan_cache_detail_parser.py

Parses the SECOND table of the SQLWR report's "Plan Cache Health" section -- the top
cached plans by reuse count (at most 15 shown) -- into mssql_sqlwr_plan_cache_detail. The
first table (summary) is handled by sqlwr_plan_cache_summary_parser.py; the two tables are
independent, and either can be a "no data" placeholder while the other has rows (report
sqlwr_1_70_71 is exactly that: no summary, 15 plans).

POINT-IN-TIME section: read at the END snapshot only -- not a delta and not a window.
The values describe the plan cache at the instant of the end snapshot, so snapshot_time is
that instant. begin_snapshot_id still keys the report (begin -> end); the raw sample sits
under the END snapshot_id. To reach it, join mssql_dmv_snapshot on (instance_id,
snapshot_time). See Documentation/MSSQL_SQLWR_Parsed_Tables_Conventions.md.

Notes
-----
* query_hash is read from the raw HTML cell as TEXT. It is 16 hex characters and can be
  all digits ("0123456789012345"); a pandas read would turn an all-numeric column into
  integers and silently drop the leading zero, changing the hash.
* query_hash is the plan cache's query_hash (a hash of the statement text), NOT Query
  Store's query_id -- the two are different identifiers and do not join to the SQL
  ordered-by tables' sql_id. Several cached plans can share one query_hash.
* Plan Type is the cache object type as SQL Server reports it (e.g. Proc, Adhoc, Prepared).
* CPU time is shown in seconds, size in KB, exactly as the report prints them.
* Rows are numbered when several are identical in every value (assign_row_hashes) so that
  none is silently dropped.
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
logger = get_logger("sqlwr_plan_cache_detail_parser")

SECTION_HEADING = "Plan Cache Health"
TABLE_NAME = "mssql_sqlwr_plan_cache_detail"


def parse_plan_cache_detail(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)
    tables = get_section_tables(soup, SECTION_HEADING)
    if not tables:                                           # section absent from this (older) report
        is_section_missing_or_empty(None, SECTION_HEADING, TABLE_NAME)
        return []
    if len(tables) < 2:
        logger.warning(f"{SECTION_HEADING}: expected 2 tables, found {len(tables)} -- detail table not parsed")
        return []
    if subtable_is_empty(tables[1], f"{SECTION_HEADING} (detail table)", TABLE_NAME):
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
                     f"instance={metadata['instance']!r} -- skipping {SECTION_HEADING} (detail)")
        return []

    records = []
    for row in read_raw_rows(tables[1]):
        query_hash = text_or_none(row.get("Query Hash"))
        if query_hash is None:
            continue
        records.append({
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "query_hash": query_hash,
            "plan_type": text_or_none(row.get("Plan Type")),
            "use_count": clean_number(row.get("Use Count")),
            "size_kb": clean_number(row.get("Size (KB)")),
            "executions": clean_number(row.get("Executions")),
            "cpu_time_s": clean_number(row.get("CPU Time (s)")),
            "logical_reads": clean_number(row.get("Logical Reads")),
            "begin_snapshot_id": metadata["begin_snap"],
        })
    assign_row_hashes(records)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} (detail) record(s) from {filepath}")
    return records


def insert_plan_cache_detail(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "query_hash", "plan_type",
                 "use_count", "size_kb", "executions", "cpu_time_s", "logical_reads",
                 "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_plan_cache_detail(parse_plan_cache_detail(_target))
    else:
        logger.error("No filepath provided")
