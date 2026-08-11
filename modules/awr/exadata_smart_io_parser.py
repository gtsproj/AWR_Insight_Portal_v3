# modules/awr/exadata_smart_io_parser.py
# ============================================================
# Parses the "Exadata Smart IO" section of an Exadata AWR
# report.
#
# One row per storage cell (plus an 'All' aggregate row).
# Key metrics:
#   - Eligible MB/s  : eligible for Smart Scan offload
#   - SI Savings MB/s: eliminated by Storage Indexes
#   - Flash MB/s     : served from Flash Cache (smart scan)
#   - Disk MB/s      : read from hard disk (smart scan)
#   - Passthru MB/s  : not offloaded (passthru reason)
#   - Columnar Cache : served from Columnar Cache
#   - Reverse Offload: data transferred back to cell for processing
#
# Derived:
#   - passthru_pct = passthru_mbps / eligible_mbps * 100
#   - disk_pct     = disk_mbps     / eligible_mbps * 100
#
# Section header in AWR HTML:
#   <h3>Exadata Smart IO</h3>
#
# Table structure (per-cell rows):
#   Name | Eligible (MB) | SI Savings (MB) | Flash (MB) | Disk (MB) |
#   Passthru (MB) | Columnar Cache (MB) | Reverse Offload (MB)
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

logger = get_logger("exadata_smart_io_parser")

_SECTION_KW = ["exadata smart io", "smart io", "smart scan io"]


