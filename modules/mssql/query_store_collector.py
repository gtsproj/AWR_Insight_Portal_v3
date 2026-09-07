"""
modules/mssql/query_store_collector.py
========================================
Pulls completed sys.query_store_* intervals into mssql_qs_query_text /
query / plan / runtime_stats / wait_stats -- the "native interval pull"
collection model (MS SQL Analysis Model doc, Section 4.2). Unlike the
cumulative-DMV collector (not yet built), Query Store has already
aggregated this data into its own intervals by the time we read it --
our job is just to pull completed intervals on a schedule and store
them, no delta math needed.

Connection pattern mirrors modules/oracle_live_query.py directly, per
the design doc's Section 4.1 -- pyodbc's connection-timeout and
cursor.execute pattern support the same shape (a single shared
connection helper, a configurable timeout, per-query try/except so one
failure doesn't take down a batch) without needing a different
approach.

Licensing: checks is_db_type_licensed("mssql") at the top of
run_query_store_collection() -- the extension point built for exactly
this in modules/license_engine.py.

IMPORTANT — not yet tested against a live SQL Server. Every DMV/Query
Store column referenced was verified against current Microsoft
documentation during the schema-design pass (see schema/mssql_qs_tables.sql
and the Analysis Model design doc), but this module itself has only
been tested at the Python level (query-string construction, row_hash
computation, mocked pyodbc connections) -- there is no SQL Server
available in the environment this was built in. Ganesh: please run
this against your test instance and report back whatever breaks --
expect some. This mirrors the exact pattern that caught real bugs in
the PL/SQL Performance test-data script (STANDARD_HASH, integer
overflow) -- first real-instance runs surfacing issues is normal, not
a sign something was rushed.
"""

import os
import sys
import logging

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))
# Also needed: license_engine.py and db.py's sibling modules live in
# the top-level modules/ folder, not common/ -- this file lives one
# level deeper, in modules/mssql/, so that parent directory needs to
# be added explicitly too, or `from license_engine import ...` below
# fails with ModuleNotFoundError (confirmed by an actual run against
# a real Windows install -- common/ alone wasn't enough).
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'modules'))
# And this file's own directory, for the shared connection.py sibling
# module -- matching the same flat sys.path-import convention used
# throughout this codebase (from utils import ..., from db import ...)
# rather than package-relative imports.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from logger_utils import get_logger
from utils import row_hash
from connection import (
    mssql_connect as _mssql_connect,
    handle_datetimeoffset as _handle_datetimeoffset,
    to_naive_utc as _to_naive_utc,
    resolve_instance_id as _resolve_instance_id,
    QUERY_TIMEOUT_SECONDS,
)

logger = get_logger('mssql_query_store_collector')

try:
    from config_loader import load_config
    _cfg = load_config() or {}
except Exception:
    _cfg = {}

# QUERY_TIMEOUT_SECONDS now comes from the shared connection.py import
# above -- removed the duplicate local computation that used to be
# here (it would have silently shadowed the import otherwise).

# How many completed intervals to pull per collection run, per database.
# Bounded so a database that hasn't been collected in a long time (or
# ever) doesn't try to pull an unbounded backlog in one run -- mirrors
# the PL/SQL Performance queries' own timeout-safety-net philosophy:
# bound the work, don't let one slow/large pull consume unbounded time.
MAX_INTERVALS_PER_RUN = int(_cfg.get("mssql", {}).get("max_qs_intervals_per_run", 50))


# _handle_datetimeoffset, _to_naive_utc, _mssql_connect now live in
# the shared connection.py (imported above) -- removed the duplicate
# definitions that used to be here.



