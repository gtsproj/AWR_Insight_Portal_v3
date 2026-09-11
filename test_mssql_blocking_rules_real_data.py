"""
test_mssql_blocking_rules_real_data.py
=========================================
Shows the raw blocking snapshot metrics and the MSSQL_BLOCK_* findings
they produce, mirroring test_mssql_wait_rules_real_data.py's pattern
for the wait-statistics category. Uses the same config/settings.yaml
connection as everything else.

Run from the repo root:
    py test_mssql_blocking_rules_real_data.py
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

        metrics = re_mssql.fetch_blocking_metrics(conn, instance_id)

        if not metrics:
            print("\n(No blocking activity in the most recent snapshot -- a good sign, not a gap.)")
            continue

        print(f"\n--- Real blocking snapshot ({len(metrics)} blocked session(s)) ---")
        for m in metrics:
            wait_s = m['wait_time_ms'] / 1000
            print(f"  session {m['session_id']:<6} blocked by {str(m['blocking_session_id']):<6} "
                  f"waited {wait_s:6.1f}s  resource_type={m['resource_type'] or '?':<8} "
                  f"blocker's total blocked count={m['blocked_count']}  db={m['database_name']}")

        findings = engine.evaluate_blocking_rules(metrics)
        print(f"\n--- Findings: mssql_blocking ({len(findings)}) ---")
        if not findings:
            print("  (none -- blocking activity present but below every rule's threshold, or no lock "
                  "escalation/head-blocker pattern detected)")
        for f in findings:
            print(f"  [{f['severity'].upper():6}] {f['rule_id']} -- {f['title']}")
            if f['rule_id'] == 'MSSQL_BLOCK_003':
                print(f"           head blocker session={f['session_id']}  blocking {f.get('blocked_count')} sessions")
            else:
                print(f"           session={f['session_id']}  blocked_by={f['blocking_session_id']}  "
                      f"resource_type={f.get('resource_type')}  wait_time_ms={f.get('wait_time_ms')}")

    conn.close()


if __name__ == "__main__":
    main()
