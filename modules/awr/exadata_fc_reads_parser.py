# modules/awr/exadata_fc_reads_parser.py
# ============================================================
# Parses two related Flash Cache read sections from Exadata AWR:
#
#   1. "Flash Cache User Reads Per Second"
#      Per-cell: OLTP req/s, OLTP miss/s, Scan req/s, Scan miss/s
#
#   2. "Flash Cache User Reads Efficiency"  (or "Reads Efficiency")
#      Per-cell: OLTP hit%, Scan hit%
#
# Both sections are merged into awr_exadata_fc_reads:
#   (cell_name, io_type='OLTP' | io_type='Scan')
#
# io_type = 'Total' is inserted if only aggregate data is present.
#
# Key diagnostic signal:
#   hit_pct < 80 (OLTP) or < 70 (Scan) = HIGH alert
#   Cells with significantly lower hit_pct than peers =
#     likely in Flash Cache flushing state (cross-reference
#     awr_exadata_fc_config.is_flushing for the same snap)
#
# Section headers in AWR HTML:
#   <h3>Flash Cache User Reads Per Second</h3>
#   <h3>Flash Cache User Reads Efficiency</h3>   (or "Reads - Efficiency")
#
# CALLED BY master_parser via main(filepath).
# ============================================================

import os
import sys
import re
import warnings
from io import StringIO

import pandas as pd
from bs4 import BeautifulSoup

warnings.simplefilter(action="ignore", category=FutureWarning)

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, "common"))

from db import get_db_connection
from utils import row_hash as make_row_hash, extract_workload_repo_metadata, clean_number, sanitize_record
from logger_utils import get_logger

logger = get_logger("exadata_fc_reads_parser")

_RPS_KW   = ["flash cache user reads per second",
             "flash cache reads per second",
             "fc user reads per second"]
_EFF_KW   = ["flash cache user reads efficiency",
             "flash cache reads efficiency",
             "reads efficiency",
             "flash cache user reads - efficiency"]
_SKIP_KW  = ["flash cache user reads - skips",
             "flash cache user reads skips",
             "flash cache read skips",
             "fc read skips"]


