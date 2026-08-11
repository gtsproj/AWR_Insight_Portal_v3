# modules/awr/exadata_cell_iostat_parser.py
# ============================================================
# Parses the "Exadata OS IO Statistics" section of an Exadata
# AWR report, specifically the Outlier Cells sub-table.
#
# One row per (cell, device_type) pair.
# device_type distinguishes Flash vs Hard Disk devices.
#
# Key diagnostic flags derived by the parser:
#   is_outlier      — cell marked as outlier vs its peers
#   at_max_capacity — cell device at maximum IOPs
#
# Section headers in AWR HTML:
#   <h3>Exadata OS IO Statistics</h3>
#   <h3>OS IO Statistics</h3>
#   <h3>Exadata OS IO Statistics - Outlier Cells</h3>
# ============================================================
import os, sys, re, warnings
from io import StringIO
import pandas as pd
from bs4 import BeautifulSoup
warnings.simplefilter("ignore")

_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(_ROOT, "common"))
from db import get_db_connection
from utils import row_hash as _rh, extract_workload_repo_metadata, sanitize_record
from logger_utils import get_logger
logger = get_logger("exadata_cell_iostat_parser")

_SECTION_KW = ["exadata os io statistics", "os io statistics",
               "cell io statistics", "outlier cells"]


def _find(soup):
    for tag in soup.find_all(["h2","h3"]):
        t = tag.get_text(strip=True).lower()
        if any(k in t for k in _SECTION_KW): return tag
    return None


def _col(df, *cands):
    lm = {c.lower(): c for c in df.columns}
    for n in cands:
        if n.lower() in lm: return lm[n.lower()]
    for n in cands:
        for k,v in lm.items():
            if n.lower() in k: return v
    return None


def _n(v):
    if v is None: return None
    s = str(v).strip().replace(",","").replace("%","")
    if s.lower() in ("nan","n/a","--","-",""): return None
    try: return float(s)
    except: return None


def parse_cell_iostat(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []

    sec = _find(soup)
    if not sec:
        logger.warning("⚠️  OS IO Statistics section not found"); return []

    # Scan up to 3 tables (Oracle sometimes splits Flash/HardDisk into separate tables)
    found_tables = []
    sib = sec.find_next_sibling()
    while sib and len(found_tables) < 3:
        name = getattr(sib,"name",None)
        if name in ("h2",): break
        if name == "table":
            try:
                dfs = pd.read_html(StringIO(str(sib)))
                if dfs and not dfs[0].empty: found_tables.append(dfs[0])
            except: pass
        sib = sib.find_next_sibling()

    if not found_tables:
        logger.warning("⚠️  No OS IO Statistics tables found"); return []

    for df in found_tables:
        col_cell   = _col(df,"Name","Cell","Cell Name","Storage Cell")
        col_dev    = _col(df,"Device","Device Type","Type","Disk Type","Flash","Hard Disk")
        col_iops   = _col(df,"IOPs","IO/s","IOPS","IO per sec")
        col_tput   = _col(df,"Throughput","MB/s","Throughput MB/s")
        col_util   = _col(df,"Util","Util%","Utilization","Utilization %","% Util")
        col_svc    = _col(df,"Service","Service Time","Service ms","Svc ms","Avg Service")
        col_queue  = _col(df,"Queue","Queue Time","Queue ms","Avg Queue","Wait ms")
        col_outlier= _col(df,"Outlier","Is Outlier","Outlier Flag")
        col_maxcap = _col(df,"Max Capacity","At Max","Max Cap","Capacity")
        use_pos    = col_cell is None

        for _, row in df.iterrows():
            vals = list(row)
            cell   = str(vals[0]).strip() if use_pos else str(row.get(col_cell,"")).strip()
            if not cell or cell.lower() in ("nan","name","cell","storage cell"): continue

            dev    = str(vals[1]).strip() if use_pos else str(row.get(col_dev,"")).strip() if col_dev else "Unknown"
            iops   = _n(vals[2] if use_pos else row.get(col_iops))
            tput   = _n(vals[3] if use_pos else row.get(col_tput))
            util   = _n(vals[4] if use_pos else row.get(col_util))
            svc    = _n(vals[5] if use_pos else row.get(col_svc))
            queue  = _n(vals[6] if use_pos else row.get(col_queue))

            # Outlier and max-capacity: parse boolean-like strings
            raw_out = str(vals[7] if use_pos and len(vals)>7 else row.get(col_outlier,"")).lower() if col_outlier or (use_pos and len(vals)>7) else ""
            raw_cap = str(vals[8] if use_pos and len(vals)>8 else row.get(col_maxcap,"")).lower() if col_maxcap or (use_pos and len(vals)>8) else ""
            is_outlier  = raw_out in ("yes","true","1","outlier","y")
            at_max_cap  = raw_cap in ("yes","true","1","max","y","at max capacity")

            rh = _rh({"cell":cell,"dev":dev,"iops":iops,"util":util})
            records.append(sanitize_record({
                "dbname":meta["dbname"],"instance":meta["instance"],
                "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
                "cell_name":cell,"device_type":dev,
                "iops":iops,"throughput_mbps":tput,"util_pct":util,
                "service_ms":svc,"queue_ms":queue,
                "is_outlier":is_outlier,"at_max_capacity":at_max_cap,
                "row_hash":rh,
            }))

    outliers = [r["cell_name"] for r in records if r.get("is_outlier")]
    maxcap   = [r["cell_name"] for r in records if r.get("at_max_capacity")]
    logger.info(f"✅ Parsed {len(records)} Cell IOStat rows"
                + (f" | outliers:{outliers}" if outliers else "")
                + (f" | max_cap:{maxcap}" if maxcap else ""))
    return records


def insert_cell_iostat(records):
    if not records:
        logger.warning("⚠️  No Cell IOStat records to insert"); return
    sql = """INSERT INTO awr_exadata_cell_iostat
        (dbname,instance,begin_snap,snap_time,cell_name,device_type,
         iops,throughput_mbps,util_pct,service_ms,queue_ms,
         is_outlier,at_max_capacity,row_hash)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,cell_name,device_type,row_hash) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["cell_name"],r["device_type"],r["iops"],r["throughput_mbps"],
                r["util_pct"],r["service_ms"],r["queue_ms"],
                r["is_outlier"],r["at_max_capacity"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_cell_iostat")
    except Exception as e:
        logger.error(f"❌ {e}", exc_info=True)
    finally:
        if conn: conn.close()


def main(filepath):
    r = parse_cell_iostat(filepath)
    if r: insert_cell_iostat(r)

if __name__ == "__main__":
    t = globals().get("filepath") or (sys.argv[1] if len(sys.argv)>1 else None)
    if not t: print("Usage: python exadata_cell_iostat_parser.py <awr.html>"); sys.exit(1)
    insert_cell_iostat(parse_cell_iostat(t))
