"""
modules/mssql/sqlwr_sql_cpu_time_parser.py

Parses the SQLWR report's "SQL ordered by CPU Time" section (one row per
query, top by CPU time) into mssql_sqlwr_sql_cpu_time.

Same family as sqlwr_sql_elapsed_time_parser.py, and the same conventions
apply (see that module's docstring for the reasoning):

* The report's truncated "SQL Text" column is not parsed; full text comes from
  the separate "Complete List of SQL Text" section, joined on sql_id.
* sql_id is normalized via the shared normalize_sql_id() so a query has one id
  regardless of the report's age (old "q39" and current "39" both -> "39").
* stored_procedure keeps the report's "(ad hoc / no object)" literal for
  statements that belong to no stored procedure.
* Older report versions with a header-only table insert nothing; a missing
  Stored Procedure column is stored as NULL.

Specific to this section: it also carries an "Elapsed Time (s)" column, stored
as elapsed_time_s, so a query's CPU-vs-elapsed relationship is visible without
joining to the elapsed-time table. %CPU here can exceed 100 -- CPU time is
summed across a parallel plan's workers, so it can exceed wall-clock elapsed.
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
logger = get_logger("sqlwr_sql_cpu_time_parser")

SECTION_HEADING = "SQL ordered by CPU Time"
TABLE_NAME = "mssql_sqlwr_sql_cpu_time"


def parse_sql_cpu_time(filepath: str, pg_conn=None) -> list:
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
            "cpu_time_s": clean_number(row.get("CPU Time (s)")),
            "cpu_per_exec_s": clean_number(row.get("CPU per Exec (s)")),
            "elapsed_time_s": clean_number(row.get("Elapsed Time (s)")),
            "pct_total": _pct(row.get("%Total")),
            "pct_cpu": _pct(row.get("%CPU")),
            "pct_io": _pct(row.get("%IO")),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_sql_cpu_time(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "sql_id", "sql_module",
                 "stored_procedure", "executions", "cpu_time_s", "cpu_per_exec_s",
                 "elapsed_time_s", "pct_total", "pct_cpu", "pct_io",
                 "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_sql_cpu_time(parse_sql_cpu_time(_target))
    else:
        logger.error("No filepath provided")
