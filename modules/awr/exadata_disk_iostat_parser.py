# modules/awr/exadata_disk_iostat_parser.py — OS IO Statistics Outlier Disks
import os,sys,warnings
from io import StringIO
import pandas as pd
from bs4 import BeautifulSoup
warnings.simplefilter("ignore")
_ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..",".."))
sys.path.insert(0,os.path.join(_ROOT,"common"))
from db import get_db_connection
from utils import row_hash as _rh,extract_workload_repo_metadata,sanitize_record
from logger_utils import get_logger
logger=get_logger("exadata_disk_iostat_parser")
_KW=["os io statistics - outlier disks","outlier disks","disk outlier","io statistics outlier disk"]

def _find(soup):
    for t in soup.find_all(["h2","h3"]):
        if any(k in t.get_text(strip=True).lower() for k in _KW): return t
    return None
def _col(df,*c):
    lm={x.lower():x for x in df.columns}
    for n in c:
        if n.lower() in lm: return lm[n.lower()]
    for n in c:
        for k,v in lm.items():
            if n.lower() in k: return v
    return None
def _n(v):
    if v is None: return None
    s=str(v).strip().replace(",","").replace("%","").replace("ms","")
    if s.lower() in ("nan","n/a","--",""): return None
    try: return float(s)
    except: return None

def parse_disk_iostat(filepath):
    records=[]
    with open(filepath,encoding="utf-8",errors="replace") as f:
        soup=BeautifulSoup(f,"html.parser")
    meta=extract_workload_repo_metadata(soup)
    if not meta: return []
    sec=_find(soup)
    if not sec:
        logger.warning("⚠️  Outlier Disks section not found"); return []
    tbl=sec.find_next("table")
    if not tbl: return []
    df=pd.read_html(StringIO(str(tbl)))[0]
    col_cell =_col(df,"Cell","Cell Name")
    col_disk =_col(df,"Disk","Disk Name","Device")
    col_dev  =_col(df,"Device Type","Type","Disk Type")
    col_iops =_col(df,"IOPs","IO/s","IOPS")
    col_tput =_col(df,"Throughput","MB/s","Throughput MB/s")
    col_util =_col(df,"Util","Util%","Utilization")
    col_svc  =_col(df,"Service","Service ms","Service Time")
    col_out  =_col(df,"Outlier","Is Outlier","Outlier Flag")
    use_pos  =col_cell is None
    for _,row in df.iterrows():
        vals=list(row)
        cell =str(vals[0] if use_pos else row.get(col_cell,"")).strip()
        if not cell or cell.lower() in ("nan","cell","name"): continue
        disk =str(vals[1] if use_pos else row.get(col_disk,"")).strip() if (use_pos or col_disk) else None
        dev  =str(vals[2] if use_pos else row.get(col_dev,"")).strip()  if (use_pos or col_dev)  else "Unknown"
        iops =_n(vals[3] if use_pos else row.get(col_iops))
        tput =_n(vals[4] if use_pos else row.get(col_tput))
        util =_n(vals[5] if use_pos else row.get(col_util))
        svc  =_n(vals[6] if use_pos else row.get(col_svc))
        raw_out=str(vals[7] if use_pos and len(vals)>7 else row.get(col_out,"")).lower() if col_out or (use_pos and len(vals)>7) else ""
        is_out=raw_out in ("yes","true","1","outlier","y")
        rh=_rh({"cell":cell,"disk":disk,"iops":iops,"util":util})
        records.append(sanitize_record({
            "dbname":meta["dbname"],"instance":meta["instance"],
            "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
            "cell_name":cell,
            "disk_name":disk if disk not in ("nan","") else None,
            "device_type":dev if dev not in ("nan","") else "Unknown",
            "iops":iops,"throughput_mbps":tput,"util_pct":util,
            "service_ms":svc,"is_outlier":is_out,"row_hash":rh}))
    outliers=[r["cell_name"] for r in records if r.get("is_outlier")]
    logger.info(f"✅ Disk IOStat: {len(records)} rows | outliers={outliers}")
    return records

def insert_disk_iostat(records):
    if not records: return
    sql="""INSERT INTO awr_exadata_disk_iostat
        (dbname,instance,begin_snap,snap_time,cell_name,disk_name,device_type,
         iops,throughput_mbps,util_pct,service_ms,is_outlier,row_hash)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,cell_name,device_type,row_hash) DO NOTHING"""
    conn=None
    try:
        conn=get_db_connection(); cur=conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["cell_name"],r["disk_name"],r["device_type"],r["iops"],
                r["throughput_mbps"],r["util_pct"],r["service_ms"],r["is_outlier"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_disk_iostat")
    except Exception as e: logger.error(f"❌ {e}",exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath):
    r=parse_disk_iostat(filepath)
    if r: insert_disk_iostat(r)
if __name__=="__main__":
    t=globals().get("filepath") or (sys.argv[1] if len(sys.argv)>1 else None)
    if t: insert_disk_iostat(parse_disk_iostat(t))
