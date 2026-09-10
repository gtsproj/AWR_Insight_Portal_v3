"""
modules/mssql/mssql_recommendation_engine.py
================================================
Orchestration layer above rule_engine.py -- restructured to match
recommendation_engine.py's (the Oracle AWR one, at the project root)
established architecture: a RecommendationEngine class with a
separate evaluate() (pure computation, no side effects) and
store_recommendations() (explicit, opt-in persistence) split, a
module-level run() for programmatic callers, and a main() CLI
supporting both human-readable and --json output.

Named mssql_recommendation_engine.py, not recommendation_engine.py --
the Oracle file already uses that exact name at the project root.
Different paths mean no actual Python import collision on their own,
but once MS SQL work is wired into the same portal process as the
Oracle side, a bare `import recommendation_engine` from either
context would become genuinely ambiguous (whichever module happened
to be imported first would occupy that name in sys.modules for the
rest of the process). A distinct filename removes this risk
entirely, rather than relying on sys.path ordering to keep the two
apart.

Two things this module does that the Oracle one doesn't, both
deliberate and kept (not removed for consistency's sake):

1. CORRELATION -- rule_engine.py's rules carry a related_rules field
   specifically for this. When two or more findings that reference
   each other fire together (e.g. MSSQL_WAIT_002's instance-wide
   LCK_M_* signal and MSSQL_WAIT_006's per-query Query Store Lock
   signal), that's independent corroboration from two different data
   sources, not two disconnected findings -- flagged via
   correlated=true rather than reported separately. Oracle's
   dedup-by-rule_id is a different, simpler operation (collapsing
   repeat firings of the SAME rule); this is additive to that, not a
   replacement -- MS SQL findings are still deduped within a category
   by rule_engine.py itself before this module ever sees them.

2. GROUND TRUTH FEEDBACK -- record_feedback()/accuracy_report() exist
   because there was no existing mechanism to check "80-90% accuracy"
   against, on either side of the codebase. This is additive to the
   established architecture, not a divergence from it.
"""

import os
import sys
import json

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'modules'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from logger_utils import get_logger
from utils import row_hash
import rule_engine as re_mssql

logger = get_logger('mssql_recommendation_engine')

SEVERITY_RANK = {"low": 0, "medium": 1, "high": 2}


def _correlate_findings(findings: list) -> list:
    """
    Groups findings whose rules reference each other via related_rules
    into connected components (a simple graph traversal, not a full
    union-find library -- the graphs here are small, at most a handful
    of nodes). Returns a list of groups, each a list of findings.
    Findings with no correlated partner are returned as their own
    single-element group.

    Builds an UNDIRECTED adjacency graph first, not a directed one --
    the related_rules relationship in the rules file is often
    asymmetric (e.g. MSSQL_WAIT_006's related_rules lists
    MSSQL_WAIT_002, but MSSQL_WAIT_002's own related_rules is empty).
    A one-directional traversal starting from MSSQL_WAIT_002 would
    never discover MSSQL_WAIT_006 even though they're clearly meant
    to correlate -- caught by testing this against exactly that real
    pair before this function was used anywhere.
    """
    by_rule_id = {f["rule_id"]: f for f in findings}
    fired_rule_ids = set(by_rule_id.keys())

    adjacency = {rid: set() for rid in fired_rule_ids}
    for rid in fired_rule_ids:
        for related in by_rule_id[rid].get("related_rules", []):
            if related in fired_rule_ids:
                adjacency[rid].add(related)
                adjacency[related].add(rid)  # the undirected part -- record both directions

    visited = set()
    groups = []
    for rule_id in fired_rule_ids:
        if rule_id in visited:
            continue
        component = []
        queue = [rule_id]
        while queue:
            current = queue.pop()
            if current in visited:
                continue
            visited.add(current)
            component.append(by_rule_id[current])
            for neighbor in adjacency[current]:
                if neighbor not in visited:
                    queue.append(neighbor)
        groups.append(component)

    return groups


