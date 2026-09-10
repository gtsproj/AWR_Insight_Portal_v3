"""
test_mssql_wait_rules_real_data.py
====================================
Runs the MS SQL wait-statistics rule engine against whatever real data
is already sitting in Postgres from the two collectors' proven runs --
not synthetic test data this time. Uses the same config/settings.yaml
connection the collectors themselves use, so no connection details
need to be typed in.

Run from the repo root:
    py test_mssql_wait_rules_real_data.py

Or target a specific host/instance if more than one is registered:
    py test_mssql_wait_rules_real_data.py --host DESKTOP-TT7JK6I --instance-name MSSQLSERVER
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'common'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules', 'mssql'))

from db import get_db_connection
import rule_engine as re_mssql


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=None, help="Filter to a specific registered instance's host_name")
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    parser.add_argument("--database", default=None, help="Database name for the Query Store tier (omit to use whichever has the most recent interval)")
    args = parser.parse_args()

    conn = get_db_connection()

    with conn.cursor() as cur:
        if args.host:
            cur.execute(
                "SELECT id, host_name, instance_name FROM mssql_instance_master "
                "WHERE host_name = %s AND instance_name = %s AND active = true",
                (args.host, args.instance_name)
            )
        else:
            cur.execute(
                "SELECT id, host_name, instance_name FROM mssql_instance_master WHERE active = true"
            )
        instances = cur.fetchall()

    if not instances:
        print("No registered, active instances found in mssql_instance_master.")
        print("Register one first, or check --host/--instance-name if you passed them.")
        return

    for instance_id, host_name, instance_name in instances:
        print(f"\n{'='*70}")
        print(f"Instance: {host_name}\\{instance_name}  (id={instance_id})")
        print(f"{'='*70}")

        # ── How much real data actually exists ──
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM mssql_dmv_snapshot WHERE instance_id = %s", (instance_id,))
            snapshot_count = cur.fetchone()[0]
            cur.execute(
                "SELECT count(*) FROM mssql_qs_interval WHERE instance_id = %s AND (%s IS NULL OR database_name = %s)",
                (instance_id, args.database, args.database)
            )
            interval_count = cur.fetchone()[0]

        print(f"DMV snapshots collected: {snapshot_count}  |  Query Store intervals collected: {interval_count}")

        engine = re_mssql.MssqlRuleEngine()

        if snapshot_count < 2:
            print(f"\n(Only {snapshot_count} DMV snapshot(s) -- wait_type findings need at least 2 to compute a "
                  f"delta. Run the DMV collector again to get a second snapshot, then re-run this.)")
        else:
            type_metrics, diag = re_mssql.fetch_wait_type_metrics(conn, instance_id, return_diagnostics=True)
            nonzero = diag['raw_rows'] - diag['filtered_negative_or_zero']
            print(f"\n--- wait_type filtering breakdown ---")
            print(f"  {diag['raw_rows']} distinct wait type(s) tracked by the instance, compared across the two snapshots")
            print(f"  {diag['filtered_negative_or_zero']} had NO new activity in this window (delta=0 -- normal; most wait "
                  f"types sit idle most of the time) or a negative delta (counter reset, e.g. a service restart)")
            print(f"  -> {nonzero} had genuine nonzero activity in this window, of which:")
            print(f"       {diag['filtered_benign']} excluded: known benign background waits (SOS_WORK_DISPATCHER, etc.)")
            print(f"       {diag['filtered_below_floor']} excluded: below the {re_mssql.MIN_WAIT_TIME_MS_DELTA}ms minimum floor")
            print(f"       {diag['remaining']} remaining, eligible for rule evaluation")

            print(f"\n--- Real wait_type metrics (top 10 by share of total wait time) ---")
            if not type_metrics:
                print("  (none -- see the filtering breakdown above for why)")
            for m in type_metrics[:10]:
                print(f"  {m['wait_type']:<30} pct={m['wait_pct_of_total']:6.2f}%  "
                      f"avg_ms={m['avg_wait_ms']:8.1f}  delta_ms={m['wait_time_ms_delta']}")

            type_findings = engine.evaluate_wait_type_rules(type_metrics)
            print(f"\n--- Findings: mssql_wait_type ({len(type_findings)}) ---")
            if not type_findings:
                print("  (none -- either genuinely healthy, or nothing matched a rule's event_pattern/condition)")
            for f in type_findings:
                print(f"  [{f['severity'].upper():6}] {f['rule_id']} -- {f['title']}")
                print(f"           wait_type={f['wait_type']}  pct={f['wait_pct_of_total']}%  avg_ms={f['avg_wait_ms']}")

        if interval_count == 0:
            print(f"\n(No Query Store intervals collected yet for this filter -- "
                  f"wait_category findings need at least one completed interval.)")
        else:
            cat_metrics, interval_meta = re_mssql.fetch_wait_category_metrics(
                conn, instance_id, args.database, return_interval_meta=True)

            import datetime
            age_str = ""
            if interval_meta.get("end_time"):
                age_seconds = (datetime.datetime.now() - interval_meta["end_time"]).total_seconds()
                age_str = f", ended {age_seconds:.0f}s ago"

            print(f"\n--- Real wait_category metrics (Query Store interval #{interval_meta.get('qs_interval_id')}"
                  f"{age_str}) ---")
            print(f"  NOTE: this is always 'the most recent interval' -- if that number/age matches a previous "
                  f"run's, you're looking at the SAME interval again, not fresh data (Query Store hasn't closed "
                  f"a new one yet between checks). A signal that seems to persist across runs may just be this, "
                  f"not a genuinely ongoing condition.")
            for m in cat_metrics:
                print(f"  {m['wait_category_desc']:<20} pct={m['pct_query_wait_time']:6.2f}%  "
                      f"avg_ms={float(m['avg_wait_ms'] or 0):8.1f}  plan_id={m['qs_plan_id']}")

            cat_findings = engine.evaluate_wait_category_rules(cat_metrics)
            print(f"\n--- Findings: mssql_wait_category ({len(cat_findings)}) ---")
            if not cat_findings:
                print("  (none -- either genuinely healthy, or nothing matched a rule's event_pattern/condition)")
            for f in cat_findings:
                print(f"  [{f['severity'].upper():6}] {f['rule_id']} -- {f['title']}")
                print(f"           wait_category={f['wait_category']}  plan_id={f['qs_plan_id']}  "
                      f"pct={f['pct_query_wait_time']}%")

    conn.close()


if __name__ == "__main__":
    main()
