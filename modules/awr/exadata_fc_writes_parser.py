# modules/awr/exadata_fc_writes_parser.py
# Parses Flash Cache User Writes, Large Writes, Rejections, Skips,
# Internal Reads and Internal Writes sections from Exadata AWR.
# Writes to: awr_exadata_fc_writes, awr_exadata_fc_write_reject,
#            awr_exadata_fc_internal
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
logger = get_logger("exadata_fc_writes_parser")

_WR_KW     = ["flash cache user writes",  "fc user writes"]
_LW_KW     = ["flash cache user writes - large", "large writes"]
_REJ_KW    = ["flash cache user writes - large write reject", "large write rejection"]
_SKIP_KW   = ["flash cache user writes - skip", "fc write skips"]
_INT_RD_KW = ["flash cache internal read", "fc internal read"]
_INT_WR_KW = ["flash cache internal write", "fc internal write"]

def _find(soup, kws):
    for tag in soup.find_all(["h2","h3"]):
        t = tag.get_text(strip=True).lower()
        if any(k in t for k in kws): return tag
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


def parse_fc_writes(filepath):
    fw_recs = []; rej_recs = []; int_recs = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return fw_recs, rej_recs, int_recs

    # ── Flash Cache User Writes ────────────────────────────────────────────
    sec = _find(soup, _WR_KW)
    if sec:
        tbl = sec.find_next("table")
        if tbl:
            df = pd.read_html(StringIO(str(tbl)))[0]
            col_name = _col(df,"Name","Cell")
            col_tot  = _col(df,"Total Write","Total Write Reqs","Total Writes")
            col_part = _col(df,"Partial Write","Partial Writes")
            col_abs  = _col(df,"Absorbed","Absorbed Writes")
            col_rej  = _col(df,"Rejected","Rejected Writes")
            col_pct  = _col(df,"Partial Write%","Partial%","Partial Pct")
            for _, row in df.iterrows():
                cell = str(row.get(col_name,"") if col_name else row.iloc[0]).strip()
                if not cell or cell.lower() in ("nan","name","cell"): continue
                tot  = _n(row.get(col_tot)  if col_tot  else row.iloc[1])
                part = _n(row.get(col_part) if col_part else row.iloc[2])
                abso = _n(row.get(col_abs)  if col_abs  else row.iloc[3])
                rej  = _n(row.get(col_rej)  if col_rej  else row.iloc[4])
                pct  = _n(row.get(col_pct)  if col_pct  else row.iloc[5])
                rh   = _rh({"cell":cell,"tot":tot,"part":part,"sec":"user_writes"})
                fw_recs.append(sanitize_record({
                    "dbname":meta["dbname"],"instance":meta["instance"],
                    "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
                    "cell_name":cell,"write_section":"User Writes",
                    "total_write_reqs":int(tot) if tot else None,
                    "partial_writes":int(part) if part else None,
                    "absorbed_writes":int(abso) if abso else None,
                    "rejected_writes":int(rej) if rej else None,
                    "partial_write_pct":pct,
                    "large_write_count":None,"large_write_type":None,
                    "skip_count":None,"skip_reason":None,"row_hash":rh}))

    # ── Large Writes ───────────────────────────────────────────────────────
    sec = _find(soup, _LW_KW)
    if sec:
        tbl = sec.find_next("table")
        if tbl:
            df = pd.read_html(StringIO(str(tbl)))[0]
            col_name = _col(df,"Name","Cell")
            col_cnt  = _col(df,"Large Write Count","Count","Write Count")
            col_type = _col(df,"Large Write Type","Type","Write Type")
            for _, row in df.iterrows():
                cell = str(row.get(col_name,"") if col_name else row.iloc[0]).strip()
                if not cell or cell.lower() in ("nan","name","cell"): continue
                cnt   = _n(row.get(col_cnt)  if col_cnt  else row.iloc[1])
                ltype = str(row.get(col_type,"") if col_type else row.iloc[2]).strip()
                rh    = _rh({"cell":cell,"cnt":cnt,"type":ltype,"sec":"large_writes"})
                fw_recs.append(sanitize_record({
                    "dbname":meta["dbname"],"instance":meta["instance"],
                    "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
                    "cell_name":cell,"write_section":"Large Writes",
                    "total_write_reqs":None,"partial_writes":None,
                    "absorbed_writes":None,"rejected_writes":None,"partial_write_pct":None,
                    "large_write_count":int(cnt) if cnt else None,
                    "large_write_type":ltype if ltype not in ("nan","") else None,
                    "skip_count":None,"skip_reason":None,"row_hash":rh}))

    # ── Write Skips ────────────────────────────────────────────────────────
    sec = _find(soup, _SKIP_KW)
    if sec:
        tbl = sec.find_next("table")
        if tbl:
            df = pd.read_html(StringIO(str(tbl)))[0]
            col_name = _col(df,"Name","Cell")
            col_skip = _col(df,"Skip Count","Skips","Skip")
            col_rsn  = _col(df,"Skip Reason","Reason")
            for _, row in df.iterrows():
                cell = str(row.get(col_name,"") if col_name else row.iloc[0]).strip()
                if not cell or cell.lower() in ("nan","name","cell"): continue
                skip = _n(row.get(col_skip) if col_skip else row.iloc[1])
                rsn  = str(row.get(col_rsn,"") if col_rsn else row.iloc[2]).strip()
                rh   = _rh({"cell":cell,"skip":skip,"rsn":rsn,"sec":"write_skips"})
                fw_recs.append(sanitize_record({
                    "dbname":meta["dbname"],"instance":meta["instance"],
                    "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
                    "cell_name":cell,"write_section":"Write Skips",
                    "total_write_reqs":None,"partial_writes":None,
                    "absorbed_writes":None,"rejected_writes":None,"partial_write_pct":None,
                    "large_write_count":None,"large_write_type":None,
                    "skip_count":int(skip) if skip else None,
                    "skip_reason":rsn if rsn not in ("nan","") else None,"row_hash":rh}))

    # ── Write Rejections ───────────────────────────────────────────────────
    sec = _find(soup, _REJ_KW)
    if sec:
        tbl = sec.find_next("table")
        if tbl:
            df = pd.read_html(StringIO(str(tbl)))[0]
            col_name = _col(df,"Name","Cell")
            col_rsn  = _col(df,"Reason","Rejection Reason")
            col_cnt  = _col(df,"Rejection Count","Count","Rejections")
            col_pct  = _col(df,"Rejection%","Rejection Pct","%")
            for _, row in df.iterrows():
                cell = str(row.get(col_name,"") if col_name else row.iloc[0]).strip()
                if not cell or cell.lower() in ("nan","name","cell"): continue
                rsn = str(row.get(col_rsn,"") if col_rsn else row.iloc[1]).strip()
                cnt = _n(row.get(col_cnt) if col_cnt else row.iloc[2])
                pct = _n(row.get(col_pct) if col_pct else row.iloc[3])
                rh  = _rh({"cell":cell,"rsn":rsn,"cnt":cnt})
                rej_recs.append(sanitize_record({
                    "dbname":meta["dbname"],"instance":meta["instance"],
                    "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
                    "cell_name":cell,
                    "reason":rsn if rsn not in ("nan","") else "Unknown",
                    "rejection_count":int(cnt) if cnt else None,
                    "rejection_pct":pct,"row_hash":rh}))

    # ── Internal Reads ─────────────────────────────────────────────────────
    for kws, direction, cnt_col, type_col in [
        (_INT_RD_KW,"Internal Read","Internal Read Reqs","Read Type"),
        (_INT_WR_KW,"Internal Write","Population Writes","Write Type"),
    ]:
        sec = _find(soup, kws)
        if sec:
            tbl = sec.find_next("table")
            if tbl:
                df = pd.read_html(StringIO(str(tbl)))[0]
                col_name = _col(df,"Name","Cell")
                col_cnt  = _col(df,cnt_col,"Count","Reqs","Writes")
                col_type = _col(df,type_col,"Type")
                for _, row in df.iterrows():
                    cell = str(row.get(col_name,"") if col_name else row.iloc[0]).strip()
                    if not cell or cell.lower() in ("nan","name","cell"): continue
                    cnt  = _n(row.get(col_cnt)  if col_cnt  else row.iloc[1])
                    itype= str(row.get(col_type,"") if col_type else row.iloc[2]).strip()
                    rh   = _rh({"cell":cell,"dir":direction,"cnt":cnt,"type":itype})
                    int_recs.append(sanitize_record({
                        "dbname":meta["dbname"],"instance":meta["instance"],
                        "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
                        "cell_name":cell,"io_direction":direction,
                        "request_count":int(cnt) if cnt else None,
                        "io_type":itype if itype not in ("nan","") else None,
                        "row_hash":rh}))

    tot_rej = sum(r.get("rejection_count",0) or 0 for r in rej_recs)
    logger.info(f"✅ FC Writes: {len(fw_recs)} rows | Rejections: {len(rej_recs)} ({tot_rej:,} total) | Internal: {len(int_recs)}")
    return fw_recs, rej_recs, int_recs


