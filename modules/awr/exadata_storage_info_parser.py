# modules/awr/exadata_storage_info_parser.py — Exadata Storage Information
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
logger = get_logger("exadata_storage_info_parser")
_SECTION_KW = ["exadata storage information","storage information"]
_STOP_KW    = ["exadata griddisk","exadata celldisk","asm diskgroup"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in _SECTION_KW) and "server" not in txt and "version" not in txt: return tag
    return None

def _num(v):
    if v is None: return None
    s = str(v).strip().replace(",","")
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None

def parse_storage_info(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Exadata Storage Information section not found"); return []
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
                    n_cells = _num(vals[0]) if vals else None
                    if n_cells is None: continue
                    r = dict(zip(df.columns, vals))
                    def g(*kws):
                        for col in df.columns:
                            if all(k in col for k in kws): return _num(r.get(col))
                        return None
                    cell_list_raw = str(vals[-1]) if vals else ""
                    cell_list = cell_list_raw if "cell" in cell_list_raw.lower() else None
                    rec = sanitize_record({
                        "dbname": meta["dbname"], "begin_snap": meta["begin_snap"],
                        "snap_time": meta["snap_time"],
                        "n_cells": int(n_cells), "flash_cache_gb": g("flash cache","flash cache size"),
                        "xrmem_cache_gb": g("xrmem"), "flash_log_gb": g("flash log"),
                        "n_hard_disk": int(g("hard disk","hdd") or 0) or None,
                        "n_flash_disk": int(g("flash","n_flash","flash disk") or 0) or None,
                        "n_griddisks": int(g("griddisk") or 0) or None,
                        "n_celldisks": int(g("celldisk") or 0) or None,
                        "cell_list": cell_list,
                        "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"],"nc":int(n_cells)}),
                    })
                    records.append(rec)
            except: pass
        sib = sib.find_next_sibling()
    logger.info(f"✅ Parsed {len(records)} Storage Information rows")
    return records

def insert_storage_info(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_storage_info
            (dbname,begin_snap,snap_time,n_cells,flash_cache_gb,xrmem_cache_gb,
             flash_log_gb,n_hard_disk,n_flash_disk,n_griddisks,n_celldisks,cell_list,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,n_cells) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["begin_snap"],r["snap_time"],r["n_cells"],
                r["flash_cache_gb"],r["xrmem_cache_gb"],r["flash_log_gb"],
                r["n_hard_disk"],r["n_flash_disk"],r["n_griddisks"],r["n_celldisks"],
                r["cell_list"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_storage_info")
    except Exception as e:
        logger.error(f"❌ Storage Info insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_storage_info(filepath); insert_storage_info(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
