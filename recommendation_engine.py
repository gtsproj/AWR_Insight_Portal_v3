# recommendation_engine.py
# ============================================================
# AWR Insight Portal — Recommendation Engine v2
#
# Evaluates 60+ rules against parsed AWR/SAR metrics and
# returns ranked, severity-weighted recommendations.
#
# Three operating modes (set via settings.yaml ai.mode):
#   rules  — deterministic rule engine only (default, ~75% accuracy)
#   local  — Ollama local LLM supplements rule output
#   cloud  — Anthropic API supplements rule output
#
# The rule engine always runs first. AI modes add narrative
# analysis on top of rule findings, they don't replace rules.
#
# USAGE:
#   from recommendation_engine import RecommendationEngine
#   engine = RecommendationEngine()
#   results = engine.evaluate(dbname="COLDBPRD", begin_snap=100, end_snap=110)
#
# API endpoint (called by FastAPI portal):
#   python recommendation_engine.py --db COLDBPRD --start 100 --end 110
# ============================================================

import os
import sys
import json
import re
import argparse
from typing import Optional

_PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, "common"))

from config_loader import load_config
from db import get_db_connection
from logger_utils import get_logger

logger = get_logger("recommendation_engine")

# ── config ──────────────────────────────────────────────────────────
_cfg      = load_config()
_ai_cfg   = _cfg.get("ai", {})
AI_MODE   = _ai_cfg.get("mode", "rules")
RULES_FILE = os.path.join(
    _PROJECT_ROOT,
    _ai_cfg.get("rules", {}).get("rules_file", "rules/recommendation_rules_v2.json")
)
MIN_SEVERITY = _ai_cfg.get("rules", {}).get("min_severity_to_show", "medium")

SEVERITY_RANK = {"low": 1, "medium": 2, "high": 3, "critical": 4}
MIN_RANK      = SEVERITY_RANK.get(MIN_SEVERITY.lower(), 2)


# ── load rules ────────────────────────────────────────────────────────
def _load_rules() -> list:
    """Load and parse the rules JSON file. Strips JS-style // comments."""
    try:
        with open(RULES_FILE, "r", encoding="utf-8") as f:
            raw = f.read()
        # Strip single-line // comments (not valid JSON but used for readability)
        cleaned = re.sub(r"//[^\n]*", "", raw)
        data = json.loads(cleaned)
        rules = data.get("rules", [])
        logger.info(f"Loaded {len(rules)} recommendation rules from {RULES_FILE}")
        return rules
    except Exception as e:
        logger.error(f"Failed to load rules from {RULES_FILE}: {e}")
        return []


# ── metric fetchers ───────────────────────────────────────────────────
def _fetch_wait_metrics(conn, dbname: str, begin_snap: int, end_snap: int) -> list:
    """Fetch foreground wait event metrics for the snap range."""
    sql = """
        SELECT event AS event_name, avg(pct_db_time) AS pct_db_time,
               avg(avg_wait_ms) AS avg_wait_ms,
               sum(waits) AS total_waits
        FROM awr_foreground_wait_events
        WHERE dbname = %s
          AND begin_snap BETWEEN %s AND %s
        GROUP BY event
        ORDER BY pct_db_time DESC NULLS LAST
        LIMIT 30
    """
    try:
        with conn.cursor() as cur:
            cur.execute(sql, (dbname, begin_snap, end_snap))
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]
    except Exception as e:
        logger.warning(f"Wait metrics fetch failed: {e}")
        return []


def _fetch_sql_metrics(conn, dbname: str, begin_snap: int, end_snap: int) -> dict:
    """
    Fetch SQL performance metrics aggregated by sql_id.
    Elapsed + parse metrics from awr_sql_elapsed_time.
    CPU metrics from awr_sql_cpu_time (separate table, LEFT JOINed).
    """
    # ── Step 1: elapsed time + executions from awr_sql_elapsed_time ──
    sql_elapsed = """
        SELECT sql_id,
               avg(elapsed_time_per_exec_s) AS elapsed_time_s,
               avg(executions)              AS executions
        FROM awr_sql_elapsed_time
        WHERE dbname = %s AND begin_snap BETWEEN %s AND %s
        GROUP BY sql_id
        ORDER BY elapsed_time_s DESC NULLS LAST
        LIMIT 20
    """
    # ── Step 2: CPU time from awr_sql_cpu_time ─────────────────────
    sql_cpu = """
        SELECT sql_id,
               avg(cpu_per_exec_s) AS cpu_time_s
        FROM awr_sql_cpu_time
        WHERE dbname = %s AND begin_snap BETWEEN %s AND %s
        GROUP BY sql_id
    """
    # ── Step 3: parse calls from awr_sql_parsed_calls ──────────────
    sql_parse = """
        SELECT sql_id,
               sum(parse_calls) AS parse_calls
        FROM awr_sql_parsed_calls
        WHERE dbname = %s AND begin_snap BETWEEN %s AND %s
        GROUP BY sql_id
    """
    results = {"top_elapsed": [], "high_parse": [], "high_cpu": []}
    try:
        with conn.cursor() as cur:
            cur.execute(sql_elapsed, (dbname, begin_snap, end_snap))
            cols = [d[0] for d in cur.description]
            rows = {r[0]: dict(zip(cols, r)) for r in cur.fetchall()}  # keyed by sql_id

        try:
            with conn.cursor() as cur:
                cur.execute(sql_cpu, (dbname, begin_snap, end_snap))
                for r in cur.fetchall():
                    if r[0] in rows:
                        rows[r[0]]["cpu_time_s"] = float(r[1] or 0)
        except Exception as e:
            conn.rollback()
            logger.warning(f"SQL CPU metrics fetch failed: {e}")

        try:
            with conn.cursor() as cur:
                cur.execute(sql_parse, (dbname, begin_snap, end_snap))
                for r in cur.fetchall():
                    if r[0] in rows:
                        rows[r[0]]["parse_calls"] = float(r[1] or 0)
        except Exception as e:
            conn.rollback()
            logger.warning(f"SQL parse metrics fetch failed: {e}")

        for r in rows.values():
            elapsed = float(r.get("elapsed_time_s") or 0)
            cpu     = float(r.get("cpu_time_s") or 0)
            execs   = float(r.get("executions") or 1)
            parses  = float(r.get("parse_calls") or 0)

            if elapsed > 60:
                results["top_elapsed"].append(r)
            if cpu > 30:
                results["high_cpu"].append(r)
            if execs > 0 and (parses / execs) > 0.8 and parses > 1000:
                results["high_parse"].append(r)

    except Exception as e:
        conn.rollback()
        logger.warning(f"SQL metrics fetch failed: {e}")
    return results


def _fetch_instance_efficiency(conn, dbname: str, begin_snap: int, end_snap: int) -> dict:
    """Fetch instance efficiency ratios."""
    sql = """
        SELECT metric, avg(value) AS value
        FROM awr_instance_efficiency
        WHERE dbname = %s AND begin_snap BETWEEN %s AND %s
        GROUP BY metric
    """
    result = {}
    try:
        with conn.cursor() as cur:
            cur.execute(sql, (dbname, begin_snap, end_snap))
            for row in cur.fetchall():
                result[row[0]] = row[1]
    except Exception as e:
        logger.warning(f"Instance efficiency fetch failed: {e}")
    return result


def _fetch_object_metadata(conn, dbname: str, owner_object_pairs: list) -> dict:
    """
    Fetch awr_object_metadata for a list of (owner, object_name) pairs.
    Returns a dict keyed by 'OWNER.OBJECT_NAME' for fast lookup.
    Used to enrich segment rule findings with structural context
    (num_rows, partitioned, index_type, blevel, clustering_factor, last_analyzed).
    Falls back silently if the table is missing or the query fails.
    """
    if not owner_object_pairs:
        return {}
    result = {}
    try:
        with conn.cursor() as cur:
            for owner, object_name in owner_object_pairs:
                try:
                    cur.execute("""
                        SELECT object_type, num_rows, blocks, avg_row_len,
                               last_analyzed, partitioned, compression,
                               index_type, uniqueness, blevel, leaf_blocks,
                               distinct_keys, clustering_factor, partition_type,
                               partition_count, status
                        FROM awr_object_metadata
                        WHERE dbname = %s
                          AND UPPER(owner) = UPPER(%s)
                          AND UPPER(object_name) = UPPER(%s)
                        ORDER BY uploaded_at DESC
                        LIMIT 1
                    """, (dbname, owner, object_name))
                    row = cur.fetchone()
                    if row:
                        cols = ["object_type", "num_rows", "blocks", "avg_row_len",
                                "last_analyzed", "partitioned", "compression",
                                "index_type", "uniqueness", "blevel", "leaf_blocks",
                                "distinct_keys", "clustering_factor", "partition_type",
                                "partition_count", "status"]
                        meta = dict(zip(cols, row))
                        # Normalise numeric fields to float for rule conditions
                        for f in ("num_rows", "blocks", "avg_row_len", "blevel",
                                  "leaf_blocks", "distinct_keys", "clustering_factor",
                                  "partition_count"):
                            if meta.get(f) is not None:
                                meta[f] = float(meta[f])
                        key = f"{owner.upper()}.{object_name.upper()}"
                        result[key] = meta
                except Exception:
                    pass
    except Exception as e:
        logger.debug(f"Object metadata fetch skipped: {e}")
    return result


