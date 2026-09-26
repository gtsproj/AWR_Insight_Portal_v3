"""
modules/mssql/sqlwr_cpu_utilization_parser.py

Parses the SQLWR report's CPU Utilization section into
mssql_sqlwr_cpu_utilization. Unlike Load Profile, this section has a
<p> tag (sample count) between the <h3> heading and its <table> --
get_section_table()'s find_next("table") still finds the right table
regardless (it skips right past the <p>), but the sample count itself
needs a separate, small extraction step since it's not part of the
table at all.
"""

import re
import sys
import warnings

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, get_section_table,
    is_section_missing_or_empty, insert_records, row_hash, clean_number,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_cpu_utilization_parser")

SECTION_HEADING = "CPU Utilization"
TABLE_NAME = "mssql_sqlwr_cpu_utilization"


def _extract_sample_count(soup) -> int:
    """
    Pulls the sample count from this section's own <p> tag text
    ("N sample(s) in this window ..."), the one piece of this
    section's data that isn't inside its table at all.
    """
    heading = soup.find("h3", string=SECTION_HEADING)
    if not heading:
        return None
    p = heading.find_next("p")
    if not p:
        return None
    match = re.search(r"(\d+)\s+sample", p.get_text())
    return int(match.group(1)) if match else None


def parse_cpu_utilization(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)
    df = get_section_table(soup, SECTION_HEADING)
    if is_section_missing_or_empty(df, SECTION_HEADING, TABLE_NAME):
        return []

    sample_count = _extract_sample_count(soup)

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
        if not metric:
            continue
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "metric": metric,
            "min_pct": clean_number(row.get("Min %")),
            "max_pct": clean_number(row.get("Max %")),
            "avg_pct": clean_number(row.get("Avg %")),
            "sample_count": sample_count,
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_cpu_utilization(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "metric",
                 "min_pct", "max_pct", "avg_pct", "sample_count", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_cpu_utilization(parse_cpu_utilization(_target))
    else:
        logger.error("No filepath provided")
