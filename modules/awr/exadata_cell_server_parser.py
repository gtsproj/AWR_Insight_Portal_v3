# modules/awr/exadata_cell_server_parser.py
# ============================================================
# Parses the "Cell Server Statistics" section of an Exadata
# AWR report.
#
# One row per cell. Captures small/large read/write breakdown
# in both IOPs and MB/s, plus derived metrics:
#   total_iops          — sum of all IO types
#   large_write_pct_iops — large writes as % of total IOPs
#
# Cross-cell imbalance detection: cells doing 2x the average
# IOPs indicate uneven data distribution or maintenance tasks.
# High large_write_pct_iops (>40%) signals checkpoint storms
# or large temp spills hitting that cell.
#
# Section headers in AWR HTML:
#   <h3>Exadata Cell Server Statistics</h3>
#   <h3>Cell Server Statistics</h3>
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
logger = get_logger("exadata_cell_server_parser")

_SECTION_KW = ["exadata cell server statistics", "cell server statistics",
               "cell server stats"]


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
    s = str(v).strip().replace(",","")
    if s.lower() in ("nan","n/a","--","-",""): return None
    s = re.sub(r"\s*(mb/s|io/s|mb|iops)\s*$","",s,flags=re.IGNORECASE)
    try: return float(s)
    except: return None


def parse_cell_server(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []

    sec = _find(soup)
    if not sec:
        logger.warning("⚠️  Cell Server Statistics section not found"); return []

    tbl = sec.find_next("table")
    if not tbl:
        logger.warning("⚠️  Cell Server Statistics table not found"); return []

    df = pd.read_html(StringIO(str(tbl)))[0]
    col_cell   = _col(df,"Name","Cell","Cell Name")
    col_sr_io  = _col(df,"Small Read IO","Small Rd IO","Small Read IOPS","SR IO","Small Read/s")
    col_sw_io  = _col(df,"Small Write IO","Small Wr IO","Small Write IOPS","SW IO","Small Write/s")
    col_lr_io  = _col(df,"Large Read IO","Large Rd IO","Large Read IOPS","LR IO","Large Read/s")
    col_lw_io  = _col(df,"Large Write IO","Large Wr IO","Large Write IOPS","LW IO","Large Write/s")
    col_sr_mb  = _col(df,"Small Read MB","Small Rd MB","SR MB","Small Read MB/s")
    col_sw_mb  = _col(df,"Small Write MB","Small Wr MB","SW MB","Small Write MB/s")
    col_lr_mb  = _col(df,"Large Read MB","Large Rd MB","LR MB","Large Read MB/s")
    col_lw_mb  = _col(df,"Large Write MB","Large Wr MB","LW MB","Large Write MB/s")
    use_pos    = col_cell is None

    for _, row in df.iterrows():
        vals = list(row)
        cell = str(vals[0]).strip() if use_pos else str(row.get(col_cell,"")).strip()
        if not cell or cell.lower() in ("nan","name","cell"): continue

        def g(col,idx):
            return _n(vals[idx] if use_pos else row.get(col))

        sr_io = g(col_sr_io,1); sw_io = g(col_sw_io,2)
        lr_io = g(col_lr_io,3); lw_io = g(col_lw_io,4)
        sr_mb = g(col_sr_mb,5); sw_mb = g(col_sw_mb,6)
        lr_mb = g(col_lr_mb,7); lw_mb = g(col_lw_mb,8)

        total_iops = sum(x for x in [sr_io,sw_io,lr_io,lw_io] if x is not None) or None
        lw_pct = round(lw_io/total_iops*100,1) if lw_io and total_iops else None

        rh = _rh({"cell":cell,"sr_io":sr_io,"lw_io":lw_io,"lr_mb":lr_mb})
        records.append(sanitize_record({
            "dbname":meta["dbname"],"instance":meta["instance"],
            "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
            "cell_name":cell,
            "small_read_iops":sr_io,"small_write_iops":sw_io,
            "large_read_iops":lr_io,"large_write_iops":lw_io,
            "small_read_mbps":sr_mb,"small_write_mbps":sw_mb,
            "large_read_mbps":lr_mb,"large_write_mbps":lw_mb,
            "total_iops":total_iops,"large_write_pct_iops":lw_pct,
            "row_hash":rh,
        }))

    if records:
        avg = sum(r.get("total_iops") or 0 for r in records) / len(records)
        imbalanced = [r["cell_name"] for r in records if (r.get("total_iops") or 0) > avg*1.8]
        logger.info(f"✅ Parsed {len(records)} Cell Server rows"
                    + (f" | imbalanced cells: {imbalanced}" if imbalanced else ""))
    return records


def insert_cell_server(records):
    if not records:
        logger.warning("⚠️  No Cell Server records to insert"); return
    sql = """INSERT INTO awr_exadata_cell_server
        (dbname,instance,begin_snap,snap_time,cell_name,
         small_read_iops,small_write_iops,large_read_iops,large_write_iops,
         small_read_mbps,small_write_mbps,large_read_mbps,large_write_mbps,
         total_iops,large_write_pct_iops,row_hash)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,cell_name,row_hash) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["cell_name"],r["small_read_iops"],r["small_write_iops"],
                r["large_read_iops"],r["large_write_iops"],
                r["small_read_mbps"],r["small_write_mbps"],
                r["large_read_mbps"],r["large_write_mbps"],
                r["total_iops"],r["large_write_pct_iops"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_cell_server")
    except Exception as e:
        logger.error(f"❌ {e}", exc_info=True)
    finally:
        if conn: conn.close()


def main(filepath):
    r = parse_cell_server(filepath)
    if r: insert_cell_server(r)

if __name__ == "__main__":
    t = globals().get("filepath") or (sys.argv[1] if len(sys.argv)>1 else None)
    if not t: print("Usage: python exadata_cell_server_parser.py <awr.html>"); sys.exit(1)
    insert_cell_server(parse_cell_server(t))
