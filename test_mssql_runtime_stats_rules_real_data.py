"""
test_mssql_runtime_stats_rules_real_data.py
==============================================
Shows recently-collected Query Store runtime stats above the memory
pre-filter, and the MSSQL_RUNTIME_* findings they produce -- mirrors
the other test_mssql_*_rules_real_data.py scripts' pattern. Uses the
same config/settings.yaml connection as everything else.

Run from the repo root:
    py test_mssql_runtime_stats_rules_real_data.py
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

        metrics = re_mssql.fetch_runtime_stats_metrics(conn, instance_id, args.database)

        if not metrics:
            print("\n(No queries above the memory pre-filter in recent runtime stats -- "
                  "a good sign, not a gap.)")
            continue

        print(f"\n--- Queries above the memory pre-filter ({len(metrics)}) ---")
        for m in metrics:
            mem_mb = (m['avg_query_max_used_memory_kb'] or 0) / 1024
            tag = "[StatMan/auto-stats]" if m.get('is_auto_stats_update') else ("[SELECT INTO #temp]" if m['is_select_into_temp'] else "")
            # Falls back to the query text when object_name is legitimately
            # None (ad-hoc queries, including SQL Server's own internal
            # StatMan statistics-update mechanism, genuinely have no object
            # to name) -- otherwise this row gives no clue what it actually
            # is, even though the text was successfully retrieved.
            obj_display = m['object_name'] or (
                f"(ad-hoc: {m['query_sql_text'][:60].strip()}...)" if m.get('query_sql_text') else "(unresolved)")
            print(f"  plan_id={m['qs_plan_id']:<8} exec={m['count_executions']:<6} "
                  f"avg_mem={mem_mb:6.1f}MB {tag}  obj={obj_display}")

        findings = engine.evaluate_runtime_stats_rules(metrics)
        print(f"\n--- Findings: mssql_runtime ({len(findings)}) ---")
        for f in findings:
            obj_display = f['object_name'] or (
                f"(ad-hoc: {f['query_sql_text'][:60].strip()}...)" if f.get('query_sql_text') else "(unresolved)")
            print(f"  [{f['severity'].upper():6}] {f['rule_id']} -- {f['title']}")
            print(f"           plan_id={f['qs_plan_id']}  obj={obj_display}  "
                  f"exec={f['count_executions']}  select_into_temp={f['is_select_into_temp']}")

    conn.close()


if __name__ == "__main__":
    main()