def _fetch_segment_metrics(conn, dbname: str, begin_snap: int, end_snap: int) -> dict:
    """Fetch top segment metrics across all segment tables."""
    metrics = {}
    tables = {
        "logical_reads":    ("awr_seg_logical_reads",     "logical_reads",      "pcttotal"),
        "physical_reads":   ("awr_seg_phy_reads",         "physical_reads",     "pcttotal"),
        "buffer_busy":      ("awr_seg_buff_busy_waits",   "buffer_busy_waits",  "pct_of_capture"),
        "row_lock_waits":   ("awr_seg_row_lck_waits",     "row_lock_waits",     "pct_of_capture"),
        "itl_waits":        ("awr_seg_itl_waits",         "itl_waits",          "pct_of_capture"),
        "table_scans":      ("awr_seg_table_scan",         "table_scans",        "pcttotal"),
        "gc_buffer_busy":   ("awr_seg_gbl_cache_buff_busy", "gc_buffer_busy",   "pct_of_capture"),
    }
    for key, (table, metric_col, pct_col) in tables.items():
        try:
            sql = f"""
                SELECT owner, object_name, obj_type,
                       SUM({metric_col}) AS metric_value,
                       AVG({pct_col}) AS pct_value
                FROM {table}
                WHERE dbname = %s AND begin_snap BETWEEN %s AND %s
                GROUP BY owner, object_name, obj_type
                ORDER BY metric_value DESC NULLS LAST
                LIMIT 5
            """
            with conn.cursor() as cur:
                cur.execute(sql, (dbname, begin_snap, end_snap))
                cols = [d[0] for d in cur.description]
                metrics[key] = [dict(zip(cols, row)) for row in cur.fetchall()]
        except Exception as e:
            logger.debug(f"Segment fetch for {table} failed: {e}")
            metrics[key] = []
    return metrics


# ── rule evaluator ────────────────────────────────────────────────────
def _fetch_exadata_metrics(conn, dbname: str, begin_snap: int, end_snap: int) -> dict:
    """
    Fetch Exadata-specific metrics for the snap range.
    Returns a dict with keys: fc_config, perf_summary, smart_io, fc_reads.
    Returns empty structures if no Exadata data is present (non-Exadata AWR).
    """
    metrics = {
        "fc_config":    [],   # list of {cell_name, fc_status, is_flushing, fc_size_gb}
        "perf_summary": {},   # {fc_pct, xrmem_pct, fc_hit_oltp_pct, fc_hit_scan_pct, ...}
        "smart_io":     [],   # list of {cell_name, eligible_mbps, disk_pct, passthru_pct, ...}
        "fc_reads":     [],   # list of {cell_name, io_type, hit_pct, req_per_sec, ...}
    }

    try:
        cur = conn.cursor()

        # Flash Cache Configuration — detect flushing cells
        cur.execute("""
            SELECT cell_name, fc_status, is_flushing, fc_size_gb, fl_size_mb
            FROM awr_exadata_fc_config
            WHERE dbname = %s AND begin_snap BETWEEN %s AND %s
            ORDER BY cell_name
        """, (dbname, begin_snap, end_snap))
        metrics["fc_config"] = [
            {"cell_name": r[0], "fc_status": r[1], "is_flushing": r[2],
             "fc_size_gb": r[3], "fl_size_mb": r[4]}
            for r in cur.fetchall()
        ]

        # Performance Summary — system-wide cache efficiency
        cur.execute("""
            SELECT fc_pct_of_db_ios, xrmem_pct_of_db_ios, rdma_pct_of_db_ios,
                   fc_hit_oltp_pct, fc_hit_scan_pct,
                   fc_read_skip_count, fc_write_skip_count, fc_read_miss_count
            FROM awr_exadata_perf_summary
            WHERE dbname = %s AND begin_snap BETWEEN %s AND %s
            ORDER BY begin_snap DESC
            LIMIT 1
        """, (dbname, begin_snap, end_snap))
        row = cur.fetchone()
        if row:
            metrics["perf_summary"] = {
                "fc_pct":         float(row[0] or 0),
                "xrmem_pct":      float(row[1] or 0),
                "rdma_pct":       float(row[2] or 0),
                "fc_hit_oltp_pct": float(row[3] or 0),
                "fc_hit_scan_pct": float(row[4] or 0),
                "fc_read_skip_count":  int(row[5] or 0),
                "fc_write_skip_count": int(row[6] or 0),
                "fc_read_miss_count":  int(row[7] or 0),
            }

        # Smart IO — per-cell Smart Scan efficiency
        cur.execute("""
            SELECT cell_name, eligible_mbps, si_savings_mbps,
                   flash_read_mbps, disk_read_mbps,
                   passthru_mbps, passthru_pct, disk_pct
            FROM awr_exadata_smart_io
            WHERE dbname = %s AND begin_snap BETWEEN %s AND %s
            ORDER BY cell_name
        """, (dbname, begin_snap, end_snap))
        metrics["smart_io"] = [
            {"cell_name":     r[0],
             "eligible_mbps": float(r[1] or 0),
             "si_savings_mbps": float(r[2] or 0),
             "flash_read_mbps": float(r[3] or 0),
             "disk_read_mbps":  float(r[4] or 0),
             "passthru_mbps":   float(r[5] or 0),
             "passthru_pct":    float(r[6] or 0) if r[6] is not None else None,
             "disk_pct":        float(r[7] or 0) if r[7] is not None else None}
            for r in cur.fetchall()
        ]

        # Flash Cache User Reads — per-cell hit% by IO type
        cur.execute("""
            SELECT cell_name, io_type, req_per_sec, miss_per_sec, hit_pct, skip_count
            FROM awr_exadata_fc_reads
            WHERE dbname = %s AND begin_snap BETWEEN %s AND %s
            ORDER BY cell_name, io_type
        """, (dbname, begin_snap, end_snap))
        metrics["fc_reads"] = [
            {"cell_name":   r[0], "io_type":     r[1],
             "req_per_sec": float(r[2] or 0),
             "miss_per_sec": float(r[3] or 0),
             "hit_pct":     float(r[4] or 0) if r[4] is not None else None,
             "skip_count":  int(r[5] or 0)}
            for r in cur.fetchall()
        ]
        cur.close()

    except Exception as e:
        logger.warning(f"Exadata metrics fetch error (non-Exadata DB?): {e}")

    # ── Wave 2: Top DB, Cell IOStat, IO Reasons, FC Space, Cell Server ─────
    metrics["top_db"]      = []
    metrics["cell_iostat"] = []
    metrics["io_reasons"]  = []
    metrics["fc_space"]    = []
    metrics["cell_server"] = []
    try:
        cur = conn.cursor()

        cur.execute("""SELECT target_dbname,flash_req_pct,disk_req_pct,
                              small_avg_lat_ms,large_avg_lat_ms,iorm_queue_ms,total_req
                       FROM awr_exadata_top_db
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s
                       ORDER BY iorm_queue_ms DESC NULLS LAST""",
                    (dbname, begin_snap, end_snap))
        metrics["top_db"] = [
            {"target_db":r[0],"flash_req_pct":float(r[1] or 0),
             "disk_req_pct":float(r[2] or 0),
             "small_avg_lat_ms":float(r[3] or 0),"large_avg_lat_ms":float(r[4] or 0),
             "iorm_queue_ms":float(r[5] or 0),"total_req":int(r[6] or 0)}
            for r in cur.fetchall()]

        cur.execute("""SELECT cell_name,device_type,iops,throughput_mbps,
                              util_pct,service_ms,queue_ms,is_outlier,at_max_capacity
                       FROM awr_exadata_cell_iostat
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s""",
                    (dbname, begin_snap, end_snap))
        metrics["cell_iostat"] = [
            {"cell_name":r[0],"device_type":r[1],
             "iops":float(r[2] or 0),"throughput_mbps":float(r[3] or 0),
             "util_pct":float(r[4] or 0),"service_ms":float(r[5] or 0),
             "queue_ms":float(r[6] or 0),"is_outlier":bool(r[7]),
             "at_max_capacity":bool(r[8])}
            for r in cur.fetchall()]

        cur.execute("""SELECT cell_name,reason,small_req,large_req,
                              total_req,total_mb,pct_of_total_req
                       FROM awr_exadata_io_reasons
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s
                         AND cell_name='All'
                       ORDER BY total_req DESC NULLS LAST""",
                    (dbname, begin_snap, end_snap))
        metrics["io_reasons"] = [
            {"cell_name":r[0],"reason":r[1],
             "small_req":int(r[2] or 0),"large_req":int(r[3] or 0),
             "total_req":int(r[4] or 0),"total_mb":float(r[5] or 0),
             "pct_of_total_req":float(r[6] or 0) if r[6] else None}
            for r in cur.fetchall()]

        cur.execute("""SELECT cell_name,total_fc_mb,oltp_used_mb,scan_used_mb,
                              large_write_mb,large_write_pct,free_mb
                       FROM awr_exadata_fc_space
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s""",
                    (dbname, begin_snap, end_snap))
        metrics["fc_space"] = [
            {"cell_name":r[0],"total_fc_mb":float(r[1] or 0),
             "oltp_used_mb":float(r[2] or 0),"scan_used_mb":float(r[3] or 0),
             "large_write_mb":float(r[4] or 0),
             "large_write_pct":float(r[5] or 0) if r[5] is not None else None,
             "free_mb":float(r[6] or 0)}
            for r in cur.fetchall()]

        cur.execute("""SELECT cell_name,small_read_iops,large_write_iops,
                              total_iops,large_write_pct_iops
                       FROM awr_exadata_cell_server
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s""",
                    (dbname, begin_snap, end_snap))
        metrics["cell_server"] = [
            {"cell_name":r[0],"small_read_iops":float(r[1] or 0),
             "large_write_iops":float(r[2] or 0),"total_iops":float(r[3] or 0),
             "large_write_pct_iops":float(r[4] or 0) if r[4] is not None else None}
            for r in cur.fetchall()]
        cur.close()
    except Exception as e2:
        logger.warning(f"Wave 2 Exadata fetch error: {e2}")

    # ── Wave 3: FC Writes, Write Rejections, Config, Disk IOStat, Internal IO ─
    metrics["fc_writes"]      = []
    metrics["write_rejects"]  = []
    metrics["exa_config"]     = []
    metrics["disk_iostat"]    = []
    metrics["int_io_reasons"] = []
    try:
        cur = conn.cursor()
        cur.execute("""SELECT cell_name,write_type,total_writes,partial_writes,
                              absorbed_writes,rejected_writes,skip_count,partial_write_pct
                       FROM awr_exadata_fc_writes
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s""",
                    (dbname,begin_snap,end_snap))
        metrics["fc_writes"]=[{"cell_name":r[0],"write_type":r[1],
            "total_writes":int(r[2] or 0),"partial_writes":int(r[3] or 0),
            "absorbed_writes":int(r[4] or 0),"rejected_writes":int(r[5] or 0),
            "skip_count":int(r[6] or 0),
            "partial_write_pct":float(r[7] or 0) if r[7] else None}
            for r in cur.fetchall()]
        cur.execute("""SELECT cell_name,reason,rejection_count,rejection_pct
                       FROM awr_exadata_fc_write_reject
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s""",
                    (dbname,begin_snap,end_snap))
        metrics["write_rejects"]=[{"cell_name":r[0],"reason":r[1],
            "rejection_count":int(r[2] or 0),
            "rejection_pct":float(r[3] or 0) if r[3] else None}
            for r in cur.fetchall() if r[2] and int(r[2])>0]
        cur.execute("""SELECT cell_name,model,flash_cache_mb,flash_log_mb,has_flash_log
                       FROM awr_exadata_config
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s""",
                    (dbname,begin_snap,end_snap))
        metrics["exa_config"]=[{"cell_name":r[0],"model":r[1],
            "flash_cache_mb":float(r[2] or 0),"flash_log_mb":float(r[3] or 0) if r[3] else None,
            "has_flash_log":bool(r[4])}
            for r in cur.fetchall()]
        cur.execute("""SELECT cell_name,disk_name,iops,util_pct,is_outlier,at_max_capacity
                       FROM awr_exadata_disk_iostat
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s""",
                    (dbname,begin_snap,end_snap))
        metrics["disk_iostat"]=[{"cell_name":r[0],"disk_name":r[1],
            "iops":float(r[2] or 0),"util_pct":float(r[3] or 0),
            "is_outlier":bool(r[4]),"at_max_capacity":bool(r[5])}
            for r in cur.fetchall()]
        cur.execute("""SELECT cell_name,internal_reason,req_count,pct_of_internal
                       FROM awr_exadata_io_reasons_internal
                       WHERE dbname=%s AND begin_snap BETWEEN %s AND %s""",
                    (dbname,begin_snap,end_snap))
        metrics["int_io_reasons"]=[{"cell_name":r[0],"internal_reason":r[1],
            "req_count":int(r[2] or 0),
            "pct_of_internal":float(r[3] or 0) if r[3] else None}
            for r in cur.fetchall()]
        cur.close()
    except Exception as e3:
        logger.warning(f"Wave 3 Exadata fetch error: {e3}")

    # Wave 3: FC Writes, Config, Disk IOStat, FC Internal
    metrics["fc_writes"] = []
    metrics["fc_write_reject"] = []
    metrics["exadata_config"] = []
    metrics["disk_iostat"] = []
    metrics["fc_internal"] = []
    try:
        cur2 = conn.cursor()
        cur2.execute(
            "SELECT cell_name,write_section,total_write_reqs,partial_writes,"
            "rejected_writes,partial_write_pct,large_write_count,large_write_type "
            "FROM awr_exadata_fc_writes WHERE dbname=%s AND begin_snap BETWEEN %s AND %s",
            (dbname, begin_snap, end_snap))
        metrics["fc_writes"] = [
            {"cell_name":r[0],"write_section":r[1],"total_write_reqs":int(r[2] or 0),
             "partial_writes":int(r[3] or 0),"rejected_writes":int(r[4] or 0),
             "partial_write_pct":float(r[5] or 0),"large_write_count":int(r[6] or 0),
             "large_write_type":r[7]} for r in cur2.fetchall()]
        cur2.execute(
            "SELECT cell_name,reason,rejection_count,rejection_pct "
            "FROM awr_exadata_fc_write_reject WHERE dbname=%s AND begin_snap BETWEEN %s AND %s",
            (dbname, begin_snap, end_snap))
        metrics["fc_write_reject"] = [
            {"cell_name":r[0],"reason":r[1],"rejection_count":int(r[2] or 0),
             "rejection_pct":float(r[3] or 0)} for r in cur2.fetchall()]
        cur2.execute(
            "SELECT cell_name,model,flash_cache_mb,flash_log_mb,cell_disks,grid_disks,has_flash_log "
            "FROM awr_exadata_config WHERE dbname=%s AND begin_snap BETWEEN %s AND %s",
            (dbname, begin_snap, end_snap))
        metrics["exadata_config"] = [
            {"cell_name":r[0],"model":r[1],"flash_cache_mb":float(r[2] or 0),
             "flash_log_mb":float(r[3] or 0) if r[3] else None,"has_flash_log":bool(r[6])}
            for r in cur2.fetchall()]
        cur2.execute(
            "SELECT cell_name,device_type,iops,util_pct,is_outlier "
            "FROM awr_exadata_disk_iostat WHERE dbname=%s AND begin_snap BETWEEN %s AND %s",
            (dbname, begin_snap, end_snap))
        metrics["disk_iostat"] = [
            {"cell_name":r[0],"device_type":r[1],"iops":float(r[2] or 0),
             "util_pct":float(r[3] or 0),"is_outlier":bool(r[4])} for r in cur2.fetchall()]
        cur2.execute(
            "SELECT cell_name,io_direction,request_count,io_type "
            "FROM awr_exadata_fc_internal WHERE dbname=%s AND begin_snap BETWEEN %s AND %s",
            (dbname, begin_snap, end_snap))
        metrics["fc_internal"] = [
            {"cell_name":r[0],"io_direction":r[1],"request_count":int(r[2] or 0),"io_type":r[3]}
            for r in cur2.fetchall()]
        cur2.close()
    except Exception as e3:
        logger.warning(f"Wave 3 Exadata fetch error: {e3}")

    flushing = sum(1 for c in metrics["fc_config"] if c.get("is_flushing"))
    logger.info(f"Exadata metrics: {len(metrics['fc_config'])} cells, "
                f"{flushing} flushing, {len(metrics['smart_io'])} smart_io rows, "
                f"{len(metrics['fc_reads'])} fc_reads rows, "
                f"top_db={len(metrics['top_db'])}, cell_iostat={len(metrics['cell_iostat'])}, "
                f"io_reasons={len(metrics['io_reasons'])}, fc_space={len(metrics['fc_space'])}, "
                f"cell_server={len(metrics['cell_server'])}")
    return metrics


