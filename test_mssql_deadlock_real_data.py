"""
test_mssql_deadlock_real_data.py
===================================
Shows the full stored detail of captured deadlock events -- event-
level (contested resource, lock modes, database, RCSI status, and the
classified root cause) and process-level (role, app/login context,
and critically the exact DML statement each process was executing).

Uses the same config/settings.yaml connection the collectors and the
wait-rules script already use.

Run from the repo root:
    py test_mssql_deadlock_real_data.py
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'common'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'modules'))

from db import get_db_connection


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=None, help="Filter to a specific registered instance's host_name")
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    parser.add_argument("--limit", type=int, default=10, help="Most recent N events to show (default 10)")
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
        print(f"\n{'='*70}")
        print(f"Instance: {host_name}\\{instance_name}  (id={instance_id})")
        print(f"{'='*70}")

        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, deadlock_time, database_name, process_count, contested_table,
                       contested_index, lock_mode_1, lock_mode_2, rcsi_enabled, deadlock_cause
                FROM mssql_deadlock_events
                WHERE instance_id = %s
                ORDER BY deadlock_time DESC
                LIMIT %s
            """, (instance_id, args.limit))
            events = cur.fetchall()

        print(f"\nTotal deadlock events for this instance: ", end="")
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM mssql_deadlock_events WHERE instance_id = %s", (instance_id,))
            print(cur.fetchone()[0])

        if not events:
            print("\n(No deadlock events captured yet for this instance.)")
            continue

        for (event_id, deadlock_time, database_name, process_count, contested_table,
             contested_index, lock_mode_1, lock_mode_2, rcsi_enabled, deadlock_cause) in events:

            print(f"\n{'-'*70}")
            print(f"Deadlock at {deadlock_time}  (event id={event_id})")
            print(f"{'-'*70}")
            print(f"  Database:          {database_name}")
            print(f"  Contested table:   {contested_table}")
            print(f"  Contested index:   {contested_index or '(none -- table-level lock)'}")
            print(f"  Lock modes:        {lock_mode_1} / {lock_mode_2}")
            print(f"  RCSI enabled:      {rcsi_enabled}")
            print(f"  Process count:     {process_count}")
            print(f"  >>> Classified cause: {deadlock_cause}")

            with conn.cursor() as cur:
                cur.execute("""
                    SELECT role, spid, client_app, login_name, host_name, isolation_level,
                           tran_count, exact_dml_statement, executing_proc, caller_proc
                    FROM mssql_deadlock_processes
                    WHERE deadlock_event_id = %s
                    ORDER BY role DESC
                """, (event_id,))
                processes = cur.fetchall()

            print(f"\n  Participating processes ({len(processes)}):")
            for (role, spid, client_app, login_name, host, isolation_level,
                 tran_count, exact_dml, executing_proc, caller_proc) in processes:
                print(f"\n    [{role}] SPID {spid} -- {client_app} / {login_name} @ {host}")
                print(f"      Isolation level: {isolation_level}  |  Open transactions: {tran_count}")
                if executing_proc:
                    print(f"      Executing procedure: {executing_proc}" +
                          (f"  (called from {caller_proc})" if caller_proc else ""))
                print(f"      Exact DML at deadlock time: {exact_dml}")

    conn.close()


if __name__ == "__main__":
    main()