def _is_query_store_enabled(conn, database_name: str) -> bool:
    """
    Explicit capability check per database (Analysis Model doc
    Section 4.4) -- Query Store is not on by default even on SQL
    Server 2016+, and a meaningful fraction of real-world databases
    will have it off. Checking this BEFORE attempting to pull data,
    rather than treating an empty result as "nothing to report" --
    the same honesty standard already applied throughout the Oracle
    side's rule engine (SGA_001/SQL_005-style genuinely-blocked
    flagging, not a silently-empty result presented as "all clear").
    """
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT actual_state FROM sys.database_query_store_options "
                "WHERE 1=1"  # actual_state is a database-scoped view;
                             # the connection's current database context
                             # determines which database this reads
            )
            row = cur.fetchone()
            # actual_state: 0=OFF, 1=READ_ONLY, 2=READ_WRITE
            return row is not None and row[0] in (1, 2)
    except Exception as e:
        logger.warning(f"Could not check Query Store status for {database_name}: {e}")
        return False


# _resolve_instance_id now lives in the shared connection.py
# (imported above) -- removed the duplicate definition.



def run_query_store_collection(mssql_cfg: dict, database_names: list = None) -> dict:
    """
    Main entry point. Pulls completed Query Store intervals for the
    given databases (or all Query-Store-enabled databases on the
    instance if database_names is None) into the mssql_qs_* tables.

    Returns a summary dict: {"databases_processed": [...], "databases_skipped": [...],
    "intervals_collected": N, "errors": [...]}
    """
    from license_engine import is_db_type_licensed
    if not is_db_type_licensed("mssql"):
        logger.info("MS SQL Server not licensed -- skipping Query Store collection")
        return {"databases_processed": [], "databases_skipped": [], "intervals_collected": 0,
                "errors": ["mssql not licensed"]}

    summary = {"databases_processed": [], "databases_skipped": [],
               "intervals_collected": 0, "errors": []}

    host_name = mssql_cfg["host"]
    instance_name = mssql_cfg.get("instance_name", "MSSQLSERVER")

    try:
        instance_id = _resolve_instance_id(host_name, instance_name)
    except Exception as e:
        logger.error(f"Instance resolution failed: {e}")
        summary["errors"].append(str(e))
        return summary

    # Discover databases if not explicitly given
    if database_names is None:
        try:
            conn = _mssql_connect({**mssql_cfg, "database": "master"})
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT name FROM sys.databases "
                        "WHERE database_id > 4 AND state = 0"  # exclude system DBs, only ONLINE
                    )
                    database_names = [r[0] for r in cur.fetchall()]
            finally:
                conn.close()
        except Exception as e:
            logger.error(f"Database discovery failed: {e}")
            summary["errors"].append(f"database discovery: {e}")
            return summary

    for db_name in database_names:
        try:
            conn = _mssql_connect({**mssql_cfg, "database": db_name})
        except Exception as e:
            logger.warning(f"Could not connect to database {db_name}: {e}")
            summary["databases_skipped"].append(db_name)
            summary["errors"].append(f"{db_name}: connect failed: {e}")
            continue

        try:
            if not _is_query_store_enabled(conn, db_name):
                logger.info(f"Query Store not enabled on {db_name} -- skipping")
                summary["databases_skipped"].append(db_name)
                continue

            n = _collect_database(conn, instance_id, db_name)
            summary["intervals_collected"] += n
            summary["databases_processed"].append(db_name)
        except Exception as e:
            logger.error(f"Collection failed for {db_name}: {e}")
            summary["errors"].append(f"{db_name}: {e}")
        finally:
            try:
                conn.close()
            except Exception:
                pass

    return summary


