# modules/awr/exadata_top_db_parser.py
# ============================================================
# Parses the "Top Databases by IO Requests" section of an
# Exadata AWR report, including the Details sub-table.
#
# Key metrics per database:
#   - flash_req_pct / disk_req_pct  : IO source split
#   - small_avg_lat_ms              : single-block average latency
#   - large_avg_lat_ms              : multi-block average latency
#   - iorm_queue_ms                 : IORM large-IO queue time
#
# iorm_queue_ms > 5ms = HIGH alert (IORM resource contention).
# High disk_req_pct = Flash Cache not serving this DB's IOs.
#
# Section headers in AWR HTML:
#   <h3>Top Databases by IO Requests</h3>
#   <h3>Top Databases by IO Requests - Details</h3>
#
# CALLED BY master_parser via main(filepath).
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
logger = get_logger("exadata_top_db_parser")

_SUMMARY_KW = ["top databases by io requests", "top databases io requests",
               "exadata top databases"]
_DETAIL_KW  = ["top databases by io requests - details",
               "top databases by io requests detail",
               "top databases - details", "top databases details"]


def _find(soup, kws):
    for tag in soup.find_all(["h2", "h3"]):
        t = tag.get_text(strip=True).lower()
        if any(k in t for k in kws):
            return tag
    return None


def _col(df, *candidates):
    lm = {c.lower(): c for c in df.columns}
    for n in candidates:
        if n.lower() in lm: return lm[n.lower()]
    for n in candidates:
        for k, v in lm.items():
            if n.lower() in k: return v
    return None


def _n(v):
    if v is None: return None
    s = str(v).strip().replace(",", "").replace("%", "").replace("ms", "")
    if s.lower() in ("nan", "n/a", "--", "-", ""): return None
    try: return float(s)
    except: return None


