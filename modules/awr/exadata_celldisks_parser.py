# modules/awr/exadata_celldisks_parser.py — Exadata Celldisks
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
logger = get_logger("exadata_celldisks_parser")
_SECTION_KW = ["exadata celldisk","celldisks"]
_STOP_KW    = ["asm diskgroup","iorm objective","exadata server health"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in _SECTION_KW) and "griddisk" not in txt: return tag
    return None

def _num(v):
    if v is None: return None
    s = str(v).strip().replace(",","")
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None

def parse_celldisks(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Exadata Celldisks section not found"); return []
    sib = section.find_next_sibling()
    while sib:
        nm = getattr(sib, "name", None)
        if nm in ("h2","h3","h4") and any(k in sib.get_text(strip=True).lower() for k in _STOP_KW): break
        if nm == "table":
            try:
                dfs = pd.read_html(StringIO(str(sib)))
                if not dfs: sib = sib.find_next_sibling(); continue
                df = dfs[0]
                df.columns = [str(c).lower() for c in df.columns]
                for _, row in df.iterrows():
                    vals = list(row)
                    disk_type = str(vals[0]).strip() if vals else None
                    if not disk_type or disk_type.lower() in ("nan","disk type","type",""): continue
                    r = dict(zip(df.columns, vals))
                    def g(*kws):
                        for col in df.columns:
                            if all(k in col for k in kws): return _num(r.get(col))
                        return None
                    rec = sanitize_record({
                        "dbname": meta["dbname"], "begin_snap": meta["begin_snap"],
                        "snap_time": meta["snap_time"], "disk_type": disk_type,
                        "celldisk_size_gb": g("size"),
                        "n_celldisks": int(g("# celldisk","n_cell","num cell","celldisk") or 0) or None,
                        "cells": str(r.get([c for c in df.columns if "cell" in c and "disk" not in c][0] if any("cell" in c and "disk" not in c for c in df.columns) else "",""  )).strip() or None,
                        "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"],"dt":disk_type}),
                    })
                    records.append(rec)
            except: pass
        sib = sib.find_next_sibling()
    logger.info(f"✅ Parsed {len(records)} Celldisk rows")
    return records

def insert_celldisks(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_celldisks
            (dbname,begin_snap,snap_time,disk_type,celldisk_size_gb,n_celldisks,cells,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,disk_type) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["begin_snap"],r["snap_time"],r["disk_type"],
                r["celldisk_size_gb"],r["n_celldisks"],r["cells"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_celldisks")
    except Exception as e:
        logger.error(f"❌ Celldisks insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_celldisks(filepath); insert_celldisks(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
