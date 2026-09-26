"""
modules/mssql/sqlwr_load_profile_parser.py

Parses the SQLWR report's Load Profile section (a 2-column
"Stat Name" / "Per Second" table) into mssql_sqlwr_load_profile.
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
logger = get_logger("sqlwr_load_profile_parser")

SECTION_HEADING = "Load Profile"
TABLE_NAME = "mssql_sqlwr_load_profile"


def parse_load_profile(filepath: str, pg_conn=None) -> list:
    """
    Parse the Load Profile section from a generated SQLWR report.
    pg_conn is used only to resolve host_name/instance_name into
    instance_id -- if not supplied, one is opened just for that lookup
    via the shared get_db_connection().
    """
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
    # Column names are literally "Stat Name" and "Per Second" in this
    # report's own HTML (see sqlwr_report_generator.py's _build_load_profile).
    for _, row in df.iterrows():
        metric = str(row.get("Stat Name", "")).strip().rstrip(":")
        if not metric:
            continue
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "metric": metric,
            "metric_value": clean_number(row.get("Per Second")),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_load_profile(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "metric",
                 "metric_value", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_load_profile(parse_load_profile(_target))
    else:
        logger.error("No filepath provided")
