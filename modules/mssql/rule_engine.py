"""
modules/mssql/rule_engine.py
==============================
MS SQL Server rule evaluation -- a genuinely separate module from
recommendation_engine.py, not an extension bolted onto it. That file's
RuleEngine.evaluate_condition() is small, generic, and database-
agnostic in principle, but its category-specific evaluate_XXX_rules()
methods and RecommendationEngine.run() are built around Oracle's
begin_snap/end_snap concept throughout -- MS SQL has no equivalent
(Query Store uses its own interval_id, the cumulative-DMV collector
uses snapshot_id, neither maps onto a snap-range). Rather than modify
that large, working, production file to accommodate a second database
type, or import deeply from it, this module re-implements the small,
stable evaluate_condition() logic directly (a handful of lines,
low-risk to duplicate) and builds its own category-specific evaluators
matching MS SQL's actual data shapes.

Loads rules/recommendation_rules_mssql_v1.json -- a separate file from
the Oracle rules/recommendation_rules_v2.json, per the Analysis Model
design doc's Section 6 ("recommend a separate file initially, to avoid
the two engines' rule sets becoming entangled during early
development").

First category built: wait statistics, both tiers from the design
doc's Section 3.1 two-tier design --
  mssql_wait_type     -- instance-wide, fine-grained (sys.dm_os_wait_stats,
                          via mssql_wait_stats_delta). Requires a DELTA
                          between two consecutive snapshots -- the
                          collector stores raw cumulative values by
                          design (Section 4.2), so this fetcher is
                          where that delta math actually happens, at
                          read time, matching the stated architecture.
  mssql_wait_category -- per-query, category-level (sys.query_store_wait_stats,
                          via mssql_qs_wait_stats). Already
                          interval-aggregated by Query Store itself --
                          no delta math needed here, a straight read.
"""

import os
import sys
import json
import re

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'modules'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from logger_utils import get_logger

logger = get_logger('mssql_rule_engine')

RULES_FILE = os.path.join(_PROJECT_ROOT, 'rules', 'recommendation_rules_mssql_v1.json')

SAFE_GLOBALS = {"__builtins__": {}}


