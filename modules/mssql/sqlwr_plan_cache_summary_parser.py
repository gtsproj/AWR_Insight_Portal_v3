"""
modules/mssql/sqlwr_plan_cache_summary_parser.py

Parses the FIRST table of the SQLWR report's "Plan Cache Health" section -- the
plan cache summary (total / single-use / ad hoc plan counts and memory) -- into
mssql_sqlwr_plan_cache_summary. The section's second table (top cached plans) is
handled by sqlwr_plan_cache_detail_parser.py; the two tables are independent, and
either can be a "no data" placeholder while the other has rows.

POINT-IN-TIME section: read at the END snapshot only -- not a delta and not a window.
The values describe the plan cache at the instant of the end snapshot, so snapshot_time is
that instant. begin_snapshot_id still keys the report (begin -> end); the raw sample sits
under the END snapshot_id. To reach it, join mssql_dmv_snapshot on (instance_id,
snapshot_time). See Documentation/MSSQL_SQLWR_Parsed_Tables_Conventions.md.

The report shows this table display-formatted, and the parser turns it back into numbers:

    Metric                              Count          Memory
    Total Cached Plans                  158            35.8 MB
    Single-Use Plans (never reused)     33 (20.9%)     8.3 MB
    Ad Hoc Plans                        24             1.8 MB

    -> plan_count = 158 / 33 / 24;  pct_of_total = NULL / 20.9 / NULL;  memory_mb = 35.8 / 8.3 / 1.8

pct_of_total is only reported for the single-use row (its share of total plans, one
decimal); it is NULL for the others. `metric` is stored exactly as the report words it. A
Count or Memory cell that does not match the expected pattern is logged as a WARNING and
stored as NULL for that field -- it is never guessed at, and never aborts the report.
"""

import re
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
logger = get_logger("sqlwr_plan_cache_summary_parser")

SECTION_HEADING = "Plan Cache Health"
TABLE_NAME = "mssql_sqlwr_plan_cache_summary"

_COUNT_RE = re.compile(r"^\s*([\d,]+)\s*(?:\(\s*([\d.]+)\s*%\s*\))?\s*$")     # "158"  or  "33 (20.9%)"
_MB_RE = re.compile(r"^\s*([\d,]*\.?\d+)\s*MB\s*$", re.IGNORECASE)           # "35.8 MB"


def _parse_count(text, metric):
    """'158' -> (158, None);  '33 (20.9%)' -> (33, 20.9);  anything else -> (None, None) + WARNING."""
    t = text_or_none(text)
    if t is None:
        return None, None
    m = _COUNT_RE.match(t)
    if not m:
        logger.warning(f"{SECTION_HEADING} summary: unrecognised Count cell {t!r} for {metric!r} -- stored as NULL")
        return None, None
    return clean_number(m.group(1)), (clean_number(m.group(2)) if m.group(2) else None)


def _parse_mb(text, metric):
    """'35.8 MB' -> 35.8;  anything else -> None + WARNING."""
    t = text_or_none(text)
    if t is None:
        return None
    m = _MB_RE.match(t)
    if not m:
        logger.warning(f"{SECTION_HEADING} summary: unrecognised Memory cell {t!r} for {metric!r} -- stored as NULL")
        return None
    return clean_number(m.group(1))


def parse_plan_cache_summary(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)
    tables = get_section_tables(soup, SECTION_HEADING)
    if not tables:                                           # section absent from this (older) report
        is_section_missing_or_empty(None, SECTION_HEADING, TABLE_NAME)
        return []
    if subtable_is_empty(tables[0], f"{SECTION_HEADING} (summary table)", TABLE_NAME):
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
                     f"instance={metadata['instance']!r} -- skipping {SECTION_HEADING} (summary)")
        return []

    records = []
    for row in read_raw_rows(tables[0]):
        metric = text_or_none(row.get("Metric"))
        if metric is None:
            continue
        plan_count, pct = _parse_count(row.get("Count"), metric)
        records.append({
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "metric": metric,
            "plan_count": plan_count,
            "pct_of_total": pct,
            "memory_mb": _parse_mb(row.get("Memory"), metric),
            "begin_snapshot_id": metadata["begin_snap"],
        })
    assign_row_hashes(records)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} (summary) record(s) from {filepath}")
    return records


def insert_plan_cache_summary(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "metric", "plan_count",
                 "pct_of_total", "memory_mb", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_plan_cache_summary(parse_plan_cache_summary(_target))
    else:
        logger.error("No filepath provided")
