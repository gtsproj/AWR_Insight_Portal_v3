"""
debug_mssql_collection.py
============================
Diagnoses exactly why no rows are landing in mssql_dmv_snapshot (or
mssql_qs_interval) despite the collectors reporting "completed
successfully" -- calls run_dmv_collection()/run_query_store_collection()
DIRECTLY (not through subprocess, not through the CLI) so the full,
raw result dict is visible with no ambiguity about what got captured
in stdout vs stderr. Also checks Postgres connectivity and the
instance/snapshot registry state directly, before and after, so a
silent "nothing changed" is visible as exactly that.

This exists because of a real, now-fixed bug: both collectors' own
CLI entry points printed their result summary (including any errors)
to stdout, but never actually exited non-zero when result["errors"]
was non-empty or nothing was collected -- so a caller checking only
the process exit code (like mssql_collector_scheduler.py) saw
"completed successfully" even when the collection genuinely failed
internally. That's fixed now (both collectors correctly exit non-zero
on failure going forward), but this script is still the fastest way
to see EXACTLY what happened on this specific host/instance right now,
with nothing hidden behind subprocess stdout/stderr capture at all.

Usage:
    py debug_mssql_collection.py --host DESKTOP-TT7JK6I --instance-name "SQL SERVER" ^
        --username dar_mssql_collector --password Admin@123 --database TESTDB
"""

import sys
import os
import getpass

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'modules'))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'common'))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'modules', 'mssql'))


