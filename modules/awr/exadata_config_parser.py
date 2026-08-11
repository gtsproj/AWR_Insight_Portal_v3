# modules/awr/exadata_config_parser.py — Exadata Configuration parser
import os,sys,re,warnings
from io import StringIO
import pandas as pd
from bs4 import BeautifulSoup
warnings.simplefilter("ignore")
_ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..",".."))
sys.path.insert(0,os.path.join(_ROOT,"common"))
from db import get_db_connection
from utils import row_hash as _rh,extract_workload_repo_metadata,sanitize_record
from logger_utils import get_logger
logger=get_logger("exadata_config_parser")
_KW=["exadata configuration","cell configuration","storage cell configuration"]

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
def _n(v,gb=False):
    if v is None: return None
    s=re.sub(r"\s*(gb|mb|tb)\s*$","",str(v).strip().replace(",",""),flags=re.I)
    if s.lower() in ("nan","n/a","--",""): return None
    try:
        f=float(s)
        return f*1024 if gb else f
    except: return None

def parse_config(filepath):
    records=[]
    with open(filepath,encoding="utf-8",errors="replace") as f:
        soup=BeautifulSoup(f,"html.parser")
    meta=extract_workload_repo_metadata(soup)
    if not meta: return []
    sec=_find(soup)
    if not sec:
        logger.warning("⚠️  Exadata Configuration section not found"); return []
    tbl=sec.find_next("table")
    if not tbl: return []
    df=pd.read_html(StringIO(str(tbl)))[0]
    col_name=_col(df,"Name","Cell","Cell Name")
    col_model=_col(df,"Model","Cell Model","Storage Model")
    col_ver  =_col(df,"Storage Version","Version","Cell Version","SW Version")
    col_fc   =_col(df,"Flash Cache Size","FC Size","Flash Cache")
    col_fl   =_col(df,"Flash Log Size","Flash Log","FL Size")
    col_cd   =_col(df,"Cell Disks","CellDisks","Disks")
    col_gd   =_col(df,"Grid Disks","GridDisks")
    use_pos  =col_name is None
    for _,row in df.iterrows():
        vals=list(row)
        cell =str(vals[0] if use_pos else row.get(col_name,"")).strip()
        if not cell or cell.lower() in ("nan","name","cell"): continue
        model=str(vals[1] if use_pos else row.get(col_model,"")).strip() if (use_pos or col_model) else None
        ver  =str(vals[2] if use_pos else row.get(col_ver,"")).strip()  if (use_pos or col_ver)   else None
        fc_r =str(vals[3] if use_pos else row.get(col_fc,"")).strip()   if (use_pos or col_fc)    else None
        fl_r =str(vals[4] if use_pos else row.get(col_fl,"")).strip()   if (use_pos or col_fl)    else None
        cd_r =str(vals[5] if use_pos else row.get(col_cd,"")).strip()   if (use_pos or col_cd)    else None
        gd_r =str(vals[6] if use_pos else row.get(col_gd,"")).strip()   if (use_pos or col_gd)    else None
        # Parse flash cache / log sizes (GB → MB)
        def parse_size_mb(raw,default_unit="GB"):
            if not raw or str(raw).lower() in ("nan","--",""): return None
            m=re.search(r"([\d,\.]+)\s*(GB|MB|TB)?",str(raw).upper())
            if not m: return None
            v=float(m.group(1).replace(",","")); u=m.group(2) or default_unit
            return v*1024 if u=="GB" else v/1024 if u=="TB" else v
        fc_mb=parse_size_mb(fc_r)
        fl_mb=parse_size_mb(fl_r,"MB")
        try: cd=int(float(str(cd_r).replace(",","")))
        except: cd=None
        try: gd=int(float(str(gd_r).replace(",","")))
        except: gd=None
        rh=_rh({"cell":cell,"model":model,"fc_mb":fc_mb})
        records.append(sanitize_record({
            "dbname":meta["dbname"],"instance":meta["instance"],
            "begin_snap":meta["begin_snap"],"snap_time":meta["snap_time"],
            "cell_name":cell,
            "model":model if model not in ("nan","") else None,
            "storage_version":ver if ver not in ("nan","") else None,
            "flash_cache_mb":fc_mb,"flash_log_mb":fl_mb,
            "cell_disks":cd,"grid_disks":gd,
            "has_flash_log":fl_mb is not None,"row_hash":rh}))
    # Config consistency check
    fc_sizes=set(r["flash_cache_mb"] for r in records if r.get("flash_cache_mb"))
    fl_miss =[r["cell_name"] for r in records if not r.get("has_flash_log")]
    logger.info(f"✅ Config: {len(records)} cells | FC sizes={fc_sizes} | no_flash_log={fl_miss}")
    return records

def insert_config(records):
    if not records: return
    sql="""INSERT INTO awr_exadata_config
        (dbname,instance,begin_snap,snap_time,cell_name,model,storage_version,
         flash_cache_mb,flash_log_mb,cell_disks,grid_disks,has_flash_log,row_hash)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap,cell_name,row_hash) DO NOTHING"""
    conn=None
    try:
        conn=get_db_connection(); cur=conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["instance"],r["begin_snap"],r["snap_time"],
                r["cell_name"],r["model"],r["storage_version"],r["flash_cache_mb"],
                r["flash_log_mb"],r["cell_disks"],r["grid_disks"],r["has_flash_log"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_config")
    except Exception as e: logger.error(f"❌ {e}",exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath):
    r=parse_config(filepath)
    if r: insert_config(r)
if __name__=="__main__":
    t=globals().get("filepath") or (sys.argv[1] if len(sys.argv)>1 else None)
    if t: insert_config(parse_config(t))
