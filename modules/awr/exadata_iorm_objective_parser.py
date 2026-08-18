# modules/awr/exadata_iorm_objective_parser.py — IORM Objective
import os, sys, warnings
from io import StringIO
import pandas as pd
from bs4 import BeautifulSoup
warnings.simplefilter("ignore")
_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(_ROOT, "common"))
from db import get_db_connection
from utils import row_hash as make_row_hash, extract_workload_repo_metadata, sanitize_record
from logger_utils import get_logger
logger = get_logger("exadata_iorm_objective_parser")
_SECTION_KW = ["iorm objective"]
_STOP_KW    = ["exadata server health","exadata statistics","exadata alerts"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        if any(kw in tag.get_text(strip=True).lower() for kw in _SECTION_KW): return tag
    return None

def parse_iorm_objective(filepath):
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  IORM Objective section not found"); return []
    sib = section.find_next_sibling()
    while sib:
        nm = getattr(sib, "name", None)
        if nm in ("h2","h3","h4") and any(k in sib.get_text(strip=True).lower() for k in _STOP_KW): break
        if nm == "table":
            try:
                dfs = pd.read_html(StringIO(str(sib)))
                if not dfs: sib = sib.find_next_sibling(); continue
                df = dfs[0]
                if df.empty: sib = sib.find_next_sibling(); continue
                row = list(df.iloc[0])
                begin = str(row[0]).strip() if row else None
                end   = str(row[1]).strip() if len(row)>1 else None
                cells = str(row[2]).strip() if len(row)>2 else None
                if begin and begin.lower() not in ("nan","begin",""):
                    rec = sanitize_record({
                        "dbname": meta["dbname"], "begin_snap": meta["begin_snap"],
                        "snap_time": meta["snap_time"],
                        "iorm_begin": begin,
                        "iorm_end":   None if (not end or end.lower() in ("nan","")) else end,
                        "cells":      cells,
                        "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"]}),
                    })
                    logger.info(f"✅ Parsed IORM Objective: begin={begin}, cells={cells}")
                    return [rec]
            except: pass
        sib = sib.find_next_sibling()
    logger.warning("⚠️  No IORM Objective table rows found"); return []

def insert_iorm_objective(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_iorm_objective
            (dbname,begin_snap,snap_time,iorm_begin,iorm_end,cells,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["begin_snap"],r["snap_time"],
                r["iorm_begin"],r["iorm_end"],r["cells"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_iorm_objective")
    except Exception as e:
        logger.error(f"❌ IORM Objective insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_iorm_objective(filepath); insert_iorm_objective(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
