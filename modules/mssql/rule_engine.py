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

# Wait types that are present on essentially every SQL Server instance
# regardless of real workload -- internal housekeeping/background
# threads sleeping between their own periodic checks, not query
# activity. Confirmed against multiple independent, credible DBA
# sources (all converging on largely the same list) before use here,
# not assembled from memory -- this is a well-established, widely
# documented exclusion list, not a guess.
#
# SOS_WORK_DISPATCHER specifically verified against Paul Randal's own
# sqlskills.com reference page and an independent deep-dive using
# Extended Events call-stack tracing -- both explicitly confirm it's
# benign (idle worker threads waiting for work) and note it commonly
# shows up as the #1 wait type on SQL Server 2019+, which is exactly
# what a real run against a live instance showed here: 68.59% of total
# wait time, before this fix, on an instance with no other findings.
# Without this filter, wait_pct_of_total is computed against a
# denominator dominated by background noise, silently diluting every
# genuine workload-related wait type's apparent share -- not a crash,
# a quietly wrong percentage, the same class of issue this project has
# caught and fixed before.
BENIGN_WAIT_TYPES = frozenset([
    "SLEEP_TASK", "SLEEP_SYSTEMTASK", "SLEEP_TEMPDBSTARTUP", "SLEEP_DBSTARTUP",
    "SLEEP_DCOMSTARTUP", "SLEEP_MASTERDBREADY", "SLEEP_MASTERMDREADY",
    "SLEEP_MASTERUPGRADED", "SLEEP_MSDBSTARTUP", "SLEEP_WAITTASK",
    "SLEEP_WORKER_POOL_INITIALIZATION", "SLEEP_USERTASK", "SLEEP_DBTASK",
    "WAITFOR", "WAITFOR_TASKSHUTDOWN",
    "LAZYWRITER_SLEEP",
    "SQLTRACE_BUFFER_FLUSH", "SQLTRACE_INCREMENTAL_FLUSH_SLEEP",
    "SQLTRACE_WAIT_ENTRIES", "SQL_TRACE_RECONFIGURE",
    "LOGMGR_QUEUE", "CHECKPOINT_QUEUE",
    "REQUEST_FOR_DEADLOCK_SEARCH",
    "XE_TIMER_EVENT", "XE_DISPATCHER_WAIT",
    "BROKER_TO_FLUSH", "BROKER_TASK_STOP", "BROKER_EVENTHANDLER", "BROKER_TRANSMITTER",
    "DISPATCHER_QUEUE_SEMAPHORE",
    "FT_IFTS_SCHEDULER_IDLE_WAIT",
    "XIO_IDLE", "SNI_HTTP_ACCEPT",
    "DBMIRROR_EVENTS_QUEUE", "DBMIRROR_DBM_EVENT", "DBMIRROR_WORKER_QUEUE",
    "ONDEMAND_TASK_QUEUE", "SERVER_IDLE_CHECK",
    "HADR_WORK_QUEUE", "HADR_FILESTREAM_IOMGR_IOCOMPLETION", "HADR_TIMER_TASK",
    "HADR_CLUSAPI_CALL", "HADR_LOGCAPTURE_WAIT", "HADR_NOTIFICATION_DEQUEUE",
    "SP_SERVER_DIAGNOSTICS_SLEEP",
    "CLR_AUTO_EVENT", "CLR_MANUAL_EVENT", "CLR_SEMAPHORE",
    "WAIT_XTP_OFFLINE_CKPT_NEW_LOG", "WAIT_XTP_HOST_WAIT",
    "KSOURCE_WAKEUP", "DIRTY_PAGE_POLL", "RESOURCE_QUEUE",
    "SOS_WORK_DISPATCHER",
    # Added after two more real-instance findings surfaced them:
    "QDS_PERSIST_TASK_MAIN_LOOP_SLEEP",           # Query Store's own persistence-task
    "QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP",  # sleep loops, confirmed benign
    "CXCONSUMER",  # NOT a CXPACKET-equivalent needing its own rule -- the opposite.
                   # SQL Server deliberately split CXPACKET into CXPACKET (still
                   # actionable, still MSSQL_WAIT_003's target) and CXCONSUMER
                   # (the "good"/expected side of parallelism) specifically so
                   # the benign half wouldn't be mistaken for a real problem --
                   # confirmed against Paul Randal's own reference and multiple
                   # other sources ("make sure to add CXCONSUMER to the wait
                   # types ignored by your monitoring tools"). Initially assumed
                   # this needed a new rule; the research corrected that.
    "QDS_ASYNC_QUEUE",  # Query Store's async persist-queue task sleeping between
                        # scheduled writes -- confirmed benign directly by Paul
                        # Randal in a public forum reply ("Is this a wait type
                        # that can be put on the ignore-list?" -> "Yup - entirely
                        # expected"), and his own reference page uses the same
                        # "I usually filter out as benign" wording as his other
                        # confirmed-benign entries. Large delta values are
                        # expected and not alarming -- it only flushes to
                        # sys.dm_os_wait_stats in bursts (on Query Store
                        # config change, restart, or its own periodic flush),
                        # not continuously, so a big number here reflects
                        # accumulated background sleep time, not sustained
                        # real-time contention. One dissenting source exists
                        # (unlike SOS_WORK_DISPATCHER, which had none) --
                        # if a future instance shows this dominating alongside
                        # other genuine symptoms, it's worth a second look
                        # rather than treating this exclusion as absolute.
])

