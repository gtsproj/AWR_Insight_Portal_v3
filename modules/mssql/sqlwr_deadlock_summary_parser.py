"""
modules/mssql/sqlwr_deadlock_summary_parser.py

Parses the SQLWR report's "Deadlock Summary" section (deadlocks recorded within
the report's snapshot window, newest first, at most 15) into
mssql_sqlwr_deadlock_summary.

Time semantics: a TIME WINDOW section (deadlocks whose deadlock_time falls between
the begin and end snapshot times), not a delta and not an end-snapshot sample. The
report is empty whenever there was no deadlock in the window -- the normal case --
so "nothing to insert" is not an error. See
Documentation/MSSQL_SQLWR_Parsed_Tables_Conventions.md.

Things specific to this section
-------------------------------
* deadlock_time is parsed with an explicit "%Y-%m-%d %H:%M:%S" format -- never a
  guessing parser -- so the day/month can't be swapped for days 1-12 (the shared
  metadata parser's dayfirst behaviour is documented in sqlwr_parser_utils.py).
  The report prints whole seconds only.

* Two deadlocks in the same second with the same table, cause and victim render
  as IDENTICAL rows, and the table's uniqueness rule is a hash of the row values,
  so plain hashing would silently keep one and undercount deadlocks. Repeated
  rows within one report are therefore numbered, and the number is mixed into the
  hash of the 2nd, 3rd... copy only (the first copy hashes exactly as the values
  alone would). Re-parsing the same report is still idempotent.

* The report writes the literals "(not classified)" (no cause was computed) and
  "(not captured)" (no victim procedure/statement text) into those cells; they are
  stored as shown -- treat them as "unknown", not as a cause or a procedure name.
  The victim column is the victim's executing procedure, or, when it was not inside
  a procedure, the first 60 characters of its statement.

* Empty cells (no contested table/index, no victim app/login) are stored as NULL.

* The cells are read from the raw HTML rather than through pandas, so names such as
  "NA" or "null" are not turned into missing values and a statement's own line
  breaks are kept.
"""

import sys
import warnings
from datetime import datetime

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, get_section_table,
    is_section_missing_or_empty, insert_records, assign_row_hashes, clean_number,
    text_or_none,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_deadlock_summary_parser")

SECTION_HEADING = "Deadlock Summary"
TABLE_NAME = "mssql_sqlwr_deadlock_summary"
_TIME_FORMAT = "%Y-%m-%d %H:%M:%S"


def _int(value):
    n = clean_number(value)
    if n is None:
        return None
    return int(n) if float(n).is_integer() else n


def _raw_text(cell) -> "str | None":
    """A cell's own text (line breaks kept), None if blank."""
    return text_or_none(cell.get_text())


def _read_rows(table) -> list:
    header = [th.get_text(strip=True) for th in table.find("tr").find_all("th")]
    out = []
    for tr in table.find_all("tr")[1:]:
        cells = tr.find_all("td")
        if cells:
            out.append(dict(zip(header, cells)))
    return out


def parse_deadlock_summary(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)

    # Classification only (missing / header-only / "(no deadlocks recorded ...)" placeholder).
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

    table = soup.find("h3", string=SECTION_HEADING).find_next("table")
    records = []
    for cells in _read_rows(table):
        time_text = cells["Time"].get_text(strip=True) if "Time" in cells else ""
        try:
            deadlock_time = datetime.strptime(time_text, _TIME_FORMAT)
        except ValueError:
            logger.warning(f"{SECTION_HEADING}: unreadable Time cell {time_text!r} -- row skipped")
            continue

        def cell(name):
            return _raw_text(cells[name]) if name in cells else None

        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "deadlock_time": deadlock_time,
            "deadlock_database_name": cell("Database"),
            "contested_table": cell("Contested Table"),
            "contested_index": cell("Contested Index"),
            "deadlock_cause": cell("Cause"),
            "process_count": _int(cells["Process Count"].get_text()) if "Process Count" in cells else None,
            "victim_app": cell("Victim App"),
            "victim_login": cell("Victim Login"),
            "victim_proc_or_statement": cell("Victim Proc/Statement"),
            "begin_snapshot_id": metadata["begin_snap"],
        }
        records.append(rec)
    assign_row_hashes(records)      # numbers repeated rows so none is dropped (see module docstring)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_deadlock_summary(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "deadlock_time", "deadlock_database_name",
                 "contested_table", "contested_index", "deadlock_cause", "process_count",
                 "victim_app", "victim_login", "victim_proc_or_statement",
                 "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_deadlock_summary(parse_deadlock_summary(_target))
    else:
        logger.error("No filepath provided")
