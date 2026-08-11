# modules/awr/exadata_io_reasons_parser.py
# ============================================================
# Parses the "IO Reasons by Requests" section of an Exadata
# AWR report.
#
# One row per (cell_name, reason) pair.
# Common reasons: Smart Scan, Redo, DBWR Checkpoint, Scrub IO,
#                 Internal IO, Others.
# cell_name = 'All' is the system aggregate.
#
# Key metrics:
#   pct_of_total_req — % of all storage cell requests this reason
#   large_req        — large-IO dominated reasons (Smart Scan, DBWR)
#   small_req        — small-IO dominated reasons (OLTP, redo)
#
# Section headers in AWR HTML:
#   <h3>IO Reasons by Requests</h3>
#   <h3>Exadata IO Reasons</h3>
#   <h3>IO Reasons</h3>
# ============================================================
import os, sys, warnings
from io import StringIO
import pandas as pd
from bs4 import BeautifulSoup
warnings.simplefilter("ignore")

_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(_ROOT, "common"))
from db import get_db_connection
from utils import row_hash as _rh, extract_workload_repo_metadata, sanitize_record
from logger_utils import get_logger
logger = get_logger("exadata_io_reasons_parser")

_SECTION_KW = ["io reasons by requests", "exadata io reasons",
               "io reasons", "cell io reasons"]


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


def parse_io_reasons(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []

    sec = _find(soup)
    if not sec:
        logger.warning("⚠️  IO Reasons section not found"); return []

    # May have one aggregate table then per-cell breakdown; parse up to 2
    tables_parsed = 0
    sib = sec.find_next_sibling()
    while sib and tables_parsed < 2:
        name = getattr(sib,"name",None)
        if name == "h2": break
        if name == "table":
            try:
                df = pd.read_html(StringIO(str(sib)))[0]
                _parse_reasons_table(df, meta, records)
                tables_parsed += 1
            except: pass
        sib = sib.find_next_sibling()

    if not records:
        logger.warning("⚠️  No IO Reasons data found"); return []

    # Compute pct_of_total_req from 'All' aggregate row if available
    all_rows = {r["reason"]: r for r in records if r.get("cell_name") == "All"}
    total_all = sum((r.get("total_req") or 0) for r in records if r.get("cell_name") == "All")
    if total_all > 0:
        for r in records:
            if r.get("cell_name") == "All" and r.get("total_req"):
                r["pct_of_total_req"] = round(r["total_req"] / total_all * 100, 1)

    logger.info(f"✅ Parsed {len(records)} IO Reasons rows")
    return records


def _parse_reasons_table(df, meta, records):
    col_cell   = _col(df,"Cell","Cell Name","Name","Storage Cell")
    col_reason = _col(df,"Reason","IO Reason","Cause","Type")
    col_sm_req = _col(df,"Small Req","Small Requests","Small IOs","Small")
    col_lg_req = _col(df,"Large Req","Large Requests","Large IOs","Large")
    col_tot_req= _col(df,"Total Req","Total Requests","Requests")
    col_sm_mb  = _col(df,"Small MB","Small MBs","Small Size")
    col_lg_mb  = _col(df,"Large MB","Large MBs","Large Size")
    col_tot_mb = _col(df,"Total MB","Total MBs","MB")
    use_pos    = col_reason is None

    current_cell = "All"
    for _, row in df.iterrows():
        vals = list(row)
        if use_pos:
            cell   = str(vals[0]).strip()
            reason = str(vals[1]).strip() if len(vals)>1 else None
            sm_req = _n(vals[2]) if len(vals)>2 else None
            lg_req = _n(vals[3]) if len(vals)>3 else None
            tot_req= _n(vals[4]) if len(vals)>4 else None
            sm_mb  = _n(vals[5]) if len(vals)>5 else None
            lg_mb  = _n(vals[6]) if len(vals)>6 else None
            tot_mb = _n(vals[7]) if len(vals)>7 else None
        else:
            cell   = str(row.get(col_cell,"")).strip() if col_cell else "All"
            reason = str(row.get(col_reason,"")).strip()
            sm_req = _n(row.get(col_sm_req)) if col_sm_req else None
            lg_req = _n(row.get(col_lg_req)) if col_lg_req else None
            tot_req= _n(row.get(col_tot_req)) if col_tot_req else None
            sm_mb  = _n(row.get(col_sm_mb)) if col_sm_mb else None
            lg_mb  = _n(row.get(col_lg_mb)) if col_lg_mb else None
            tot_mb = _n(row.get(col_tot_mb)) if col_tot_mb else None

        # Handle hierarchical layout (cell spans multiple reason rows)
        if cell and cell.lower() not in ("nan","cell","name"): current_cell = cell
        if not reason or reason.lower() in ("nan","reason","io reason"): continue
        tot_req = tot_req or ((sm_req or 0)+(lg_req or 0)) or None
        tot_mb  = tot_mb  or ((sm_mb  or 0)+(lg_mb  or 0)) or None
        rh = _rh({"cell":current_cell,"reason":reason,"tot_req":tot_req})
        records.append(sanitize_record({
            "dbname":meta["dbname"],"instance":meta["instance"],
            "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
            "cell_name":current_cell,"reason":reason,
            "small_req":int(sm_req) if sm_req else None,
            "large_req":int(lg_req) if lg_req else None,
            "total_req":int(tot_req) if tot_req else None,
            "small_mb":sm_mb,"large_mb":lg_mb,"total_mb":tot_mb,
            "pct_of_total_req":None,   # filled in after all rows parsed
            "row_hash":rh,
        }))


def insert_io_reasons(records):
    if not records:
        logger.warning("⚠️  No IO Reasons records to insert"); return
    sql = """INSERT INTO awr_exadata_io_reasons
        (dbname,instance,begin_snap,snap_time,cell_name,reason,
         small_req,large_req,total_req,small_mb,large_mb,total_mb,
         pct_of_total_req,row_hash)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,cell_name,reason,row_hash) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["cell_name"],r["reason"],r["small_req"],r["large_req"],r["total_req"],
                r["small_mb"],r["large_mb"],r["total_mb"],r["pct_of_total_req"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_io_reasons")
    except Exception as e:
        logger.error(f"❌ {e}", exc_info=True)
    finally:
        if conn: conn.close()


def main(filepath):
    r = parse_io_reasons(filepath)
    if r: insert_io_reasons(r)

if __name__ == "__main__":
    t = globals().get("filepath") or (sys.argv[1] if len(sys.argv)>1 else None)
    if not t: print("Usage: python exadata_io_reasons_parser.py <awr.html>"); sys.exit(1)
    insert_io_reasons(parse_io_reasons(t))
