"""
modules/mssql/sqlwr_sql_gets_parser.py

Parses the SQLWR report's "SQL ordered by Gets" section (one row per query,
top by logical reads / buffer gets) into mssql_sqlwr_sql_gets.

Same family and conventions as sqlwr_sql_elapsed_time_parser.py (truncated SQL
Text column not parsed; sql_id normalized via the shared helper;
"(ad hoc / no object)" kept as shown; header-only tables insert nothing; a
missing Stored Procedure column is stored as NULL).

Old-format reports and the "Elapsed Time (s)" column
----------------------------------------------------
Reports generated before a generator fix carry a WRONG value in this section's
"Elapsed Time (s)" column: the column held 100 * elapsed / total_elapsed -- a
percentage -- under a header that says seconds. Every such report already on
disk has it. Rather than store a percentage as seconds, this parser detects the
old format and uses the correct figure, which is in the same file: the
"Elapsed Time (s)" column for the same sql_id in the same report -- taken from
the Elapsed Time section, or, if the query isn't in that one, the CPU Time or
Executions section (all three carry correct seconds). The four sections each
take their own top 15 by their own metric from a larger pool, so a query can be
in one and not another; only a query in none of the three gets NULL.

Detection is exact, not a heuristic. In a correct report the Gets section's
elapsed figure for a query MUST equal the Elapsed Time section's seconds for
that query. In an old-format report it instead equals that query's %Total. So a
report is treated as old-format only if some row's value differs from the
elapsed seconds AND matches the elapsed %Total -- a combination a correct report
cannot produce. When it fires, one WARNING is logged with the row count, and
elapsed_time_s is taken from the Elapsed Time section. Correct (current-format)
reports are stored exactly as shown with no warning.
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
logger = get_logger("sqlwr_sql_gets_parser")

SECTION_HEADING = "SQL ordered by Gets"
ELAPSED_SECTION_HEADING = "SQL ordered by Elapsed Time"
# Sections whose "Elapsed Time (s)" column holds real seconds (the Gets section's did not).
REFERENCE_HEADINGS = (ELAPSED_SECTION_HEADING, "SQL ordered by CPU Time", "SQL ordered by Executions")
TABLE_NAME = "mssql_sqlwr_sql_gets"

_TOL = 0.011  # both figures are printed to 2 decimals


def _reference(soup):
    """
    Returns (secs, pct):
      secs: sql_id -> correct elapsed seconds, from the "Elapsed Time (s)" column of the
            Elapsed Time, CPU Time and Executions sections (first section listing it wins).
      pct:  sql_id -> that query's %Total, from the Elapsed Time section only (used to
            recognise the old wrong format).
    """
    secs, pct = {}, {}
    for heading in REFERENCE_HEADINGS:
        df = get_section_table(soup, heading)
        if df is None or df.empty or str(df.iloc[0, 0]).strip().startswith("("):
            continue
        for _, row in df.iterrows():
            sid = normalize_sql_id(row.get("SQL Id"))
            val = clean_number(row.get("Elapsed Time (s)"))
            if sid is None:
                continue
            if val is not None:
                secs.setdefault(sid, val)
            if heading == ELAPSED_SECTION_HEADING:
                pct[sid] = _pct(row.get("%Total"))
    return secs, pct


def _is_old_format(rows_elapsed: list, secs: dict, pct: dict) -> bool:
    """True iff some row is impossible in a correct report: != elapsed seconds AND == elapsed %Total."""
    for sid, gets_elapsed in rows_elapsed:
        if sid in secs and sid in pct and gets_elapsed is not None and pct[sid] is not None:
            if abs(gets_elapsed - secs[sid]) > _TOL and abs(gets_elapsed - pct[sid]) <= _TOL:
                return True
    return False


def parse_sql_gets(filepath: str, pg_conn=None) -> list:
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

    secs, pct = _reference(soup)
    rows_elapsed = [(normalize_sql_id(r.get("SQL Id")), clean_number(r.get("Elapsed Time (s)")))
                    for _, r in df.iterrows()]
    old_format = _is_old_format(rows_elapsed, secs, pct)
    if old_format:
        unresolved = sum(1 for sid, _ in rows_elapsed if sid is not None and sid not in secs)
        logger.warning(f"{SECTION_HEADING}: old-format report -- its 'Elapsed Time (s)' column holds each "
                       f"query's %Total, not seconds. Using the correct seconds from the report's other "
                       f"sections for {len(df) - unresolved} of {len(df)} row(s) instead of storing a "
                       f"percentage as seconds" + (f"; {unresolved} query(ies) appear in none of them -> NULL."
                                                    if unresolved else "."))

    records = []
    for _, row in df.iterrows():
        sql_id = normalize_sql_id(row.get("SQL Id"))
        if sql_id is None:
            continue
        elapsed = clean_number(row.get("Elapsed Time (s)"))
        if old_format:
            elapsed = secs.get(sql_id)
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
            "sql_id": sql_id,
            "sql_module": _text(row.get("SQL Module")),
            "stored_procedure": _text(row.get("Stored Procedure")),
            "buffer_gets": clean_number(row.get("Buffer Gets")),
            "executions": clean_number(row.get("Executions")),
            "gets_per_exec": clean_number(row.get("Gets per Exec")),
            "pct_total": _pct(row.get("%Total")),
            "elapsed_time_s": elapsed,
            "pct_cpu": _pct(row.get("%CPU")),
            "pct_io": _pct(row.get("%IO")),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_sql_gets(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "sql_id", "sql_module",
                 "stored_procedure", "buffer_gets", "executions", "gets_per_exec", "pct_total",
                 "elapsed_time_s", "pct_cpu", "pct_io", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_sql_gets(parse_sql_gets(_target))
    else:
        logger.error("No filepath provided")