def _insert(sql, records, conn):
    if not records: return
    cur = conn.cursor()
    for r in records:
        try: cur.execute(sql, list(r.values())[:-1] + [r[list(r.keys())[-1]]])
        except: pass

def insert_all(fw_recs, rej_recs, int_recs):
    conn = None
    try:
        conn = get_db_connection()
        if fw_recs:
            cur = conn.cursor()
            for r in fw_recs:
                cur.execute("""INSERT INTO awr_exadata_fc_writes
                    (dbname,instance,begin_snap,snap_time,cell_name,write_section,
                     total_write_reqs,partial_writes,absorbed_writes,rejected_writes,
                     partial_write_pct,large_write_count,large_write_type,
                     skip_count,skip_reason,row_hash)
                    VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (dbname,begin_snap,cell_name,write_section,row_hash) DO NOTHING""",
                    (r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                     r["cell_name"],r["write_section"],r["total_write_reqs"],
                     r["partial_writes"],r["absorbed_writes"],r["rejected_writes"],
                     r["partial_write_pct"],r["large_write_count"],r["large_write_type"],
                     r["skip_count"],r["skip_reason"],r["row_hash"]))
        if rej_recs:
            cur = conn.cursor()
            for r in rej_recs:
                cur.execute("""INSERT INTO awr_exadata_fc_write_reject
                    (dbname,instance,begin_snap,snap_time,cell_name,reason,rejection_count,rejection_pct,row_hash)
                    VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (dbname,begin_snap,cell_name,reason,row_hash) DO NOTHING""",
                    (r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                     r["cell_name"],r["reason"],r["rejection_count"],r["rejection_pct"],r["row_hash"]))
        if int_recs:
            cur = conn.cursor()
            for r in int_recs:
                cur.execute("""INSERT INTO awr_exadata_fc_internal
                    (dbname,instance,begin_snap,snap_time,cell_name,io_direction,request_count,io_type,row_hash)
                    VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (dbname,begin_snap,cell_name,io_direction,io_type,row_hash) DO NOTHING""",
                    (r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                     r["cell_name"],r["io_direction"],r["request_count"],r["io_type"],r["row_hash"]))
        conn.commit()
        logger.info(f"✅ Inserted fw={len(fw_recs)} rej={len(rej_recs)} int={len(int_recs)}")
    except Exception as e:
        logger.error(f"❌ {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath):
    fw, rej, internal = parse_fc_writes(filepath)
    if fw or rej or internal: insert_all(fw, rej, internal)

if __name__ == "__main__":
    t = globals().get("filepath") or (sys.argv[1] if len(sys.argv)>1 else None)
    if t: insert_all(*parse_fc_writes(t))