# Absolute floor, in ms, below which a wait_type's total delta is too
# small to mean anything, REGARDLESS of its percentage share of total
# wait time. This is a genuinely different problem from
# BENIGN_WAIT_TYPES above: some wait types (the PREEMPTIVE_OS_* family
# especially) are NOT always benign the way SOS_WORK_DISPATCHER always
# is -- PREEMPTIVE_OS_AUTHENTICATIONOPS running high can mean a real
# Active Directory/Domain Controller performance problem, confirmed
# against multiple DBA sources -- so blanket-excluding the whole
# PREEMPTIVE_* family the way BENIGN_WAIT_TYPES does for genuinely
# always-irrelevant types would be wrong; it would permanently hide a
# real signal at scale, not just suppress noise.
#
# A real run against a near-idle instance showed exactly why a floor
# is still needed even so: PAGEIOLATCH_SH fired MSSQL_WAIT_001 as HIGH
# severity on a 50ms total delta (26.88% of an ~186ms total across
# every wait type) -- a technically-correct percentage computed from
# numbers too small to represent a real problem on any system. The
# same multiple sources that discuss PREEMPTIVE_OS_AUTHENTICATIONOPS
# as a genuine problem when high are explicit that sub-millisecond-
# average, small-total values aren't worth worrying about, which is
# the same "small numbers, even if 100% of a tiny total, aren't a
# finding" principle this floor encodes generally rather than
# per-wait-type.
#
# 1000ms (1 second) of total wait time across the delta window is a
# conservative, reasonable starting floor, not an empirically-tuned
# one -- like several other thresholds in this project's rules, this
# may need adjusting once real production-scale (not near-idle
# test-instance) data is available to tune against.
MIN_WAIT_TIME_MS_DELTA = 1000

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

def fetch_wait_type_metrics(pg_conn, instance_id: int, snapshot_id: int = None,
                              return_diagnostics: bool = False):
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

    return_diagnostics: when True, returns (results, diagnostics) instead
    of just results. diagnostics reports how many wait_type rows existed
    in the raw delta before filtering, and how many were removed by each
    filter reason -- added after a real run returned an empty top-10 list
    with no way to tell whether that meant "genuinely no wait activity"
    or "something had activity and got silently filtered out." Default
    is False so every existing caller's behavior is unchanged.
    """
    diag = {"raw_rows": 0, "filtered_negative_or_zero": 0,
            "filtered_benign": 0, "filtered_below_floor": 0, "remaining": 0}

    with pg_conn.cursor() as cur:
        if snapshot_id is None:
            cur.execute(
                "SELECT snapshot_id, snapshot_time FROM mssql_dmv_snapshot "
                "WHERE instance_id = %s ORDER BY snapshot_time DESC LIMIT 1",
                (instance_id,)
            )
            row = cur.fetchone()
            if not row:
                return ([], diag) if return_diagnostics else []
            snapshot_id, latest_time = row
        else:
            cur.execute(
                "SELECT snapshot_time FROM mssql_dmv_snapshot WHERE snapshot_id = %s",
                (snapshot_id,)
            )
            row = cur.fetchone()
            if not row:
                return ([], diag) if return_diagnostics else []
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
            return ([], diag) if return_diagnostics else []
        prev_snapshot_id, prev_time = prev_row

        elapsed_seconds = (latest_time - prev_time).total_seconds()
        if elapsed_seconds <= 0:
            return ([], diag) if return_diagnostics else []

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

    diag["raw_rows"] = len(rows)

    # Filter out negative deltas (a service restart between snapshots
    # resets the cumulative counters -- a negative delta here means
    # exactly that, not a real decrease, and should be excluded rather
    # than reported as a nonsensical negative wait time), zero-delta
    # rows (no new waits of this type since the previous snapshot),
    # benign background wait types (BENIGN_WAIT_TYPES) -- confirmed
    # against a real instance run: without this filter,
    # SOS_WORK_DISPATCHER alone consumed 68.59% of total wait time,
    # silently diluting every genuine workload wait's computed share
    # and producing zero findings despite the raw data being real --
    # and, separately, waits below MIN_WAIT_TIME_MS_DELTA in absolute
    # terms -- confirmed against a second real run: PAGEIOLATCH_SH
    # fired a HIGH-severity finding on a 50ms total delta out of an
    # ~186ms total across every wait type on a near-idle instance,
    # technically correct at 26.88% share but not a real problem at
    # that magnitude.
    diag["filtered_negative_or_zero"] = sum(1 for wt, d, t in rows if d <= 0)
    diag["filtered_benign"] = sum(1 for wt, d, t in rows if d > 0 and wt in BENIGN_WAIT_TYPES)
    diag["filtered_below_floor"] = sum(
        1 for wt, d, t in rows if d > 0 and wt not in BENIGN_WAIT_TYPES and d < MIN_WAIT_TIME_MS_DELTA
    )
    clean = [(wt, d, t) for wt, d, t in rows
             if d > 0 and wt not in BENIGN_WAIT_TYPES and d >= MIN_WAIT_TIME_MS_DELTA]
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
    diag["remaining"] = len(results)
    results = sorted(results, key=lambda r: r["wait_pct_of_total"], reverse=True)
    return (results, diag) if return_diagnostics else results


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