class RuleEngine:
    """
    Evaluates rules against a dict of current metric values.
    Conditions are expressed as simple Python-evaluatable expressions.
    """

    SAFE_GLOBALS = {"__builtins__": {}}

    def __init__(self, rules: list):
        self.rules = rules

    def evaluate_condition(self, condition: str, context: dict) -> bool:
        """
        Safely evaluate a condition string like 'pct_db_time > 15 OR avg_wait_ms > 10'
        against a context dict of current metric values.
        Returns True if condition is met.
        """
        if not condition:
            return False
        try:
            # Replace boolean operators to Python equivalents
            expr = condition.replace(" AND ", " and ").replace(" OR ", " or ")
            return bool(eval(expr, self.SAFE_GLOBALS, context))
        except Exception:
            return False

    def match_wait_event(self, rule: dict, wait_event: dict) -> bool:
        """Check if a wait event matches a rule's event_pattern."""
        pattern = rule.get("event_pattern", "*")
        event   = (wait_event.get("event_name") or "").lower()

        if pattern == "*":
            return True
        if "*" in pattern:
            # Simple wildcard match
            prefix = pattern.split("*")[0].lower()
            return event.startswith(prefix)
        return event == pattern.lower()

    def evaluate_wait_rules(self, wait_metrics: list) -> list:
        findings = []
        wait_rules = [r for r in self.rules if r.get("category") == "wait"]

        for event in wait_metrics:
            context = {
                "pct_db_time":  float(event.get("pct_db_time") or 0),
                "avg_wait_ms":  float(event.get("avg_wait_ms") or 0),
                "total_waits":  float(event.get("total_waits") or 0),
            }

            matched_rules = [r for r in wait_rules if self.match_wait_event(r, event)]
            for rule in matched_rules:
                if self.evaluate_condition(rule.get("condition", ""), context):
                    findings.append({
                        "rule_id":      rule["rule_id"],
                        "category":     "wait",
                        "severity":     rule.get("severity", "medium"),
                        "title":        rule.get("title", ""),
                        "event":        event.get("event_name"),
                        "pct_db_time":  context["pct_db_time"],
                        "avg_wait_ms":  context["avg_wait_ms"],
                        "root_cause":   rule.get("root_cause", ""),
                        "resolution":   rule.get("resolution_steps", []),
                        "diagnostic_sql": rule.get("diagnostic_sql", []),
                        "related_rules":  rule.get("related_rules", []),
                    })
                    break   # Don't double-fire specific + wildcard for same event

        return findings

    def evaluate_sql_rules(self, sql_metrics: dict) -> list:
        findings = []
        sql_rules = [r for r in self.rules if r.get("category") == "sql"]

        mappings = [
            ("high_elapsed_time", "top_elapsed",  {"elapsed_time_s": "elapsed_time_s", "executions": "executions"}),
            ("high_cpu",          "high_cpu",     {"cpu_time_s": "cpu_time_s", "executions": "executions"}),
            ("high_parse_calls",  "high_parse",   {"parse_calls": "parse_calls", "executions": "executions"}),
        ]

        for pattern_key, metric_key, field_map in mappings:
            items = sql_metrics.get(metric_key, [])
            if not items:
                continue
            rule = next((r for r in sql_rules
                         if r.get("event_pattern") == pattern_key), None)
            if not rule:
                continue

            for item in items[:5]:   # Top 5 per category
                context = {k: float(item.get(v) or 0) for k, v in field_map.items()}
                context["parse_calls_pct"] = (
                    context.get("parse_calls", 0) / max(context.get("executions", 1), 1) * 100
                )
                if self.evaluate_condition(rule.get("condition", ""), context):
                    findings.append({
                        "rule_id":       rule["rule_id"],
                        "category":      "sql",
                        "severity":      rule.get("severity", "medium"),
                        "title":         rule.get("title", ""),
                        "sql_id":        item.get("sql_id"),
                        "metrics":       context,
                        "root_cause":    rule.get("root_cause", ""),
                        "resolution":    rule.get("resolution_steps", []),
                        "diagnostic_sql": rule.get("diagnostic_sql", []),
                        "related_rules": rule.get("related_rules", []),
                    })

        return findings

    def evaluate_efficiency_rules(self, efficiency: dict) -> list:
        findings = []
        eff_rules = [r for r in self.rules if r.get("category") == "instance_efficiency"]

        pattern_to_metric = {
            "buffer_cache_hit_ratio": ["Buffer Cache Hit Ratio", "Buffer Nowait %"],
            "soft_parse_ratio":       ["Soft Parse %"],
            "library_cache_hit_ratio":["Library Cache Hit Ratio", "Library Hit %"],
            "execute_to_parse_ratio": ["Execute to Parse %"],
        }

        for rule in eff_rules:
            pattern  = rule.get("event_pattern", "")
            metrics  = pattern_to_metric.get(pattern, [pattern])
            value    = None
            for m in metrics:
                if m in efficiency:
                    value = float(efficiency[m] or 0)
                    break
            if value is None:
                continue
            context = {"value": value}
            if self.evaluate_condition(rule.get("condition", ""), context):
                findings.append({
                    "rule_id":      rule["rule_id"],
                    "category":     "instance_efficiency",
                    "severity":     rule.get("severity", "medium"),
                    "title":        rule.get("title", ""),
                    "metric":       pattern,
                    "value":        value,
                    "root_cause":   rule.get("root_cause", ""),
                    "resolution":   rule.get("resolution_steps", []),
                    "diagnostic_sql": rule.get("diagnostic_sql", []),
                    "related_rules":  rule.get("related_rules", []),
                })

        return findings

    def evaluate_segment_rules(self, segment_metrics: dict, object_metadata: dict = None) -> list:
        findings = []
        seg_rules = [r for r in self.rules if r.get("category") == "segment"]
        object_metadata = object_metadata or {}

        pattern_to_key = {
            "high_logical_reads":    "logical_reads",
            "high_physical_reads":   "physical_reads",
            "high_table_scans":      "table_scans",
            "high_row_lock_waits":   "row_lock_waits",
            "high_gc_buffer_busy":   "gc_buffer_busy",
        }

        for rule in seg_rules:
            pattern   = rule.get("event_pattern", "")
            metric_key = pattern_to_key.get(pattern)
            if not metric_key:
                continue
            items = segment_metrics.get(metric_key, [])
            for item in items[:3]:
                # Base numeric metrics
                context = {
                    "logical_reads":   float(item.get("metric_value") or 0),
                    "physical_reads":  float(item.get("metric_value") or 0),
                    "table_scans":     float(item.get("metric_value") or 0),
                    "row_lock_waits":  float(item.get("metric_value") or 0),
                    "gc_buffer_busy":  float(item.get("metric_value") or 0),
                    "pcttotal":        float(item.get("pct_value") or 0),
                }

                # Enrich with awr_object_metadata for richer rule conditions
                # and more specific segment-type targeting in rule titles/resolutions.
                meta_key = f"{(item.get('owner') or '').upper()}.{(item.get('object_name') or '').upper()}"
                meta     = object_metadata.get(meta_key, {})
                context.update({
                    "num_rows":            meta.get("num_rows", 0) or 0,
                    "blevel":              meta.get("blevel", 0) or 0,
                    "clustering_factor":   meta.get("clustering_factor", 0) or 0,
                    "leaf_blocks":         meta.get("leaf_blocks", 0) or 0,
                    "partition_count":     meta.get("partition_count", 0) or 0,
                    "is_partitioned":      1 if meta.get("partitioned") == "YES" else 0,
                    "is_compressed":       1 if (meta.get("compression") or "").upper() == "ENABLED" else 0,
                    "days_since_analyzed": (
                        (
                            __import__("datetime").datetime.now() - meta["last_analyzed"]
                        ).days if meta.get("last_analyzed") else 999
                    ),
                })

                if self.evaluate_condition(rule.get("condition", ""), context):
                    findings.append({
                        "rule_id":      rule["rule_id"],
                        "category":     "segment",
                        "severity":     rule.get("severity", "medium"),
                        "title":        rule.get("title", ""),
                        "object":       f"{item.get('owner','')}.{item.get('object_name','')}",
                        "obj_type":     item.get("obj_type") or meta.get("object_type", ""),
                        "metric_value": float(item.get("metric_value") or 0),
                        "pcttotal":     float(item.get("pct_value") or 0),
                        "metadata": {
                            "num_rows":          meta.get("num_rows"),
                            "partitioned":       meta.get("partitioned"),
                            "index_type":        meta.get("index_type"),
                            "blevel":            meta.get("blevel"),
                            "clustering_factor": meta.get("clustering_factor"),
                            "last_analyzed":     str(meta["last_analyzed"]) if meta.get("last_analyzed") else None,
                            "compression":       meta.get("compression"),
                        },
                        "root_cause":     rule.get("root_cause", ""),
                        "resolution":     rule.get("resolution_steps", []),
                        "diagnostic_sql": rule.get("diagnostic_sql", []),
                        "related_rules":  rule.get("related_rules", []),
                    })

        return findings

    def evaluate_exadata_rules(self, exadata_metrics: dict) -> list:
        """
        Evaluate Exadata-specific rules against Flash Cache Config,
        Performance Summary, Smart IO, and FC Reads metrics.
        Fires even when rules JSON has no exadata category — the
        critical flushing rule is hard-coded for safety.
        """
        findings = []
        exa_rules = [r for r in self.rules if r.get("category") == "exadata"]

        fc_config    = exadata_metrics.get("fc_config", [])
        perf_summary = exadata_metrics.get("perf_summary", {})
        smart_io     = exadata_metrics.get("smart_io", [])
        fc_reads     = exadata_metrics.get("fc_reads", [])

        if not fc_config and not perf_summary:
            return findings   # non-Exadata AWR — nothing to evaluate

        # ── Hard-coded CRITICAL: Flash Cache Flushing detection ────────────
        # This rule is always evaluated regardless of rules JSON content.
        flushing_cells = [c["cell_name"] for c in fc_config if c.get("is_flushing")]
        if flushing_cells:
            findings.append({
                "rule_id":    "EXA_001",
                "category":   "exadata",
                "severity":   "critical",
                "title":      f"Flash Cache Flushing on {len(flushing_cells)} Cell(s)",
                "metric_value": len(flushing_cells),
                "detail":     f"Flushing cells: {', '.join(flushing_cells)}",
                "root_cause": (
                    "One or more Exadata storage cells have Flash Cache in 'normal - flushing' "
                    "state. When flushing, the cell's Flash Cache is migrating data back to hard "
                    "disk. During this time, ALL client IOs are redirected to hard disk, causing "
                    "20-50× higher latency on cell smart table scan and cell single block physical "
                    "read wait events. This is the most severe Flash Cache condition and will "
                    "directly manifest as spiking DB time on I/O wait events."
                ),
                "resolution": [
                    f"1. IMMEDIATE: On each flushing cell, run: ALTER FLASHCACHE CANCEL FLUSH;",
                    f"   Flushing cells: {', '.join(flushing_cells)}",
                    "2. Verify cancellation: cellcli -e 'list flashcache detail' | grep status",
                    "3. Monitor cell smart table scan avg_wait_ms — should drop within 5 minutes.",
                    "4. Do NOT run ALTER FLASHCACHE FLUSH during peak hours. Schedule maintenance "
                    "   windows for Flash Cache operations.",
                    "5. If flash log is missing on these cells (check Exadata Configuration "
                    "   section), add flash log before doing any further Flash Cache maintenance.",
                ],
                "diagnostic_sql": [
                    "-- Verify Flash Cache status from database side\n"
                    "SELECT cellname, flashcachestatus FROM v$cell_state\n"
                    "WHERE flashcachestatus != 'normal';",
                    "-- Monitor cell smart table scan wait trend\n"
                    "SELECT event, total_waits, time_waited_micro/1000000 AS wait_s,\n"
                    "       average_wait/1000 AS avg_ms\n"
                    "FROM v$system_event\n"
                    "WHERE event LIKE 'cell smart%'\n"
                    "ORDER BY time_waited_micro DESC;"
                ],
                "related_rules": ["EXA_002", "EXA_004"],
            })

        # ── Rule-based evaluation from JSON rules ──────────────────────────
        for rule in exa_rules:
            rule_id  = rule.get("rule_id", "")
            sub_cat  = rule.get("sub_category", "perf_summary")
            cond     = rule.get("condition", "")

            # Build context from the appropriate data source
            if sub_cat == "perf_summary" and perf_summary:
                ctx = dict(perf_summary)
                if self.evaluate_condition(cond, ctx):
                    findings.append({
                        "rule_id":    rule_id,
                        "category":   "exadata",
                        "severity":   rule.get("severity", "medium"),
                        "title":      rule.get("title", ""),
                        "metric_value": ctx.get(rule.get("primary_metric", ""), 0),
                        "detail":     rule.get("detail_template", "").format(**ctx),
                        "root_cause": rule.get("root_cause", ""),
                        "resolution": rule.get("resolution_steps", []),
                        "diagnostic_sql": rule.get("diagnostic_sql", []),
                        "related_rules":  rule.get("related_rules", []),
                    })

            elif sub_cat == "smart_io":
                for cell in smart_io:
                    if cell.get("cell_name") == "All":
                        continue
                    ctx = dict(cell)
                    if self.evaluate_condition(cond, ctx):
                        findings.append({
                            "rule_id":    rule_id,
                            "category":   "exadata",
                            "severity":   rule.get("severity", "medium"),
                            "title":      rule.get("title", "").format(**ctx),
                            "metric_value": ctx.get(rule.get("primary_metric", ""), 0),
                            "detail":     rule.get("detail_template", "").format(**ctx),
                            "root_cause": rule.get("root_cause", ""),
                            "resolution": rule.get("resolution_steps", []),
                            "diagnostic_sql": rule.get("diagnostic_sql", []),
                            "related_rules":  rule.get("related_rules", []),
                        })
                        break   # one finding per rule across cells

            elif sub_cat == "fc_reads":
                for read in fc_reads:
                    ctx = dict(read)
                    if self.evaluate_condition(cond, ctx):
                        findings.append({
                            "rule_id":    rule_id,
                            "category":   "exadata",
                            "severity":   rule.get("severity", "medium"),
                            "title":      rule.get("title", "").format(**ctx),
                            "metric_value": ctx.get(rule.get("primary_metric", "hit_pct"), 0),
                            "detail":     rule.get("detail_template", "").format(**ctx),
                            "root_cause": rule.get("root_cause", ""),
                            "resolution": rule.get("resolution_steps", []),
                            "diagnostic_sql": rule.get("diagnostic_sql", []),
                            "related_rules":  rule.get("related_rules", []),
                        })
                        break

        # ── Wave 2: Top DB, Cell IOStat, IO Reasons, FC Space, Cell Server ──────
        top_db      = exadata_metrics.get("top_db", [])
        cell_iostat = exadata_metrics.get("cell_iostat", [])
        io_reasons  = exadata_metrics.get("io_reasons", [])
        fc_space    = exadata_metrics.get("fc_space", [])
        cell_server = exadata_metrics.get("cell_server", [])

        # EXA_008: IORM queue saturation (large IO queue > 5ms)
        for db in top_db:
            iorm = db.get("iorm_queue_ms") or 0
            if iorm > 5:
                findings.append({
                    "rule_id": "EXA_008", "category": "exadata", "severity": "high",
                    "title": f"High IORM Large IO Queue Time ({iorm}ms)",
                    "metric_value": iorm,
                    "detail": f"DB {db['target_db']}: large IO IORM queue = {iorm}ms (threshold 5ms)",
                    "root_cause": (
                        f"IORM large IO queue time is {iorm}ms — requests are waiting in the IORM "
                        "scheduler before reaching the storage device. This directly inflates "
                        "cell smart table scan latency and large IO wait times. Causes: competing "
                        "databases consuming disproportionate IO, IORM resource plans misconfigured, "
                        "or one database submitting excessive parallel query IO flooding the cells."
                    ),
                    "resolution": [
                        "1. Review IORM resource plans: SELECT * FROM v$iorm_plan;",
                        "2. Identify which DB is consuming the most IO via Top Databases section.",
                        "3. If a single DB dominates IO, apply an IORM directive: ",
                        "   dbms_resource_manager.update_io_plan(plan=>'<plan>',dbname=>'<db>',share=>N);",
                        "4. Check for runaway parallel queries: ",
                        "   SELECT sql_id, px_servers_allocated FROM v$px_session GROUP BY sql_id;",
                        "5. Review PARALLEL_MAX_SERVERS and PARALLEL_DEGREE_LIMIT parameters.",
                    ],
                    "diagnostic_sql": [
                        "-- IORM statistics\nSELECT cellname, iormlatency FROM v$cell_state ORDER BY iormlatency DESC;",
                        "-- Top parallel queries\nSELECT sql_id, COUNT(*) AS px_slaves FROM v$px_session GROUP BY sql_id ORDER BY 2 DESC;",
                    ],
                    "related_rules": ["EXA_001","EXA_007"],
                })
                break

        # EXA_009: Cell outlier at max IO capacity
        for cell in cell_iostat:
            if cell.get("at_max_capacity") and cell.get("is_outlier"):
                cn = cell["cell_name"]; util = cell.get("util_pct",0)
                findings.append({
                    "rule_id": "EXA_009", "category": "exadata", "severity": "critical",
                    "title": f"Cell {cn} at Maximum IO Capacity (Outlier)",
                    "metric_value": util,
                    "detail": f"Cell {cn}: util={util}%, is_outlier=True, at_max_capacity=True",
                    "root_cause": (
                        f"Storage cell {cn} is simultaneously an IO outlier vs its peers AND "
                        f"running at maximum device capacity ({util}% utilization). "
                        "This cell is throttling IOs — requests queue behind this bottleneck "
                        "inflating cell smart table scan and cell single block physical read wait "
                        "times system-wide. Causes: failed disk reducing capacity, uneven data "
                        "distribution, or maintenance activities on this cell."
                    ),
                    "resolution": [
                        f"1. Check cell {cn} health: cellcli -e 'list celldisk detail where name like {cn}'",
                        "2. Check for disk failures: cellcli -e 'list alerthistory'",
                        f"3. Verify data distribution — high IO on {cn} may indicate hot data objects.",
                        "4. Check for active maintenance: ASM rebalance or backup on this cell.",
                        "5. If a disk failed, replace it and allow ASM rebalance to redistribute.",
                    ],
                    "diagnostic_sql": [
                        f"-- Cell {cn} disk status\n-- Run on cell: cellcli -e 'list celldisk detail'",
                        "-- Cell IO distribution from DB\nSELECT cellname, diskiops FROM v$cell_state ORDER BY diskiops DESC;",
                    ],
                    "related_rules": ["EXA_001","EXA_008"],
                })
                break

        # EXA_010: Flash Cache large write space exceeded
        for cell in fc_space:
            lw = cell.get("large_write_pct") or 0
            if lw > 20:
                cn = cell["cell_name"]
                findings.append({
                    "rule_id": "EXA_010", "category": "exadata", "severity": "high",
                    "title": f"Flash Cache Large Write Space at {lw}% (Global Limit Risk)",
                    "metric_value": lw,
                    "detail": f"Cell {cn}: large_write_pct={lw}% of total Flash Cache space",
                    "root_cause": (
                        f"Flash Cache Large Write space is at {lw}% on cell {cn}. "
                        "Large Writes (temp spills, direct-path inserts, DBWR) are consuming "
                        "Flash Cache capacity. When the Global Limit is reached, additional "
                        "large writes bypass Flash Cache and go directly to hard disk — "
                        "dramatically increasing write latency and reducing Flash Cache "
                        "availability for OLTP and Smart Scan reads."
                    ),
                    "resolution": [
                        "1. Identify PGA over-allocation causing temp spills: ",
                        "   SELECT sql_id, temp_space_allocated FROM v$sql WHERE temp_space_allocated > 1073741824;",
                        "2. Reduce PGA_AGGREGATE_TARGET or add PGA limits per consumer group.",
                        "3. Tune direct-path insert statements to reduce Flash Cache write pressure.",
                        "4. Review main_workload_type on cells: cellcli -e 'describe cell' | grep mainWorkloadType",
                        "5. Set mainWorkloadType='analytical' if workload is primarily read-heavy.",
                    ],
                    "diagnostic_sql": [
                        "-- Large temp spill SQLs\nSELECT sql_id, ROUND(temp_space_allocated/1073741824,1) AS temp_gb\nFROM v$sql WHERE temp_space_allocated > 0 ORDER BY 2 DESC FETCH FIRST 10 ROWS ONLY;",
                    ],
                    "related_rules": ["EXA_003","EXA_005"],
                })
                break

        # EXA_011: Smart Scan IO reasons very low (<20% of cell IO)
        ss_reasons = [r for r in io_reasons if r.get("reason","").lower() in
                      ("smart scan","smartscan","exadata smart scan")]
        if ss_reasons:
            total_all = sum(r.get("total_req",0) for r in io_reasons) or 1
            ss_pct = sum(r.get("total_req",0) for r in ss_reasons) / total_all * 100
            if ss_pct < 20:
                findings.append({
                    "rule_id": "EXA_011", "category": "exadata", "severity": "medium",
                    "title": f"Smart Scan Contribution Low ({round(ss_pct,1)}% of Cell IO)",
                    "metric_value": round(ss_pct,1),
                    "detail": f"Smart Scan = {round(ss_pct,1)}% of all cell IO requests",
                    "root_cause": (
                        f"Smart Scan (Exadata offload) accounts for only {round(ss_pct,1)}% of "
                        "all storage cell IO. In an analytics/DWH workload this should be "
                        "40-70%+. Low Smart Scan contribution means the workload is dominated "
                        "by OLTP single-block reads, redo/archive operations, or DBWR writes "
                        "rather than offloaded analytics — indicating either a predominantly "
                        "OLTP workload or Smart Scan eligibility issues."
                    ),
                    "resolution": [
                        "1. Check workload type — if this is OLTP, low Smart Scan% is expected.",
                        "2. Review passthru rate in Smart IO section — high passthru reduces SS%.",
                        "3. Ensure analytics queries use FULL table scans on large tables, not index lookups.",
                        "4. Check for CELL_FLASH_CACHE NONE or NO_MERGE hints preventing offload.",
                    ],
                    "diagnostic_sql": [
                        "-- Smart Scan vs total IO\nSELECT name, value FROM v$sysstat WHERE name IN ('cell physical IO bytes eligible for predicate offload','cell physical IO interconnect bytes');",
                    ],
                    "related_rules": ["EXA_006","EXA_005"],
                })

        # EXA_012: Internal IO excessive (>30%)
        int_reasons = [r for r in io_reasons if "internal" in r.get("reason","").lower()]
        if int_reasons:
            total_all = sum(r.get("total_req",0) for r in io_reasons) or 1
            int_pct = sum(r.get("total_req",0) for r in int_reasons) / total_all * 100
            if int_pct > 30:
                findings.append({
                    "rule_id": "EXA_012", "category": "exadata", "severity": "medium",
                    "title": f"High Internal IO on Storage Cells ({round(int_pct,1)}%)",
                    "metric_value": round(int_pct,1),
                    "detail": f"Internal IO = {round(int_pct,1)}% of all cell requests",
                    "root_cause": (
                        "Internal IO (cell software internal operations) represents over 30% "
                        "of all storage cell requests. This typically indicates: active scrubbing "
                        "of hard disks, Flash Cache population after restart, ASM rebalance "
                        "activity, or flash log writes. High internal IO competes with database "
                        "IO for device bandwidth."
                    ),
                    "resolution": [
                        "1. Check for active scrub: cellcli -e 'list celldisk attributes name,scrubStatus'",
                        "2. If ASM rebalance active: SELECT inst_id, operation, state FROM gv$asm_operation;",
                        "3. Schedule scrub during maintenance windows, not during peak hours.",
                        "4. Monitor Flash Cache population after restarts — internal IO drops to normal after warm-up.",
                    ],
                    "diagnostic_sql": [],
                    "related_rules": ["EXA_007","EXA_009"],
                })

        # EXA_013: Cell server large write dominance per cell
        for cell in cell_server:
            lw_pct = cell.get("large_write_pct_iops") or 0
            if lw_pct > 40:
                cn = cell["cell_name"]
                findings.append({
                    "rule_id": "EXA_013", "category": "exadata", "severity": "high",
                    "title": f"Large Write IO Dominates Cell {cn} ({lw_pct}% of IOPs)",
                    "metric_value": lw_pct,
                    "detail": f"Cell {cn}: {lw_pct}% of all IOPs are large writes",
                    "root_cause": (
                        f"Cell {cn} is spending {lw_pct}% of its IO capacity on large writes "
                        "(temp spills, direct-path inserts, DBWR checkpoint). When a cell is "
                        "dominated by writes, read IO latency increases due to device queue depth "
                        "contention. Combined with high Flash Cache Large Write space, this "
                        "indicates a checkpoint storm, runaway temp spill, or bulk load."
                    ),
                    "resolution": [
                        "1. Identify bulk-load or direct-path insert jobs running during this period.",
                        "2. Check for DBWR checkpoint pressure: SELECT * FROM v$bgprocess WHERE name='DBW0';",
                        "3. Tune CHECKPOINT_CHANGE# interval — reduce FAST_START_MTTR_TARGET if set aggressively.",
                        "4. Cross-reference with Flash Cache Space Usage section for large_write_pct.",
                    ],
                    "diagnostic_sql": [
                        "-- DBWR checkpoint statistics\nSELECT name, value FROM v$sysstat WHERE name LIKE 'background checkpoints%' OR name LIKE 'DBWR%';",
                    ],
                    "related_rules": ["EXA_010","EXA_009"],
                })
                break

        # ── Wave 3: FC Writes, Write Rejections, Config, Disk IOStat ───────────
        fc_writes     = exadata_metrics.get("fc_writes", [])
        write_rejects = exadata_metrics.get("write_rejects", [])
        exa_config    = exadata_metrics.get("exa_config", [])
        disk_iostat   = exadata_metrics.get("disk_iostat", [])
        int_io        = exadata_metrics.get("int_io_reasons", [])

        # EXA_014: High partial write rate (>5% of FC writes = non-aligned IO pressure)
        for c in [x for x in fc_writes if x.get("write_type")=="Total"]:
            pp = c.get("partial_write_pct") or 0
            if pp > 5:
                findings.append({
                    "rule_id":"EXA_014","category":"exadata","severity":"medium",
                    "title":f"High Flash Cache Partial Write Rate on {c['cell_name']} ({pp}%)",
                    "metric_value":pp,
                    "detail":f"Cell {c['cell_name']}: {pp}% of writes are partial (cross-page IO)",
                    "root_cause":(
                        f"Flash Cache partial write rate is {pp}% on cell {c['cell_name']}. "
                        "Partial writes occur when a write crosses page boundaries within the "
                        "Flash Cache. A high rate indicates small, non-aligned write IO patterns "
                        "(common with OLTP-heavy workloads with block sizes not aligned to FC pages) "
                        "or heavy DBWR checkpoint activity. Partial writes reduce Flash Cache "
                        "effective throughput."),
                    "resolution":["1. Review CELL_FLASH_CACHE storage clause on high-write tables.",
                        "2. Check for small block size vs Flash Cache page size mismatch.",
                        "3. Review DBWR checkpoint settings (FAST_START_MTTR_TARGET)."],
                    "diagnostic_sql":["SELECT name,value FROM v$sysstat WHERE name LIKE '%flash cache%write%';"],
                    "related_rules":["EXA_010","EXA_013"],
                })
                break

        # EXA_015: Large write rejections (Global Limit hit — temp spills to disk)
        global_limit_rejects = [r for r in write_rejects if "global" in (r.get("reason") or "").lower()]
        total_rejects = sum(r.get("rejection_count",0) for r in global_limit_rejects)
        if total_rejects > 1000:
            findings.append({
                "rule_id":"EXA_015","category":"exadata","severity":"high",
                "title":f"Flash Cache Large Write Global Limit Rejections ({total_rejects:,})",
                "metric_value":total_rejects,
                "detail":f"Global Limit rejections: {total_rejects:,} large writes rejected across cells",
                "root_cause":(
                    f"Flash Cache rejected {total_rejects:,} large writes due to Global Limit. "
                    "This means the Flash Cache large write area (for temp spills and direct-path "
                    "writes) is full. Rejected large writes go to hard disk, causing significantly "
                    "higher write latency. Root causes: excessive PGA spills to temp, heavy "
                    "direct-path inserts, or DBWR checkpoint storms consuming large write space."),
                "resolution":[
                    "1. Identify queries causing large temp spills: SELECT sql_id, temp_space_allocated FROM v$sql WHERE temp_space_allocated > 1073741824 ORDER BY 2 DESC;",
                    "2. Reduce PGA_AGGREGATE_TARGET to limit temp spills per session.",
                    "3. Review CELL_FLASH_CACHE NONE on large objects — if set, removes contention.",
                    "4. Set mainWorkloadType='analytical' on cells if workload is read-heavy."],
                "diagnostic_sql":["SELECT name,value FROM v$sysstat WHERE name LIKE '%flash cache%reject%';"],
                "related_rules":["EXA_010","EXA_013"],
            })

        # EXA_016: Exadata config mismatch (missing flash log on some cells)
        cells_no_fl = [c["cell_name"] for c in exa_config if not c.get("has_flash_log")]
        cells_with_fl = [c["cell_name"] for c in exa_config if c.get("has_flash_log")]
        if cells_no_fl and cells_with_fl:
            findings.append({
                "rule_id":"EXA_016","category":"exadata","severity":"medium",
                "title":f"Exadata Cell Config Mismatch — Flash Log Missing on {len(cells_no_fl)} Cell(s)",
                "metric_value":len(cells_no_fl),
                "detail":f"No Flash Log: {', '.join(cells_no_fl)} | Has Flash Log: {', '.join(cells_with_fl)}",
                "root_cause":(
                    "Storage cells have inconsistent Flash Log configuration. Cells without "
                    "Flash Log write redo log entries to hard disk, causing higher log write "
                    "latency on those cells. This creates an uneven performance profile across "
                    "cells and can be difficult to diagnose without looking at the Configuration section."),
                "resolution":[
                    f"1. Configure Flash Log on cells: {', '.join(cells_no_fl)}",
                    "   cellcli -e 'CREATE FLASHLOG ALL'",
                    "2. Verify after creation: cellcli -e 'LIST FLASHLOG DETAIL'",
                    "3. Schedule during maintenance window — Flash Log creation requires brief IO pause."],
                "diagnostic_sql":["-- Run on cell: cellcli -e 'LIST FLASHLOG DETAIL'"],
                "related_rules":["EXA_001"],
            })

        # EXA_017: Specific disk outlier at max capacity
        outlier_disks = [d for d in disk_iostat if d.get("is_outlier") and d.get("at_max_capacity")]
        if outlier_disks:
            od = outlier_disks[0]
            findings.append({
                "rule_id":"EXA_017","category":"exadata","severity":"high",
                "title":f"Hard Disk Outlier at Max IOPs: {od['disk_name']}",
                "metric_value":od.get("util_pct",0),
                "detail":f"Disk {od['disk_name']} (cell {od['cell_name']}): util={od['util_pct']}%, at_max_capacity=True",
                "root_cause":(
                    f"Hard disk {od['disk_name']} on cell {od['cell_name']} is both an IO outlier "
                    "and running at maximum device IOPs. This disk is throttling — requests queue "
                    "behind this bottleneck causing latency spikes on all IO through this disk. "
                    "Causes: disk media degradation, uneven data distribution loading this disk "
                    "more than peers, or active ASM rebalance writing to this disk preferentially."),
                "resolution":[
                    f"1. Check disk health: cellcli -e 'LIST CELLDISK {od['disk_name'].split('_CD')[0] if '_' in od['disk_name'] else od['disk_name']} DETAIL'",
                    "2. Check for disk errors in cell alert log: cellcli -e 'LIST ALERTHISTORY'",
                    "3. If ASM rebalance active: SELECT * FROM gv$asm_operation;",
                    "4. If disk is failing: replace proactively to avoid data loss."],
                "diagnostic_sql":["SELECT path,mode_status,state FROM v$asm_disk ORDER BY path;"],
                "related_rules":["EXA_009","EXA_008"],
            })

        # EXA_018: Disk Writer Sync > 50% of internal IO (confirms FC flushing)
        dws = [r for r in int_io if "disk writer" in (r.get("internal_reason") or "").lower()
               or "sync" in (r.get("internal_reason") or "").lower()]
        if dws:
            max_dws_pct = max((r.get("pct_of_internal") or 0) for r in dws)
            if max_dws_pct > 50:
                findings.append({
                    "rule_id":"EXA_018","category":"exadata","severity":"high",
                    "title":f"Disk Writer Sync Dominates Internal IO ({max_dws_pct}%)",
                    "metric_value":max_dws_pct,
                    "detail":f"Disk Writer Sync = {max_dws_pct}% of internal cell IO — confirms active Flash Cache flush",
                    "root_cause":(
                        "Disk Writer Sync is the dominant internal IO type, confirming that "
                        "Flash Cache flush is actively writing cached data back to hard disk. "
                        "This is a secondary confirmation signal for EXA_001 (Flash Cache Flushing). "
                        "During flush, the disk writer thread becomes very active, consuming "
                        "significant cell IO bandwidth that would otherwise serve database reads."),
                    "resolution":[
                        "1. IMMEDIATE: Cancel Flash Cache flush: cellcli -e 'ALTER FLASHCACHE CANCEL FLUSH'",
                        "2. Verify Disk Writer Sync drops after cancellation.",
                        "3. Cross-reference with FC Internal Writes — absence confirms flush is active.",],
                    "related_rules":["EXA_001","EXA_007"],
                })

        # Wave 3: FC Writes, Config, Disk IOStat
        fc_write_reject = exadata_metrics.get("fc_write_reject", [])
        exa_config      = exadata_metrics.get("exadata_config", [])
        disk_io         = exadata_metrics.get("disk_iostat", [])

        # EXA_014: Large Write Rejections
        total_rej = sum(r.get("rejection_count",0) for r in fc_write_reject
                        if "global" in (r.get("reason") or "").lower())
        if total_rej > 0:
            findings.append({
                "rule_id":"EXA_014","category":"exadata","severity":"high",
                "title":f"FC Large Write Rejections — Global Limit Hit ({total_rej:,})",
                "metric_value":total_rej,
                "detail":f"{total_rej:,} large writes rejected due to Global Limit",
                "root_cause":(
                    "Flash Cache Large Write space ceiling reached. New large writes "
                    "(temp spills, direct-path inserts) are redirected to hard disk, "
                    "inflating direct path write temp and direct path read temp wait times."
                ),
                "resolution":[
                    "1. Reduce PGA_AGGREGATE_TARGET to reduce temp spill pressure.",
                    "2. Review main_workload_type on cells (set to analytical for DWH).",
                    "3. Monitor awr_exadata_fc_space.large_write_pct > 20% triggers EXA_010.",
                ],
                "diagnostic_sql":["SELECT name,value FROM v$sysstat WHERE name LIKE '%direct path%';"],
                "related_rules":["EXA_010","EXA_013"],
            })

        # EXA_015: Cell configuration mismatch
        if exa_config:
            fc_sizes = set(round(r.get("flash_cache_mb",0)/1024) for r in exa_config if r.get("flash_cache_mb"))
            no_fl    = [r["cell_name"] for r in exa_config if not r.get("has_flash_log")]
            if len(fc_sizes) > 1:
                findings.append({
                    "rule_id":"EXA_015","category":"exadata","severity":"medium",
                    "title":f"Cell Config Mismatch — Unequal Flash Cache Sizes",
                    "metric_value":len(fc_sizes),
                    "detail":f"FC sizes vary: {fc_sizes} GB across cells",
                    "root_cause":"Cells with smaller FC have lower hit rates and more disk IO.",
                    "resolution":["Align Flash Cache sizes across all cells using cellcli."],
                    "diagnostic_sql":["-- cellcli -e 'LIST FLASHCACHE DETAIL'"],
                    "related_rules":["EXA_001","EXA_002"],
                })
            elif no_fl:
                findings.append({
                    "rule_id":"EXA_015","category":"exadata","severity":"medium",
                    "title":f"Flash Log Missing on {len(no_fl)} Cell(s)",
                    "metric_value":len(no_fl),
                    "detail":f"No Flash Log on: {', '.join(no_fl)}",
                    "root_cause":"Cells without Flash Log write redo to spinning disk — higher log file sync latency.",
                    "resolution":[f"Create Flash Log: cellcli -e 'CREATE FLASHLOG ALL' on affected cells."],
                    "diagnostic_sql":["-- cellcli -e 'LIST FLASHLOG DETAIL'"],
                    "related_rules":["EXA_008"],
                })

        # EXA_016: Disk-level outlier
        disk_outliers = [d for d in disk_io if d.get("is_outlier") and d.get("util_pct",0) > 70]
        if disk_outliers:
            cell = disk_outliers[0]["cell_name"]; util = disk_outliers[0]["util_pct"]
            findings.append({
                "rule_id":"EXA_016","category":"exadata","severity":"medium",
                "title":f"Disk Outlier in Cell {cell} — Possible Degraded Disk",
                "metric_value":util,
                "detail":f"Cell {cell}: disk outlier at {util}% util (>70%)",
                "root_cause":"A disk within a cell is doing disproportionate IO — may indicate data skew or degraded disk.",
                "resolution":[
                    f"1. Check disk health: cellcli -e 'LIST PHYSICALDISK DETAIL' on {cell}",
                    "2. Check ASM balance and cell alert history for bad blocks.",
                ],
                "diagnostic_sql":["-- cellcli -e 'LIST ALERTHISTORY WHERE severity IN (critical, warning)'"],
                "related_rules":["EXA_009"],
            })

        # Deduplicate within Exadata findings
        seen = set()
        deduped = []
        for f in findings:
            k = f["rule_id"]
            if k not in seen:
                seen.add(k)
                deduped.append(f)
        return deduped


