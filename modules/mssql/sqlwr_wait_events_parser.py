"""
modules/mssql/sqlwr_wait_events_parser.py

Parses the SQLWR report's "Top N Wait Types by Total Wait Time"
section into mssql_sqlwr_wait_events.

This section's own <h3> heading is dynamic (f'Top {top_n} Wait Types
by Total Wait Time', top_n defaults to 15 and nothing currently
overrides that default at the call site -- confirmed directly in
sqlwr_report_generator.py, not assumed) -- so this parser matches the
heading by regex instead of the shared get_section_table()'s exact-
string match, to stay correct even if that default is ever changed.
"""

import re
import sys
import warnings

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id,
    is_section_missing_or_empty, insert_records, row_hash, clean_number,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_wait_events_parser")

HEADING_PATTERN = re.compile(r"^Top \d+ Wait Types by Total Wait Time$")
SECTION_LABEL = "Top N Wait Types by Total Wait Time"
TABLE_NAME = "mssql_sqlwr_wait_events"


def _get_wait_events_table(soup):
    import pandas as pd
    from io import StringIO
    heading = soup.find("h3", string=HEADING_PATTERN)
    if not heading:
        return None
    table = heading.find_next("table")
    if not table:
        return None
    try:
        return pd.read_html(StringIO(str(table)))[0]
    except ValueError:
        return None


def parse_wait_events(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)
    df = _get_wait_events_table(soup)
    if is_section_missing_or_empty(df, SECTION_LABEL, TABLE_NAME):
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
                     f"instance={metadata['instance']!r} -- skipping {SECTION_LABEL}")
        return []

    records = []
    for _, row in df.iterrows():
        wait_type = str(row.get("Wait Type", "")).strip()
        if not wait_type:
            continue
        # "% of Total" renders with a literal "%" suffix in this table
        # (unlike Wait Classes' equivalent column, which doesn't) --
        # clean_number() strips commas but not a trailing "%", so it's
        # stripped here before the numeric conversion.
        pct_raw = str(row.get("% of Total", "")).strip().rstrip("%")
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "wait_type": wait_type,
            "wait_class": str(row.get("Wait Class", "")).strip() or None,
            "total_wait_time_s": clean_number(row.get("Time(s)")),
            "pct_of_total": clean_number(pct_raw),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_LABEL} record(s) from {filepath}")
    return records


def insert_wait_events(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "wait_type", "wait_class",
                 "total_wait_time_s", "pct_of_total", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_wait_events(parse_wait_events(_target))
    else:
        logger.error("No filepath provided")
