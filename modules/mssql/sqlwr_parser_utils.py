"""
modules/mssql/sqlwr_parser_utils.py

Shared utilities for every MSSQL SQLWR-report section parser.

Reuses common/utils.py's row_hash(), clean_number(), sanitize_record()
directly -- these are already generic, not Oracle-specific. Also
reuses extract_workload_repo_metadata() directly for dbname/instance/
begin_snap/snap_time: confirmed by direct testing against a real
generated SQLWR report that this works as-is, because this project's
Database Summary and Snapshot Summary tables deliberately use the
identical summary= HTML attribute text the Oracle parsers already look
for (a choice made earlier this session specifically so the Oracle
parser architecture could be adapted with less duplicated effort, not
a coincidence).

extract_sqlwr_metadata() below extends that shared function with the
two things it doesn't cover for this report: host_name (a column the
Oracle-side Database Summary table doesn't have) and end_snap/
end_snap_time (this report's Snapshot Summary table has both a Begin
Snap AND an End Snap row, unlike Oracle's simpler, begin-snap-only
convention).

Deliberately does NOT replicate the sys.exit(0) pattern found in the
existing Oracle parsers (e.g. sql_elapsed_time_parser.py) when a
section is empty -- confirmed directly, earlier this session, that
this kills the entire Python process, not just that one section's
parsing. Every parser built on these utilities returns an empty list
for an empty/missing section instead, so a future orchestrator can run
many parsers against one report file in a single process without one
empty section aborting all the others.
"""

import os
import re
import sys
import warnings
from io import StringIO

import pandas as pd

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "..", "common"))
from utils import extract_workload_repo_metadata, row_hash, clean_number, sanitize_record  # noqa: E402
from db import get_db_connection  # noqa: E402
from logger_utils import get_logger  # noqa: E402

logger = get_logger("sqlwr_parser_utils")


def extract_sqlwr_metadata(soup) -> dict:
    """
    Full metadata for a SQLWR report: dbname, instance, begin_snap,
    snap_time (from the shared extract_workload_repo_metadata()),
    plus host_name and end_snap/end_snap_time (extracted here,
    specific to this report's own HTML shape).
    """
    # The shared function parses snap_time with dayfirst=True (right for Oracle
    # AWR's dd/mm dates). On this report's ISO timestamps that produces a pandas
    # UserWarning when the day is > 12 (dayfirst is ignored, value is correct) and
    # SILENTLY swaps day/month when the day is <= 12. The warning is therefore
    # noise, and the silent case is the real hazard -- which is why snap_time is
    # re-parsed correctly below and overwritten. Suppress only that one message
    # (not a blanket filter) so any other, genuine warning still surfaces.
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message=r"Parsing dates in .* when dayfirst=True was specified",
            category=UserWarning,
        )
        metadata = extract_workload_repo_metadata(soup)
    metadata["host_name"] = None
    metadata["end_snap"] = None
    metadata["end_snap_time"] = None

    inst_table = soup.find("table", summary="This table displays database instance information")
    if inst_table is not None:
        try:
            df = pd.read_html(StringIO(str(inst_table)))[0]
        except ValueError:
            df = None
        if df is not None and not df.empty:
            row = df.iloc[0]
            cols = [str(c).strip().lower() for c in df.columns]
            if "host name" in cols:
                v = row.iloc[cols.index("host name")]
                metadata["host_name"] = None if pd.isna(v) else str(v).strip()

    snap_table = soup.find("table", summary="This table displays snapshot information")
    if snap_table is not None:
        try:
            df = pd.read_html(StringIO(str(snap_table)))[0]
        except ValueError:
            df = None
        if df is not None:
            for _, row in df.iterrows():
                vals = list(row)
                if not vals:
                    continue
                label = str(vals[0]).strip().lower()
                if "begin snap" in label and len(vals) > 2:
                    # The shared extract_workload_repo_metadata() parses snap_time with
                    # dayfirst=True (correct for Oracle AWR's dd/mm-style dates), which
                    # SWAPS day and month on this report's ISO timestamps whenever the
                    # day is <= 12 (confirmed directly: '2026-09-03' -> 2026-03-09).
                    # Re-parse the begin snapshot time here without dayfirst so
                    # metadata["snap_time"] is right for every day of the month.
                    ts = str(vals[2]).strip()
                    if ts and ts.lower() not in ("nan", "none"):
                        parsed = pd.to_datetime(ts, errors="coerce")
                        if not pd.isna(parsed):
                            metadata["snap_time"] = parsed
                if "end snap" in label:
                    try:
                        metadata["end_snap"] = int(float(str(vals[1])))
                    except (ValueError, IndexError):
                        pass
                    if len(vals) > 2:
                        try:
                            ts = str(vals[2]).strip()
                            if ts and ts.lower() not in ("nan", "none"):
                                metadata["end_snap_time"] = pd.to_datetime(ts, errors="coerce")
                        except (ValueError, IndexError):
                            pass
                    break

    return metadata


def resolve_instance_id(pg_conn, host_name, instance_name):
    """Look up mssql_instance_master.id for (host_name, instance_name)."""
    if not host_name or not instance_name:
        return None
    with pg_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM mssql_instance_master WHERE host_name = %s AND instance_name = %s",
            (host_name, instance_name)
        )
        row = cur.fetchone()
    return row[0] if row else None


def text_or_none(value):
    """Cell text stripped, or None for None / empty / NaN (pandas' marker for a missing cell)."""
    if value is None:
        return None
    s = str(value).strip()
    return None if s == "" or s.lower() == "nan" else s