# ── AI supplement ──────────────────────────────────────────────────────
def _ai_supplement(findings: list, dbname: str, snap_range: str) -> str:
    """
    Generate an AI narrative summary of the top findings.
    Falls back gracefully if AI is unavailable.
    """
    if AI_MODE == "rules":
        return ""

    top_findings = findings[:5]
    if not top_findings:
        return ""

    prompt = f"""You are an Oracle DBA expert. Analyse these performance findings for database {dbname} (snap range {snap_range}) and provide a concise 3-5 paragraph executive summary with prioritised action items.

Findings:
{json.dumps(top_findings, indent=2, default=str)}

Respond with: 1) Summary of the overall performance state. 2) Top 3 most urgent actions in priority order. 3) Any cross-finding patterns worth noting (e.g. chain of related issues). Keep it factual and concise."""

    if AI_MODE == "local":
        return _call_ollama(prompt)
    elif AI_MODE == "cloud":
        return _call_anthropic(prompt)
    return ""


def _call_ollama(prompt: str) -> str:
    try:
        import urllib.request
        ollama_cfg = _ai_cfg.get("ollama", {})
        url   = ollama_cfg.get("base_url", "http://localhost:11434") + "/api/generate"
        model = ollama_cfg.get("model", "llama3")
        payload = json.dumps({"model": model, "prompt": prompt, "stream": False}).encode()
        req = urllib.request.Request(url, data=payload,
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read())
            return data.get("response", "")
    except Exception as e:
        logger.warning(f"Ollama call failed: {e}")
        return ""