def section(title):
    print(f"\n{'='*70}\n{title}\n{'='*70}")


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    parser.add_argument("--port", type=int, default=None)
    parser.add_argument("--trusted-connection", action="store_true")
    parser.add_argument("--username", default=None)
    parser.add_argument("--password", default=None)
    parser.add_argument("--database", action="append", dest="databases")
    args = parser.parse_args()

    if not args.trusted_connection and not args.username:
        parser.error("--username is required unless --trusted-connection is set")

    cfg = {"host": args.host, "instance_name": args.instance_name}
    if args.port:
        cfg["port"] = args.port
    if args.trusted_connection:
        cfg["trusted_connection"] = True
    else:
        password = args.password or getpass.getpass(f"Password for {args.username}@{args.host}: ")
        cfg["username"] = args.username
        cfg["password"] = password

    # ── Step 1: Postgres connectivity ──────────────────────────────
    section("STEP 1: Postgres connectivity")
    try:
        from db import get_db_connection
        from config_loader import load_config
        pg_conn = get_db_connection()
        with pg_conn.cursor() as cur:
            cur.execute("SELECT current_database(), current_user, current_schema(), inet_server_addr(), inet_server_port()")
            db_name, db_user, db_schema, db_host, db_port = cur.fetchone()
        print("OK -- connected to Postgres successfully.")
        print(f"  Actually connected to: host={db_host or 'localhost/socket'} port={db_port} "
              f"database={db_name!r} schema={db_schema!r} as user={db_user!r}")
        conf = load_config().get("database", {})
        print(f"  config/settings.yaml says: host={conf.get('host')!r} port={conf.get('port')!r} "
              f"dbname={conf.get('dbname')!r} user={conf.get('user')!r}")
        print("  If a schema migration was run against a DIFFERENT host/port/database than the")
        print("  one shown above, it changed a different database than this script (and the")
        print("  actual scheduler/collectors) are connected to -- that alone fully explains")
        print("  'the column exists' from one place while this script still can't see it.")

        # Directly confirm, right now, on THIS exact connection -- not
        # assumed from the migration having been run at some point --
        # whether sqlserver_start_time genuinely exists on this table.
        with pg_conn.cursor() as cur:
            cur.execute("""
                SELECT column_name FROM information_schema.columns
                WHERE table_name = 'mssql_dmv_snapshot' ORDER BY ordinal_position
            """)
            cols = [r[0] for r in cur.fetchall()]
        print(f"\n  mssql_dmv_snapshot columns as seen by THIS connection: {cols}")
        if "sqlserver_start_time" in cols:
            print("  sqlserver_start_time IS present here -- STEP 3 below should now work.")
        else:
            print("  sqlserver_start_time is NOT present on THIS specific database/connection --")
            print("  the migration needs to be run against THIS exact host/port/database shown")
            print("  above, not wherever it may have already been run against.")
    except Exception as e:
        print(f"FAILED -- could not connect to Postgres at all: {e}")
        print("This alone would explain zero rows anywhere -- nothing downstream can work")
        print("until this is fixed. Check config/settings.yaml's database section.")
        return

    # ── Step 2: instance registry state (before) ───────────────────
    section("STEP 2: mssql_instance_master state (BEFORE running anything)")
    with pg_conn.cursor() as cur:
        cur.execute(
            "SELECT id, host_name, instance_name, active FROM mssql_instance_master "
            "WHERE host_name = %s AND instance_name = %s",
            (args.host, args.instance_name)
        )
        row = cur.fetchone()
    if row:
        instance_id = row[0]
        print(f"Instance already registered: id={row[0]}, active={row[3]}")
    else:
        instance_id = None
        print("Instance NOT yet registered -- this would be the very first collection "
              "for this exact (host_name, instance_name) pair. That's fine -- "
              "resolve_instance_id() creates it automatically on first use.")

    # ── Step 3: last snapshot state (before) -- directly checks the
    #    min_interval_minutes-skip hypothesis ──────────────────────
    section("STEP 3: mssql_dmv_snapshot -- most recent row for this instance (BEFORE)")
    if instance_id:
        try:
            with pg_conn.cursor() as cur:
                cur.execute(
                    "SELECT snapshot_id, snapshot_time, sqlserver_start_time FROM mssql_dmv_snapshot "
                    "WHERE instance_id = %s ORDER BY snapshot_time DESC LIMIT 1",
                    (instance_id,)
                )
                last = cur.fetchone()
            if last:
                print(f"Most recent snapshot: id={last[0]}, taken at {last[1]}, "
                      f"sqlserver_start_time={last[2]}")
                print("If this timestamp is very recent (within --min-interval-minutes of now), "
                      "that alone would correctly cause the NEXT run to skip -- not a bug, "
                      "expected behavior of the interval-enforcement safeguard.")
            else:
                print("No snapshots yet for this instance -- min_interval_minutes cannot be "
                      "the cause of anything missing; there's nothing to compare against yet.")
        except Exception as e:
            # A failed query leaves this connection's transaction
            # ABORTED -- every later step reuses pg_conn, so without
            # an explicit rollback here, steps 4-6 below would all
            # fail too with a confusing, unrelated-looking
            # "current transaction is aborted" error, hiding whatever
            # they'd have actually shown.
            pg_conn.rollback()
            print(f"Could not query mssql_dmv_snapshot (see STEP 1 above for exactly which "
                  f"database this connection is actually pointed at): {e}")
            print("Continuing to the remaining steps anyway -- this alone doesn't block them.")
    else:
        print("(Instance not registered yet -- no snapshots possible)")

    # ── Step 3.5: Query Store's RAW state, directly on SQL Server --
    #    settles whether this is "nothing closed yet" (Query Store's
    #    own, expected behavior for still-running queries) vs. a
    #    genuine collector/report bug, before guessing further ──────
    section("STEP 3.5: Query Store raw state on SQL Server (bypassing the collector entirely)")
    if not args.databases:
        print("No --database given -- skipping this check (need a specific database to query "
              "Query Store options against).")
    else:
        for db_name in args.databases:
            print(f"\n--- {db_name} ---")
            try:
                import pyodbc
                conn_parts = [f"DRIVER={{ODBC Driver 17 for SQL Server}}", f"SERVER={args.host}"]
                if args.instance_name and args.instance_name != "MSSQLSERVER":
                    conn_parts[-1] += f"\\{args.instance_name}"
                if args.port:
                    conn_parts[-1] += f",{args.port}"
                conn_parts.append("Trusted_Connection=yes" if args.trusted_connection
                                   else f"UID={args.username};PWD={cfg.get('password','')}")
                conn_parts.append(f"DATABASE={db_name}")
                mssql_conn = pyodbc.connect(";".join(conn_parts), timeout=15)
                cur = mssql_conn.cursor()

                cur.execute("SELECT actual_state_desc, desired_state_desc, interval_length_minutes "
                            "FROM sys.database_query_store_options")
                qs_row = cur.fetchone()
                if not qs_row:
                    print("  Query Store options row not found (unexpected).")
                else:
                    print(f"  Query Store: actual_state={qs_row[0]}, desired_state={qs_row[1]}, "
                          f"interval_length_minutes={qs_row[2]}")
                    if qs_row[0] not in ("READ_WRITE", "READ_ONLY"):
                        print("  Query Store is NOT capturing data on this database at all "
                              "(actual_state is neither READ_WRITE nor READ_ONLY) -- this alone "
                              "would fully explain empty SQL sections, independent of anything else.")

                cur.execute("SELECT TOP 5 runtime_stats_interval_id, start_time, end_time "
                            "FROM sys.query_store_runtime_stats_interval ORDER BY runtime_stats_interval_id DESC")
                intervals = cur.fetchall()
                print(f"  Most recent intervals (up to 5, newest first):")
                for iv_id, start, end in intervals:
                    status = "OPEN (still accumulating)" if end is None else "closed"
                    print(f"    id={iv_id} start={start} end={end} [{status}]")
                if intervals and intervals[0][2] is None:
                    print("  The MOST RECENT interval is still OPEN -- any query that started in it")
                    print("  (including one still executing right now, matching what the Activity")
                    print("  Monitor screenshot showed) has NO runtime_stats row yet. This is Query")
                    print("  Store's own behavior, not something the collector or report can work")
                    print("  around -- it will appear once that interval closes and/or the query completes.")

                if intervals:
                    latest_closed = next((iv for iv in intervals if iv[2] is not None), None)
                    if latest_closed:
                        cur.execute(
                            "SELECT COUNT(*) FROM sys.query_store_runtime_stats WHERE runtime_stats_interval_id = ?",
                            latest_closed[0]
                        )
                        count = cur.fetchone()[0]
                        print(f"  Most recent CLOSED interval (id={latest_closed[0]}) has "
                              f"{count} runtime_stats row(s) on SQL Server right now.")
                        if count == 0:
                            print("  Zero rows even for a closed interval -- genuinely no completed")
                            print("  query executions fell inside it (or Query Store only just enabled).")
                mssql_conn.close()
            except Exception as e:
                print(f"  Could not check Query Store state directly: {e}")

    # ── Step 4: run the DMV collector DIRECTLY, print the FULL result ──
    section("STEP 4: Calling run_dmv_collection() directly (bypassing subprocess/CLI entirely)")
    try:
        import dmv_delta_collector as dmv
        result = dmv.run_dmv_collection(cfg, database_names=args.databases)
        print("Full result dict returned:")
        for k, v in result.items():
            print(f"  {k}: {v}")
    except Exception as e:
        import traceback
        print(f"EXCEPTION raised directly (this would NOT have been visible in the "
              f"scheduler's log before today's exit-code fix):")
        traceback.print_exc()
        result = None

    # ── Step 5: run the Query Store collector DIRECTLY, print the FULL result ──
    section("STEP 5: Calling run_query_store_collection() directly")
    try:
        import query_store_collector as qsc
        qs_result = qsc.run_query_store_collection(cfg, database_names=args.databases)
        print("Full result dict returned:")
        for k, v in qs_result.items():
            print(f"  {k}: {v}")
    except Exception as e:
        import traceback
        print(f"EXCEPTION raised directly:")
        traceback.print_exc()

    # ── Step 6: snapshot state AFTER -- did a row actually land? ────
    section("STEP 6: mssql_dmv_snapshot state AFTER running the collector")
    with pg_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM mssql_instance_master WHERE host_name = %s AND instance_name = %s",
            (args.host, args.instance_name)
        )
        row = cur.fetchone()
    if row:
        instance_id = row[0]
        with pg_conn.cursor() as cur:
            cur.execute(
                "SELECT snapshot_id, snapshot_time FROM mssql_dmv_snapshot "
                "WHERE instance_id = %s ORDER BY snapshot_time DESC LIMIT 3",
                (instance_id,)
            )
            rows = cur.fetchall()
        if rows:
            print(f"{len(rows)} most recent snapshot(s) now on record:")
            for snap_id, snap_time in rows:
                print(f"  snapshot_id={snap_id}, taken at {snap_time}")
        else:
            print("STILL ZERO snapshots for this instance after running the collector directly.")
            print("Combined with STEP 4's result dict above, the 'errors' list there is almost")
            print("certainly the direct explanation -- that's the real, underlying failure reason,")
            print("not something hidden further away.")
    else:
        print("Instance still not registered at all -- resolve_instance_id() itself never "
              "succeeded. Check STEP 4's output above for the specific exception/error.")

    section("DONE")
    print("If STEP 4 showed errors but STEP 6 still shows zero snapshots, the errors list")
    print("IS the answer -- whatever's printed there is exactly what's blocking collection.")
    print("Common causes: the SQL Server login lacks VIEW SERVER STATE permission (needed")
    print("for most of the DMVs queried), or a specific database in --database wasn't found.")


if __name__ == "__main__":
    main()