def parse_top_db(filepath):
    records = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []

    # ── Summary table ──────────────────────────────────────────────────────
    sum_sec = _find(soup, _SUMMARY_KW)
    if not sum_sec:
        logger.warning("⚠️  Top Databases section not found")
        return []

    sum_tbl = sum_sec.find_next("table")
    if not sum_tbl: return []

    df = pd.read_html(StringIO(str(sum_tbl)))[0]
    col_db       = _col(df, "Database", "DB Name", "DB", "Name")
    col_flash_rq = _col(df, "Flash Req%", "Flash %", "% Flash Req", "Flash Request %", "% Requests Flash")
    col_disk_rq  = _col(df, "Disk Req%",  "Disk %",  "% Disk Req",  "Disk Request %",  "% Requests Disk")
    col_flash_mb = _col(df, "Flash MB%",  "Flash MB %", "% MB Flash")
    col_disk_mb  = _col(df, "Disk MB%",   "Disk MB %",  "% MB Disk")
    col_total    = _col(df, "Total Req", "Total Requests", "Requests")
    use_pos = col_db is None

    summary = {}
    for _, row in df.iterrows():
        vals = list(row)
        db    = str(vals[0]).strip() if use_pos else str(row.get(col_db, "")).strip()
        if not db or db.lower() in ("nan", "database", "db name"): continue
        summary[db] = {
            "flash_req_pct": _n(vals[1] if use_pos else row.get(col_flash_rq)),
            "disk_req_pct":  _n(vals[2] if use_pos else row.get(col_disk_rq)),
            "flash_mb_pct":  _n(vals[3] if use_pos else row.get(col_flash_mb)),
            "disk_mb_pct":   _n(vals[4] if use_pos else row.get(col_disk_mb)),
            "total_req":     _n(vals[5] if use_pos else row.get(col_total)),
        }

    # ── Details table (latency + IORM queue) ──────────────────────────────
    det_sec = _find(soup, _DETAIL_KW)
    details = {}
    if det_sec:
        det_tbl = det_sec.find_next("table")
        if det_tbl:
            ddf = pd.read_html(StringIO(str(det_tbl)))[0]
            col_ddb   = _col(ddf, "Database", "DB Name", "DB", "Name")
            col_sm    = _col(ddf, "Small", "Small Avg Lat", "Small IO Lat", "Avg Small")
            col_lg    = _col(ddf, "Large", "Large Avg Lat", "Large IO Lat", "Avg Large")
            col_iorm  = _col(ddf, "IORM", "IORM Queue", "IORM Queue Ms", "Large IO Queue")
            use_dpos  = col_ddb is None
            for _, row in ddf.iterrows():
                vals = list(row)
                db = str(vals[0]).strip() if use_dpos else str(row.get(col_ddb,"")).strip()
                if not db or db.lower() in ("nan","database","db name"): continue
                details[db] = {
                    "small_avg_lat_ms": _n(vals[1] if use_dpos else row.get(col_sm)),
                    "large_avg_lat_ms": _n(vals[2] if use_dpos else row.get(col_lg)),
                    "iorm_queue_ms":    _n(vals[3] if use_dpos else row.get(col_iorm)),
                }

    # ── Merge and emit ─────────────────────────────────────────────────────
    all_dbs = set(summary) | set(details)
    if not all_dbs:
        # single-DB AWR: default to the parsed dbname
        all_dbs = {meta["dbname"]}

    for db in all_dbs:
        s = summary.get(db, {})
        d = details.get(db, {})
        rh = _rh({"db": db, "flash": s.get("flash_req_pct"), "iorm": d.get("iorm_queue_ms")})
        records.append(sanitize_record({
            "dbname": meta["dbname"], "instance": meta["instance"],
            "begin_snap": meta["begin_snap"], "snap_time": meta["snap_time"],
            "target_dbname":    db,
            "flash_req_pct":    s.get("flash_req_pct"),
            "disk_req_pct":     s.get("disk_req_pct"),
            "flash_mb_pct":     s.get("flash_mb_pct"),
            "disk_mb_pct":      s.get("disk_mb_pct"),
            "total_req":        int(s["total_req"]) if s.get("total_req") else None,
            "small_avg_lat_ms": d.get("small_avg_lat_ms"),
            "large_avg_lat_ms": d.get("large_avg_lat_ms"),
            "iorm_queue_ms":    d.get("iorm_queue_ms"),
            "row_hash": rh,
        }))

    high_iorm = [r["target_dbname"] for r in records if (r.get("iorm_queue_ms") or 0) > 5]
    logger.info(f"✅ Parsed {len(records)} Top DB rows"
                + (f" | HIGH IORM: {high_iorm}" if high_iorm else ""))
    return records


def insert_top_db(records):
    if not records:
        logger.warning("⚠️  No Top DB records to insert"); return
    sql = """INSERT INTO awr_exadata_top_db
        (dbname,instance,begin_snap,snap_time,target_dbname,
         flash_req_pct,disk_req_pct,flash_mb_pct,disk_mb_pct,total_req,
         small_avg_lat_ms,large_avg_lat_ms,iorm_queue_ms,row_hash)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,target_dbname,row_hash) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["target_dbname"],r["flash_req_pct"],r["disk_req_pct"],
                r["flash_mb_pct"],r["disk_mb_pct"],r["total_req"],
                r["small_avg_lat_ms"],r["large_avg_lat_ms"],r["iorm_queue_ms"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_top_db")
    except Exception as e:
        logger.error(f"❌ {e}", exc_info=True)
    finally:
        if conn: conn.close()


def main(filepath):
    r = parse_top_db(filepath)
    if r: insert_top_db(r)

if __name__ == "__main__":
    t = globals().get("filepath") or (sys.argv[1] if len(sys.argv)>1 else None)
    if not t: print("Usage: python exadata_top_db_parser.py <awr.html>"); sys.exit(1)
    insert_top_db(parse_top_db(t))
