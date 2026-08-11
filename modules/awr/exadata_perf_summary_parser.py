# modules/awr/exadata_perf_summary_parser.py
# ============================================================
# Parses the "Exadata Performance Summary" section of an
# Exadata AWR report.
#
# Captures two sub-sections:
#   1. Cache Savings  — where DB IOs are served from:
#        Flash Cache%, XRMEM Cache%, RDMA%, OLTP/Scan hit%
#   2. Disk Activity  — why reads go to disk:
#        read skips, write skips, scrub IO rate, miss count
#
# Section headers in AWR HTML (Oracle uses either):
#   <h3>Exadata Performance Summary</h3>
#   <h3>Performance Summary</h3>      ← Global AWR variant
#
# The section contains key-value style tables where col[0] is
# the metric name and col[1] is the value.  The parser handles
# both a single merged table and two separate sub-tables.
#
# CALLED BY master_parser via main(filepath).
# Safe to run on non-Exadata AWR: section not found → 0 rows.
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

logger = get_logger("exadata_perf_summary_parser")

# ── Section heading variants ──────────────────────────────────────────────────
_SECTION_KW  = ["exadata performance summary", "performance summary"]
# Sub-sections that contain the key metrics
_CACHE_KW    = ["cache savings", "cache hit", "cache efficiency"]
_DISK_KW     = ["disk activity", "disk io", "disk reason"]


def _find_section(soup):
    """Return the h3 tag for the Exadata Performance Summary section."""
    for tag in soup.find_all(["h2", "h3"]):
        txt = tag.get_text(strip=True).lower()
        if any(kw in txt for kw in _SECTION_KW):
            return tag
    return None


def _num(val):
    """Extract a float from strings like '30.73%', '3,072', 'N/A'."""
    if val is None:
        return None
    s = str(val).strip().replace(",", "").replace("%", "")
    if s.lower() in ("nan", "n/a", "--", "-", ""):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _scan_tables(soup, section_tag, max_tables=6):
    """Collect up to max_tables tables that immediately follow section_tag."""
    tables = []
    sibling = section_tag.find_next_sibling()
    while sibling and len(tables) < max_tables:
        tag_name = getattr(sibling, "name", None)
        if tag_name in ("h2",):          # stop at next major section
            break
        if tag_name == "table":
            try:
                dfs = pd.read_html(StringIO(str(sibling)))
                if dfs and not dfs[0].empty:
                    tables.append(dfs[0])
            except Exception:
                pass
        sibling = sibling.find_next_sibling()
    return tables


def _kv_from_df(df):
    """
    Build a {lowercase_metric_name: value} dict from a 2-column key-value
    DataFrame.  Works whether df uses positional integers or string columns.
    """
    kv = {}
    for _, row in df.iterrows():
        vals = list(row)
        if len(vals) < 2:
            continue
        key = str(vals[0]).strip().lower()
        val = vals[1]
        if key and key not in ("nan", "metric", "statistic", "description"):
            kv[key] = val
    return kv


def _get(kv, *candidates):
    """Return the first matching value from a kv dict (substring search)."""
    for cand in candidates:
        for k, v in kv.items():
            if cand.lower() in k:
                return v
    return None


