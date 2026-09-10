"""
modules/mssql/recommendation_engine.py
=========================================
Orchestration layer sitting above rule_engine.py -- the same relationship
Oracle's recommendation_engine.py has to its own RuleEngine class, just
built as a genuinely separate module here (see rule_engine.py's own
docstring for why). The rule engine evaluates thresholds and produces
individual findings; this module correlates those findings into
synthesized, deduplicated RECOMMENDATIONS, and is where ground-truth
feedback tracking attaches.

Correlation, not just aggregation: every rule already carries a
related_rules field (populated since the first wait rules were
written) specifically for this. When two or more findings that name
each other in related_rules fire together in the same run, that's
independent corroboration of the same underlying issue from different
angles (e.g. MSSQL_WAIT_002's instance-wide LCK_M_* signal and
MSSQL_WAIT_006's Query Store per-query Lock signal both firing is a
stronger, more specific signal than either alone) -- correlated
recommendations are flagged as such and this is meant to eventually
factor into confidence/severity, not just be a cosmetic grouping.

Ground truth: mssql_recommendation_feedback is the actual mechanism
for turning "80-90% accuracy" from an assertion into a computable
number -- record_feedback() is how a DBA's review of a generated
recommendation gets attached, and accuracy_report() computes the real
metric from whatever feedback has accumulated so far.
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
        # wait_type findings have 'wait_type'; wait_category findings
        # have 'wait_category' -- affected_object is whichever this
        # finding actually has, not a hardcoded key name.
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


def generate_recommendations(pg_conn, instance_id: int, database_name: str = None) -> list:
    """
    Main entry point: runs the wait-statistics rule evaluation,
    correlates the findings, and stores synthesized recommendations
    (deduped via row_hash against re-storing the same recommendation
    on every run while the underlying condition persists).

    Returns the list of recommendation dicts that were newly stored
    this run (not ones that were already present -- matches the
    collectors' own "new rows this run" reporting convention).
    """
    wait_findings = re_mssql.evaluate_wait_findings(pg_conn, instance_id, database_name)
    all_findings = wait_findings["wait_type_findings"] + wait_findings["wait_category_findings"]

    if not all_findings:
        return []

    groups = _correlate_findings(all_findings)
    new_recommendations = []

    for group in groups:
        rec = _synthesize_recommendation(group)

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
            existing = cur.fetchone()
            if existing:
                continue  # already generated, not a new recommendation this run

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

        new_recommendations.append(rec)

    pg_conn.commit()
    return new_recommendations


# ══════════════════════ GROUND TRUTH FEEDBACK ══════════════════════

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
