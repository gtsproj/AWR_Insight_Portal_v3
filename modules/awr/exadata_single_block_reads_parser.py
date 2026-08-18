# modules/awr/exadata_single_block_reads_parser.py
# ============================================================
# Parses "Single Block Reads" section — OLTP read profile:
# Database IOs (FC hits, XRMEM hits, RDMA reads, totals),
# Small Reads Distribution (Flash/Disk/XRMEM %).
# Screenshots: exadata10.
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
logger = get_logger("exadata_single_block_reads_parser")

_SECTION_KW = ["single block read"]
_STOP_KW    = ["database io summary","smart scan summary","temp io","large write"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        if any(kw in tag.get_text(strip=True).lower() for kw in _SECTION_KW): return tag
    return None

def _num(v):
    if v is None: return None
    s = str(v).strip().replace(",","").replace("%","").split("(")[0].strip()
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None

def parse_single_block_reads(filepath):
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Single Block Reads section not found"); return []
    # Collect all tables in the section
    all_kv = {}  # for "Database IOs" style table (Stat Name | Value | per Sec)
    dist_rows = []  # for "Small Reads Distribution" (Flash/Disk/XRMEM)
    small_flash_ps = small_disk_ps = small_xrmem_ps = None
    sib = section.find_next_sibling()
    while sib:
        nm = getattr(sib, "name", None)
        if nm in ("h2","h3","h4") and any(k in sib.get_text(strip=True).lower() for k in _STOP_KW): break
        if nm == "table":
            try:
                dfs = pd.read_html(StringIO(str(sib)))
                if not dfs: sib = sib.find_next_sibling(); continue
                df = dfs[0]
                cols = [str(c).lower() for c in df.columns]
                # Detect table type by column names
                if any("stat" in c or "metric" in c for c in cols):
                    # Database IOs kv table
                    for _, row in df.iterrows():
                        v = list(row)
                        if len(v) >= 2:
                            all_kv[str(v[0]).lower().strip()] = (_num(v[1]), _num(v[2]) if len(v)>2 else None)
                elif any("device" in c or "type" in c for c in cols) and any("%" in c for c in cols):
                    # Small Reads Distribution
                    for _, row in df.iterrows():
                        v = list(row)
                        if not v: continue
                        dtype = str(v[0]).strip().lower()
                        pct   = _num(v[1]) if len(v)>1 else None
                        ps    = _num(v[2]) if len(v)>2 else None
                        if "flash" in dtype: small_flash_ps = ps
                        elif "disk" in dtype: small_disk_ps  = ps
                        elif "xrmem" in dtype: small_xrmem_ps = ps
            except: pass
        sib = sib.find_next_sibling()
    def g(*kws):
        for key in all_kv:
            if all(k in key for k in kws): return all_kv[key]
        return (None, None)
    phys_tot   = g("physical read total")
    phys_io    = g("physical read io")
    fc_hits    = g("flash cache read hit","cell flash cache read hit")
    xrmem_hits = g("xrmem cache","cell xrmem")
    rdma_reads = g("rdma read","cell rdma")
    # Derive distribution % from per_sec values if distribution table wasn't found
    total_ps = (small_flash_ps or 0) + (small_disk_ps or 0) + (small_xrmem_ps or 0)
    def pct(v): return round(v / total_ps * 100, 2) if total_ps and v else None
    rec = sanitize_record({
        "dbname": meta["dbname"], "instance": meta["instance"],
        "begin_snap": meta["begin_snap"], "snap_time": meta["snap_time"],
        "phys_read_total_io":  g("physical read total")[0],
        "phys_read_io_reqs":   g("physical read io req")[0],
        "fc_read_hits":        int(fc_hits[0]) if fc_hits[0] else None,
        "xrmem_cache_hits":    int(xrmem_hits[0]) if xrmem_hits[0] else None,
        "cell_rdma_reads":     int(rdma_reads[0]) if rdma_reads[0] else None,
        "phys_read_total_ps":  phys_tot[1],
        "phys_read_io_reqs_ps":phys_io[1],
        "fc_read_hits_ps":     fc_hits[1],
        "xrmem_hits_ps":       xrmem_hits[1],
        "rdma_reads_ps":       rdma_reads[1],
        "pct_flash":           pct(small_flash_ps or 0),
        "pct_disk":            pct(small_disk_ps or 0),
        "pct_xrmem":           pct(small_xrmem_ps or 0),
        "small_reads_flash_ps":small_flash_ps,
        "small_reads_disk_ps": small_disk_ps,
        "small_reads_xrmem_ps":small_xrmem_ps,
        "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"]}),
    })
    logger.info(f"✅ Parsed Single Block Reads (flash%={pct(small_flash_ps or 0)}, "
                f"disk%={pct(small_disk_ps or 0)}, xrmem%={pct(small_xrmem_ps or 0)})")
    return [rec]

def insert_single_block_reads(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_single_block_reads
            (dbname,instance,begin_snap,snap_time,
             phys_read_total_io,phys_read_io_reqs,fc_read_hits,xrmem_cache_hits,cell_rdma_reads,
             phys_read_total_ps,phys_read_io_reqs_ps,fc_read_hits_ps,xrmem_hits_ps,rdma_reads_ps,
             pct_flash,pct_disk,pct_xrmem,
             small_reads_flash_ps,small_reads_disk_ps,small_reads_xrmem_ps,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,instance,begin_snap) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["phys_read_total_io"],r["phys_read_io_reqs"],r["fc_read_hits"],
                r["xrmem_cache_hits"],r["cell_rdma_reads"],
                r["phys_read_total_ps"],r["phys_read_io_reqs_ps"],r["fc_read_hits_ps"],
                r["xrmem_hits_ps"],r["rdma_reads_ps"],
                r["pct_flash"],r["pct_disk"],r["pct_xrmem"],
                r["small_reads_flash_ps"],r["small_reads_disk_ps"],r["small_reads_xrmem_ps"],
                r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_single_block_reads")
    except Exception as e:
        logger.error(f"❌ Single Block Reads insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_single_block_reads(filepath); insert_single_block_reads(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