def _load_rules() -> list:
    try:
        with open(RULES_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        rules = data.get("rules", [])
        logger.info(f"Loaded {len(rules)} MS SQL recommendation rules from {RULES_FILE}")
        return rules
    except Exception as e:
        logger.error(f"Failed to load MS SQL rules from {RULES_FILE}: {e}")
        return []


def evaluate_condition(condition: str, context: dict) -> bool:
    """Same logic as recommendation_engine.RuleEngine.evaluate_condition --
    small and stable enough to duplicate rather than import, keeping
    this module genuinely independent of the Oracle-specific file."""
    if not condition:
        return False
    try:
        expr = condition.replace(" AND ", " and ").replace(" OR ", " or ")
        return bool(eval(expr, SAFE_GLOBALS, context))
    except Exception:
        return False


def _match_event_pattern(pattern: str, event: str) -> bool:
    """Wildcard match, same semantics as the Oracle side's
    match_wait_event -- '*' matches everything, 'PREFIX*' matches
    anything starting with PREFIX (case-insensitive), otherwise exact
    match."""
    pattern_l = (pattern or "*").lower()
    event_l = (event or "").lower()
    if pattern_l == "*":
        return True
    if "*" in pattern_l:
        prefix = pattern_l.split("*")[0]
        return event_l.startswith(prefix)
    return event_l == pattern_l


# ══════════════════════ FETCHERS ══════════════════════

def fetch_wait_type_metrics(pg_conn, instance_id: int, snapshot_id: int = None) -> list:
    """
    Instance-wide, fine-grained wait_type metrics -- computes a DELTA
    between the given snapshot (or the latest one, if not specified)
    and the immediately preceding snapshot for the same instance. This
    is where the "store raw, compute delta at read time" architecture
    (Analysis Model doc Section 4.2) actually happens -- the collector
    itself never computes this.

    Returns a list of dicts: wait_type, wait_time_ms_delta,
    waiting_tasks_count_delta, elapsed_seconds, avg_wait_ms (per-wait
    average within the delta window), wait_pct_of_total (this
    wait_type's share of all wait_time_ms_delta across every wait_type
    in the window -- the metric MSSQL_WAIT_001-004's conditions
    actually check).

    Returns [] (not an error) if fewer than 2 snapshots exist yet for
    this instance -- a delta needs two points, and that's a normal,
    expected state shortly after the collector's first run, not a
    failure.
    """
    with pg_conn.cursor() as cur:
        if snapshot_id is None:
            cur.execute(
                "SELECT snapshot_id, snapshot_time FROM mssql_dmv_snapshot "
                "WHERE instance_id = %s ORDER BY snapshot_time DESC LIMIT 1",
                (instance_id,)
            )
            row = cur.fetchone()
            if not row:
                return []
            snapshot_id, latest_time = row
        else:
            cur.execute(
                "SELECT snapshot_time FROM mssql_dmv_snapshot WHERE snapshot_id = %s",
                (snapshot_id,)
            )
            row = cur.fetchone()
            if not row:
                return []
            latest_time = row[0]

        cur.execute(
            "SELECT snapshot_id, snapshot_time FROM mssql_dmv_snapshot "
            "WHERE instance_id = %s AND snapshot_time < %s "
            "ORDER BY snapshot_time DESC LIMIT 1",
            (instance_id, latest_time)
        )
        prev_row = cur.fetchone()
        if not prev_row:
            logger.info(f"Only one snapshot exists for instance {instance_id} -- "
                        f"no delta possible yet, this is expected shortly after first collection")
            return []
        prev_snapshot_id, prev_time = prev_row

        elapsed_seconds = (latest_time - prev_time).total_seconds()
        if elapsed_seconds <= 0:
            return []

        cur.execute("""
            SELECT cur.wait_type,
                   cur.wait_time_ms - COALESCE(prev.wait_time_ms, 0) AS wait_time_ms_delta,
                   cur.waiting_tasks_count - COALESCE(prev.waiting_tasks_count, 0) AS tasks_delta
            FROM mssql_wait_stats_delta cur
            LEFT JOIN mssql_wait_stats_delta prev
                ON prev.snapshot_id = %s AND prev.wait_type = cur.wait_type
            WHERE cur.snapshot_id = %s
        """, (prev_snapshot_id, snapshot_id))
        rows = cur.fetchall()

    # Filter out negative deltas (a service restart between snapshots
    # resets the cumulative counters -- a negative delta here means
    # exactly that, not a real decrease, and should be excluded rather
    # than reported as a nonsensical negative wait time) and zero-delta
    # rows (no new waits of this type since the previous snapshot).
    clean = [(wt, d, t) for wt, d, t in rows if d > 0]
    total_wait_ms = sum(d for _, d, _ in clean) or 1  # avoid div-by-zero if everything was filtered

    results = []
    for wait_type, wait_time_ms_delta, tasks_delta in clean:
        results.append({
            "wait_type": wait_type,
            "wait_time_ms_delta": wait_time_ms_delta,
            "waiting_tasks_count_delta": tasks_delta,
            "elapsed_seconds": elapsed_seconds,
            "avg_wait_ms": (wait_time_ms_delta / tasks_delta) if tasks_delta > 0 else 0,
            "wait_pct_of_total": (wait_time_ms_delta / total_wait_ms) * 100,
        })
    return sorted(results, key=lambda r: r["wait_pct_of_total"], reverse=True)


def fetch_wait_category_metrics(pg_conn, instance_id: int, database_name: str = None,
                                  qs_interval_id: int = None) -> list:
    """
    Per-query wait_category metrics from Query Store -- already
    interval-aggregated, no delta math needed (the "native interval
    pull" model, Section 4.2). Defaults to the most recent fully-
    collected interval if qs_interval_id isn't given.

    Returns a list of dicts: wait_category_desc, qs_plan_id,
    total_query_wait_time_ms, avg_query_wait_time_ms,
    pct_query_wait_time (this row's share of all wait time captured in
    the interval -- the metric MSSQL_WAIT_005/006's conditions check).
    """
    with pg_conn.cursor() as cur:
        if qs_interval_id is None:
            params = [instance_id]
            db_filter = ""
            if database_name:
                db_filter = "AND database_name = %s"
                params.append(database_name)
            cur.execute(f"""
                SELECT qs_interval_id, database_name FROM mssql_qs_interval
                WHERE instance_id = %s {db_filter}
                ORDER BY start_time DESC LIMIT 1
            """, params)
            row = cur.fetchone()
            if not row:
                return []
            qs_interval_id, database_name = row

        cur.execute("""
            SELECT wait_category_desc, qs_plan_id, total_query_wait_time_ms, avg_query_wait_time_ms
            FROM mssql_qs_wait_stats
            WHERE instance_id = %s AND database_name = %s AND qs_interval_id = %s
        """, (instance_id, database_name, qs_interval_id))
        rows = cur.fetchall()

    total = sum(r[2] or 0 for r in rows) or 1
    results = []
    for wait_category_desc, plan_id, total_ms, avg_ms in rows:
        results.append({
            "wait_category_desc": wait_category_desc,
            "qs_plan_id": plan_id,
            "total_query_wait_time_ms": total_ms,
            "avg_wait_ms": avg_ms,
            "pct_query_wait_time": ((total_ms or 0) / total) * 100,
        })
    return sorted(results, key=lambda r: r["pct_query_wait_time"], reverse=True)


# ══════════════════════ EVALUATOR ══════════════════════

class MssqlRuleEngine:
    def __init__(self, rules: list = None):
        self.rules = rules if rules is not None else _load_rules()

    def evaluate_wait_type_rules(self, wait_type_metrics: list) -> list:
        findings = []
        type_rules = [r for r in self.rules if r.get("category") == "mssql_wait_type"]

        for metric in wait_type_metrics:
            context = {
                "wait_pct_of_total": metric["wait_pct_of_total"],
                "avg_wait_ms": metric["avg_wait_ms"],
                "wait_time_ms_delta": metric["wait_time_ms_delta"],
            }
            matched = [r for r in type_rules if _match_event_pattern(r.get("event_pattern", "*"), metric["wait_type"])]
            for rule in matched:
                if evaluate_condition(rule.get("condition", ""), context):
                    findings.append({
                        "rule_id": rule["rule_id"],
                        "category": "mssql_wait_type",
                        "severity": rule.get("severity", "medium"),
                        "title": rule.get("title", ""),
                        "wait_type": metric["wait_type"],
                        "wait_pct_of_total": round(context["wait_pct_of_total"], 2),
                        "avg_wait_ms": round(context["avg_wait_ms"], 2),
                        "root_cause": rule.get("root_cause", ""),
                        "resolution": rule.get("resolution_steps", []),
                        "related_rules": rule.get("related_rules", []),
                    })
                    break  # don't double-fire multiple rules for the same wait_type
        return findings

    def evaluate_wait_category_rules(self, wait_category_metrics: list) -> list:
        findings = []
        cat_rules = [r for r in self.rules if r.get("category") == "mssql_wait_category"]

        for metric in wait_category_metrics:
            context = {
                "pct_query_wait_time": metric["pct_query_wait_time"],
                "avg_wait_ms": metric["avg_wait_ms"] or 0,
            }
            matched = [r for r in cat_rules
                       if _match_event_pattern(r.get("event_pattern", "*"), metric["wait_category_desc"])]
            for rule in matched:
                if evaluate_condition(rule.get("condition", ""), context):
                    findings.append({
                        "rule_id": rule["rule_id"],
                        "category": "mssql_wait_category",
                        "severity": rule.get("severity", "medium"),
                        "title": rule.get("title", ""),
                        "wait_category": metric["wait_category_desc"],
                        "qs_plan_id": metric["qs_plan_id"],
                        "pct_query_wait_time": round(context["pct_query_wait_time"], 2),
                        "avg_wait_ms": round(context["avg_wait_ms"], 2),
                        "root_cause": rule.get("root_cause", ""),
                        "resolution": rule.get("resolution_steps", []),
                        "related_rules": rule.get("related_rules", []),
                    })
                    break
        return findings


def evaluate_wait_findings(pg_conn, instance_id: int, database_name: str = None) -> dict:
    """
    Convenience entry point: fetches both wait-metric tiers and
    evaluates both rule categories against them in one call. Returns
    {"wait_type_findings": [...], "wait_category_findings": [...]}.
    """
    engine = MssqlRuleEngine()

    type_metrics = fetch_wait_type_metrics(pg_conn, instance_id)
    type_findings = engine.evaluate_wait_type_rules(type_metrics)

    cat_metrics = fetch_wait_category_metrics(pg_conn, instance_id, database_name)
    cat_findings = engine.evaluate_wait_category_rules(cat_metrics)

    return {
        "wait_type_findings": type_findings,
        "wait_category_findings": cat_findings,
    }