def _collect_database(conn, instance_id: int, db_name: str) -> int:
    """
    Collect completed Query Store intervals for one database. Returns
    the number of intervals newly collected.

    Only pulls intervals that have already ENDED (end_time IS NOT NULL
    and in the past) -- the current, still-accumulating interval would
    give incomplete and changing data if pulled now and would need to
    be re-pulled differently next run; simpler and correct to just wait
    for it to close.
    """
    from db import get_db_connection

    with conn.cursor() as cur:
        cur.execute(f"""
            SELECT TOP {MAX_INTERVALS_PER_RUN}
                   runtime_stats_interval_id, start_time, end_time
            FROM sys.query_store_runtime_stats_interval
            WHERE end_time IS NOT NULL AND end_time < SYSDATETIME()
            ORDER BY runtime_stats_interval_id DESC
        """)
        intervals = cur.fetchall()

    if not intervals:
        return 0

    pg_conn = get_db_connection()
    collected = 0
    try:
        for interval_id, raw_start_time, raw_end_time in intervals:
            # DATETIMEOFFSET columns -- normalize to naive UTC before
            # they reach anything else (comparisons, the eventual
            # Postgres INSERT). See _to_naive_utc's docstring for why
            # this matters beyond just avoiding a crash.
            start_time = _to_naive_utc(raw_start_time)
            end_time = _to_naive_utc(raw_end_time)
            # Already-collected check -- uq_mssql_qs_interval (instance_id,
            # database_name, qs_interval_id) makes this idempotent even
            # without this pre-check, but checking first avoids
            # re-pulling query_text/query/plan/runtime_stats/wait_stats
            # for an interval already fully collected, which is real
            # wasted work against the live SQL Server on every run.
            with pg_conn.cursor() as pg_cur:
                pg_cur.execute(
                    "SELECT 1 FROM mssql_qs_interval "
                    "WHERE instance_id = %s AND database_name = %s AND qs_interval_id = %s",
                    (instance_id, db_name, interval_id)
                )
                if pg_cur.fetchone():
                    continue

            _collect_interval(conn, pg_conn, instance_id, db_name, interval_id, start_time, end_time)
            collected += 1
        pg_conn.commit()
    except Exception:
        pg_conn.rollback()
        raise
    finally:
        pg_conn.close()

    return collected


