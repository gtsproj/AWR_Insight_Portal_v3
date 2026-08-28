#modules/undo_statistics_parser.py

import os
import sys
import warnings
import psycopg2
import pandas as pd
from bs4 import BeautifulSoup

# --- Suppress pandas FutureWarnings ---
warnings.simplefilter(action="ignore", category=FutureWarning)

# --- Add common folder to path ---
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "common"))
from db import get_db_connection
from config_loader import load_config
from utils import row_hash, extract_workload_repo_metadata, clean_number, is_section_empty, sanitize_record, get_col
from logger_utils import get_logger
import io

# --- Logging Setup ---
LOG_DIR = os.path.join(os.path.dirname(__file__), "..", "logs")
os.makedirs(LOG_DIR, exist_ok=True)
log_file = os.path.join(LOG_DIR, "undo_statistics_parser.log")

logger = get_logger("undo_statistics_parser")  # or dynamic module name


def _split_sto_oos(raw):
    """'0/0' -> (sto_count, oos_count). Returns (None, None) on any
    unexpected shape rather than raising -- a malformed cell shouldn't
    take down the whole row."""
    if raw is None:
        return None, None
    parts = str(raw).strip().split("/")
    if len(parts) != 2:
        logger.warning(f"⚠️ Unexpected STO/OOS cell shape: {raw!r}")
        return None, None
    return clean_number(parts[0]), clean_number(parts[1])


def _split_block_stats(raw):
    """'0/0/0/0/0/6045319' -> (uS, uR, uU, eS, eR, eU). Returns six
    Nones on any unexpected shape rather than raising."""
    if raw is None:
        return (None,) * 6
    parts = str(raw).strip().split("/")
    if len(parts) != 6:
        logger.warning(f"⚠️ Unexpected uS/uR/uU/eS/eR/eU cell shape: {raw!r}")
        return (None,) * 6
    return tuple(clean_number(p) for p in parts)


def parse_undo_statistics(filepath):
    """Parse the Undo Segment Stats section from AWR report."""
    records = []

    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    metadata = extract_workload_repo_metadata(soup)
    if not metadata:
        logger.error("❌ Failed extracting workload repo metadata")
        return []

    section = soup.find("h3", string="Undo Segment Stats")
    if not section:
        logger.warning("⚠️ Undo Segment Stats section not found.")
        return []

    table = section.find_next("table")
    if not table:
        logger.warning("⚠️ Undo Segment Stats table not found.")
        return []

    df = pd.read_html(io.StringIO(str(table)))[0]
    logger.info(f"Found {len(df)} rows in Undo Segment Stats section")

    if is_section_empty(df, "Undo Segment Stats", "awr_undo_statistics"):
        sys.exit(0)  # Skip this section

    for _, row in df.iterrows():
        sto_count, oos_count = _split_sto_oos(get_col(row, "STO/ OOS", logger, "Undo Segment Stats"))
        us, ur, uu, es, er, eu = _split_block_stats(
            get_col(row, "uS/uR/uU/ eS/eR/eU", logger, "Undo Segment Stats"))
        rec = {
            "dbname": metadata["dbname"],
            "instance": metadata["instance"],
            "instnum": metadata["instnum"],
            "snap_time": metadata["snap_time"],
            "begin_snap": metadata["begin_snap"],
            "num_undo_blocks": clean_number(row.get("Num Undo Blocks", None)),
            "number_of_transactions": clean_number(row.get("Number of Transactions", None)),
            "max_qry_len_s": clean_number(row.get("Max Qry Len (s)", None)),
            "max_tx_concy": clean_number(row.get("Max Tx Concy", None)),
            "tun_ret_mins": clean_number(get_col(row, "Tun Ret (mins)", logger, "Undo Segment Stats")),
            "sto_count": sto_count,
            "oos_count": oos_count,
            "us_stolen": us, "ur_released": ur, "uu_reused": uu,
            "es_stolen": es, "er_released": er, "eu_reused": eu,
        }
        rec["row_hash"] = row_hash(rec)
        records.append(rec)

    logger.info(f"✅ Parsed {len(records)} Undo Segment Stats records")
    return records


def insert_undo_statistics(records):
    """Insert parsed Undo Segment Stats into DB."""
    if not records:
        logger.warning("⚠️ No records to insert into awr_undo_statistics")
        return

    #sanitize all records before insertion
    records = [sanitize_record(rec) for rec in records]

    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        insert_query = """
            INSERT INTO awr_undo_statistics (
                dbname, instance, instnum, snap_time,
                num_undo_blocks, number_of_transactions, max_qry_len_s, max_tx_concy,
                tun_ret_mins, sto_count, oos_count,
                us_stolen, ur_released, uu_reused, es_stolen, er_released, eu_reused,
                begin_snap, row_hash
            )
            VALUES (
                %(dbname)s, %(instance)s, %(instnum)s, %(snap_time)s,
                %(num_undo_blocks)s, %(number_of_transactions)s, %(max_qry_len_s)s, %(max_tx_concy)s,
                %(tun_ret_mins)s, %(sto_count)s, %(oos_count)s,
                %(us_stolen)s, %(ur_released)s, %(uu_reused)s, %(es_stolen)s, %(er_released)s, %(eu_reused)s,
                %(begin_snap)s, %(row_hash)s
            )
            ON CONFLICT (dbname, instance, begin_snap, row_hash) DO NOTHING
        """

        cur.executemany(insert_query, records)
        conn.commit()
        cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_undo_statistics")

    except psycopg2.errors.UniqueViolation:
        logger.warning("⚠️ Skipped duplicate Undo Segment Stats record")
        if conn:
            conn.rollback()

    except Exception as e:
        logger.error(f"❌ Failed inserting Undo Segment Stats: {e}", exc_info=True)
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    # When called via exec fallback from master_parser, 
    # `filepath` is injected into globals
    _target = globals().get("filepath") or locals().get("filepath")
    if not _target:
        import sys
        _target = sys.argv[1] if len(sys.argv) > 1 else None
    if _target:
        records = parse_undo_statistics(_target)
        insert_undo_statistics(records)
    else:
        logger.error("No filepath provided")
