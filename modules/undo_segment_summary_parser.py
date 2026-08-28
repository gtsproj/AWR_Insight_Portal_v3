#modules/undo_segment_summary_parser.py

# modules/undo_segment_summary_parser.py
#
# Parses the "Undo Segment Summary" section of the AWR report -- a
# SEPARATE section from "Undo Segment Stats" (undo_statistics_parser.py):
# one row per undo tablespace (Undo TS#) summarizing the whole snapshot
# range, rather than one row per V$UNDOSTAT 10-minute interval.
#
# Two things this table has that Undo Segment Stats doesn't:
#   - Num Undo Blocks (K) is in THOUSANDS (per the AWR report's own
#     column header) -- stored as num_undo_blocks_k, not normalized to
#     a raw count, so it matches what's shown on the report page.
#   - Min/Max TR (mins) is a combined "min/max" range (e.g. "300/300"),
#     unlike Undo Segment Stats' single "Tun Ret (mins)" value -- split
#     into min_tr_mins / max_tr_mins.
#
# STO/OOS and uS/uR/uU/eS/eR/eU are shaped the same way as in Undo
# Segment Stats (combined slash-delimited cells), so this reuses the
# same split helpers.

import os
import sys
import warnings
import psycopg2
import pandas as pd
from bs4 import BeautifulSoup

warnings.simplefilter(action="ignore", category=FutureWarning)

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "common"))
from db import get_db_connection
from utils import row_hash, extract_workload_repo_metadata, clean_number, is_section_empty, sanitize_record, get_col
from logger_utils import get_logger
import io

LOG_DIR = os.path.join(os.path.dirname(__file__), "..", "logs")
os.makedirs(LOG_DIR, exist_ok=True)
logger = get_logger("undo_segment_summary_parser")


def _split_sto_oos(raw):
    """'0/0' -> (sto_count, oos_count)."""
    if raw is None:
        return None, None
    parts = str(raw).strip().split("/")
    if len(parts) != 2:
        logger.warning(f"⚠️ Unexpected STO/OOS cell shape: {raw!r}")
        return None, None
    return clean_number(parts[0]), clean_number(parts[1])


def _split_block_stats(raw):
    """'0/0/0/0/0/6045319' -> (uS, uR, uU, eS, eR, eU)."""
    if raw is None:
        return (None,) * 6
    parts = str(raw).strip().split("/")
    if len(parts) != 6:
        logger.warning(f"⚠️ Unexpected uS/uR/uU/eS/eR/eU cell shape: {raw!r}")
        return (None,) * 6
    return tuple(clean_number(p) for p in parts)


def _split_min_max_tr(raw):
    """'300/300' -> (min_tr_mins, max_tr_mins)."""
    if raw is None:
        return None, None
    parts = str(raw).strip().split("/")
    if len(parts) != 2:
        logger.warning(f"⚠️ Unexpected Min/Max TR cell shape: {raw!r}")
        return None, None
    return clean_number(parts[0]), clean_number(parts[1])


def parse_undo_segment_summary(filepath):
    """Parse the Undo Segment Summary section from an AWR HTML report."""
    records = []

    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_workload_repo_metadata(soup)
    if not metadata:
        logger.error("❌ Failed extracting workload repo metadata")
        return []

    section = soup.find("h3", string="Undo Segment Summary")
    if not section:
        logger.warning("⚠️ Undo Segment Summary section not found.")
        return []

    table = section.find_next("table")
    if not table:
        logger.warning("⚠️ Undo Segment Summary table not found.")
        return []

    df = pd.read_html(io.StringIO(str(table)))[0]
    logger.info(f"Found {len(df)} rows in Undo Segment Summary section")

    if is_section_empty(df, "Undo Segment Summary", "awr_undo_segment_summary"):
        return []

    for _, row in df.iterrows():
        sto_count, oos_count = _split_sto_oos(get_col(row, "STO/ OOS", logger, "Undo Segment Summary"))
        us, ur, uu, es, er, eu = _split_block_stats(
            get_col(row, "uS/uR/uU/ eS/eR/eU", logger, "Undo Segment Summary"))
        min_tr, max_tr = _split_min_max_tr(
            get_col(row, "Min/Max TR (mins)", logger, "Undo Segment Summary"))

        rec = {
            "dbname": metadata["dbname"],
            "instance": metadata["instance"],
            "instnum": metadata["instnum"],
            "snap_time": metadata["snap_time"],
            "begin_snap": metadata["begin_snap"],
            "undo_ts_num": clean_number(get_col(row, "Undo TS#", logger, "Undo Segment Summary")),
            "num_undo_blocks_k": clean_number(get_col(row, "Num Undo Blocks (K)", logger, "Undo Segment Summary")),
            "number_of_transactions": clean_number(row.get("Number of Transactions", None)),
            "max_qry_len_s": clean_number(row.get("Max Qry Len (s)", None)),
            "max_tx_concurrency": clean_number(get_col(row, "Max Tx Concurcy", logger, "Undo Segment Summary")),
            "min_tr_mins": min_tr,
            "max_tr_mins": max_tr,
            "sto_count": sto_count,
            "oos_count": oos_count,
            "us_stolen": us, "ur_released": ur, "uu_reused": uu,
            "es_stolen": es, "er_released": er, "eu_reused": eu,
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"✅ Parsed {len(records)} Undo Segment Summary records")
    return records


def insert_undo_segment_summary(records):
    """Insert parsed Undo Segment Summary rows into DB."""
    if not records:
        logger.warning("⚠️ No records to insert into awr_undo_segment_summary")
        return

    records = [sanitize_record(rec) for rec in records]

    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        insert_query = """
            INSERT INTO awr_undo_segment_summary (
                dbname, instance, instnum, snap_time,
                undo_ts_num, num_undo_blocks_k, number_of_transactions,
                max_qry_len_s, max_tx_concurrency, min_tr_mins, max_tr_mins,
                sto_count, oos_count,
                us_stolen, ur_released, uu_reused, es_stolen, er_released, eu_reused,
                begin_snap, row_hash
            )
            VALUES (
                %(dbname)s, %(instance)s, %(instnum)s, %(snap_time)s,
                %(undo_ts_num)s, %(num_undo_blocks_k)s, %(number_of_transactions)s,
                %(max_qry_len_s)s, %(max_tx_concurrency)s, %(min_tr_mins)s, %(max_tr_mins)s,
                %(sto_count)s, %(oos_count)s,
                %(us_stolen)s, %(ur_released)s, %(uu_reused)s, %(es_stolen)s, %(er_released)s, %(eu_reused)s,
                %(begin_snap)s, %(row_hash)s
            )
            ON CONFLICT (dbname, instance, begin_snap, row_hash) DO NOTHING
        """

        cur.executemany(insert_query, records)
        conn.commit()
        cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_undo_segment_summary")

    except psycopg2.errors.UniqueViolation:
        logger.warning("⚠️ Skipped duplicate Undo Segment Summary record")
        if conn:
            conn.rollback()

    except Exception as e:
        logger.error(f"❌ Failed inserting Undo Segment Summary: {e}", exc_info=True)
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
        records = parse_undo_segment_summary(_target)
        insert_undo_segment_summary(records)
    else:
        logger.error("No filepath provided")
