"""
test_mssql_plan_rules_real_data.py
=====================================
Shows recently-collected Query Store plans that have an implicit
conversion blocking an index seek -- the Hibernate/JDBC NVARCHAR-vs-
VARCHAR anti-pattern, detected directly from SQL Server's own
PlanAffectingConvert warning in the stored plan XML, not inferred from
wait stats. Mirrors the other test_mssql_*_rules_real_data.py scripts'
pattern. Uses the same config/settings.yaml connection as everything
else.

Run from the repo root:
    py test_mssql_plan_rules_real_data.py
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
    parser.add_argument("--host", default=None)
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    parser.add_argument("--database", default=None)
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
            cur.execute("SELECT id, host_name, instance_name FROM mssql_instance_master WHERE active = true")
        instances = cur.fetchall()

    if not instances:
        print("No registered, active instances found.")
        return

    engine = re_mssql.MssqlRuleEngine()

    for instance_id, host_name, instance_name in instances:
        print(f"\n{'='*70}\nInstance: {host_name}\\{instance_name}  (id={instance_id})\n{'='*70}")

        metrics = re_mssql.fetch_implicit_conversion_metrics(conn, instance_id, args.database)

        if not metrics:
            print("\n(No implicit-conversion-blocking-a-seek warnings found in recently-collected "
                  "plans -- a good sign, not a gap. Only the most severe issue type "
                  "(ConvertIssue='Seek Plan') is checked here; a plan could still have a milder "
                  "Cardinality Estimate conversion warning that this deliberately doesn't flag.)")
            continue

        print(f"\n--- Plans with a seek-blocking implicit conversion ({len(metrics)}) ---")
        for m in metrics:
            print(f"  plan_id={m['qs_plan_id']:<8} db={m['database_name']:<10}")
            print(f"    {m['expression']}")

        findings = engine.evaluate_plan_rules(metrics)
        print(f"\n--- Findings: mssql_plan ({len(findings)}) ---")
        for f in findings:
            print(f"  [{f['severity'].upper():6}] {f['rule_id']} -- {f['title']}")
            print(f"           plan_id={f['qs_plan_id']}  db={f['database_name']}")
            print(f"           {f['expression']}")

    conn.close()


if __name__ == "__main__":
    main()
