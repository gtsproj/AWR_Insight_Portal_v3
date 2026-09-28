"""
modules/mssql/sqlwr_sql_executions_parser.py

Parses the SQLWR report's "SQL ordered by Executions" section (one row per
query, top by execution count) into mssql_sqlwr_sql_executions.

Same family and conventions as sqlwr_sql_elapsed_time_parser.py (truncated SQL
Text column not parsed; sql_id normalized via the shared helper;
"(ad hoc / no object)" kept as shown; header-only tables insert nothing; a
missing Stored Procedure column is stored as NULL).

Specific to this section: it carries rows processed and rows per execution, and
its "Elapsed Time (s)" column holds real seconds (unlike the Gets section's
column before the generator fix -- see sqlwr_sql_gets_parser.py), so it is
stored as shown. This section has no %Total column.
"""

import sys
import warnings

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, get_section_table,
    is_section_missing_or_empty, insert_records, row_hash, clean_number,
    text_or_none as _text, parse_pct as _pct, normalize_sql_id,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_sql_executions_parser")

SECTION_HEADING = "SQL ordered by Executions"
TABLE_NAME = "mssql_sqlwr_sql_executions"


def parse_sql_executions(filepath: str, pg_conn=None) -> list:
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
        sql_id = normalize_sql_id(row.get("SQL Id"))
        if sql_id is None:
            continue
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "sql_id": sql_id,
            "sql_module": _text(row.get("SQL Module")),
            "stored_procedure": _text(row.get("Stored Procedure")),
            "executions": clean_number(row.get("Executions")),
            "elapsed_time_s": clean_number(row.get("Elapsed Time (s)")),
            "pct_cpu": _pct(row.get("%CPU")),
            "pct_io": _pct(row.get("%IO")),
            "rows_processed": clean_number(row.get("Rows Processed")),
            "rows_per_exec": clean_number(row.get("Rows per Exec")),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_sql_executions(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "sql_id", "sql_module",
                 "stored_procedure", "executions", "elapsed_time_s", "pct_cpu", "pct_io",
                 "rows_processed", "rows_per_exec", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_sql_executions(parse_sql_executions(_target))
    else:
        logger.error("No filepath provided")