def _call_anthropic(prompt: str) -> str:
    try:
        import urllib.request
        ant_cfg  = _ai_cfg.get("anthropic", {})
        api_key  = ant_cfg.get("api_key") or os.environ.get("ANTHROPIC_API_KEY", "")
        if not api_key:
            logger.warning("Anthropic API key not set — skipping AI supplement")
            return ""
        model    = ant_cfg.get("model", "claude-sonnet-4-6")
        max_tok  = int(ant_cfg.get("max_tokens", 1024))
        payload  = json.dumps({
            "model": model, "max_tokens": max_tok,
            "messages": [{"role": "user", "content": prompt}]
        }).encode()
        req = urllib.request.Request(
            "https://api.anthropic.com/v1/messages",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01"
            }
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
            return data["content"][0]["text"]
    except Exception as e:
        logger.warning(f"Anthropic API call failed: {e}")
        return ""


# ── main evaluator ────────────────────────────────────────────────────
class RecommendationEngine:

    def __init__(self):
        self.rules  = _load_rules()
        self.engine = RuleEngine(self.rules)

    def evaluate(self, dbname: str, begin_snap: int, end_snap: int,
                 instance: Optional[str] = None) -> dict:
        """
        Run all rule categories against the given snap range.

        Returns:
            {
                "dbname": ...,
                "snap_range": "begin-end",
                "total_findings": N,
                "findings": [ { rule_id, category, severity, title, ... } ],
                "ai_summary": "..." (empty if AI mode is rules)
            }
        """
        logger.info(f"Evaluating recommendations: {dbname} snaps {begin_snap}-{end_snap}")

        conn = get_db_connection()
        try:
            wait_metrics     = _fetch_wait_metrics(conn, dbname, begin_snap, end_snap)
            sql_metrics      = _fetch_sql_metrics(conn, dbname, begin_snap, end_snap)
            efficiency       = _fetch_instance_efficiency(conn, dbname, begin_snap, end_snap)
            seg_metrics      = _fetch_segment_metrics(conn, dbname, begin_snap, end_snap)
            exadata_metrics  = _fetch_exadata_metrics(conn, dbname, begin_snap, end_snap)

            # Build the set of (owner, object_name) pairs from all segment metric results
            # and fetch their metadata from awr_object_metadata in one pass.
            seg_pairs = set()
            for items in seg_metrics.values():
                for item in items:
                    if item.get("owner") and item.get("object_name"):
                        seg_pairs.add((item["owner"], item["object_name"]))
            object_metadata = _fetch_object_metadata(conn, dbname, list(seg_pairs))
        finally:
            conn.close()

        # Run all rule categories
        findings = []
        findings += self.engine.evaluate_wait_rules(wait_metrics)
        findings += self.engine.evaluate_sql_rules(sql_metrics)
        findings += self.engine.evaluate_efficiency_rules(efficiency)
        findings += self.engine.evaluate_segment_rules(seg_metrics, object_metadata)
        findings += self.engine.evaluate_exadata_rules(exadata_metrics)

        # Filter by minimum severity
        findings = [f for f in findings
                    if SEVERITY_RANK.get(f.get("severity", "low"), 0) >= MIN_RANK]

        # Sort: critical first, then high, then by category
        findings.sort(
            key=lambda f: (-SEVERITY_RANK.get(f.get("severity", "low"), 0),
                           f.get("category", ""),
                           f.get("rule_id", ""))
        )

        # Deduplicate by rule_id (same rule can fire for multiple events/segments)
        seen     = set()
        deduped  = []
        for f in findings:
            key = f.get("rule_id")
            if key not in seen:
                seen.add(key)
                deduped.append(f)

        snap_range  = f"{begin_snap}-{end_snap}"
        ai_summary  = _ai_supplement(deduped, dbname, snap_range)

        result = {
            "dbname":         dbname,
            "begin_snap":     begin_snap,
            "end_snap":       end_snap,
            "snap_range":     snap_range,
            "ai_mode":        AI_MODE,
            "total_findings": len(deduped),
            "critical":       sum(1 for f in deduped if f.get("severity") == "critical"),
            "high":           sum(1 for f in deduped if f.get("severity") == "high"),
            "medium":         sum(1 for f in deduped if f.get("severity") == "medium"),
            "low":            sum(1 for f in deduped if f.get("severity") == "low"),
            "findings":       deduped,
            "ai_summary":     ai_summary,
        }

        logger.info(f"Recommendations complete: {len(deduped)} findings "
                    f"(critical={result['critical']}, high={result['high']})")
        return result

    def _enrich_finding_with_metadata(self, f: dict) -> dict:
        """
        Inject awr_object_metadata facts into a segment finding's root_cause
        and resolution steps before storing to DB.

        The rules JSON defines generic guidance; this method personalises it
        with the actual object's structural characteristics so the DBA sees
        context-specific text in the Grafana recommendations panel, not boilerplate.

        Only modifies segment-category findings that have a non-empty metadata dict.
        All other findings (wait, sql, instance_efficiency) are returned unchanged.
        """
        if f.get("category") != "segment":
            return f

        meta = f.get("metadata", {})
        if not meta:
            return f

        obj        = f.get("object", "")
        obj_type   = (f.get("obj_type") or "").upper()
        num_rows   = meta.get("num_rows")
        blevel     = meta.get("blevel")
        cf         = meta.get("clustering_factor")
        partitioned = meta.get("partitioned", "NO")
        index_type  = meta.get("index_type")
        last_analyzed = meta.get("last_analyzed")
        compression   = meta.get("compression")

        # Build a context line describing what we know about this object
        ctx_parts = [f"Object: {obj} ({obj_type})"]

        if obj_type in ("TABLE", "TABLE PARTITION", "TABLE SUBPARTITION", "CLUSTER"):
            if num_rows is not None:
                ctx_parts.append(f"Rows: {int(num_rows):,}")
            if partitioned == "YES":
                ctx_parts.append("Partitioned: YES")
            if compression and compression.upper() == "ENABLED":
                ctx_parts.append("Compression: ENABLED")
            if last_analyzed:
                ctx_parts.append(f"Last analyzed: {last_analyzed}")

        elif obj_type in ("INDEX", "INDEX PARTITION", "INDEX SUBPARTITION",
                          "LOB INDEX", "CLUSTER INDEX"):
            if blevel is not None:
                ctx_parts.append(f"BLEVEL: {int(blevel)}")
                if blevel > 4:
                    ctx_parts.append("⚠ High BLEVEL — rebuild candidate")
            if cf is not None and num_rows is not None and num_rows > 0:
                cf_ratio = cf / num_rows
                ctx_parts.append(
                    f"Clustering Factor: {int(cf):,} / {int(num_rows):,} rows "
                    f"(ratio: {cf_ratio:.2f})"
                )
                if cf_ratio > 0.5:
                    ctx_parts.append("⚠ Poor clustering — consider table reorganisation")
            if index_type:
                ctx_parts.append(f"Index type: {index_type}")
            if last_analyzed:
                ctx_parts.append(f"Last analyzed: {last_analyzed}")

        elif obj_type in ("LOB", "LOB PARTITION"):
            ctx_parts.append("LOB segment — check SecureFile vs BasicFile and CACHE setting")

        elif obj_type in ("ROLLBACK", "TYPE2 UNDO"):
            ctx_parts.append("Undo segment — check UNDO_RETENTION and undo tablespace sizing")

        elif obj_type == "TEMPORARY":
            ctx_parts.append("Temporary segment — indicates sort/hash spill to temp tablespace")

        metadata_context = " | ".join(ctx_parts)

        # Prepend metadata context to root_cause
        original_root_cause = f.get("root_cause", "")
        enriched_root_cause = f"[{metadata_context}]\n{original_root_cause}"

        # Prepend a metadata-specific action as the first resolution step
        original_resolution = f.get("resolution", [])
        metadata_action = f"Object context: {metadata_context}"
        enriched_resolution = [metadata_action] + original_resolution

        enriched = dict(f)
        enriched["root_cause"] = enriched_root_cause
        enriched["resolution"] = enriched_resolution
        return enriched

    def store_recommendations(self, result: dict) -> None:
        """Persist recommendation results to awr_recommendations table."""
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                for f in result["findings"]:
                    # Enrich segment findings with metadata context before storing
                    f_stored = self._enrich_finding_with_metadata(f)
                    cur.execute("""
                        INSERT INTO awr_recommendations
                            (dbname, begin_snap, end_snap, rule_id, category,
                             severity, title, event_or_object,
                             root_cause, resolution_json, ai_summary, created_at)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW())
                        ON CONFLICT (dbname, begin_snap, end_snap, rule_id) DO UPDATE
                            SET severity       = EXCLUDED.severity,
                                title          = EXCLUDED.title,
                                event_or_object = EXCLUDED.event_or_object,
                                root_cause     = EXCLUDED.root_cause,
                                resolution_json = EXCLUDED.resolution_json,
                                created_at     = NOW()
                    """, (
                        result["dbname"], result["begin_snap"], result["end_snap"],
                        f_stored.get("rule_id"), f_stored.get("category"),
                        f_stored.get("severity"), f_stored.get("title"),
                        f_stored.get("event") or f_stored.get("object") or f_stored.get("sql_id") or "",
                        f_stored.get("root_cause", ""),
                        json.dumps(f_stored.get("resolution", []), default=str),
                        result.get("ai_summary", ""),
                    ))
            conn.commit()
            logger.info(f"Stored {len(result['findings'])} recommendations to DB")
        except Exception as e:
            conn.rollback()
            logger.error(f"Failed to store recommendations: {e}", exc_info=True)
        finally:
            conn.close()


