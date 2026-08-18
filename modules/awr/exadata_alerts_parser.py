# modules/awr/exadata_alerts_parser.py — Exadata Alerts Summary
import os, sys, warnings
from bs4 import BeautifulSoup
warnings.simplefilter("ignore")
_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(_ROOT, "common"))
from db import get_db_connection
from utils import row_hash as make_row_hash, extract_workload_repo_metadata, sanitize_record
from logger_utils import get_logger
logger = get_logger("exadata_alerts_parser")
_SECTION_KW = ["exadata alerts summary","exadata alert summary","exadata alerts"]
_STOP_KW    = ["exadata alerts detail","exadata non-online","back to exadata"]

def _find_section(soup):
    for tag in soup.find_all(["h2","h3","h4","h5"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in _SECTION_KW) and "detail" not in txt: return tag
    return None

def parse_alerts(filepath):
    with open(filepath, encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")
    meta = extract_workload_repo_metadata(soup)
    if not meta: return []
    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Exadata Alerts Summary section not found"); return []
    # Read text content between this heading and the next h3/h2
    text_parts = []
    sib = section.find_next_sibling()
    while sib:
        nm = getattr(sib, "name", None)
        if nm in ("h2","h3","h4") and any(k in sib.get_text(strip=True).lower() for k in _STOP_KW): break
        if nm in ("h2","h3") and nm != "h4": break
        text = sib.get_text(separator=" ", strip=True) if hasattr(sib, "get_text") else ""
        if text: text_parts.append(text)
        sib = sib.find_next_sibling()
    alert_text = " ".join(text_parts).strip()
    has_alerts = "no open alerts" not in alert_text.lower() and bool(alert_text)
    alert_count = 0 if not has_alerts else max(1, alert_text.lower().count("warning") + alert_text.lower().count("critical"))
    rec = sanitize_record({
        "dbname": meta["dbname"], "begin_snap": meta["begin_snap"],
        "snap_time": meta["snap_time"], "alert_count": alert_count,
        "has_open_alerts": has_alerts,
        "alert_text": alert_text[:2000] if alert_text else "No open alerts.",
        "row_hash": make_row_hash({"dbname":meta["dbname"],"snap":meta["begin_snap"]}),
    })
    logger.info(f"✅ Parsed Exadata Alerts: has_alerts={has_alerts}, count={alert_count}")
    return [rec]

def insert_alerts(records):
    if not records: return
    sql = """
        INSERT INTO awr_exadata_alerts
            (dbname,begin_snap,snap_time,alert_count,has_open_alerts,alert_text,row_hash)
        VALUES (%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (dbname,begin_snap) DO NOTHING"""
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        for r in records:
            cur.execute(sql,(r["dbname"],r["begin_snap"],r["snap_time"],
                r["alert_count"],r["has_open_alerts"],r["alert_text"],r["row_hash"]))
        conn.commit(); cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_alerts")
    except Exception as e:
        logger.error(f"❌ Alerts insert failed: {e}", exc_info=True)
    finally:
        if conn: conn.close()

def main(filepath): records = parse_alerts(filepath); insert_alerts(records)
if __name__ == "__main__": main(sys.argv[1] if len(sys.argv)>1 else None)
