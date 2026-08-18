# modules/awr/exadata_flash_activity_parser.py
# ============================================================
# Parses "Flash Activity" section — IO/s for each flash operation:
# Flash Log writes, FC OLTP reads, FC scan reads, Columnar reads,
# FC user writes, Disk writer reads, Population writes, Metadata writes.
# Row-keyed table: col[0]=IO type, col[1]=IO/s, col[2]=Total, col[3]=per Cell.
# Screenshot: exadata9.
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
logger = get_logger("exadata_flash_activity_parser")

_SECTION_KW = ["flash activity"]
_STOP_KW    = ["disk activity","io reason","single block"]

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

def _kv_from_table(df):
    """Build {io_type_lower: (io_per_sec, total, per_cell)} from row-keyed table."""
    kv = {}
    for _, row in df.iterrows():
        vals = [str(v).strip() for v in row]
        if not vals or vals[0].lower() in ("nan","i/o type","io type",""): continue
        key = vals[0].lower()
        ps  = _num(vals[1]) if len(vals) > 1 else None
        tot = _num(vals[2]) if len(vals) > 2 else None
        pc  = _num(vals[3]) if len(vals) > 3 else None
        kv[key] = (ps, tot, pc)
    return kv

def _get(kv, *kws):
    for key in kv:
        if all(k in key for k in kws): return kv[key]
    return (None, None, None)

def parse_flash_activity(filepath):
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Flash Activity section not found"); return []
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
        logger.warning("⚠️  No tables in Flash Activity"); return []
    kv = {}
    for df in tables: kv.update(_kv_from_table(df))
    if not kv:
        logger.warning("⚠️  No key-value rows in Flash Activity"); return []
    def g(*kws): return _get(kv, *kws)
    fl_log      = g("flash log write")
    oltp_read   = g("oltp read","flash cache oltp")
    scan_read   = g("scan read","flash cache scan")
    col_read    = g("columnar")
    user_write  = g("user write","flash cache user")
    dwr_read    = g("disk writer read")
    pop_write   = g("population write")
    meta_write  = g("metadata write")
    rec = sanitize_record({
        "dbname":  meta["dbname"], "instance": meta["instance"],
        "begin_snap": meta["begin_snap"], "snap_time": meta["snap_time"],
        "flash_log_writes_ps":     fl_log[0],
        "flash_log_writes_total":  fl_log[1],
        "flash_log_writes_per_cell": fl_log[2],
        "fc_oltp_reads_ps":        oltp_read[0],
        "fc_oltp_reads_total":     oltp_read[1],
        "fc_scan_reads_ps":        scan_read[0],
        "fc_scan_reads_total":     scan_read[1],
        "columnar_reads_ps":       col_read[0],
        "columnar_reads_total":    col_read[1],
        "fc_user_writes_ps":       user_write[0],
        "fc_user_writes_total":    user_write[1],
        "disk_writer_reads_ps":    dwr_read[0],
        "population_writes_ps":    pop_write[0],
        "metadata_writes_ps":      meta_write[0],
        "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"]}),
    })
    logger.info(f"✅ Parsed Flash Activity (fl_log_writes={fl_log[0]}/s, fc_oltp={oltp_read[0]}/s, fc_scan={scan_read[0]}/s)")
    return [rec]

def insert_flash_activity(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_flash_activity
            (dbname,instance,begin_snap,snap_time,
             flash_log_writes_ps,flash_log_writes_total,flash_log_writes_per_cell,
             fc_oltp_reads_ps,fc_oltp_reads_total,
             fc_scan_reads_ps,fc_scan_reads_total,
             columnar_reads_ps,columnar_reads_total,
             fc_user_writes_ps,fc_user_writes_total,
             disk_writer_reads_ps,population_writes_ps,metadata_writes_ps,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,instance,begin_snap) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["flash_log_writes_ps"],r["flash_log_writes_total"],r["flash_log_writes_per_cell"],
                r["fc_oltp_reads_ps"],r["fc_oltp_reads_total"],
                r["fc_scan_reads_ps"],r["fc_scan_reads_total"],
                r["columnar_reads_ps"],r["columnar_reads_total"],
                r["fc_user_writes_ps"],r["fc_user_writes_total"],
                r["disk_writer_reads_ps"],r["population_writes_ps"],r["metadata_writes_ps"],
                r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_flash_activity")
    except Exception as e:
        logger.error(f"❌ Flash Activity insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_flash_activity(filepath); insert_flash_activity(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