def parse_pct(value):
    """Percent cell -> float. Tolerates a trailing '%' (some sections render one, some don't)."""
    return clean_number(str(value).strip().rstrip("%"))


_Q_PREFIXED_ID = re.compile(r"^q(\d+)$", re.IGNORECASE)
_FLOATED_INT = re.compile(r"^(\d+)\.0+$")


def normalize_sql_id(value):
    """
    Query Store query_id as text, one canonical form across report ages.

    Reports generated before the cosmetic "q" prefix was dropped carry ids like
    "q39"; current reports carry "39" -- the prefix carried no information (see
    sqlwr_report_generator.py), so it is stripped, otherwise the same query would
    be stored under two ids depending on report age. Also strips the ".0" pandas
    produces when a whole-number column has a missing cell. Deliberately strict:
    only a leading q followed ENTIRELY by digits, or digits followed by .0+ --
    anything else is returned untouched.

        'q39' -> '39'   39 -> '39'   47.0 -> '47'   None/NaN/'' -> None
        'q39a', 'qq39', '47.5', '0x1F' -> unchanged
    """
    s = text_or_none(value)
    if s is None:
        return None
    m = _Q_PREFIXED_ID.match(s)
    if m:
        return m.group(1)
    m = _FLOATED_INT.match(s)
    if m:
        return m.group(1)
    return s


def get_section_table(soup, heading_text: str):
    """
    Find a report section's table by its exact <h3> heading text and
    parse it into a DataFrame. Returns None if the section or its
    table isn't found in this report -- callers should return an
    empty list in that case, not sys.exit(0) (see module docstring).
    """
    section = soup.find("h3", string=heading_text)
    if not section:
        return None
    table = section.find_next("table")
    if not table:
        return None
    try:
        return pd.read_html(StringIO(str(table)))[0]
    except ValueError:
        return None


def is_section_missing_or_empty(df, section_name: str, table_name: str) -> bool:
    """
    Logs a warning and returns True if df is None or has no real data
    rows (the "(...)"-style single placeholder row every empty SQLWR
    section renders, e.g. "(no deadlocks recorded for this snapshot
    pair)", counts as empty here too, so those placeholder rows never
    get parsed as real data).
    """
    if df is None:
        logger.warning(f"{section_name} section not found or has no table.")
        return True
    if df.empty:
        # Table present with a header row but no data rows: how the report renders
        # an empty SQL-ordered-by section (and how some older reports rendered
        # others). A legitimate empty state, not a problem -- INFO, not WARNING.
        logger.info(f"{section_name}: table has a header but no data rows -- "
                    f"nothing to insert into {table_name}.")
        return True
    if df.dropna(how="all").empty:
        logger.warning(f"{section_name} section has no data rows.")
        return True
    # A single row whose first cell starts with "(" is this report's own
    # empty-state placeholder text (e.g. "(no ... for this snapshot pair)"),
    # not real data -- checked so it's never inserted as a row.
    if len(df) == 1:
        first_cell = str(df.iloc[0, 0]).strip()
        if first_cell.startswith("("):
            logger.info(f"{section_name}: only the empty-state placeholder row present, "
                        f"nothing to insert into {table_name}.")
            return True
    return False


def insert_records(records: list, table_name: str, columns: list, conflict_columns: list) -> int:
    """
    Shared, generic INSERT ... ON CONFLICT DO NOTHING for any SQLWR
    section table -- every one of these tables follows the identical
    shape (columns + row_hash + a UNIQUE(..., row_hash) constraint),
    so one shared function handles the insert for all of them rather
    than duplicating a near-identical INSERT statement in every parser
    file. `columns` must match the record dict keys exactly and the
    target table's actual column order is irrelevant (uses %(name)s
    named placeholders, not positional).
    """
    if not records:
        # Every caller reaches here only after already logging the actual reason at
        # the right level (INFO for a section that legitimately has no data rows,
        # WARNING if the section is missing from the report, ERROR if the instance
        # can't be resolved) -- a second WARNING here just duplicated that and made
        # a perfectly normal empty section look like a problem.
        logger.debug(f"No records to insert into {table_name}")
        return 0

    records = [sanitize_record(dict(rec)) for rec in records]
    col_list = ", ".join(columns)
    placeholders = ", ".join(f"%({c})s" for c in columns)
    conflict_list = ", ".join(conflict_columns)

    sql = f"""
        INSERT INTO {table_name} ({col_list})
        VALUES ({placeholders})
        ON CONFLICT ({conflict_list}) DO NOTHING
        RETURNING 1
    """

    conn = None
    inserted = 0
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            # executemany()'s own rowcount is unreliable for batched
            # ON CONFLICT DO NOTHING (confirmed directly: it reported
            # the full batch size even on a second, fully-duplicate
            # re-run where zero rows were actually new) -- executing
            # one at a time with RETURNING 1 and counting actual
            # results is slower but accurate, and this insert path
            # only ever handles one report's worth of rows at a time
            # (tens to low hundreds), not a volume where that matters.
            for rec in records:
                cur.execute(sql, rec)
                if cur.fetchone() is not None:
                    inserted += 1
        conn.commit()
        logger.info(f"Inserted {inserted} new row(s) (of {len(records)} parsed) into {table_name}")
    except Exception as e:
        logger.error(f"Failed inserting into {table_name}: {e}", exc_info=True)
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()
    return inserted
