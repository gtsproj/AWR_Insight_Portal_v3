"""
diagnose_query_context_resolution.py
=======================================
Checks each step of the mssql_qs_plan -> mssql_qs_query ->
mssql_qs_query_text join chain SEPARATELY for specific plan_ids, to
find exactly where it's breaking -- rather than guessing, since
_resolve_query_context's inner joins mean any single missing link
makes the WHOLE result come back empty, hiding which step actually
failed.

Run from the repo root:
    py diagnose_query_context_resolution.py --host DESKTOP-TT7JK6I --plan-ids 129,126,123
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
    parser.add_argument("--database", default="TestDB")
    parser.add_argument("--plan-ids", required=True, help="Comma-separated qs_plan_id values to check")
    args = parser.parse_args()

    plan_ids = [int(x) for x in args.plan_ids.split(",")]

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

    for plan_id in plan_ids:
        print(f"\n{'='*60}\nplan_id={plan_id}\n{'='*60}")

        with conn.cursor() as cur:
            cur.execute("""
                SELECT qs_query_id FROM mssql_qs_plan
                WHERE instance_id=%s AND database_name=%s AND qs_plan_id=%s
            """, (instance_id, args.database, plan_id))
            plan_row = cur.fetchone()
        print(f"  Step 1 -- mssql_qs_plan row exists: {'YES, qs_query_id=' + str(plan_row[0]) if plan_row else 'NO -- this is where the chain breaks'}")
        if not plan_row:
            continue
        qs_query_id = plan_row[0]

        with conn.cursor() as cur:
            cur.execute("""
                SELECT qs_query_text_id, object_name FROM mssql_qs_query
                WHERE instance_id=%s AND database_name=%s AND qs_query_id=%s
            """, (instance_id, args.database, qs_query_id))
            query_row = cur.fetchone()
        print(f"  Step 2 -- mssql_qs_query row exists: {'YES, qs_query_text_id=' + str(query_row[0]) + ', object_name=' + str(query_row[1]) if query_row else 'NO -- this is where the chain breaks'}")
        if not query_row:
            continue
        qs_query_text_id = query_row[0]

        with conn.cursor() as cur:
            cur.execute("""
                SELECT LEFT(query_sql_text, 80) FROM mssql_qs_query_text
                WHERE instance_id=%s AND database_name=%s AND qs_query_text_id=%s
            """, (instance_id, args.database, qs_query_text_id))
            text_row = cur.fetchone()
        print(f"  Step 3 -- mssql_qs_query_text row exists: {'YES: ' + text_row[0] if text_row else 'NO -- this is where the chain breaks'}")

    conn.close()


if __name__ == "__main__":
    main()