def _collect_interval(conn, pg_conn, instance_id: int, db_name: str,
                       interval_id: int, start_time, end_time) -> None:
    """Collect one completed interval's query text, query, plan,
    runtime_stats, and wait_stats rows."""

    # ── interval record itself ──────────────────────────────────
    interval_rec = {
        "instance_id": instance_id, "database_name": db_name,
        "qs_interval_id": interval_id, "start_time": start_time, "end_time": end_time,
    }
    interval_rec["row_hash"] = row_hash(interval_rec)
    with pg_conn.cursor() as pg_cur:
        pg_cur.execute("""
            INSERT INTO mssql_qs_interval
                (instance_id, database_name, qs_interval_id, start_time, end_time, row_hash)
            VALUES (%(instance_id)s, %(database_name)s, %(qs_interval_id)s,
                    %(start_time)s, %(end_time)s, %(row_hash)s)
            ON CONFLICT (instance_id, database_name, qs_interval_id) DO NOTHING
        """, interval_rec)

    # ── runtime_stats + wait_stats for plans active in this interval ──
    with conn.cursor() as cur:
        cur.execute("""
            SELECT rs.runtime_stats_id, rs.plan_id, rs.execution_type_desc,
                   rs.count_executions, rs.avg_duration, rs.avg_cpu_time,
                   rs.avg_logical_io_reads, rs.avg_physical_io_reads,
                   rs.avg_logical_io_writes, rs.avg_dop,
                   rs.avg_query_max_used_memory, rs.avg_rowcount,
                   rs.avg_log_bytes_used
            FROM sys.query_store_runtime_stats rs
            WHERE rs.runtime_stats_interval_id = ?
        """, interval_id)
        runtime_rows = cur.fetchall()

    plan_ids_seen = set()
    for r in runtime_rows:
        rs_rec = {
            "instance_id": instance_id, "database_name": db_name,
            "qs_runtime_stats_id": r[0], "qs_plan_id": r[1], "qs_interval_id": interval_id,
            "execution_type_desc": r[2], "count_executions": r[3],
            "avg_duration_us": r[4], "avg_cpu_time_us": r[5],
            "avg_logical_io_reads": r[6], "avg_physical_io_reads": r[7],
            "avg_logical_io_writes": r[8], "avg_dop": r[9],
            "avg_query_max_used_memory_kb": r[10], "avg_rowcount": r[11],
            "avg_log_bytes_used": r[12],
        }
        rs_rec["row_hash"] = row_hash(rs_rec)
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_qs_runtime_stats
                    (instance_id, database_name, qs_runtime_stats_id, qs_plan_id, qs_interval_id,
                     execution_type_desc, count_executions, avg_duration_us, avg_cpu_time_us,
                     avg_logical_io_reads, avg_physical_io_reads, avg_logical_io_writes, avg_dop,
                     avg_query_max_used_memory_kb, avg_rowcount, avg_log_bytes_used, row_hash)
                VALUES (%(instance_id)s, %(database_name)s, %(qs_runtime_stats_id)s, %(qs_plan_id)s,
                        %(qs_interval_id)s, %(execution_type_desc)s, %(count_executions)s,
                        %(avg_duration_us)s, %(avg_cpu_time_us)s, %(avg_logical_io_reads)s,
                        %(avg_physical_io_reads)s, %(avg_logical_io_writes)s, %(avg_dop)s,
                        %(avg_query_max_used_memory_kb)s, %(avg_rowcount)s, %(avg_log_bytes_used)s,
                        %(row_hash)s)
                ON CONFLICT (instance_id, database_name, qs_runtime_stats_id) DO NOTHING
            """, rs_rec)
        plan_ids_seen.add(r[1])

    with conn.cursor() as cur:
        cur.execute("""
            SELECT ws.wait_stats_id, ws.plan_id, ws.wait_category_desc,
                   ws.execution_type_desc, ws.total_query_wait_time_ms,
                   ws.avg_query_wait_time_ms, ws.max_query_wait_time_ms
            FROM sys.query_store_wait_stats ws
            WHERE ws.runtime_stats_interval_id = ?
        """, interval_id)
        wait_rows = cur.fetchall()

    for r in wait_rows:
        ws_rec = {
            "instance_id": instance_id, "database_name": db_name,
            "qs_wait_stats_id": r[0], "qs_plan_id": r[1], "qs_interval_id": interval_id,
            "wait_category_desc": r[2], "execution_type_desc": r[3],
            "total_query_wait_time_ms": r[4], "avg_query_wait_time_ms": r[5],
            "max_query_wait_time_ms": r[6],
        }
        ws_rec["row_hash"] = row_hash(ws_rec)
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_qs_wait_stats
                    (instance_id, database_name, qs_wait_stats_id, qs_plan_id, qs_interval_id,
                     wait_category_desc, execution_type_desc, total_query_wait_time_ms,
                     avg_query_wait_time_ms, max_query_wait_time_ms, row_hash)
                VALUES (%(instance_id)s, %(database_name)s, %(qs_wait_stats_id)s, %(qs_plan_id)s,
                        %(qs_interval_id)s, %(wait_category_desc)s, %(execution_type_desc)s,
                        %(total_query_wait_time_ms)s, %(avg_query_wait_time_ms)s,
                        %(max_query_wait_time_ms)s, %(row_hash)s)
                ON CONFLICT (instance_id, database_name, qs_wait_stats_id) DO NOTHING
            """, ws_rec)
        plan_ids_seen.add(r[1])

    # ── plan + query + query_text for every plan referenced above ──
    for plan_id in plan_ids_seen:
        _collect_plan_chain(conn, pg_conn, instance_id, db_name, plan_id)


