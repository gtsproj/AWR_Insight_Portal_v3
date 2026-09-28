"""
modules/mssql/sqlwr_wait_by_procedure_parser.py

Parses the SQLWR report's Wait Events by Stored Procedure section into
mssql_sqlwr_wait_by_procedure.

Unlike the sections parsed so far, this one is PIVOTED in the report: one
row per procedure, then a column per wait category ("Buffer IO", "CPU",
"Lock", ...) -- and which category columns exist varies from report to
report (only categories with nonzero wait time in that window become
columns; see _build_wait_events_by_procedure in sqlwr_report_generator.py).
mssql_sqlwr_wait_by_procedure is LONG: one row per (procedure, category).
So this parser unpivots -- every column that isn't one of the three fixed
ones is treated as a wait category, discovered from the header rather than
assumed, so it keeps working whatever categories a given report contains.

Zero cells are not stored. A 0.0 means "no wait in this category for this
procedure", and the report also rounds to 0.1s, so it can't distinguish
"none" from "under 0.05s" -- storing a row of 0 would add noise and imply
a precision the report doesn't have.

Caution for anyone querying this table (e.g. the future materialized views):
"executions" is a per-PROCEDURE figure repeated on every one of that
procedure's category rows, so SUM(executions) across the table multiplies it
by the number of categories. Take it once per procedure (MAX or DISTINCT per
procedure_name), and sum wait_time_s only.
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
logger = get_logger("sqlwr_wait_by_procedure_parser")

SECTION_HEADING = "Wait Events by Stored Procedure"
TABLE_NAME = "mssql_sqlwr_wait_by_procedure"

# Everything else in the header row is a wait category.
FIXED_COLUMNS = {"Stored Procedure", "Executions", "Total Wait (s)"}


def parse_wait_by_procedure(filepath: str, pg_conn=None) -> list:
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

    category_cols = [c for c in df.columns if str(c).strip() not in FIXED_COLUMNS]
    if not category_cols:
        logger.warning(f"{SECTION_HEADING}: table has no wait-category columns -- nothing to unpivot")
        return []

    records = []
    for _, row in df.iterrows():
        procedure = str(row.get("Stored Procedure", "")).strip()
        if not procedure or procedure.lower() == "nan":
            continue
        executions = clean_number(row.get("Executions"))
        for col in category_cols:
            wait_s = clean_number(row[col])
            if wait_s is None or wait_s <= 0:
                continue
            rec = {
                "database_name": metadata["dbname"],
                "instance_id": instance_id,
                "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
                "procedure_name": procedure,
                "executions": executions,
                "wait_category": str(col).strip(),
                "wait_time_s": wait_s,
                "begin_snapshot_id": metadata["begin_snap"],
            }
            rec["row_hash"] = row_hash(rec)
            records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) "
                f"({len(df)} procedure row(s) x {len(category_cols)} category column(s)) from {filepath}")
    return records


def insert_wait_by_procedure(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "procedure_name", "executions",
                 "wait_category", "wait_time_s", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_wait_by_procedure(parse_wait_by_procedure(_target))
    else:
        logger.error("No filepath provided")
