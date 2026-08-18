# modules/awr/exadata_os_io_summary_parser.py
# ============================================================
# Parses "OS I/O Summary" from Exadata AWR — screenshot exadata8.
# Captures per-disk-type: IOPs, MB/s, latency, %disk utilisation.
# Disk types: F/6.2T (flash), H/20.0T (HDD), etc.
# Also handles "I/O Summary" which appears just before OS I/O.
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
logger = get_logger("exadata_os_io_summary_parser")

_SECTION_KW = ["os i/o summary", "os io summary", "os i/o stat", "os io stat"]
_STOP_KW    = ["cell i/o", "cell io", "cache savings", "flash activity"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in _SECTION_KW):
            return tag
    return None

def _num(v):
    if v is None: return None
    s = str(v).strip().replace(",","").replace("%","")
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None

def parse_os_io_summary(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  OS I/O Summary section not found"); return []
    tables = []
    sib = section.find_next_sibling()
    while sib and len(tables) < 3:
        nm = getattr(sib, "name", None)
        if nm == "table":
            try:
                dfs = pd.read_html(StringIO(str(sib)))
                if dfs: tables.extend(dfs)
            except: pass
        elif nm in ("h2","h3","h4"):
            if any(kw in sib.get_text(strip=True).lower() for kw in _STOP_KW): break
        sib = sib.find_next_sibling()
    if not tables:
        logger.warning("⚠️  No tables in OS I/O Summary"); return []
    for df in tables:
        df.columns = [str(c).lower().strip() for c in df.columns]
        for _, row in df.iterrows():
            vals = list(row)
            disk_type = str(vals[0]).strip() if vals else None
            if not disk_type or disk_type.lower() in ("nan","disk type","total","type"): continue
            if "total" in disk_type.lower(): continue
            r = dict(zip(df.columns, vals))
            def g(*kws):
                for col in df.columns:
                    if any(kw in col for kw in kws): return _num(r.get(col))
                return None
            rec = sanitize_record({
                "dbname":         meta["dbname"],
                "instance":       meta["instance"],
                "begin_snap":     meta["begin_snap"],
                "snap_time":      meta["snap_time"],
                "disk_type":      disk_type,
                "n_cells":        int(g("cell","#cell") or 0) or None,
                "n_disks":        int(g("disk","#disk") or 0) or None,
                "total_iops":     g("total","iops","reqs"),
                "iops_per_cell":  g("per cell","cell iops","average iops"),
                "total_mbps":     g("mb/s","mbps","throughput") ,
                "mbps_per_cell":  g("per cell mb","cell mb"),
                "service_time_ms":g("service","svc time"),
                "wait_time_ms":   g("wait time"),
                "pct_disk_util":  g("util","utiliz","disk util"),
                "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"],"dt":disk_type}),
            })
            records.append(rec)
    logger.info(f"✅ Parsed {len(records)} OS I/O Summary rows")
    return records

def insert_os_io_summary(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_os_io_summary
            (dbname,instance,begin_snap,snap_time,disk_type,
             n_cells,n_disks,total_iops,iops_per_cell,
             total_mbps,mbps_per_cell,service_time_ms,wait_time_ms,pct_disk_util,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,instance,begin_snap,disk_type) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["disk_type"],r["n_cells"],r["n_disks"],r["total_iops"],r["iops_per_cell"],
                r["total_mbps"],r["mbps_per_cell"],r["service_time_ms"],r["wait_time_ms"],
                r["pct_disk_util"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_os_io_summary")
    except Exception as e:
        logger.error(f"❌ OS I/O Summary insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_os_io_summary(filepath); insert_os_io_summary(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
