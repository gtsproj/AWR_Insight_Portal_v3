"""
modules/mssql/sqlwr_sql_text_parser.py

Parses the SQLWR report's "Complete List of SQL Text" section (the full text of
every query referenced by the four "SQL ordered by ..." sections, one row per
sql_id) into mssql_sqlwr_sql_text. The four ordered-by sections show only a
30-character preview; this is where the whole statement lives, joined on sql_id.

Why the text is read from the raw HTML cell and NOT via pandas
--------------------------------------------------------------
pandas.read_html collapses every run of whitespace inside a cell to a single
space, which destroys line breaks. For SQL that is not cosmetic: a "--" line
comment then swallows everything after it. Real example from a report: a
statement whose comment lines end with "-- otherwise pick" followed on the next
line by "WHERE UPPER(notes) LIKE '%X%'" -- pandas returns it all on one line, so
the WHERE clause becomes part of the comment and the stored statement means
something different. So the section is still classified (missing / header-only /
empty-placeholder) with the shared pandas-based helper, but the ids and texts
are taken from the cells' own text, which keeps the original newlines and
indentation. Only leading/trailing whitespace of a text is stripped.

sql_id goes through the shared normalize_sql_id() like the other SQL sections,
so a query has the same id here as in the ordered-by tables whatever the age of
the report (old "q39" and current "39" both -> "39") -- required for joining
text to them.
"""

import sys
import warnings

from bs4 import BeautifulSoup

from sqlwr_parser_utils import (
    extract_sqlwr_metadata, resolve_instance_id, get_section_table,
    is_section_missing_or_empty, insert_records, row_hash, normalize_sql_id,
)
from logger_utils import get_logger

warnings.simplefilter(action="ignore", category=FutureWarning)
logger = get_logger("sqlwr_sql_text_parser")

SECTION_HEADING = "Complete List of SQL Text"
TABLE_NAME = "mssql_sqlwr_sql_text"


def parse_sql_text(filepath: str, pg_conn=None) -> list:
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_sqlwr_metadata(soup)

    # Classification only (missing / header-only / "(no SQL captured ...)" placeholder).
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
    seen = set()
    for tr in table.find_all("tr"):
        cells = tr.find_all("td")          # header row has <th>, so it is skipped here
        if len(cells) < 2:
            continue
        sql_id = normalize_sql_id(cells[0].get_text(strip=True))
        if sql_id is None:
            continue
        if sql_id in seen:
            logger.warning(f"{SECTION_HEADING}: sql_id {sql_id} listed more than once -- keeping the first")
            continue
        seen.add(sql_id)
        sql_text = cells[1].get_text().strip()      # raw text: newlines/indentation preserved
        rec = {
            "database_name": metadata["dbname"],
            "instance_id": instance_id,
            "sql_id": sql_id,
            "sql_text": sql_text or None,
            "begin_snapshot_id": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"Parsed {len(records)} {SECTION_HEADING} record(s) from {filepath}")
    return records


def insert_sql_text(records: list) -> int:
    return insert_records(
        records, TABLE_NAME,
        columns=["database_name", "instance_id", "sql_id", "sql_text", "begin_snapshot_id", "row_hash"],
        conflict_columns=["database_name", "instance_id", "begin_snapshot_id", "row_hash"],
    )


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if _target:
        insert_sql_text(parse_sql_text(_target))
    else:
        logger.error("No filepath provided")
