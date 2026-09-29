"""
modules/mssql/sqlwr_database_summary_parser.py

Parses the SQLWR report's (extended) "Database Summary" section into
mssql_sqlwr_database_summary -- one row per report. This is the first parser
the MSSQL master parser runs for a report, matching Ganesh's Oracle-side
convention that the database summary is parsed before everything else.

Modeled on the Oracle side's awr_db_info, extended with the additional fields
an Oracle AWR report's Database Summary screen shows that SQL Server has a real
source for (DB Id, Startup Time, Platform, Cores, Sockets), plus two fields that
are honestly 'N/A' for SQL Server (RAC, CDB -- Oracle-only concepts) rather than
guessed at, plus Sessions/Elapsed/DB Time figures read from the report's
Snapshot Summary table. See mssql_sqlwr_database_summary's COMMENT ON TABLE
(schema/mssql_sqlwr_section_tables.sql) and
Documentation/MSSQL_SQLWR_Parsed_Tables_Conventions.md for the field-by-field
reasoning; this parser stores exactly what the report shows, without
re-deriving any of it.

Not point-in-time / window / delta like the other 26 sections -- a whole-report
summary. snapshot_time is the END snapshot's time, matching every other parsed
table's convention (see the conventions doc); begin_snap_time/end_snap_time are
also stored explicitly since this table is the one place both matter equally.

Blank cells (Unique Name when standalone, Inst Num, Cursors/Session) are stored
as NULL, not as the word the report may show ('N/A (standalone)' for Role is
the one exception, kept as literal text since it is itself the meaningful
value, not a placeholder for a missing one).
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
    """text_or_none(), but also treats the report's own '(not collected)' literal as NULL."""
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

    # Cells read via read_raw_rows(), NOT pandas -- this table's "N/A" (RAC/CDB)
    # and "(not collected)" values are exactly the strings pandas.read_html's
    # default NA-marker list turns into NaN (silently losing the real, meaningful
    # text). Caught by testing: the report renders RAC/CDB as "N/A" but a
    # pandas-based first draft of this parser stored them as NULL. read_raw_rows()
    # returns the cell's own text with no such inference, the same fix already
    # used for plan-cache query hashes and deadlock logins named "NA".
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

    # Snapshot Summary table: Sessions / Elapsed / DB Time, read straight from the
    # HTML rather than relying only on extract_sqlwr_metadata (which stops after
    # the End Snap row and doesn't read Sessions/Elapsed/DB Time at all).
    begin_sessions = end_sessions = None
    db_time_minutes = None
    # elapsed_minutes is computed directly below (begin/end snap time is always
    # available, even from reports generated before the Elapsed: row existed);
    # this is only a placeholder in case the loop's text-parsed value should
    # ever need to override it (it currently doesn't -- see the assignment
    # right after the loop).
    elapsed_minutes = None
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
            elif label.startswith("elapsed"):
                m = clean_number((cells.get("Snapshot Time") or "").replace("(mins)", ""))
                elapsed_minutes = m
            elif label.startswith("db time"):
                text = cells.get("Snapshot Time") or ""
                m = clean_number(text.split("(mins)")[0]) if "(mins)" in text else clean_number(text)
                db_time_minutes = m

    # elapsed_minutes: computed directly from begin/end snap time rather than
    # parsed from the report's "Elapsed:" row text, because that row does not
    # exist in reports generated before it was added -- confirmed on report
    # sqlwr_1_7_8 (the oldest uploaded report): its Snapshot Summary table has
    # no Sessions/Elapsed/DB Time rows at all, yet elapsed time is still a
    # trivial, always-available subtraction, so there is no reason for the
    # parser to leave it NULL just because the report predates that display
    # feature. db_time_minutes has no such fallback and stays NULL for those
    # reports -- it is an approximation the report itself computes (see
    # sqlwr_report_generator.py's _compute_db_time_seconds), not a value this
    # parser can honestly re-derive on its own without duplicating that logic.
    if metadata["snap_time"] and metadata["end_snap_time"]:
        elapsed_minutes = (metadata["end_snap_time"] - metadata["snap_time"]).total_seconds() / 60.0

    def col(name):
        return db_row.get(name)

    rec = {
        "database_name": metadata["dbname"],
        "instance_id": instance_id,
        "snapshot_time": metadata["end_snap_time"] or metadata["snap_time"],
        "database_id": _int_cell(col("DB Id")),
        "unique_name": _cell(col("Unique Name")) or None,
        "role": _cell(col("Role")),
        "edition": _cell(col("Edition")),
        "release": _cell(col("Release")),
        "rac": _cell(col("RAC")),
        "cdb": _cell(col("CDB")),
        "host_name": _cell(col("Host Name")),
        "platform": _cell(col("Platform")),
        "cpu_count": _int_cell(col("CPUs")),
        "cores": _int_cell(col("Cores")),
        "sockets": _int_cell(col("Sockets")),
        "memory_gb": clean_number(col("Memory (GB)")) if _cell(col("Memory (GB)")) else None,
        "inst_num": _int_cell(col("Inst Num")),
        "startup_time": _time_cell(col("Startup Time")),
        "begin_snap_id": metadata["begin_snap"],
        "begin_snap_time": metadata["snap_time"],
        "end_snap_id": metadata["end_snap"],
        "end_snap_time": metadata["end_snap_time"],
        "begin_sessions": begin_sessions,
        "end_sessions": end_sessions,
        "cursors_per_session": None,   # no SQL Server equivalent -- see module docstring
        "elapsed_minutes": elapsed_minutes,
        "db_time_minutes": db_time_minutes,
        "begin_snapshot_id": metadata["begin_snap"],
    }
    rec["row_hash"] = row_hash(rec)

    logger.info(f"Parsed 1 {DB_SECTION_HEADING} record from {filepath}")
    return [rec]


def insert_database_summary(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "snapshot_time", "database_id", "unique_name",
                 "role", "edition", "release", "rac", "cdb", "host_name", "platform",
                 "cpu_count", "cores", "sockets", "memory_gb", "inst_num", "startup_time",
                 "begin_snap_id", "begin_snap_time", "end_snap_id", "end_snap_time",
                 "begin_sessions", "end_sessions", "cursors_per_session",
                 "elapsed_minutes", "db_time_minutes", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_database_summary(parse_database_summary(_target))
    else:
        logger.error("No filepath provided")
