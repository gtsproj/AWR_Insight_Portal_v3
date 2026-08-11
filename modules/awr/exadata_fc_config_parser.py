# modules/awr/exadata_fc_config_parser.py
# ============================================================
# Parses the "Flash Cache Configuration" section of an
# Exadata AWR report.
#
# Stores per-cell Flash Cache status and size.
# CRITICAL alert when is_flushing = TRUE — that cell's Flash
# Cache is redirecting ALL client IOs to hard disk.
#
# Section header in AWR HTML:
#   <h3>Flash Cache Configuration</h3>
#
# Expected table columns (Oracle AWR output):
#   Name | Status | Size
#   or: Cell | Flash Cache Status | Flash Cache Size | Flash Log
#
# The parser is flexible — it probes for the most common
# column name variants used across Oracle Database versions.
#
# CALLED BY master_parser via main(filepath).
# Safe to run on non-Exadata AWR: section not found → 0 rows.
# ============================================================

import os
import sys
import warnings
import re
from io import StringIO

import pandas as pd
from bs4 import BeautifulSoup

warnings.simplefilter(action="ignore", category=FutureWarning)

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, "common"))

from db import get_db_connection
from utils import row_hash as make_row_hash, extract_workload_repo_metadata, clean_number, sanitize_record
from logger_utils import get_logger

logger = get_logger("exadata_fc_config_parser")

# ── Section heading variants (case-insensitive substring match) ────────────────
_SECTION_KEYWORDS = ["flash cache configuration"]


def _find_section(soup):
    """Return the <h3> tag for the Flash Cache Configuration section."""
    for tag in soup.find_all(["h2", "h3"]):
        text = tag.get_text(strip=True).lower()
        if any(kw in text for kw in _SECTION_KEYWORDS):
            return tag
    return None


def _col(df, *candidates):
    """Return the first matching column name (case-insensitive)."""
    lower_map = {c.lower(): c for c in df.columns}
    for name in candidates:
        if name.lower() in lower_map:
            return lower_map[name.lower()]
    return None


def _parse_size_gb(raw):
    """Convert size strings like '3,072 GB' or '512 MB' to GB float."""
    if raw is None or str(raw).strip() in ("", "nan", "--", "-"):
        return None
    s = str(raw).strip().upper()
    # Try to extract number and unit
    m = re.search(r"([\d,\.]+)\s*(GB|TB|MB)?", s)
    if not m:
        return None
    value = float(m.group(1).replace(",", ""))
    unit  = m.group(2) or "GB"
    if unit == "TB":
        return value * 1024
    if unit == "MB":
        return value / 1024
    return value  # GB


def _parse_fl_mb(raw):
    """Return flash log size in MB, or None if not configured (--)."""
    if raw is None or str(raw).strip() in ("", "nan", "--", "-", "N/A"):
        return None
    s = str(raw).strip().upper()
    m = re.search(r"([\d,\.]+)\s*(GB|TB|MB)?", s)
    if not m:
        return None
    value = float(m.group(1).replace(",", ""))
    unit  = m.group(2) or "MB"
    if unit == "GB":
        return value * 1024
    if unit == "TB":
        return value * 1024 * 1024
    return value


