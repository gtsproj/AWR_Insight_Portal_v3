"""
modules/mssql/mssql_db_info_parser.py

Registers a database's identity in mssql_db_info -- modeled on the Oracle
side's db_info_parser.py/awr_db_info, with one deliberate difference in
the dedup rule (see below). Reads the SAME Database Summary table a SQLWR
report renders (the one sqlwr_database_summary_parser.py used to read in
full before it was slimmed down -- see that module's own docstring for
what moved where).

ONE ROW PER (instance, database), EVER
---------------------------------------
Per spec: "Row will be inserted only once when the first sqlwr report of
a database is parsed. The parser should ignore if row for the database is
already inserted in the table. there should be no duplicate rows for the
same database." This is STRICTER than awr_db_info's own rule (which is
UNIQUE on db_name+instance+row_hash, so Oracle's parser inserts a NEW row
whenever the content changes between runs -- e.g. core count differs).
Here, uniqueness is on (instance_id, database_name) alone, with no
row_hash involved: once a database has a row, every later report for
that same database is skipped, even if its host/edition/core count would
now parse differently. row_hash is still computed and stored (project-
wide convention, useful for audit) but is NOT part of what makes a row
unique.

Enforced twice, deliberately: parse_db_info() checks first (SELECT 1 ...)
so a report for an already-registered database does no wasted table
reading and logs a clear "already registered" message; insert_db_info()
also relies on the table's own UNIQUE (instance_id, database_name)
constraint with ON CONFLICT DO NOTHING as a safety net, so even a changed
or race-condition-duplicated call can never produce a second row.

Fields with no reliable SQL Server source
------------------------------------------
inst_num, unique_name, role: genuinely Oracle concepts (RAC instance
number; Data Guard-style unique database name; replica role) with no
SQL Server equivalent outside an Availability Group. unique_name and
role are read from the report's own "Unique Name"/"Role" cells when
present; role's literal "N/A (standalone)" (the generator's own display
text for "no AG") is treated as NULL here, not stored verbatim -- this
is an identity REGISTRY, not a report rendering, so "not applicable"
should read as NULL rather than carry display text. inst_num is always
NULL (the report never fills it; no reliable non-AG equivalent exists).

source_type / repo_path
------------------------
Mirrors awr_db_info's own source_type default ('local_file' -- these
reports are parsed from local HTML files, not a live connection at parse
time). repo_path is NOT populated by Oracle's own db_info_parser.py (left
to the column's DB default); here it is set to the absolute path of the
report file that first registered the database, since that is directly
useful (answers "which report proves this database's recorded identity")
and the column exists for exactly this kind of provenance.
"""

import os
import sys
import warnings

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, read_raw_rows, insert_records,
    row_hash, clean_number, text_or_none,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("mssql_db_info_parser")

DB_SECTION_HEADING = "Database Summary"
TABLE_NAME = "mssql_db_info"

_NOT_COLLECTED = "(not collected)"
_NO_AG_ROLE = "N/A (standalone)"   # the report's own literal for "no Availability Group"


def _cell(value):
    """text_or_none(), but also treats the report's '(not collected)' literal,
    and Role's 'N/A (standalone)' literal, as NULL -- a registry should store
    NULL for 'not applicable', not the display text a report uses to say so."""
    t = text_or_none(value)
    return None if t is None or t in (_NOT_COLLECTED, _NO_AG_ROLE) else t


def _int_cell(value):
    c = _cell(value)
    if c is None:
        return None
    n = clean_number(c)
    return int(n) if n is not None and float(n).is_integer() else n


def _already_registered(pg_conn, instance_id: int, database_name: str) -> bool:
    with pg_conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM mssql_db_info WHERE instance_id = %s AND database_name = %s",
            (instance_id, database_name),
        )
        return cur.fetchone() is not None


def parse_db_info(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)

    own_conn = pg_conn is None
    if own_conn:
        from sqlwr_parser_utils import get_db_connection
        pg_conn = get_db_connection()
    try:
        instance_id = resolve_instance_id(pg_conn, metadata["host_name"], metadata["instance"])
        if instance_id is None:
            logger.error(f"Could not resolve instance_id for host={metadata['host_name']!r} "
                         f"instance={metadata['instance']!r} -- skipping {TABLE_NAME}")
            return []

        database_name = metadata["dbname"]
        if not database_name or database_name == _NOT_COLLECTED:
            logger.warning(f"{TABLE_NAME}: no database name in this report's metadata -- skipping")
            return []

        if _already_registered(pg_conn, instance_id, database_name):
            logger.info(f"{TABLE_NAME}: {database_name!r} on instance {instance_id} already "
                        f"registered -- skipping (first-report-only, per spec)")
            return []
    finally:
        if own_conn:
            pg_conn.close()

    db_heading = soup.find("h3", string=DB_SECTION_HEADING)
    db_table = db_heading.find_next("table") if db_heading else None
    db_rows = read_raw_rows(db_table) if db_table is not None else []
    db_row = db_rows[0] if db_rows else {}

    def col(name):
        return db_row.get(name)

    rec = {
        "instance_name": metadata["instance"],
        "instance_id": instance_id,
        "inst_num": _int_cell(col("Inst Num")),
        "database_name": database_name,
        "database_id": _int_cell(col("DB Id")),
        "unique_name": _cell(col("Unique Name")),
        "role": _cell(col("Role")),
        "edition": _cell(col("Edition")),
        "release": _cell(col("Release")),
        "host_name": _cell(col("Host Name")) or metadata["host_name"],
        "platform": _cell(col("Platform")),
        "cpu_count": _int_cell(col("CPUs")),
        "cores": _int_cell(col("Cores")),
        "socket": _int_cell(col("Sockets")),
        "memory_gb": clean_number(col("Memory (GB)")) if _cell(col("Memory (GB)")) else None,
        "source_type": "local_file",
        "repo_path": os.path.abspath(filepath),
    }
    rec["row_hash"] = row_hash(rec)

    logger.info(f"Parsed 1 {TABLE_NAME} record for {database_name!r} from {filepath}")
    return [rec]


def insert_db_info(records: list) -> int:
    """
    Delegates to the shared insert_records() (same helper every other SQLWR
    parser uses), with conflict_columns=["instance_id", "database_name"] --
    the stricter, dedicated-to-this-table dedup rule the module docstring
    describes, in place of the usual (database_name, instance_id,
    begin_snapshot_id, row_hash) pattern the other 27 tables use (this table
    has no begin_snapshot_id at all; it isn't a per-report table).
    """
    return insert_records(
        records, TABLE_NAME,
        columns=["instance_name", "instance_id", "inst_num", "database_name", "database_id",
                 "unique_name", "role", "edition", "release", "host_name", "platform",
                 "cpu_count", "cores", "socket", "memory_gb", "row_hash", "source_type", "repo_path"],
        conflict_columns=["instance_id", "database_name"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_db_info(parse_db_info(_target))
    else:
        logger.error("No filepath provided")