def _find_section(soup):
    for tag in soup.find_all(["h2", "h3"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in _SECTION_KW):
            return tag
    return None


def _col(df, *candidates):
    lower_map = {c.lower(): c for c in df.columns}
    for name in candidates:
        if name.lower() in lower_map:
            return lower_map[name.lower()]
    # Partial match
    for name in candidates:
        for k, v in lower_map.items():
            if name.lower() in k:
                return v
    return None


def _num(val):
    if val is None:
        return None
    s = str(val).strip().replace(",", "")
    if s.lower() in ("nan", "n/a", "--", "-", ""):
        return None
    # Strip trailing unit abbreviations
    s = re.sub(r"\s*(mb|gb|kb|mb/s|gb/s|bytes)\s*$", "", s, flags=re.IGNORECASE)
    try:
        return float(s)
    except ValueError:
        return None


def parse_smart_io(filepath):
    """Parse Exadata Smart IO per-cell table. Returns list of dicts."""
    records = []

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")

    meta = extract_workload_repo_metadata(soup)
    if not meta:
        logger.error("❌ Failed to extract workload repo metadata")
        return []

    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Exadata Smart IO section not found")
        return []

    table = section.find_next("table")
    if not table:
        logger.warning("⚠️  Exadata Smart IO table not found")
        return []

    df = pd.read_html(StringIO(str(table)))[0]
    if df.empty:
        logger.warning("⚠️  Exadata Smart IO table is empty")
        return []

    # ── Identify columns ───────────────────────────────────────────────────
    col_name     = _col(df, "Name", "Cell", "Cell Name", "Storage Cell")
    col_eligible = _col(df, "Eligible", "Eligible (MB)", "Smart IO Eligible",
                         "Eligible MB", "Eligible MBs")
    col_si       = _col(df, "Storage Index", "SI Savings", "SI Savings (MB)",
                         "Storage Index Savings", "SI")
    col_flash    = _col(df, "Flash", "Flash (MB)", "Flash Read",
                         "Flash MBs", "Flash Cache Read")
    col_disk     = _col(df, "Disk", "Disk (MB)", "Hard Disk",
                         "Disk MBs", "Disk Read")
    col_pass     = _col(df, "Passthru", "Passthru (MB)", "Pass Thru",
                         "Passthru MBs", "Pass-thru")
    col_col      = _col(df, "Columnar", "Columnar Cache", "Columnar Cache (MB)",
                         "Column Cache")
    col_rev      = _col(df, "Reverse", "Reverse Offload", "Reverse Offload (MB)")

    # Fallback to positional if column detection fails
    use_positional = col_name is None or col_eligible is None

    for _, row in df.iterrows():
        if use_positional:
            vals       = list(row)
            cell_name  = str(vals[0]).strip() if len(vals) > 0 else None
            eligible   = _num(vals[1]) if len(vals) > 1 else None
            si_savings = _num(vals[2]) if len(vals) > 2 else None
            flash_mb   = _num(vals[3]) if len(vals) > 3 else None
            disk_mb    = _num(vals[4]) if len(vals) > 4 else None
            pass_mb    = _num(vals[5]) if len(vals) > 5 else None
            col_mb     = _num(vals[6]) if len(vals) > 6 else None
            rev_mb     = _num(vals[7]) if len(vals) > 7 else None
        else:
            cell_name  = str(row.get(col_name,     "")).strip()
            eligible   = _num(row.get(col_eligible))
            si_savings = _num(row.get(col_si))     if col_si   else None
            flash_mb   = _num(row.get(col_flash))  if col_flash else None
            disk_mb    = _num(row.get(col_disk))   if col_disk  else None
            pass_mb    = _num(row.get(col_pass))   if col_pass  else None
            col_mb     = _num(row.get(col_col))    if col_col   else None
            rev_mb     = _num(row.get(col_rev))    if col_rev   else None

        # Skip header-like rows
        if not cell_name or cell_name.lower() in ("nan", "name", "cell", "storage cell"):
            continue

        # Derived percentages
        passthru_pct = (round(pass_mb / eligible * 100, 1)
                        if pass_mb is not None and eligible and eligible > 0
                        else None)
        disk_pct     = (round(disk_mb / eligible * 100, 1)
                        if disk_mb is not None and eligible and eligible > 0
                        else None)

        rh = make_row_hash({
            "cell": cell_name,
            "eligible": eligible,
            "flash": flash_mb,
            "disk": disk_mb,
        })

        records.append(sanitize_record({
            "dbname":              meta["dbname"],
            "instance":            meta["instance"],
            "begin_snap":          meta["begin_snap"],
            "snap_time":           meta["snap_time"],
            "cell_name":           cell_name,
            "eligible_mbps":       eligible,
            "si_savings_mbps":     si_savings,
            "flash_read_mbps":     flash_mb,
            "disk_read_mbps":      disk_mb,
            "passthru_mbps":       pass_mb,
            "col_cache_mbps":      col_mb,
            "reverse_offload_mbps": rev_mb,
            "passthru_pct":        passthru_pct,
            "disk_pct":            disk_pct,
            "row_hash":            rh,
        }))

    flushing_cells = [r["cell_name"] for r in records
                      if r.get("passthru_pct") and r["passthru_pct"] > 15]
    logger.info(f"✅ Parsed {len(records)} Exadata Smart IO rows"
                + (f" | HIGH passthru: {flushing_cells}" if flushing_cells else ""))
    return records


def insert_smart_io(records):
    """Insert Smart IO records into PostgreSQL."""
    if not records:
        logger.warning("⚠️  No Smart IO records to insert")
        return

    sql = """
        INSERT INTO awr_exadata_smart_io
            (dbname, instance, begin_snap, snap_time, cell_name,
             eligible_mbps, si_savings_mbps, flash_read_mbps, disk_read_mbps,
             passthru_mbps, col_cache_mbps, reverse_offload_mbps,
             passthru_pct, disk_pct, row_hash)
        VALUES (%s, %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s)
        ON CONFLICT (dbname, begin_snap, cell_name, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        cur  = conn.cursor()
        for r in records:
            cur.execute(sql, (
                r["dbname"], r["instance"], r["begin_snap"], r["snap_time"],
                r["cell_name"],
                r["eligible_mbps"], r["si_savings_mbps"],
                r["flash_read_mbps"], r["disk_read_mbps"],
                r["passthru_mbps"], r["col_cache_mbps"], r["reverse_offload_mbps"],
                r["passthru_pct"], r["disk_pct"], r["row_hash"],
            ))
        conn.commit()
        cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_smart_io")
    except Exception as e:
        logger.error(f"❌ Failed inserting Smart IO: {e}", exc_info=True)
    finally:
        if conn:
            conn.close()


def main(filepath):
    records = parse_smart_io(filepath)
    if records:
        insert_smart_io(records)


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if not _target:
        print("Usage: python exadata_smart_io_parser.py <awr_report.html>")
        sys.exit(1)
    records = parse_smart_io(_target)
    insert_smart_io(records)