def _synthesize_recommendation(group: list) -> dict:
    """
    Builds one recommendation dict from a correlated group of 1+
    findings. Severity is the max across the group -- corroborating
    evidence never lowers urgency. Title and summary are combined for
    groups of 2+, not just the first finding's own text repeated.
    """
    severities = [f.get("severity", "medium") for f in group]
    severity = max(severities, key=lambda s: SEVERITY_RANK.get(s, 1))

    rule_ids = [f["rule_id"] for f in group]
    titles = [f.get("title", "") for f in group]

    if len(group) == 1:
        f = group[0]
        title = f.get("title", "")
        affected_object = f.get("wait_type") or f.get("wait_category")
        pct = f.get("wait_pct_of_total") or f.get("pct_query_wait_time")
        summary = f"{title}. {f.get('root_cause', '')}"
        if pct is not None:
            summary += f" (observed at {pct}% of total wait time.)"
    else:
        affected_object = " / ".join(sorted(set(
            f.get("wait_type") or f.get("wait_category") or "" for f in group
        ) - {""}))
        title = "Correlated finding: " + " + ".join(titles)
        summary_parts = []
        for f in group:
            pct = f.get("wait_pct_of_total") or f.get("pct_query_wait_time")
            obj = f.get("wait_type") or f.get("wait_category")
            summary_parts.append(
                f"{f['rule_id']} ({obj}, {pct}%): {f.get('root_cause', '')}"
            )
        summary = ("Multiple independent signals corroborate the same underlying issue -- "
                   + " | ".join(summary_parts))

    return {
        "severity": severity,
        "title": title,
        "summary": summary,
        "contributing_rule_ids": rule_ids,
        "correlated": len(group) > 1,
        "evidence": group,
        "affected_object": affected_object,
    }


