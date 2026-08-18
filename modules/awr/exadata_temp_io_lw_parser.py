# modules/awr/exadata_temp_io_lw_parser.py
# ============================================================
# Parses "Temp IO and Large Writes Summary":
# Large Writes/s breakdown, Database Flash Cache Temp Write Hit%,
# Cell Flash Cache Large Writes for Temp (total, per sec).
# Screenshot: exadata11.
# ============================================================
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
logger = get_logger("exadata_temp_io_lw_parser")

_SECTION_KW = ["temp io and large write","temp io & large write","large write summary"]
_STOP_KW    = ["io latency","flash wear","exadata resource","exadata outlier"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in _SECTION_KW): return tag
    return None

def _num(v):
    if v is None: return None
    s = str(v).strip().replace(",","").replace("%","").split("(")[0].strip()
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None

def parse_temp_io_lw(filepath):
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Temp IO and Large Writes section not found"); return []
    all_kv = {}; lw_rows = {}; temp_hit = None
    fc_lw_total = None; fc_lw_ps = None
    sib = section.find_next_sibling()
    while sib:
        nm = getattr(sib, "name", None)
        if nm in ("h2","h3","h4") and any(k in sib.get_text(strip=True).lower() for k in _STOP_KW): break
        if nm == "table":
            try:
                dfs = pd.read_html(StringIO(str(sib)))
                if not dfs: sib = sib.find_next_sibling(); continue
                df = dfs[0]
                cols_l = [str(c).lower() for c in df.columns]
                for _, row in df.iterrows():
                    vals = [str(v).strip() for v in row]
                    if not vals or not vals[0] or vals[0].lower() == "nan": continue
                    key = vals[0].lower()
                    # Large writes breakdown table
                    if any(k in key for k in ("total","temp spill","data/temp","write only")):
                        lw_rows[key] = _num(vals[1]) if len(vals) > 1 else None
                    # Hit% table
                    elif "hit" in key and "%" in " ".join(vals):
                        val = _num(vals[-1]) or _num(vals[1]) if len(vals)>1 else None
                        if "temp" in key: temp_hit = val
                    # FC LW for Temp
                    elif "cell flash" in key or "fc lw for temp" in key:
                        fc_lw_total = _num(vals[1]) if len(vals)>1 else None
                        fc_lw_ps    = _num(vals[2]) if len(vals)>2 else None
                    # KV fallback
                    else:
                        all_kv[key] = vals[1] if len(vals) > 1 else None
            except: pass
        sib = sib.find_next_sibling()
    total_lw  = lw_rows.get("total") or _num(all_kv.get("large writes/s"))
    temp_spill= lw_rows.get("temp spill") or None
    for k in lw_rows:
        if "data/temp" in k: data_temp = lw_rows[k]; break
    else: data_temp = None
    for k in lw_rows:
        if "write only" in k: write_only = lw_rows[k]; break
    else: write_only = None
    rec = sanitize_record({
        "dbname": meta["dbname"], "instance": meta["instance"],
        "begin_snap": meta["begin_snap"], "snap_time": meta["snap_time"],
        "large_writes_total_ps":   total_lw,
        "lw_temp_spill_ps":        temp_spill,
        "lw_data_temp_ps":         data_temp,
        "lw_write_only_ps":        write_only,
        "db_temp_io_hit_pct":      temp_hit,
        "fc_lw_for_temp_total":    fc_lw_total,
        "fc_lw_for_temp_ps":       fc_lw_ps,
        "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"]}),
    })
    logger.info(f"✅ Parsed Temp IO + LW (total_lw={total_lw}/s, temp_spill={temp_spill}/s, "
                f"temp_hit%={temp_hit}, fc_lw_total={fc_lw_total})")
    return [rec]

def insert_temp_io_lw(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_temp_io_lw
            (dbname,instance,begin_snap,snap_time,
             large_writes_total_ps,lw_temp_spill_ps,lw_data_temp_ps,lw_write_only_ps,
             db_temp_io_hit_pct,fc_lw_for_temp_total,fc_lw_for_temp_ps,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,instance,begin_snap) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["large_writes_total_ps"],r["lw_temp_spill_ps"],r["lw_data_temp_ps"],
                r["lw_write_only_ps"],r["db_temp_io_hit_pct"],
                r["fc_lw_for_temp_total"],r["fc_lw_for_temp_ps"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_temp_io_lw")
    except Exception as e:
        logger.error(f"❌ Temp IO LW insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_temp_io_lw(filepath); insert_temp_io_lw(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