# ── callable interface for master_parser auto-trigger ─────────────────
def run(db_name: str, start_snap: int, end_snap: int, store: bool = False,
        instance: Optional[str] = None) -> dict:
    """
    Module-level entry point called by master_parser._run_recommendations().
    Avoids sys.argv patching — preferred over main() for programmatic use.
    """
    engine = RecommendationEngine()
    result = engine.evaluate(db_name, start_snap, end_snap, instance)
    if store:
        engine.store_recommendations(result)
    return result


# ── CLI entry point ───────────────────────────────────────────────────
def main():
    p = argparse.ArgumentParser(description="AWR Recommendation Engine v2")
    p.add_argument("--db",    required=True,       help="Database name (e.g. COLDBPRD)")
    p.add_argument("--start", required=True, type=int, help="Begin snap ID")
    p.add_argument("--end",   required=True, type=int, help="End snap ID")
    p.add_argument("--store", action="store_true",  help="Persist findings to DB")
    p.add_argument("--json",  action="store_true",  help="Output JSON instead of plain text")
    args = p.parse_args()

    engine = RecommendationEngine()
    result = engine.evaluate(args.db, args.start, args.end)

    if args.store:
        engine.store_recommendations(result)

    if args.json:
        print(json.dumps(result, indent=2, default=str))
        return

    # Human-readable output
    print(f"\n{'='*60}")
    print(f"Recommendations for {result['dbname']} (snaps {result['snap_range']})")
    print(f"Total: {result['total_findings']}  |  "
          f"Critical: {result['critical']}  High: {result['high']}  Medium: {result['medium']}")
    print(f"AI mode: {result['ai_mode']}")
    print(f"{'='*60}\n")

    for i, f in enumerate(result["findings"], 1):
        sev = f.get("severity", "").upper()
        print(f"[{i}] [{sev}] {f.get('rule_id')} — {f.get('title')}")
        if f.get("event"):
            print(f"     Event  : {f['event']} ({f.get('pct_db_time',0):.1f}% DB time, avg {f.get('avg_wait_ms',0):.1f}ms)")
        if f.get("object"):
            print(f"     Segment: {f['object']} ({f.get('obj_type','')})")
        if f.get("sql_id"):
            print(f"     SQL ID : {f['sql_id']}")
        print(f"     Cause  : {f.get('root_cause','')[:120]}...")
        print(f"     Fix 1  : {f.get('resolution',[''])[0] if f.get('resolution') else ''}")
        print()

    if result.get("ai_summary"):
        print(f"\n{'─'*60}")
        print("AI ANALYSIS SUMMARY:")
        print(result["ai_summary"])


if __name__ == "__main__":
    main()
