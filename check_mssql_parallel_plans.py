"""
check_mssql_parallel_plans.py
================================
Checks whether recently-collected Query Store plans actually used
parallelism (is_parallel_plan, populated directly from SQL Server's
own sys.query_store_plan flag -- not inferred or parsed from XML).

Built to test a specific hypothesis: since Ganesh confirmed no other
processes are running on the SQL Server during these scenario tests,
the CXSYNC_PORT wait_type dominance seen across several fintech
workload scenarios is more likely a genuine signal from those
scenarios' own queries choosing parallel plans (plausible given the
table sizes involved -- wl_emi_schedule alone is ~360K rows) than any
kind of external artifact. This checks that directly against what
SQL Server itself already recorded, rather than guessing further.

Run from the repo root:
    py check_mssql_parallel_plans.py --host DESKTOP-TT7JK6I
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'common'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules'))

from db import get_db_connection


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=None)
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    parser.add_argument("--database", default=None)
    parser.add_argument("--limit", type=int, default=30, help="Most recently-seen N plans to check (default 30)")
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

    for instance_id, host_name, instance_name in instances:
        print(f"\n{'='*70}\nInstance: {host_name}\\{instance_name}  (id={instance_id})\n{'='*70}")

        with conn.cursor() as cur:
            params = [instance_id]
            db_filter = ""
            if args.database:
                db_filter = "AND database_name = %s"
                params.append(args.database)
            params.append(args.limit)
            cur.execute(f"""
                SELECT qs_plan_id, database_name, is_parallel_plan, is_forced_plan, first_seen_at
                FROM mssql_qs_plan
                WHERE instance_id = %s {db_filter}
                ORDER BY first_seen_at DESC
                LIMIT %s
            """, params)
            rows = cur.fetchall()

        if not rows:
            print("  (no plans collected yet)")
            continue

        parallel_count = sum(1 for r in rows if r[2])
        print(f"\nMost recent {len(rows)} plans collected:")
        print(f"  {parallel_count} of {len(rows)} ({parallel_count/len(rows)*100:.0f}%) used a PARALLEL plan\n")

        for plan_id, db_name, is_parallel, is_forced, first_seen in rows:
            tag = "[PARALLEL]" if is_parallel else "          "
            print(f"  {tag} plan_id={plan_id:<8} db={db_name:<10} first_seen={first_seen}")

        print(f"\nInterpretation: if a meaningful share of these are [PARALLEL], that directly supports "
              f"the plans themselves choosing parallelism (matching CXSYNC_PORT being a genuine signal, "
              f"not an artifact) -- given no other processes are running, per your own confirmation, this "
              f"is the most direct evidence available without re-running anything.")

    conn.close()


if __name__ == "__main__":
    main()
