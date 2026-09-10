"""
run_mssql_recommendations.py
===============================
Generates recommendations from the current wait-analysis rule
findings, shows what's stored, and lets you record ground-truth
feedback against a specific recommendation.

Uses the same config/settings.yaml connection as everything else.

Examples:
    py run_mssql_recommendations.py --host DESKTOP-TT7JK6I
        Generates new recommendations (if any) and lists all stored
        ones for that instance.

    py run_mssql_recommendations.py --host DESKTOP-TT7JK6I --list-only
        Skips generation, just shows what's already stored.

    py run_mssql_recommendations.py --feedback <REC_ID> --status CONFIRMED_REAL --reviewed-by Ganesh --notes "Confirmed via manual check"
        Records feedback on a specific recommendation id. Look up
        real ids first with --host <host> or --list-only -- an id
        that doesn't exist yet (e.g. before any recommendations have
        been generated) will fail with a foreign key error, which is
        expected, not a bug -- there's nothing to attach feedback to.

    py run_mssql_recommendations.py --accuracy
        Shows the current accuracy report across all recorded feedback.
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'common'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules', 'mssql'))

from db import get_db_connection
import mssql_recommendation_engine as rec_eng


def _print_recommendation(row):
    (rec_id, generated_at, severity, title, summary, contributing, correlated,
     database_name, affected_object, feedback_status) = row
    tag = "[CORRELATED]" if correlated else ""
    print(f"\n  #{rec_id} [{severity.upper()}] {tag} {title}")
    print(f"    Generated: {generated_at}  |  DB: {database_name or '(instance-wide)'}  |  Object: {affected_object}")
    print(f"    Rules: {contributing}")
    print(f"    Feedback: {feedback_status or 'UNREVIEWED'}")
    print(f"    {summary}")


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=None)
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    parser.add_argument("--database", default=None)
    parser.add_argument("--list-only", action="store_true", help="Skip generation, just show stored recommendations")
    parser.add_argument("--feedback", type=int, default=None, metavar="REC_ID", help="Record feedback on this recommendation id")
    parser.add_argument("--status", default=None, choices=sorted(rec_eng.VALID_STATUSES))
    parser.add_argument("--reviewed-by", default=None)
    parser.add_argument("--notes", default=None)
    parser.add_argument("--accuracy", action="store_true", help="Show the accuracy report and exit")
    args = parser.parse_args()

    conn = get_db_connection()

    if args.accuracy:
        report = rec_eng.accuracy_report(conn)
        print(f"\n{'='*60}\nAccuracy Report\n{'='*60}")
        print(f"Confirmed real:       {report['confirmed_real']}")
        print(f"False positives:      {report['false_positive']}")
        print(f"Needs investigation:  {report['needs_investigation']}")
        print(f"Never reviewed:       {report['never_reviewed']}")
        print(f"Reviewed total:       {report['reviewed_total']}")
        if report['accuracy_rate'] is not None:
            print(f"Accuracy rate:        {report['accuracy_rate']*100:.1f}%")
        else:
            print(f"Accuracy rate:        (not enough reviewed feedback yet)")
        conn.close()
        return

    if args.feedback is not None:
        if not args.status:
            parser.error("--feedback requires --status")
        ok = rec_eng.record_feedback(conn, args.feedback, args.status, args.reviewed_by, args.notes)
        print(f"Feedback {'recorded' if ok else 'FAILED (invalid status)'} for recommendation #{args.feedback}")
        conn.close()
        return

    with conn.cursor() as cur:
        if args.host:
            cur.execute(
                "SELECT id, host_name, instance_name FROM mssql_instance_master "
                "WHERE host_name = %s AND instance_name = %s AND active = true",
                (args.host, args.instance_name)
            )
        else:
            cur.execute("SELECT id, host_name, instance_name FROM mssql_instance_master WHERE active = true")
        instances = cur.fetchall()

    if not instances:
        print("No registered, active instances found.")
        return

    for instance_id, host_name, instance_name in instances:
        print(f"\n{'='*70}\nInstance: {host_name}\\{instance_name}  (id={instance_id})\n{'='*70}")

        if not args.list_only:
            engine = rec_eng.MssqlRecommendationEngine()
            result = engine.evaluate(conn, instance_id, args.database)
            new_count = engine.store_recommendations(conn, result)
            print(f"New recommendations generated this run: {new_count}")

            if result['total_recommendations'] == 0:
                diag = result.get('wait_type_diagnostics', {})
                if diag:
                    nonzero = diag.get('raw_rows', 0) - diag.get('filtered_negative_or_zero', 0)
                    print(f"\nZero recommendations -- here's why, not just that:")
                    print(f"  {diag.get('raw_rows', 0)} distinct wait type(s) tracked, {nonzero} had genuine nonzero activity")
                    print(f"  {diag.get('filtered_benign', 0)} benign, {diag.get('filtered_below_floor', 0)} below the minimum floor, "
                          f"{diag.get('remaining', 0)} eligible for rule evaluation")
                    if diag.get('raw_rows', 0) < 2:
                        print(f"  (fewer than 2 snapshots exist yet, or only 1 -- run the DMV collector again to get a fresh delta)")
                    else:
                        print(f"  If this looks low across the board, the instance is plausibly just quiet right now, not broken.")
                        print(f"  If you expected real findings, re-run the collectors for a fresh snapshot, then re-run this.")

        with conn.cursor() as cur:
            cur.execute("""
                SELECT r.id, r.generated_at, r.severity, r.title, r.summary,
                       r.contributing_rule_ids, r.correlated, r.database_name,
                       r.affected_object, f.feedback_status
                FROM mssql_recommendations r
                LEFT JOIN mssql_recommendation_feedback f ON r.id = f.recommendation_id
                WHERE r.instance_id = %s
                ORDER BY r.generated_at DESC
            """, (instance_id,))
            rows = cur.fetchall()

        print(f"\nAll stored recommendations ({len(rows)}):")
        if not rows:
            print("  (none)")
        for row in rows:
            _print_recommendation(row)

    conn.close()


if __name__ == "__main__":
    main()
