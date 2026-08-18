# modules/awr/exadata_disk_activity_parser.py
# ============================================================
# Parses "Disk Activity" — IOs that go to or from disk per second:
# Redo log writes, FC misses (OLTP), read skips, write skips,
# LW rejections, Disk writer writes, Scrub IO.
# Also parses "IO Reason Summary" which immediately follows.
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
logger = get_logger("exadata_disk_activity_parser")

_SECTION_KW = ["disk activity"]
_STOP_KW    = ["single block read","database io","smart scan"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in _SECTION_KW) and "flash" not in txt: return tag
    return None

def _num(v):
    if v is None: return None
    s = str(v).strip().replace(",","").replace("%","")
    # strip parenthetical, e.g. "1.96 (20559.57)"
    s = s.split("(")[0].strip()
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None

def _kv_from_table(df):
    kv = {}
    for _, row in df.iterrows():
        vals = [str(v).strip() for v in row]
        if not vals or vals[0].lower() in ("nan","i/o type","io type",""): continue
        kv[vals[0].lower()] = tuple(vals[1:])
    return kv

def _get(kv, *kws):
    for key in kv:
        if all(k in key for k in kws): return kv[key]
    return ()

def _ps(tup, idx=0):
    return _num(tup[idx]) if tup and len(tup) > idx else None

def parse_disk_activity(filepath):
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Disk Activity section not found"); return []
    tables = []
    sib = section.find_next_sibling()
    while sib and len(tables) < 4:
        nm = getattr(sib, "name", None)
        if nm == "table":
            try:
                dfs = pd.read_html(StringIO(str(sib)))
                if dfs: tables.extend(dfs)
            except: pass
        elif nm in ("h2","h3","h4") and any(k in sib.get_text(strip=True).lower() for k in _STOP_KW): break
        sib = sib.find_next_sibling()
    if not tables:
        logger.warning("⚠️  No tables in Disk Activity"); return []
    kv = {}
    for df in tables: kv.update(_kv_from_table(df))
    redo        = _get(kv, "redo log write")
    fc_miss     = _get(kv, "flash cache miss","fc miss","misses (oltp)")
    read_skip   = _get(kv, "read skip","read skips")
    write_skip  = _get(kv, "write skip","write skips")
    lw_rej      = _get(kv, "lw rejection","large write rejection","lw reject")
    dw_write    = _get(kv, "disk writer write")
    scrub       = _get(kv, "scrub io")
    rec = sanitize_record({
        "dbname": meta["dbname"], "instance": meta["instance"],
        "begin_snap": meta["begin_snap"], "snap_time": meta["snap_time"],
        "redo_writes_ps":        _ps(redo),
        "redo_writes_total":     _ps(redo, 1),
        "fc_miss_oltp_ps":       _ps(fc_miss),
        "fc_read_skips_ps":      _ps(read_skip),
        "fc_write_skips_ps":     _ps(write_skip),
        "fc_lw_rejections_ps":   _ps(lw_rej),
        "disk_writer_writes_ps": _ps(dw_write),
        "scrub_io_ps":           _ps(scrub),
        "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"]}),
    })
    logger.info(f"✅ Parsed Disk Activity (redo={_ps(redo)}/s, fc_miss={_ps(fc_miss)}/s, "
                f"read_skip={_ps(read_skip)}/s, lw_rej={_ps(lw_rej)}/s, scrub={_ps(scrub)}/s)")
    return [rec]

def insert_disk_activity(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_disk_activity
            (dbname,instance,begin_snap,snap_time,
             redo_writes_ps,redo_writes_total,fc_miss_oltp_ps,
             fc_read_skips_ps,fc_write_skips_ps,fc_lw_rejections_ps,
             disk_writer_writes_ps,scrub_io_ps,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,instance,begin_snap) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["redo_writes_ps"],r["redo_writes_total"],r["fc_miss_oltp_ps"],
                r["fc_read_skips_ps"],r["fc_write_skips_ps"],r["fc_lw_rejections_ps"],
                r["disk_writer_writes_ps"],r["scrub_io_ps"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_disk_activity")
    except Exception as e:
        logger.error(f"❌ Disk Activity insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_disk_activity(filepath); insert_disk_activity(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