def parse_fc_config(filepath):
    """Parse Flash Cache Configuration from AWR HTML. Returns list of dicts."""
    records = []

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")

    meta = extract_workload_repo_metadata(soup)
    if not meta:
        logger.error("❌ Failed to extract workload repo metadata")
        return []

    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Flash Cache Configuration section not found — "
                       "non-Exadata or text-format AWR report")
        return []

    table = section.find_next("table")
    if not table:
        logger.warning("⚠️  Flash Cache Configuration table not found")
        return []

    df = pd.read_html(StringIO(str(table)))[0]
    if df.empty:
        logger.warning("⚠️  Flash Cache Configuration table is empty")
        return []

    # Map column names flexibly
    col_name   = _col(df, "Name", "Cell", "Cell Name", "Storage Cell")
    col_status = _col(df, "Status", "Flash Cache Status", "FC Status")
    col_size   = _col(df, "Size", "Flash Cache Size", "FC Size",
                       "Flash Cache Size (GB)", "FC Size (GB)")
    col_fl     = _col(df, "Flash Log", "Flash Log Size", "FL Size",
                       "Flash Log Size (MB)", "Smart Flash Log")

    if col_name is None or col_status is None:
        # Fall back to positional: col[0]=Name, col[1]=Status, col[2]=Size
        logger.info("ℹ️  Using positional column access for FC Config table")
        for _, row in df.iterrows():
            vals = list(row)
            cell_name  = str(vals[0]).strip() if len(vals) > 0 else None
            fc_status  = str(vals[1]).strip() if len(vals) > 1 else None
            size_raw   = str(vals[2]).strip() if len(vals) > 2 else None
            fl_raw     = str(vals[3]).strip() if len(vals) > 3 else None
            _append_record(records, meta, cell_name, fc_status, size_raw, fl_raw)
    else:
        for _, row in df.iterrows():
            cell_name = str(row.get(col_name, "")).strip()
            fc_status = str(row.get(col_status, "")).strip()
            size_raw  = str(row.get(col_size, "")) if col_size else None
            fl_raw    = str(row.get(col_fl,   "")) if col_fl   else None
            _append_record(records, meta, cell_name, fc_status, size_raw, fl_raw)

    logger.info(f"✅ Parsed {len(records)} Flash Cache Config rows "
                f"({sum(1 for r in records if r['is_flushing'])} cells flushing)")
    return records


def _append_record(records, meta, cell_name, fc_status, size_raw, fl_raw):
    """Build and append a single FC Config record."""
    if not cell_name or cell_name.lower() in ("nan", "name", "cell", "storage cell"):
        return
    fc_status = fc_status if fc_status and fc_status.lower() != "nan" else None
    is_flushing = bool(fc_status and "flushing" in fc_status.lower())
    fc_size_gb  = _parse_size_gb(size_raw)
    fl_size_mb  = _parse_fl_mb(fl_raw)

    rh = make_row_hash({
        "cell_name": cell_name,
        "fc_status": fc_status,
        "fc_size_gb": fc_size_gb,
    })

    records.append(sanitize_record({
        "dbname":     meta["dbname"],
        "instance":   meta["instance"],
        "begin_snap": meta["begin_snap"],
        "snap_time":  meta["snap_time"],
        "cell_name":  cell_name,
        "fc_status":  fc_status,
        "fc_size_gb": fc_size_gb,
        "fl_size_mb": fl_size_mb,
        "is_flushing": is_flushing,
        "row_hash":   rh,
    }))


def insert_fc_config(records):
    """Insert Flash Cache Config records into PostgreSQL."""
    if not records:
        logger.warning("⚠️  No Flash Cache Config records to insert")
        return

    sql = """
        INSERT INTO awr_exadata_fc_config
            (dbname, instance, begin_snap, snap_time,
             cell_name, fc_status, fc_size_gb, fl_size_mb,
             is_flushing, row_hash)
        VALUES (%s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s)
        ON CONFLICT (dbname, begin_snap, cell_name, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        cur  = conn.cursor()
        for r in records:
            cur.execute(sql, (
                r["dbname"], r["instance"], r["begin_snap"], r["snap_time"],
                r["cell_name"], r["fc_status"], r["fc_size_gb"], r["fl_size_mb"],
                r["is_flushing"], r["row_hash"],
            ))
        conn.commit()
        cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_fc_config")
    except Exception as e:
        logger.error(f"❌ Failed inserting FC Config: {e}", exc_info=True)
    finally:
        if conn:
            conn.close()


def main(filepath):
    records = parse_fc_config(filepath)
    if records:
        insert_fc_config(records)


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if not _target:
        print("Usage: python exadata_fc_config_parser.py <awr_report.html>")
        sys.exit(1)
    records = parse_fc_config(_target)
    insert_fc_config(records)