def _collect_plan_chain(conn, pg_conn, instance_id: int, db_name: str, plan_id: int) -> None:
    """Collect mssql_qs_plan -> mssql_qs_query -> mssql_qs_query_text
    for one plan_id, only if not already collected (these are
    natural-key/metadata-style rows, not per-interval time series --
    a plan doesn't change once created, so once collected, skip)."""
    with pg_conn.cursor() as pg_cur:
        pg_cur.execute(
            "SELECT 1 FROM mssql_qs_plan WHERE instance_id=%s AND database_name=%s AND qs_plan_id=%s",
            (instance_id, db_name, plan_id)
        )
        if pg_cur.fetchone():
            return

    with conn.cursor() as cur:
        cur.execute("""
            SELECT p.plan_id, p.query_id, CAST(p.query_plan AS NVARCHAR(MAX)),
                   p.is_parallel_plan, p.is_forced_plan
            FROM sys.query_store_plan p WHERE p.plan_id = ?
        """, plan_id)
        prow = cur.fetchone()
    if not prow:
        return

    query_id = prow[1]
    with pg_conn.cursor() as pg_cur:
        pg_cur.execute("""
            INSERT INTO mssql_qs_plan
                (instance_id, database_name, qs_plan_id, qs_query_id, query_plan,
                 is_parallel_plan, is_forced_plan)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (instance_id, database_name, qs_plan_id) DO NOTHING
        """, (instance_id, db_name, prow[0], prow[1], prow[2], prow[3], prow[4]))

    with pg_conn.cursor() as pg_cur:
        pg_cur.execute(
            "SELECT 1 FROM mssql_qs_query WHERE instance_id=%s AND database_name=%s AND qs_query_id=%s",
            (instance_id, db_name, query_id)
        )
        if pg_cur.fetchone():
            return

    with conn.cursor() as cur:
        cur.execute("""
            SELECT q.query_id, q.query_text_id, q.object_id,
                   OBJECT_NAME(q.object_id), q.query_parameterization_type_desc,
                   q.is_internal_query, q.last_execution_time
            FROM sys.query_store_query q WHERE q.query_id = ?
        """, query_id)
        qrow = cur.fetchone()
    if not qrow:
        return

    text_id = qrow[1]
    # Real fix, not a guess this time: confirmed directly against
    # Microsoft's documented column list for sys.query_store_query --
    # last_execution_time genuinely exists there, but
    # first_execution_time does not (my original assumption was
    # simply wrong -- there's no symmetric first/last pair on this
    # view). The closest real column, initial_compile_start_time,
    # tracks compile time, not execution time -- a different concept,
    # not swapped in here under a misleading name. mssql_qs_query's
    # first_execution_time schema column is left unpopulated (NULL)
    # rather than removed outright -- a minor, known, non-breaking gap
    # worth a proper schema decision later, not a reason to hold up
    # this fix.
    #
    # last_execution_time gets the same DATETIMEOFFSET UTC
    # normalization as everywhere else this type shows up -- the
    # connection-level output converter means this no longer crashes,
    # but without this explicit step it would still risk silently
    # storing the wrong absolute moment for any source server not
    # running in UTC.
    last_exec = _to_naive_utc(qrow[6])
    with pg_conn.cursor() as pg_cur:
        pg_cur.execute("""
            INSERT INTO mssql_qs_query
                (instance_id, database_name, qs_query_id, qs_query_text_id, object_id,
                 object_name, query_parameterization_type_desc, is_internal_query,
                 last_execution_time)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (instance_id, database_name, qs_query_id) DO NOTHING
        """, (instance_id, db_name, qrow[0], qrow[1], qrow[2], qrow[3],
              qrow[4], qrow[5], last_exec))

    with pg_conn.cursor() as pg_cur:
        pg_cur.execute(
            "SELECT 1 FROM mssql_qs_query_text WHERE instance_id=%s AND database_name=%s AND qs_query_text_id=%s",
            (instance_id, db_name, text_id)
        )
        if pg_cur.fetchone():
            return

    with conn.cursor() as cur:
        cur.execute("""
            SELECT query_text_id, query_sql_text
            FROM sys.query_store_query_text WHERE query_text_id = ?
        """, text_id)
        trow = cur.fetchone()
    if trow:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_qs_query_text
                    (instance_id, database_name, qs_query_text_id, query_sql_text)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (instance_id, database_name, qs_query_text_id) DO NOTHING
            """, (instance_id, db_name, trow[0], trow[1]))


# ══════════════════════════════════════════════════════════════════
# CLI ENTRY POINT
# ══════════════════════════════════════════════════════════════════
# Added after Ganesh ran this file directly (py modules\mssql\
# query_store_collector.py) expecting it to do something -- until
# this was added, the module had no executable top-level code at all,
# so running it directly just defined everything and exited cleanly
# with zero output. That's exactly what "ran without errors, but no
# rows were inserted" looks like when the collector was never
# actually invoked -- not a bug in the collection logic itself, a
# missing CLI. Mirrors modules/license_engine.py's own argparse-based
# CLI pattern.

def _main():
    import argparse
    import getpass

    parser = argparse.ArgumentParser(
        description="MS SQL Query Store collector -- pulls completed "
                     "Query Store intervals into the mssql_qs_* tables."
    )
    parser.add_argument("--host", required=True, help="SQL Server host name/IP")
    parser.add_argument("--port", type=int, default=None, help="Port (omit for default 1433)")
    parser.add_argument("--instance-name", default="MSSQLSERVER",
                         help="Named instance (default: MSSQLSERVER, i.e. the default instance)")
    parser.add_argument("--trusted-connection", action="store_true",
                         help="Use Windows Authentication (the credentials of whatever "
                              "Windows account is running this script) instead of a SQL "
                              "Server login. --username/--password are ignored if set. "
                              "Common default for a local dev SQL Server install -- if you "
                              "get 'Login failed for user ...' (error 18456) with SQL auth, "
                              "try this instead.")
    parser.add_argument("--username", default=None,
                         help="SQL Server login (SQL auth). Required unless --trusted-connection is set.")
    parser.add_argument("--password", default=None,
                         help="SQL Server password. If omitted (and not using "
                              "--trusted-connection), you'll be prompted (not shown on "
                              "screen) rather than needing to pass it on the command line, "
                              "matching how the license/install scripts already avoid "
                              "showing passwords in this project.")
    parser.add_argument("--database", action="append", dest="databases",
                         help="Database name to collect (repeatable: --database A --database B). "
                              "If omitted, every Query-Store-enabled database on the instance is collected.")
    args = parser.parse_args()

    if not args.trusted_connection and not args.username:
        parser.error("--username is required unless --trusted-connection is set")

    cfg = {
        "host": args.host,
        "instance_name": args.instance_name,
    }
    if args.port:
        cfg["port"] = args.port

    if args.trusted_connection:
        cfg["trusted_connection"] = True
    else:
        password = args.password
        if password is None:
            password = getpass.getpass(f"Password for {args.username}@{args.host}: ")
        cfg["username"] = args.username
        cfg["password"] = password

    print(f"\n{'='*60}")
    print(f"MS SQL Query Store Collector")
    print(f"{'='*60}")
    print(f"Host:      {args.host}")
    print(f"Instance:  {args.instance_name}")
    print(f"Auth:      {'Windows (trusted connection)' if args.trusted_connection else f'SQL Server login ({args.username})'}")
    print(f"Databases: {', '.join(args.databases) if args.databases else '(auto-discover)'}")
    print(f"{'='*60}\n")

    result = run_query_store_collection(cfg, database_names=args.databases)

    print(f"\n{'='*60}")
    print(f"RESULT")
    print(f"{'='*60}")
    print(f"Databases processed: {result['databases_processed']}")
    print(f"Databases skipped:   {result['databases_skipped']}")
    print(f"Intervals collected: {result['intervals_collected']}")
    if result["errors"]:
        print(f"Errors:")
        for e in result["errors"]:
            print(f"  - {e}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    _main()
