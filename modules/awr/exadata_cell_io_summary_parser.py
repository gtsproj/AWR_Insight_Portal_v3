# modules/awr/exadata_cell_io_summary_parser.py
# ============================================================
# Parses "Cell I/O Summary" — IOPs breakdown per disk type:
# small reads, small writes, large reads, large writes per sec.
# Screenshot: exadata8.
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
logger = get_logger("exadata_cell_io_summary_parser")

_SECTION_KW = ["cell i/o summary", "cell io summary"]
_STOP_KW    = ["cache savings","flash activity","disk activity"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in _SECTION_KW): return tag
    return None

def _num(v):
    if v is None: return None
    s = str(v).strip().replace(",","").replace("%","")
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None

def parse_cell_io_summary(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Cell I/O Summary section not found"); return []
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
        logger.warning("⚠️  No tables in Cell I/O Summary"); return []
    for df in tables:
        df.columns = [str(c).lower().strip() for c in df.columns]
        for _, row in df.iterrows():
            vals = list(row)
            disk_type = str(vals[0]).strip() if vals else None
            if not disk_type or disk_type.lower() in ("nan","disk type","total","type"): continue
            r = dict(zip(df.columns, vals))
            def g(*kws):
                for col in df.columns:
                    if any(kw in col for kw in kws): return _num(r.get(col))
                return None
            rec = sanitize_record({
                "dbname":           meta["dbname"],
                "instance":         meta["instance"],
                "begin_snap":       meta["begin_snap"],
                "snap_time":        meta["snap_time"],
                "disk_type":        disk_type,
                "n_cells":          int(g("#cell","cell","n_cell") or 0) or None,
                "n_disks":          int(g("#disk","disk","n_disk") or 0) or None,
                "total_iops":       g("total iop","total ios"),
                "avg_iops_per_cell":g("average","avg iop","per cell iop"),
                "small_reads_ps":   g("small read"),
                "small_writes_ps":  g("small writ"),
                "large_reads_ps":   g("large read"),
                "large_writes_ps":  g("large writ"),
                "total_mbps":       g("total mb","total thro","mb/s"),
                "avg_mbps_per_cell":g("avg mb","per cell mb"),
                "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"],"dt":disk_type}),
            })
            records.append(rec)
    logger.info(f"✅ Parsed {len(records)} Cell I/O Summary rows")
    return records

def insert_cell_io_summary(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_cell_io_summary
            (dbname,instance,begin_snap,snap_time,disk_type,
             n_cells,n_disks,total_iops,avg_iops_per_cell,
             small_reads_ps,small_writes_ps,large_reads_ps,large_writes_ps,
             total_mbps,avg_mbps_per_cell,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,instance,begin_snap,disk_type) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["disk_type"],r["n_cells"],r["n_disks"],r["total_iops"],r["avg_iops_per_cell"],
                r["small_reads_ps"],r["small_writes_ps"],r["large_reads_ps"],r["large_writes_ps"],
                r["total_mbps"],r["avg_mbps_per_cell"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_cell_io_summary")
    except Exception as e:
        logger.error(f"❌ Cell I/O Summary insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_cell_io_summary(filepath); insert_cell_io_summary(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