class MssqlRecommendationEngine:

    def evaluate(self, pg_conn, instance_id: int, database_name: str = None) -> dict:
        """
        Runs the wait-statistics rule evaluation, correlates the
        findings, and returns a structured result -- pure computation,
        no persistence (matching the Oracle RecommendationEngine's own
        evaluate()/store_recommendations() split). Call
        store_recommendations() separately to persist.

        Returns:
            {
                "instance_id": ..., "database_name": ...,
                "total_recommendations": N,
                "high": N, "medium": N, "low": N,
                "recommendations": [ { severity, title, summary,
                    contributing_rule_ids, correlated, evidence,
                    affected_object }, ... ]
            }
        """
        logger.info(f"Evaluating recommendations: instance_id={instance_id} database={database_name}")

        wait_findings = re_mssql.evaluate_wait_findings(pg_conn, instance_id, database_name,
                                                          return_diagnostics=True)
        all_findings = wait_findings["wait_type_findings"] + wait_findings["wait_category_findings"]

        groups = _correlate_findings(all_findings)
        recommendations = [_synthesize_recommendation(g) for g in groups]

        recommendations.sort(
            key=lambda r: (-SEVERITY_RANK.get(r["severity"], 1), r["title"])
        )

        result = {
            "instance_id": instance_id,
            "database_name": database_name,
            "total_recommendations": len(recommendations),
            "high": sum(1 for r in recommendations if r["severity"] == "high"),
            "medium": sum(1 for r in recommendations if r["severity"] == "medium"),
            "low": sum(1 for r in recommendations if r["severity"] == "low"),
            "recommendations": recommendations,
            # Included so "zero recommendations" is never ambiguous --
            # distinguishes genuinely healthy data from stale/missing
            # data, the same diagnostic breakdown
            # test_mssql_wait_rules_real_data.py already surfaces, now
            # propagated up through this layer too instead of stopping
            # at the rule-engine level.
            "wait_type_diagnostics": wait_findings.get("wait_type_diagnostics", {}),
        }

        logger.info(f"Recommendations complete: {len(recommendations)} "
                    f"(high={result['high']}, medium={result['medium']}, low={result['low']})")
        return result

    def store_recommendations(self, pg_conn, result: dict) -> int:
        """
        Persists the recommendations in an evaluate() result. Row_hash
        dedups against re-storing the same recommendation on every run
        while the underlying condition persists (the MS SQL
        counterpart to the Oracle side's ON CONFLICT (dbname,
        instance, begin_snap, end_snap, rule_id) upsert -- MS SQL's
        wait-analysis data doesn't have a clean snap-range natural key
        the same way, so a content hash serves the same purpose).

        Returns the number of NEWLY stored recommendations (not ones
        that were already present).
        """
        instance_id = result["instance_id"]
        database_name = result["database_name"]
        stored_count = 0

        for rec in result["recommendations"]:
            hash_input = {
                "rule_ids": sorted(rec["contributing_rule_ids"]),
                "affected_object": rec["affected_object"],
            }
            rec_hash = row_hash(hash_input)

            with pg_conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM mssql_recommendations WHERE instance_id = %s AND row_hash = %s",
                    (instance_id, rec_hash)
                )
                if cur.fetchone():
                    continue  # already stored, not new this run

                cur.execute("""
                    INSERT INTO mssql_recommendations
                        (instance_id, category, severity, title, summary, contributing_rule_ids,
                         correlated, evidence_json, database_name, affected_object, row_hash)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (instance_id, "wait_analysis", rec["severity"], rec["title"], rec["summary"],
                      ",".join(rec["contributing_rule_ids"]), rec["correlated"],
                      json.dumps(rec["evidence"], default=str), database_name,
                      rec["affected_object"], rec_hash))
                rec["id"] = cur.fetchone()[0]
                stored_count += 1

        pg_conn.commit()
        logger.info(f"Stored {stored_count} new recommendations to DB")
        return stored_count


# ── callable interface for programmatic use ────────────────────────────
def run(pg_conn, instance_id: int, database_name: str = None, store: bool = False) -> dict:
    """
    Module-level entry point, matching the Oracle recommendation_engine's
    own run() shape -- avoids callers needing to instantiate the class
    themselves for the common case.
    """
    engine = MssqlRecommendationEngine()
    result = engine.evaluate(pg_conn, instance_id, database_name)
    if store:
        engine.store_recommendations(pg_conn, result)
    return result


# ══════════════════════ GROUND TRUTH FEEDBACK ══════════════════════
# Additive to the Oracle side's architecture, not present there --
# see this module's own docstring for why this exists.

VALID_STATUSES = {"UNREVIEWED", "CONFIRMED_REAL", "FALSE_POSITIVE", "NEEDS_INVESTIGATION"}


def record_feedback(pg_conn, recommendation_id: int, status: str,
                     reviewed_by: str = None, notes: str = None) -> bool:
    """
    Records (or updates) a DBA's review of a generated recommendation --
    the actual ground-truth mechanism. One feedback row per
    recommendation (upsert, not a history log -- see the schema
    comment for why). Returns False if status isn't one of the
    recognized values, rather than silently storing something
    unusable for the accuracy computation later.
    """
    if status not in VALID_STATUSES:
        logger.error(f"Invalid feedback status {status!r} -- must be one of {VALID_STATUSES}")
        return False

    with pg_conn.cursor() as cur:
        cur.execute("""
            INSERT INTO mssql_recommendation_feedback
                (recommendation_id, feedback_status, reviewed_by, reviewed_at, notes, updated_at)
            VALUES (%s, %s, %s, CURRENT_TIMESTAMP, %s, CURRENT_TIMESTAMP)
            ON CONFLICT (recommendation_id) DO UPDATE SET
                feedback_status = EXCLUDED.feedback_status,
                reviewed_by = EXCLUDED.reviewed_by,
                reviewed_at = EXCLUDED.reviewed_at,
                notes = EXCLUDED.notes,
                updated_at = CURRENT_TIMESTAMP
        """, (recommendation_id, status, reviewed_by, notes))
    pg_conn.commit()
    return True


def accuracy_report(pg_conn, instance_id: int = None) -> dict:
    """
    Computes the actual accuracy metric from whatever feedback has
    been recorded so far -- confirmed_real / (confirmed_real +
    false_positive). needs_investigation and unreviewed are reported
    separately, not folded into either side of the ratio, since
    neither one is actually known yet.

    Returns a dict with the raw counts and the computed rate (None if
    there isn't enough reviewed feedback yet to compute one -- 0/0 is
    reported as None, not as 0% or 100%, since neither would be true).
    """
    params = []
    instance_filter = ""
    if instance_id is not None:
        instance_filter = "AND r.instance_id = %s"
        params.append(instance_id)

    with pg_conn.cursor() as cur:
        cur.execute(f"""
            SELECT f.feedback_status, count(*)
            FROM mssql_recommendation_feedback f
            JOIN mssql_recommendations r ON f.recommendation_id = r.id
            WHERE 1=1 {instance_filter}
            GROUP BY f.feedback_status
        """, params)
        counts = dict(cur.fetchall())

        cur.execute(f"""
            SELECT count(*) FROM mssql_recommendations r
            LEFT JOIN mssql_recommendation_feedback f ON r.id = f.recommendation_id
            WHERE f.id IS NULL {instance_filter}
        """, params)
        never_reviewed = cur.fetchone()[0]

    confirmed = counts.get("CONFIRMED_REAL", 0)
    false_pos = counts.get("FALSE_POSITIVE", 0)
    needs_investigation = counts.get("NEEDS_INVESTIGATION", 0)
    reviewed_total = confirmed + false_pos

    accuracy_rate = (confirmed / reviewed_total) if reviewed_total > 0 else None

    return {
        "confirmed_real": confirmed,
        "false_positive": false_pos,
        "needs_investigation": needs_investigation,
        "never_reviewed": never_reviewed,
        "reviewed_total": reviewed_total,
        "accuracy_rate": accuracy_rate,
    }


# ── CLI entry point ───────────────────────────────────────────────────
def main():
    import argparse
    from db import get_db_connection

    p = argparse.ArgumentParser(description="MS SQL Recommendation Engine")
    p.add_argument("--host", required=True, help="Registered instance host_name")
    p.add_argument("--instance-name", default="MSSQLSERVER")
    p.add_argument("--database", default=None)
    p.add_argument("--store", action="store_true", help="Persist findings to DB")
    p.add_argument("--json", action="store_true", help="Output JSON instead of plain text")
    args = p.parse_args()

    conn = get_db_connection()
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM mssql_instance_master WHERE host_name = %s AND instance_name = %s AND active = true",
            (args.host, args.instance_name)
        )
        row = cur.fetchone()
    if not row:
        print(f"No active registered instance for {args.host}\\{args.instance_name}")
        return
    instance_id = row[0]

    engine = MssqlRecommendationEngine()
    result = engine.evaluate(conn, instance_id, args.database)

    if args.store:
        engine.store_recommendations(conn, result)

    if args.json:
        print(json.dumps(result, indent=2, default=str))
        conn.close()
        return

    print(f"\n{'='*60}")
    print(f"Recommendations for {args.host}\\{args.instance_name}")
    print(f"Total: {result['total_recommendations']}  |  "
          f"High: {result['high']}  Medium: {result['medium']}  Low: {result['low']}")
    print(f"{'='*60}\n")

    if result['total_recommendations'] == 0:
        diag = result.get('wait_type_diagnostics', {})
        if diag:
            nonzero = diag.get('raw_rows', 0) - diag.get('filtered_negative_or_zero', 0)
            print(f"Zero recommendations -- here's why, not just that:")
            print(f"  {diag.get('raw_rows', 0)} distinct wait type(s) tracked, {nonzero} had genuine nonzero activity")
            print(f"  {diag.get('filtered_benign', 0)} benign, {diag.get('filtered_below_floor', 0)} below the minimum floor, "
                  f"{diag.get('remaining', 0)} eligible for rule evaluation")
            print(f"  If 'remaining' is 0 and nonzero was also low, this instance is plausibly just quiet right now --")
            print(f"  not a sign anything is broken. If you expected real findings, try re-running the collectors first")
            print(f"  to get a fresh snapshot, then re-run this.\n")

    for i, r in enumerate(result["recommendations"], 1):
        tag = "[CORRELATED]" if r["correlated"] else ""
        print(f"[{i}] [{r['severity'].upper()}] {tag} {r['title']}")
        print(f"     Rules  : {', '.join(r['contributing_rule_ids'])}")
        print(f"     Object : {r['affected_object']}")
        print(f"     {r['summary'][:200]}...")
        print()

    conn.close()


if __name__ == "__main__":
    main()