def _find_section(soup, keywords):
    for tag in soup.find_all(["h2", "h3"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in keywords):
            return tag
    return None


def _col(df, *candidates):
    lower_map = {c.lower(): c for c in df.columns}
    for name in candidates:
        if name.lower() in lower_map:
            return lower_map[name.lower()]
    for name in candidates:
        for k, v in lower_map.items():
            if name.lower() in k:
                return v
    return None


def _num(val):
    if val is None:
        return None
    s = str(val).strip().replace(",", "").replace("%", "")
    if s.lower() in ("nan", "n/a", "--", "-", ""):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _parse_rps_table(df):
    """
    Parse Flash Cache User Reads Per Second table.
    Returns dict: {cell_name: {oltp_req, oltp_miss, scan_req, scan_miss}}
    """
    result = {}

    col_name      = _col(df, "Name", "Cell", "Cell Name")
    col_oltp_req  = _col(df, "OLTP Requests", "OLTP Req/s", "OLTP Read Req",
                          "OLTP Reads/s", "OLTP")
    col_oltp_miss = _col(df, "OLTP Miss", "OLTP Misses", "OLTP Miss/s",
                          "OLTP Read Miss")
    col_scan_req  = _col(df, "Scan Requests", "Scan Req/s", "Scan Read Req",
                          "Scan Reads/s", "Scan")
    col_scan_miss = _col(df, "Scan Miss", "Scan Misses", "Scan Miss/s",
                          "Scan Read Miss")

    use_pos = col_name is None

    for _, row in df.iterrows():
        if use_pos:
            vals = list(row)
            cell = str(vals[0]).strip() if vals else None
            oltp_req  = _num(vals[1]) if len(vals) > 1 else None
            oltp_miss = _num(vals[2]) if len(vals) > 2 else None
            scan_req  = _num(vals[3]) if len(vals) > 3 else None
            scan_miss = _num(vals[4]) if len(vals) > 4 else None
        else:
            cell      = str(row.get(col_name, "")).strip()
            oltp_req  = _num(row.get(col_oltp_req))  if col_oltp_req  else None
            oltp_miss = _num(row.get(col_oltp_miss)) if col_oltp_miss else None
            scan_req  = _num(row.get(col_scan_req))  if col_scan_req  else None
            scan_miss = _num(row.get(col_scan_miss)) if col_scan_miss else None

        if not cell or cell.lower() in ("nan", "name", "cell"):
            continue
        result[cell] = {
            "oltp_req": oltp_req, "oltp_miss": oltp_miss,
            "scan_req": scan_req, "scan_miss": scan_miss,
        }
    return result


def _parse_eff_table(df):
    """
    Parse Flash Cache User Reads Efficiency table.
    Returns dict: {cell_name: {oltp_hit_pct, scan_hit_pct}}
    """
    result = {}
    col_name     = _col(df, "Name", "Cell", "Cell Name")
    col_oltp_hit = _col(df, "OLTP Hit", "OLTP %Hit", "OLTP Hit %",
                         "OLTP Hit Pct", "%Hit OLTP")
    col_scan_hit = _col(df, "Scan Hit", "Scan %Hit", "Scan Hit %",
                         "Scan Hit Pct", "%Hit Scan")

    use_pos = col_name is None

    for _, row in df.iterrows():
        if use_pos:
            vals     = list(row)
            cell     = str(vals[0]).strip() if vals else None
            oltp_hit = _num(vals[1]) if len(vals) > 1 else None
            scan_hit = _num(vals[2]) if len(vals) > 2 else None
        else:
            cell     = str(row.get(col_name, "")).strip()
            oltp_hit = _num(row.get(col_oltp_hit)) if col_oltp_hit else None
            scan_hit = _num(row.get(col_scan_hit)) if col_scan_hit else None

        if not cell or cell.lower() in ("nan", "name", "cell"):
            continue
        result[cell] = {"oltp_hit_pct": oltp_hit, "scan_hit_pct": scan_hit}
    return result


def _parse_skip_table(df):
    """
    Parse Flash Cache User Reads – Skips table.
    Returns dict: {cell_name: skip_count}
    """
    result = {}
    col_name  = _col(df, "Name", "Cell", "Cell Name")
    col_skip  = _col(df, "Skip", "Skips", "Skip Count", "Read Skips",
                      "Total Skips")

    use_pos = col_name is None

    for _, row in df.iterrows():
        if use_pos:
            vals = list(row)
            cell = str(vals[0]).strip() if vals else None
            skip = _num(vals[1]) if len(vals) > 1 else None
        else:
            cell = str(row.get(col_name, "")).strip()
            skip = _num(row.get(col_skip)) if col_skip else None

        if not cell or cell.lower() in ("nan", "name", "cell"):
            continue
        result[cell] = int(skip) if skip is not None else None
    return result


def parse_fc_reads(filepath):
    """Parse Flash Cache User Reads sections. Returns list of dicts."""
    records = []

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")

    meta = extract_workload_repo_metadata(soup)
    if not meta:
        logger.error("❌ Failed to extract workload repo metadata")
        return []

    # ── Flash Cache User Reads Per Second ─────────────────────────────────
    rps_data = {}
    rps_sec = _find_section(soup, _RPS_KW)
    if rps_sec:
        tbl = rps_sec.find_next("table")
        if tbl:
            try:
                rps_data = _parse_rps_table(pd.read_html(StringIO(str(tbl)))[0])
            except Exception as e:
                logger.warning(f"⚠️  Failed parsing FC Reads Per Second table: {e}")
    else:
        logger.warning("⚠️  Flash Cache User Reads Per Second section not found")

    # ── Flash Cache User Reads Efficiency ─────────────────────────────────
    eff_data = {}
    eff_sec = _find_section(soup, _EFF_KW)
    if eff_sec:
        tbl = eff_sec.find_next("table")
        if tbl:
            try:
                eff_data = _parse_eff_table(pd.read_html(StringIO(str(tbl)))[0])
            except Exception as e:
                logger.warning(f"⚠️  Failed parsing FC Reads Efficiency table: {e}")

    # ── Flash Cache User Reads – Skips ────────────────────────────────────
    skip_data = {}
    skip_sec = _find_section(soup, _SKIP_KW)
    if skip_sec:
        tbl = skip_sec.find_next("table")
        if tbl:
            try:
                skip_data = _parse_skip_table(pd.read_html(StringIO(str(tbl)))[0])
            except Exception as e:
                logger.warning(f"⚠️  Failed parsing FC Reads Skips table: {e}")

    if not rps_data and not eff_data:
        logger.warning("⚠️  No Flash Cache User Reads data found")
        return []

    # ── Merge per-cell data into records ──────────────────────────────────
    all_cells = set(rps_data) | set(eff_data)

    for cell in all_cells:
        rps = rps_data.get(cell, {})
        eff = eff_data.get(cell, {})
        skip_count = skip_data.get(cell)

        oltp_req  = rps.get("oltp_req")
        oltp_miss = rps.get("oltp_miss")
        scan_req  = rps.get("scan_req")
        scan_miss = rps.get("scan_miss")
        oltp_hit  = eff.get("oltp_hit_pct")
        scan_hit  = eff.get("scan_hit_pct")

        # Derive hit% if not provided in an Efficiency table
        if oltp_hit is None and oltp_req and oltp_req > 0 and oltp_miss is not None:
            oltp_hit = round((1 - oltp_miss / oltp_req) * 100, 1)
        if scan_hit is None and scan_req and scan_req > 0 and scan_miss is not None:
            scan_hit = round((1 - scan_miss / scan_req) * 100, 1)

        for io_type, req, miss, hit in [
            ("OLTP", oltp_req, oltp_miss, oltp_hit),
            ("Scan", scan_req, scan_miss, scan_hit),
        ]:
            rh = make_row_hash({
                "cell": cell, "type": io_type,
                "req": req, "hit": hit,
            })
            records.append(sanitize_record({
                "dbname":      meta["dbname"],
                "instance":    meta["instance"],
                "begin_snap":  meta["begin_snap"],
                "snap_time":   meta["snap_time"],
                "cell_name":   cell,
                "io_type":     io_type,
                "req_per_sec": req,
                "miss_per_sec": miss,
                "hit_pct":     hit,
                "skip_count":  skip_count if io_type == "OLTP" else None,
                "row_hash":    rh,
            }))

    low_hit = [f"{r['cell_name']}({r['io_type']} {r['hit_pct']}%)"
               for r in records
               if r.get("hit_pct") is not None and r["hit_pct"] < 80]
    logger.info(f"✅ Parsed {len(records)} Flash Cache User Reads rows"
                + (f" | LOW hit%: {low_hit}" if low_hit else ""))
    return records


def insert_fc_reads(records):
    """Insert Flash Cache User Reads records into PostgreSQL."""
    if not records:
        logger.warning("⚠️  No Flash Cache User Reads records to insert")
        return

    sql = """
        INSERT INTO awr_exadata_fc_reads
            (dbname, instance, begin_snap, snap_time,
             cell_name, io_type, req_per_sec, miss_per_sec,
             hit_pct, skip_count, row_hash)
        VALUES (%s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s)
        ON CONFLICT (dbname, begin_snap, cell_name, io_type, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        cur  = conn.cursor()
        for r in records:
            cur.execute(sql, (
                r["dbname"], r["instance"], r["begin_snap"], r["snap_time"],
                r["cell_name"], r["io_type"], r["req_per_sec"], r["miss_per_sec"],
                r["hit_pct"], r["skip_count"], r["row_hash"],
            ))
        conn.commit()
        cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_fc_reads")
    except Exception as e:
        logger.error(f"❌ Failed inserting FC User Reads: {e}", exc_info=True)
    finally:
        if conn:
            conn.close()


def main(filepath):
    records = parse_fc_reads(filepath)
    if records:
        insert_fc_reads(records)


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if not _target:
        print("Usage: python exadata_fc_reads_parser.py <awr_report.html>")
        sys.exit(1)
    records = parse_fc_reads(_target)
    insert_fc_reads(records)