def parse_perf_summary(filepath):
    """Parse Exadata Performance Summary. Returns list of 1 dict (system aggregate)."""
    records = []

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        soup = BeautifulSoup(f, "html.parser")

    meta = extract_workload_repo_metadata(soup)
    if not meta:
        logger.error("❌ Failed to extract workload repo metadata")
        return []

    section = _find_section(soup)
    if not section:
        logger.warning("⚠️  Exadata Performance Summary section not found")
        return []

    tables = _scan_tables(soup, section, max_tables=6)
    if not tables:
        logger.warning("⚠️  No tables found in Exadata Performance Summary")
        return []

    # Merge all kv pairs from all nearby tables
    merged_kv = {}
    for df in tables:
        merged_kv.update(_kv_from_df(df))

    if not merged_kv:
        logger.warning("⚠️  No key-value data extracted from Performance Summary tables")
        return []

    # ── Cache Savings metrics ──────────────────────────────────────────────
    fc_pct       = _num(_get(merged_kv,
                             "flash cache (% of database",
                             "% database ios serviced from flash",
                             "flash cache %",
                             "fc hit",
                             "flash cache ios"))
    xrmem_pct    = _num(_get(merged_kv,
                             "xrmem cache (% of database",
                             "% database ios serviced from xrmem",
                             "xrmem %",
                             "xrmem cache ios"))
    rdma_pct     = _num(_get(merged_kv,
                             "xrmem cache rdma",
                             "rdma (% of database",
                             "rdma reads %",
                             "via rdma"))
    fc_oltp_hit  = _num(_get(merged_kv,
                             "oltp hit",
                             "oltp read hit",
                             "flash cache oltp hit",
                             "oltp reads hit"))
    fc_scan_hit  = _num(_get(merged_kv,
                             "scan hit",
                             "scan read hit",
                             "flash cache scan hit",
                             "scan reads hit"))

    # ── Disk Activity metrics ──────────────────────────────────────────────
    fc_read_skip  = _num(_get(merged_kv,
                              "flash cache read skip",
                              "fc read skip",
                              "reads bypassing flash cache",
                              "read skips"))
    fc_write_skip = _num(_get(merged_kv,
                              "flash cache write skip",
                              "fc write skip",
                              "writes bypassing flash cache",
                              "write skips"))
    scrub_mbps    = _num(_get(merged_kv,
                              "scrub io",
                              "scrub mb",
                              "disk scrub"))
    fc_read_miss  = _num(_get(merged_kv,
                              "read miss",
                              "flash cache miss",
                              "miss count",
                              "misses"))

    rh = make_row_hash({
        "fc_pct": fc_pct,
        "xrmem_pct": xrmem_pct,
        "fc_read_skip": fc_read_skip,
    })

    records.append(sanitize_record({
        "dbname":           meta["dbname"],
        "instance":         meta["instance"],
        "begin_snap":       meta["begin_snap"],
        "snap_time":        meta["snap_time"],
        "fc_pct_of_db_ios": fc_pct,
        "xrmem_pct_of_db_ios": xrmem_pct,
        "rdma_pct_of_db_ios":  rdma_pct,
        "fc_hit_oltp_pct":  fc_oltp_hit,
        "fc_hit_scan_pct":  fc_scan_hit,
        "fc_read_skip_count": int(fc_read_skip) if fc_read_skip is not None else None,
        "fc_write_skip_count": int(fc_write_skip) if fc_write_skip is not None else None,
        "scrub_io_mbps":    scrub_mbps,
        "fc_read_miss_count": int(fc_read_miss) if fc_read_miss is not None else None,
        "row_hash":         rh,
    }))

    non_none = sum(1 for v in records[0].values() if v is not None)
    logger.info(f"✅ Parsed Exadata Performance Summary "
                f"(FC%={fc_pct}, XRMEM%={xrmem_pct}, OLTP_hit={fc_oltp_hit}%, "
                f"Scan_hit={fc_scan_hit}%, read_skips={fc_read_skip})")
    return records


def insert_perf_summary(records):
    """Insert Performance Summary record into PostgreSQL."""
    if not records:
        logger.warning("⚠️  No Exadata Performance Summary records to insert")
        return

    sql = """
        INSERT INTO awr_exadata_perf_summary
            (dbname, instance, begin_snap, snap_time,
             fc_pct_of_db_ios, xrmem_pct_of_db_ios, rdma_pct_of_db_ios,
             fc_hit_oltp_pct, fc_hit_scan_pct,
             fc_read_skip_count, fc_write_skip_count,
             scrub_io_mbps, fc_read_miss_count, row_hash)
        VALUES (%s, %s, %s, %s,
                %s, %s, %s,
                %s, %s,
                %s, %s,
                %s, %s, %s)
        ON CONFLICT (dbname, begin_snap, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        cur  = conn.cursor()
        for r in records:
            cur.execute(sql, (
                r["dbname"], r["instance"], r["begin_snap"], r["snap_time"],
                r["fc_pct_of_db_ios"], r["xrmem_pct_of_db_ios"], r["rdma_pct_of_db_ios"],
                r["fc_hit_oltp_pct"], r["fc_hit_scan_pct"],
                r["fc_read_skip_count"], r["fc_write_skip_count"],
                r["scrub_io_mbps"], r["fc_read_miss_count"], r["row_hash"],
            ))
        conn.commit()
        cur.close()
        logger.info(f"✅ Inserted {len(records)} rows into awr_exadata_perf_summary")
    except Exception as e:
        logger.error(f"❌ Failed inserting Exadata Performance Summary: {e}", exc_info=True)
    finally:
        if conn:
            conn.close()


def main(filepath):
    records = parse_perf_summary(filepath)
    if records:
        insert_perf_summary(records)


if __name__ == "__main__":
    _target = globals().get("filepath") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if not _target:
        print("Usage: python exadata_perf_summary_parser.py <awr_report.html>")
        sys.exit(1)
    records = parse_perf_summary(_target)
    insert_perf_summary(records)
