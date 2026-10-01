"""
modules/mssql/sqlwr_database_summary_parser.py

RECREATED (per spec) to a slimmer scope: parses only the PER-REPORT fields
of the SQLWR report's Database/Snapshot Summary sections into
mssql_sqlwr_database_summary -- one row per report, every time (not a
once-ever registry; that is mssql_db_info_parser.py's job now).

What moved to mssql_db_info, and why
--------------------------------------
Database/host/instance IDENTITY facts that don't change report to report
(edition, release, host_name, platform, cpu/cores/sockets, memory,
database_id, unique_name, role, instance_id, inst_num) are no longer
parsed or stored here. They are captured ONCE per database by
mssql_db_info_parser.py instead of being repeated on every single report
row -- see that module's docstring and mssql_db_info's own
COMMENT ON TABLE. This parser now reads only: the Database Summary
section's Startup Time (a per-report observation -- which SQL Server
instance-start the report's snapshots fall under), plus the Snapshot
Summary section's Sessions/Elapsed/DB Time figures.

Two intentional redundancies (kept because the column list was specified
explicitly, not an oversight): begin_snap_id and begin_snapshot_id hold
the SAME value (begin_snap_id for symmetry with end_snap_id;
begin_snapshot_id for consistency with the report-key convention every
other mssql_sqlwr_* table uses); end_snap_time and snapshot_time
likewise both hold the end snapshot's time. There is no instance_id
column on this table -- join back to mssql_dmv_snapshot on
begin_snap_id/end_snap_id if the instance is ever needed from a row here.

Not point-in-time/window/delta like the other 26 sections -- a
whole-report summary, spanning the begin and end snapshot together. See
Documentation/MSSQL_SQLWR_Parsed_Tables_Conventions.md.
"""

import sys
import warnings
from datetime import datetime

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, read_raw_rows,
    insert_records, row_hash, clean_number, text_or_none,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_database_summary_parser")

DB_SECTION_HEADING = "Database Summary"
SNAP_SECTION_HEADING = "Snapshot Summary"
TABLE_NAME = "mssql_sqlwr_database_summary"

_NOT_COLLECTED = "(not collected)"
_TIME_FORMATS = ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S")


def _cell(value):
    t = text_or_none(value)
    return None if t is None or t == _NOT_COLLECTED else t


def _int_cell(value):
    c = _cell(value)
    if c is None:
        return None
    n = clean_number(c)
    return int(n) if n is not None and float(n).is_integer() else n


def _time_cell(value):
    c = _cell(value)
    if c is None:
        return None
    for fmt in _TIME_FORMATS:
        try:
            return datetime.strptime(c, fmt)
        except ValueError:
            continue
    logger.warning(f"{DB_SECTION_HEADING}: unreadable timestamp {c!r} -- stored as NULL")
    return None


def parse_database_summary(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)

    # Cells read via read_raw_rows(), NOT pandas: pandas.read_html's default
    # NA-marker list would turn values like "N/A" into NaN -- see
    # mssql_db_info_parser.py's docstring and the commit history for where
    # this was first found (the report's RAC/CDB cells, in the predecessor
    # of this parser).
    db_heading = soup.find("h3", string=DB_SECTION_HEADING)
    db_table = db_heading.find_next("table") if db_heading else None
    if db_table is None:
        logger.warning(f"{DB_SECTION_HEADING} section not found or has no table -- skipping")
        return []
    db_rows = read_raw_rows(db_table)
    if not db_rows:
        logger.warning(f"{DB_SECTION_HEADING}: table has a header but no data row -- skipping")
        return []
    db_row = db_rows[0]

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
                     f"instance={metadata['instance']!r} -- skipping {DB_SECTION_HEADING}")
        return []

    # Snapshot Summary table: Sessions / Elapsed / DB Time.
    begin_sessions = end_sessions = None
    db_time_minutes = None
    snap_table = soup.find("h3", string=SNAP_SECTION_HEADING)
    snap_table = snap_table.find_next("table") if snap_table else None
    if snap_table is not None:
        header = [th.get_text(strip=True) for th in snap_table.find("tr").find_all("th")]
        for tr in snap_table.find_all("tr")[1:]:
            cells = dict(zip(header, [td.get_text(strip=True) for td in tr.find_all("td")]))
            label = (cells.get("Snap") or "").lower()
            if label == "begin snap":
                begin_sessions = _int_cell(cells.get("Sessions"))
            elif label == "end snap":
                end_sessions = _int_cell(cells.get("Sessions"))
            elif label.startswith("db time"):
                text = cells.get("Snapshot Time") or ""
                db_time_minutes = clean_number(text.split("(mins)")[0]) if "(mins)" in text else clean_number(text)

    # elapsed_minutes: computed directly from begin/end snap time (always
    # available) rather than parsed from the report's "Elapsed:" row text,
    # which does not exist in reports generated before that row existed.
    elapsed_minutes = None
    if metadata["snap_time"] and metadata["end_snap_time"]:
        elapsed_minutes = (metadata["end_snap_time"] - metadata["snap_time"]).total_seconds() / 60.0

    rec = {
        "database_name": metadata["dbname"],
        "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
        "startup_time": _time_cell(db_row.get("Startup Time")),
        "begin_snap_id": metadata["begin_snap"],
        "begin_snapshot_id": metadata["begin_snap"],
        "end_snap_id": metadata["end_snap"],
        "end_snap_time": metadata["end_snap_time"],
        "begin_sessions": begin_sessions,
        "end_sessions": end_sessions,
        "cursors_per_sessions": None,   # no SQL Server equivalent -- see module docstring
        "elapsed_minutes": elapsed_minutes,
        "db_time_minutes": db_time_minutes,
    }
    rec["row_hash"] = row_hash(rec)

    logger.info(f"Parsed 1 {DB_SECTION_HEADING} record from {filepath}")
    return [rec]


def insert_database_summary(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "snapshot_time", "startup_time", "begin_snap_id",
                 "begin_snapshot_id", "end_snap_id", "end_snap_time", "begin_sessions",
                 "end_sessions", "cursors_per_sessions", "elapsed_minutes",
                 "db_time_minutes", "row_hash"],
        conflict_columns=["database_name", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_database_summary(parse_database_summary(_target))
    else:
        logger.error("No filepath provided")
