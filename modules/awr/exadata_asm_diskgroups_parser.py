# modules/awr/exadata_asm_diskgroups_parser.py — ASM Diskgroups
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
logger = get_logger("exadata_asm_diskgroups_parser")
_SECTION_KW = ["asm diskgroup","asm disk group"]
_STOP_KW    = ["iorm objective","exadata server health","exadata statistics"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        if any(kw in tag.get_text(strip=True).lower() for kw in _SECTION_KW): return tag
    return None

def _num(v):
    if v is None: return None
    s = str(v).strip().replace(",","").replace("%","")
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None

def parse_asm_diskgroups(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  ASM Diskgroups section not found"); return []
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
                    dg_name = str(vals[0]).strip() if vals else None
                    if not dg_name or dg_name.lower() in ("nan","disk group","diskgroup",""): continue
                    r = dict(zip(df.columns, vals))
                    def g(*kws):
                        for col in df.columns:
                            if all(k in col for k in kws): return _num(r.get(col))
                        return None
                    size_gb = g("size")
                    used_gb = g("used")
                    rec = sanitize_record({
                        "dbname": meta["dbname"], "begin_snap": meta["begin_snap"],
                        "snap_time": meta["snap_time"], "disk_group": dg_name,
                        "size_gb": size_gb, "used_gb": used_gb,
                        "pct_used": round(used_gb/size_gb*100,2) if size_gb and used_gb and size_gb>0 else None,
                        "n_griddisks": int(g("griddisk") or 0) or None,
                        "redundancy": str(r.get([c for c in df.columns if "redund" in c][0] if any("redund" in c for c in df.columns) else "",""  )).strip() or None,
                        "state":      str(r.get([c for c in df.columns if "state" in c][0] if any("state" in c for c in df.columns) else "",""   )).strip() or None,
                        "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"],"dg":dg_name}),
                    })
                    records.append(rec)
            except: pass
        sib = sib.find_next_sibling()
    logger.info(f"✅ Parsed {len(records)} ASM Diskgroup rows")
    return records

def insert_asm_diskgroups(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_asm_diskgroups
            (dbname,begin_snap,snap_time,disk_group,size_gb,used_gb,pct_used,
             n_griddisks,redundancy,state,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,disk_group) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["begin_snap"],r["snap_time"],r["disk_group"],
                r["size_gb"],r["used_gb"],r["pct_used"],r["n_griddisks"],
                r["redundancy"],r["state"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_asm_diskgroups")
    except Exception as e:
        logger.error(f"❌ ASM Diskgroups insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_asm_diskgroups(filepath); insert_asm_diskgroups(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
