"""
modules/mssql/sqlwr_sql_elapsed_time_parser.py

Parses the SQLWR report's "SQL ordered by Elapsed Time" section (one row per
query, top by elapsed time) into mssql_sqlwr_sql_elapsed_time.

Things specific to this family of sections:

* The report's own "SQL Text" column is NOT parsed here. It is truncated to
  ~30 characters for display; the full text lives in the report's separate
  "Complete List of SQL Text" section, which has its own parser and table
  (mssql_sqlwr_sql_text), joined on sql_id.

* sql_id is Query Store's own query_id, stored as text. Reports generated
  before the "q" prefix was dropped carry ids like "q39"; current reports
  carry "39". The prefix was purely cosmetic (see sqlwr_report_generator.py),
  so it is normalized away here -- otherwise the same query would be stored
  under two different ids depending on when the report was generated. The rule
  is deliberately strict: only a leading "q" followed entirely by digits.
  pandas can also hand back a whole-number column as floats ("47.0") when any
  cell is missing, which is stripped for the same reason.

* stored_procedure holds "(ad hoc / no object)" for statements that don't
  belong to a stored procedure -- kept as the report shows it. Consumers
  should treat that literal as "no procedure", not as a procedure name.

* Older report versions differ: some have no Stored Procedure column, and some
  have this section as a header row with no data rows. Both are tolerated (a
  missing column is stored as NULL; a header-only table inserts nothing).
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
logger = get_logger("sqlwr_sql_elapsed_time_parser")

SECTION_HEADING = "SQL ordered by Elapsed Time"
TABLE_NAME = "mssql_sqlwr_sql_elapsed_time"

def parse_sql_elapsed_time(filepath: str, pg_conn=None) -> list:
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
            "elapsed_time_per_exec_s": clean_number(row.get("Elapsed Time per Exec (s)")),
            "pct_total": _pct(row.get("%Total")),
            "pct_cpu": _pct(row.get("%CPU")),
            "pct_io": _pct(row.get("%IO")),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_sql_elapsed_time(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "sql_id", "sql_module",
                 "stored_procedure", "executions", "elapsed_time_s", "elapsed_time_per_exec_s",
                 "pct_total", "pct_cpu", "pct_io", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_sql_elapsed_time(parse_sql_elapsed_time(_target))
    else:
        logger.error("No filepath provided")
