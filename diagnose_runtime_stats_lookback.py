"""
diagnose_runtime_stats_lookback.py
======================================
Checks whether the 5-interval lookback window in
fetch_runtime_stats_metrics() genuinely no longer includes the
intervals where the earlier-seen plans (129/126/123) ran, vs.
something else going wrong -- rather than assuming, since going from
5 rows to 0 could be either.

Run from the repo root:
    py diagnose_runtime_stats_lookback.py --host DESKTOP-TT7JK6I
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'common'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules'))

from db import get_db_connection


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    args = parser.parse_args()

    conn = get_db_connection()
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM mssql_instance_master WHERE host_name = %s AND instance_name = %s AND active = true",
            (args.host, args.instance_name)
        )
        row = cur.fetchone()
    if not row:
        print("No active registered instance found.")
        return
    instance_id = row[0]

    with conn.cursor() as cur:
        cur.execute("""
            SELECT count(DISTINCT qs_interval_id) FROM mssql_qs_runtime_stats WHERE instance_id = %s
        """, (instance_id,))
        total_intervals = cur.fetchone()[0]
        print(f"Total distinct intervals with runtime stats: {total_intervals}")

        cur.execute("""
            SELECT DISTINCT qs_interval_id FROM mssql_qs_runtime_stats
            WHERE instance_id = %s ORDER BY qs_interval_id DESC LIMIT 5
        """, (instance_id,))
        recent_5 = [r[0] for r in cur.fetchall()]
        print(f"The 5 most recent interval_ids (the current lookback window): {recent_5}")

        for plan_id in (129, 126, 123):
            cur.execute("""
                SELECT qs_interval_id, count_executions, avg_query_max_used_memory_kb
                FROM mssql_qs_runtime_stats
                WHERE instance_id = %s AND qs_plan_id = %s
                ORDER BY qs_interval_id DESC
            """, (instance_id, plan_id))
            plan_rows = cur.fetchall()
            print(f"\nplan_id={plan_id}: {len(plan_rows)} total row(s) across ALL history")
            for interval_id, count_exec, avg_mem in plan_rows:
                in_window = "IN the 5-interval window" if interval_id in recent_5 else "aged OUT of the window"
                print(f"  interval={interval_id}  exec={count_exec}  mem_kb={avg_mem}  -- {in_window}")

    conn.close()


if __name__ == "__main__":
    main()
