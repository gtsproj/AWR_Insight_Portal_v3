#modules/init_parameters_parser.py

# modules/init_parameters_parser.py
#
# Parses the AWR "Initialization Parameters" section -- two sub-tables
# under one h2, both with the identical shape
# Parameter Name | Begin value | End value (if different):
#   - "Modified Parameters"
#   - "Modified Multi-Valued Parameters"
#
# Storage model (per Ganesh, 2026-08-28): NOT a per-snapshot historical
# log like most awr_* tables. awr_init_parameters is a deduplicated
# CURRENT-STATE key-value store -- one row per (dbname, instance,
# parameter_name), continuously upserted.
#
# Every parameter listed is captured, not just changed ones: on first
# sight of a parameter, it's inserted using its End Value if present
# (a change happened in the very first report parsed) or its Begin
# Value otherwise (baseline, unchanged so far). On every later parse,
# a parameter's stored value is only ever overwritten when that row
# has a populated End Value (a genuine change this window) or when the
# parameter is being seen for the very first time -- rows with no End
# Value for an already-known parameter leave the existing stored value
# untouched.

import os
import sys
import warnings
import pandas as pd
from bs4 import BeautifulSoup

warnings.simplefilter(action="ignore", category=FutureWarning)

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "common"))
from db import get_db_connection
from utils import extract_workload_repo_metadata, get_col
from logger_utils import get_logger
import io

LOG_DIR = os.path.join(os.path.dirname(__file__), "..", "logs")
os.makedirs(LOG_DIR, exist_ok=True)
logger = get_logger("init_parameters_parser")


def _is_populated(val):
    """True if an End Value cell actually has a value -- pandas gives
    us NaN/None for a genuinely blank cell, but AWR HTML sometimes also
    renders it as an empty string or just whitespace."""
    if val is None:
        return False
    try:
        if pd.isna(val):
            return False
    except (TypeError, ValueError):
        pass
    return str(val).strip() != ""


def _parse_one_section(soup, header_text, metadata):
    """Parse one of the two identically-shaped tables under
    Initialization Parameters. Returns every row, not just changed
    ones -- each record carries has_end_value so insert_init_parameters
    can decide whether to overwrite an existing stored value or only
    insert-if-new. value is End Value when present, else Begin Value."""
    records = []

    section = soup.find("h3", string=header_text)
    if not section:
        logger.warning(f"⚠️ '{header_text}' section not found.")
        return records

    table = section.find_next("table")
    if not table:
        logger.warning(f"⚠️ '{header_text}' table not found.")
        return records

    try:
        df = pd.read_html(io.StringIO(str(table)))[0]
    except ValueError:
        logger.info(f"'{header_text}': no rows.")
        return records

    if df.empty:
        logger.info(f"'{header_text}': no rows.")
        return records

    changed = 0
    for _, row in df.iterrows():
        param_name = get_col(row, "Parameter Name", logger, header_text)
        if not param_name or str(param_name).strip() == "":
            continue
        begin_value = get_col(row, "Begin value", logger, header_text)
        end_value = get_col(row, "End value (if different)", logger, header_text)
        has_end_value = _is_populated(end_value)
        value = end_value if has_end_value else begin_value
        if has_end_value:
            changed += 1
        records.append({
            "dbname": metadata["dbname"],
            "instance": metadata["instance"],
            "parameter_name": str(param_name).strip(),
            "value": str(value).strip() if value is not None else None,
            "has_end_value": has_end_value,
            "last_changed_begin_snap": metadata["begin_snap"],
        })

    logger.info(f"'{header_text}': {len(records)} parameter(s) total, {changed} changed this window")
    return records


def parse_init_parameters(filepath):
    """Parse both Initialization Parameters sub-sections from an AWR
    HTML report. Returns every parameter listed (not just changed
    ones) -- see module docstring for how insert_init_parameters uses
    the has_end_value flag on each record."""
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_workload_repo_metadata(soup)
    if not metadata:
        logger.error("❌ Failed extracting workload repo metadata")
        return []

    records = []
    records += _parse_one_section(soup, "Modified Parameters", metadata)
    records += _parse_one_section(soup, "Modified Multi-Valued Parameters", metadata)

    logger.info(f"✅ Parsed {len(records)} Initialization Parameter row(s) total")
    return records


def insert_init_parameters(records):
    """Upsert parsed parameters into awr_init_parameters -- deduplicated
    key-value store keyed on (dbname, instance, parameter_name).

    Two paths, split by has_end_value:
      - has_end_value=True  -> ON CONFLICT DO UPDATE (a real change
        this window always overwrites the stored value; also serves
        as the initial insert the first time this parameter is seen).
      - has_end_value=False -> ON CONFLICT DO NOTHING (inserts only if
        this parameter has never been seen before; if it already
        exists, its stored value is left untouched since nothing
        changed this window).
    This gives: every parameter gets captured on first sight (using
    whichever of begin/end value was resolved into `value` by the
    parser), and on every later parse only genuinely-changed
    parameters overwrite what's already stored."""
    if not records:
        logger.info("No Initialization Parameters found in this report.")
        return

    changed_records   = [r for r in records if r["has_end_value"]]
    unchanged_records = [r for r in records if not r["has_end_value"]]

    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        if changed_records:
            cur.executemany("""
                INSERT INTO awr_init_parameters (
                    dbname, instance, parameter_name, value, last_changed_begin_snap
                )
                VALUES (%(dbname)s, %(instance)s, %(parameter_name)s, %(value)s, %(last_changed_begin_snap)s)
                ON CONFLICT (dbname, instance, parameter_name) DO UPDATE
                    SET value = EXCLUDED.value,
                        last_changed_begin_snap = EXCLUDED.last_changed_begin_snap,
                        updated_at = NOW()
            """, changed_records)

        if unchanged_records:
            cur.executemany("""
                INSERT INTO awr_init_parameters (
                    dbname, instance, parameter_name, value, last_changed_begin_snap
                )
                VALUES (%(dbname)s, %(instance)s, %(parameter_name)s, %(value)s, %(last_changed_begin_snap)s)
                ON CONFLICT (dbname, instance, parameter_name) DO NOTHING
            """, unchanged_records)

        conn.commit()
        cur.close()
        logger.info(f"✅ {len(changed_records)} parameter(s) updated (had End Value), "
                    f"{len(unchanged_records)} parameter(s) inserted-if-new "
                    f"(no End Value this window)")

    except Exception as e:
        logger.error(f"❌ Failed upserting Initialization Parameters: {e}", exc_info=True)
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    # When called via exec fallback from master_parser,
    # `filepath` is injected into globals
    _target = globals().get("filepath") or locals().get("filepath")
    if not _target:
        _target = sys.argv[1] if len(sys.argv) > 1 else None
    if _target:
        records = parse_init_parameters(_target)
        insert_init_parameters(records)
    else:
        logger.error("No filepath provided")
