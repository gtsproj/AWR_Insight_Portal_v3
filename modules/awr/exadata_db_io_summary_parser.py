# modules/awr/exadata_db_io_summary_parser.py
# ============================================================
# Parses "Database IO Summary" — per-consumer-DB row with:
# small IO req/s, %Flash, %Disk, flash latency us, disk latency ms,
# flash queue time, disk queue time, latency per sec.
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
logger = get_logger("exadata_db_io_summary_parser")

_SECTION_KW = ["database io summary"]
_STOP_KW    = ["smart scan","temp io","large write","io latency","exadata flash"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        if any(kw in tag.get_text(strip=True).lower() for kw in _SECTION_KW): return tag
    return None

def _num(v):
    if v is None: return None
    s = str(v).strip().replace(",","").replace("%","")
    # Strip units like 'us', 'ms', 'ns'
    for unit in ("us","ms","ns"): s = s.rstrip(unit).strip()
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None

def parse_db_io_summary(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Database IO Summary section not found"); return []
    tables = []
    sib = section.find_next_sibling()
    while sib and len(tables) < 2:
        nm = getattr(sib, "name", None)
        if nm == "table":
            try:
                dfs = pd.read_html(StringIO(str(sib)))
                if dfs: tables.extend(dfs)
            except: pass
        elif nm in ("h2","h3","h4") and any(k in sib.get_text(strip=True).lower() for k in _STOP_KW): break
        sib = sib.find_next_sibling()
    if not tables:
        logger.warning("⚠️  No tables in Database IO Summary"); return []
    for df in tables:
        df.columns = [str(c).lower().strip() for c in df.columns]
        if not any("database" in c or "db name" in c or "dbname" in c for c in df.columns):
            continue
        for _, row in df.iterrows():
            vals = list(row)
            db_name = str(vals[0]).strip() if vals else None
            if not db_name or db_name.lower() in ("nan","database name","database","db name",""): continue
            r = dict(zip(df.columns, vals))
            def g(*kws):
                for col in df.columns:
                    if all(k in col for k in kws): return _num(r.get(col))
                return None
            rec = sanitize_record({
                "dbname":           meta["dbname"],
                "instance":         meta["instance"],
                "begin_snap":       meta["begin_snap"],
                "snap_time":        meta["snap_time"],
                "db_name_consumer": db_name,
                "small_io_reqs_ps":    g("small","req","per second") or g("small io","reqs/s") or g("reqs","second"),
                "pct_flash":           g("%flash","pct flash","flash%"),
                "pct_disk":            g("%disk","pct disk","disk%"),
                "flash_latency_us":    g("flash latency","flash lat"),
                "disk_latency_us":     g("disk latency","disk lat"),
                "flash_queue_time_us": g("flash queue","queue time","flash q"),
                "disk_queue_time_us":  g("disk queue"),
                "latency_per_sec_us":  g("latency per sec","lat/sec"),
                "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"],"db":db_name}),
            })
            records.append(rec)
    logger.info(f"✅ Parsed {len(records)} Database IO Summary rows")
    return records

def insert_db_io_summary(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_db_io_summary
            (dbname,instance,begin_snap,snap_time,db_name_consumer,
             small_io_reqs_ps,pct_flash,pct_disk,
             flash_latency_us,disk_latency_us,flash_queue_time_us,disk_queue_time_us,
             latency_per_sec_us,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,instance,begin_snap,db_name_consumer) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["db_name_consumer"],r["small_io_reqs_ps"],r["pct_flash"],r["pct_disk"],
                r["flash_latency_us"],r["disk_latency_us"],r["flash_queue_time_us"],
                r["disk_queue_time_us"],r["latency_per_sec_us"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_db_io_summary")
    except Exception as e:
        logger.error(f"❌ Database IO Summary insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_db_io_summary(filepath); insert_db_io_summary(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
