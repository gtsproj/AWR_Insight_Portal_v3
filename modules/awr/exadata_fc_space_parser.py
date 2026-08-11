# modules/awr/exadata_fc_space_parser.py
# ============================================================
# Parses the "Flash Cache Space Usage" section of an Exadata
# AWR report.
#
# One row per cell (plus 'All' aggregate).
# large_write_pct is derived: large_write_mb / total_fc_mb * 100.
#
# Alert thresholds:
#   large_write_pct > 15% — approaching Global Limit
#   large_write_pct > 20% — HIGH: Large Writes crowding out
#                            OLTP and Scan data, direct-path
#                            and temp IOs going to hard disk.
#
# Section headers in AWR HTML:
#   <h3>Flash Cache Space Usage</h3>
#   <h3>Exadata Flash Cache Space Usage</h3>
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
logger = get_logger("exadata_fc_space_parser")

_SECTION_KW = ["flash cache space usage", "exadata flash cache space",
               "fc space usage", "flash cache space"]


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


def _n(v, gb_to_mb=False):
    if v is None: return None
    s = str(v).strip().replace(",","").replace("%","")
    if s.lower() in ("nan","n/a","--","-",""): return None
    # Strip unit suffix
    s = re.sub(r"\s*(gb|mb|tb)\s*$","",s,flags=re.IGNORECASE)
    try:
        val = float(s)
        if gb_to_mb: val *= 1024
        return val
    except: return None


def parse_fc_space(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []

    sec = _find(soup)
    if not sec:
        logger.warning("⚠️  Flash Cache Space Usage section not found"); return []

    tbl = sec.find_next("table")
    if not tbl:
        logger.warning("⚠️  Flash Cache Space Usage table not found"); return []

    df = pd.read_html(StringIO(str(tbl)))[0]
    col_cell  = _col(df,"Name","Cell","Cell Name")
    col_total = _col(df,"Total","Total FC","Total Size","FC Size","Total Flash Cache")
    col_oltp  = _col(df,"OLTP","OLTP Used","OLTP MB","OLTP Size")
    col_scan  = _col(df,"Scan","Scan Used","Scan MB","Scan Size")
    col_lw    = _col(df,"Large Write","LW","Large Write MB","Large Writes")
    col_free  = _col(df,"Free","Free MB","Available")
    col_lw_pct= _col(df,"Large Write%","LW%","Large Write Pct","% Large Write")
    use_pos   = col_cell is None

    for _, row in df.iterrows():
        vals = list(row)
        cell  = str(vals[0]).strip() if use_pos else str(row.get(col_cell,"")).strip()
        if not cell or cell.lower() in ("nan","name","cell"): continue

        total = _n(vals[1] if use_pos else row.get(col_total))
        oltp  = _n(vals[2] if use_pos else row.get(col_oltp))
        scan  = _n(vals[3] if use_pos else row.get(col_scan))
        lw    = _n(vals[4] if use_pos else row.get(col_lw))
        free  = _n(vals[5] if use_pos else row.get(col_free))
        lw_pct= _n(vals[6] if use_pos else row.get(col_lw_pct)) if col_lw_pct or (use_pos and len(vals)>6) else None

        if lw_pct is None and total and total > 0 and lw is not None:
            lw_pct = round(lw / total * 100, 1)

        rh = _rh({"cell":cell,"total":total,"lw_pct":lw_pct})
        records.append(sanitize_record({
            "dbname":meta["dbname"],"instance":meta["instance"],
            "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
            "cell_name":cell,"total_fc_mb":total,
            "oltp_used_mb":oltp,"scan_used_mb":scan,
            "large_write_mb":lw,"large_write_pct":lw_pct,"free_mb":free,
            "row_hash":rh,
        }))

    high_lw = [r["cell_name"] for r in records if (r.get("large_write_pct") or 0) > 20]
    logger.info(f"✅ Parsed {len(records)} FC Space rows"
                + (f" | HIGH large_write: {high_lw}" if high_lw else ""))
    return records


def insert_fc_space(records):
    if not records:
        logger.warning("⚠️  No FC Space records to insert"); return
    sql = """INSERT INTO awr_exadata_fc_space
        (dbname,instance,begin_snap,snap_time,cell_name,
         total_fc_mb,oltp_used_mb,scan_used_mb,large_write_mb,
         large_write_pct,free_mb,row_hash)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,cell_name,row_hash) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["cell_name"],r["total_fc_mb"],r["oltp_used_mb"],r["scan_used_mb"],
                r["large_write_mb"],r["large_write_pct"],r["free_mb"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_fc_space")
    except Exception as e:
        logger.error(f"❌ {e}", exc_info=True)
    finally:
        if conn: conn.close()


def main(filepath):
    r = parse_fc_space(filepath)
    if r: insert_fc_space(r)

if __name__ == "__main__":
    t = globals().get("filepath") or (sys.argv[1] if len(sys.argv)>1 else None)
    if not t: print("Usage: python exadata_fc_space_parser.py <awr.html>"); sys.exit(1)
    insert_fc_space(parse_fc_space(t))
