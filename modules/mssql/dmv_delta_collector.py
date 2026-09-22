"""
modules/mssql/dmv_delta_collector.py
======================================
Polls the cumulative-since-restart DMVs (wait stats, blocking, index
usage, memory, config, file I/O, TempDB pressure, plan cache,
scheduler, sessions) into the 13 mssql_* delta tables from
schema/mssql_dmv_tables.sql -- the "cumulative-counter delta snapshot"
collection model (MS SQL Analysis Model doc, Section 4.2).

Unlike the Query Store collector, these DMVs reset on restart and only
ever grow. This collector's job is ONLY to poll on a fixed interval
and store the RAW cumulative value each time against a new
mssql_dmv_snapshot row -- it does NOT compute (current - previous) /
elapsed_seconds deltas itself. That math belongs at read time, in the
rules engine (not yet built), specifically so a bug in delta
computation can never corrupt what's actually stored -- the design
doc's own stated reasoning for this split (Section 4.2), carried
through faithfully here rather than convenient-but-risky at
collection time.

Shares modules/mssql/connection.py with query_store_collector.py --
same proven connection/auth/DATETIMEOFFSET handling, not duplicated.

Licensing: checks is_db_type_licensed("mssql"), same gate as the
Query Store collector.

IMPORTANT -- calibrated confidence, stated honestly rather than
uniformly claimed: sys.dm_db_index_operational_stats,
sys.dm_exec_requests/dm_tran_locks/dm_os_waiting_tasks, and
sys.dm_db_session_space_usage/dm_db_task_space_usage column names
were explicitly verified against current Microsoft documentation
during this project's design phase. sys.dm_os_wait_stats,
sys.dm_os_performance_counters, sys.dm_os_memory_clerks,
sys.dm_io_virtual_file_stats, sys.dm_os_volume_stats,
sys.dm_exec_cached_plans, sys.dm_exec_query_stats, sys.dm_os_schedulers,
sys.dm_exec_sessions, and sys.dm_exec_connections are long-stable,
well-established DMVs drawn from reliable general knowledge, not
individually re-verified column-by-column in this pass -- the same
honest calibration that caught real, fixable mistakes in the Query
Store collector (a wrong assumed column, a wrong assumed instance-name
handling) applies here too. Expect at least one "Invalid column name"
error on first real run, the same as before -- report it and it gets
fixed the same way.

One confirmed, non-obvious gotcha already designed around: performance
counter object_name has a DIFFERENT prefix on a default instance
("SQLServer:Buffer Manager") vs a named instance
("MSSQL$InstanceName:Buffer Manager") -- every performance-counter
query below filters with LIKE '%:<category>' rather than an exact
match, so this works correctly on both without needing to know which
kind of instance it's running against.
"""

import os
import sys
import logging

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'modules'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from logger_utils import get_logger
from connection import mssql_connect, resolve_instance_id, to_naive_utc

logger = get_logger('mssql_dmv_delta_collector')


def run_dmv_collection(mssql_cfg: dict, database_names: list = None, min_interval_minutes: int = None) -> dict:
    """
    Main entry point. Polls every Tier 1 + Tier 2 cumulative DMV once
    against the given instance, storing raw values against one new
    mssql_dmv_snapshot row. Database-scoped DMVs (index usage, TempDB
    pressure) additionally need database_names -- server-scoped ones
    (wait stats, memory, scheduler, sessions, file I/O) only need one
    connection regardless of database count.

    min_interval_minutes, when given, enforces that a new snapshot is
    only taken if at least that much time has elapsed since this
    instance's last one -- a real gap found while reviewing this
    collector for the SQLWR report-generation work: _create_snapshot
    previously inserted a new row unconditionally on every single
    invocation, with no check against the last one. Manual or
    out-of-band re-runs (this collector has been run dozens of times
    by hand throughout this project's testing) silently created extra,
    irregularly-spaced snapshots -- which breaks the "two consecutive
    snapshots = one SQLWR report" assumption the report generator
    depends on, since "consecutive" needs to reliably mean one interval
    apart, not five minutes in one case and three hours in another.
    Checked BEFORE connecting to SQL Server at all (not after), so a
    skipped cycle costs nothing against the production instance.

    Returns a summary dict: {"snapshot_id": N, "tables_collected": {...},
    "databases_processed": [...], "databases_skipped": [...], "errors": [...],
    "skipped": bool}. skipped=True means min_interval_minutes hadn't
    elapsed yet -- not a failure, snapshot_id is the existing most
    recent one, unchanged.
    """
    from license_engine import is_db_type_licensed
    if not is_db_type_licensed("mssql"):
        logger.info("MS SQL Server not licensed -- skipping DMV collection")
        return {"snapshot_id": None, "tables_collected": {}, "databases_processed": [],
                "databases_skipped": [], "errors": ["mssql not licensed"], "skipped": False}

    summary = {"snapshot_id": None, "tables_collected": {}, "databases_processed": [],
               "databases_skipped": [], "errors": [], "skipped": False}

    host_name = mssql_cfg["host"]
    instance_name = mssql_cfg.get("instance_name", "MSSQLSERVER")

    try:
        instance_id = resolve_instance_id(host_name, instance_name)
    except Exception as e:
        logger.error(f"Instance resolution failed: {e}")
        summary["errors"].append(str(e))
        return summary

    from db import get_db_connection
    pg_conn = get_db_connection()

    if min_interval_minutes:
        with pg_conn.cursor() as cur:
            cur.execute("""
                SELECT snapshot_id, snapshot_time FROM mssql_dmv_snapshot
                WHERE instance_id = %s ORDER BY snapshot_time DESC LIMIT 1
            """, (instance_id,))
            last = cur.fetchone()
        if last:
            last_id, last_time = last
            import datetime
            elapsed_minutes = (datetime.datetime.now() - last_time).total_seconds() / 60
            if elapsed_minutes < min_interval_minutes:
                logger.info(f"Skipping DMV collection -- only {elapsed_minutes:.1f} min since "
                            f"last snapshot (id={last_id}), interval is {min_interval_minutes} min")
                summary["snapshot_id"] = last_id
                summary["skipped"] = True
                return summary

    try:
        conn = mssql_connect({**mssql_cfg, "database": mssql_cfg.get("database", "master")})
    except Exception as e:
        logger.error(f"Could not connect to instance: {e}")
        summary["errors"].append(f"connect failed: {e}")
        return summary

    try:
        snapshot_id = _create_snapshot(pg_conn, instance_id, mssql_conn=conn)
        summary["snapshot_id"] = snapshot_id
        _update_instance_metadata(conn, pg_conn, instance_id)

        # ── Server-scoped (instance-wide, no per-database loop needed) ──
        server_scoped = [
            ("mssql_wait_stats_delta", _collect_wait_stats),
            ("mssql_blocking_snapshot", _collect_blocking),
            ("mssql_perf_counters", _collect_perf_counters),
            ("mssql_memory_clerks", _collect_memory_clerks),
            ("mssql_file_io_delta", _collect_file_io),
            ("mssql_volume_stats", _collect_volume_stats),
            ("mssql_plan_cache_stats", _collect_plan_cache),
            ("mssql_scheduler_stats", _collect_scheduler_stats),
            ("mssql_session_stats", _collect_session_stats),
        ]
        for table_name, fn in server_scoped:
            try:
                n = fn(conn, pg_conn, snapshot_id)
                summary["tables_collected"][table_name] = n
            except Exception as e:
                logger.error(f"Collection failed for {table_name}: {e}")
                summary["errors"].append(f"{table_name}: {e}")

        # ── Database-scoped (need per-database queries) ──
        if database_names is None:
            with conn.cursor() as cur:
                cur.execute("SELECT name FROM sys.databases WHERE database_id > 4 AND state = 0")
                database_names = [r[0] for r in cur.fetchall()]

        for db_name in database_names:
            try:
                db_conn = mssql_connect({**mssql_cfg, "database": db_name})
            except Exception as e:
                logger.warning(f"Could not connect to database {db_name}: {e}")
                summary["databases_skipped"].append(db_name)
                summary["errors"].append(f"{db_name}: connect failed: {e}")
                continue

            try:
                n1 = _collect_index_usage(db_conn, pg_conn, snapshot_id, db_name)
                n2 = _collect_tempdb_session(db_conn, pg_conn, snapshot_id, db_name)
                n3 = _collect_tempdb_task(db_conn, pg_conn, snapshot_id, db_name)
                n4 = _collect_config(db_conn, pg_conn, snapshot_id, db_name)
                summary["tables_collected"]["mssql_index_usage_delta"] = \
                    summary["tables_collected"].get("mssql_index_usage_delta", 0) + n1
                summary["tables_collected"]["mssql_tempdb_session_usage"] = \
                    summary["tables_collected"].get("mssql_tempdb_session_usage", 0) + n2
                summary["tables_collected"]["mssql_tempdb_task_usage"] = \
                    summary["tables_collected"].get("mssql_tempdb_task_usage", 0) + n3
                summary["tables_collected"]["mssql_config_snapshot"] = \
                    summary["tables_collected"].get("mssql_config_snapshot", 0) + n4
                summary["databases_processed"].append(db_name)
            except Exception as e:
                logger.error(f"Per-database collection failed for {db_name}: {e}")
                summary["errors"].append(f"{db_name}: {e}")
            finally:
                try:
                    db_conn.close()
                except Exception:
                    pass

        pg_conn.commit()
    except Exception:
        pg_conn.rollback()
        raise
    finally:
        pg_conn.close()
        try:
            conn.close()
        except Exception:
            pass

    return summary


def _update_instance_metadata(mssql_conn, pg_conn, instance_id: int) -> None:
    """
    Updates mssql_instance_master.sql_version/sql_edition from the live
    connection -- a real gap found from a real report: the columns
    exist in the schema and sqlwr_report_generator.py already reads
    them (Database Summary's Version/Edition columns), but nothing
    ever wrote to them, so every report showed "(not collected)"
    regardless of anything else being correct.

    SERVERPROPERTY('ProductVersion')/('Edition') give clean, short
    strings (e.g. "16.0.1000.6", "Developer Edition") -- much cleaner
    than parsing @@VERSION's full multi-line text blob for the same
    information. Run once per collection cycle (a cheap, idempotent
    UPDATE), not just once ever, so a real version upgrade or edition
    change is naturally picked up on the next run without needing a
    separate "first collection only" code path.
    """
    try:
        cur = mssql_conn.cursor()
        cur.execute(
            "SELECT CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), "
            "CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128))"
        )
        row = cur.fetchone()
        if row:
            with pg_conn.cursor() as pg_cur:
                pg_cur.execute(
                    "UPDATE mssql_instance_master SET sql_version = %s, sql_edition = %s WHERE id = %s",
                    (row[0], row[1], instance_id)
                )
    except Exception as e:
        logger.warning(f"Could not update instance version/edition metadata: {e}")


def _create_snapshot(pg_conn, instance_id: int, mssql_conn=None) -> int:
    """
    Creates the new mssql_dmv_snapshot row, capturing SQL Server's own
    sqlserver_start_time from sys.dm_os_sys_info when a live connection
    is given -- needed to detect a restart between two consecutive
    snapshots later (every DMV counter resets to zero on restart, so a
    delta computed across a restart would be meaningless). mssql_conn
    is optional so this function still works for any caller that
    doesn't have a live connection handy; sqlserver_start_time is
    simply left NULL in that case, and restart-detection downstream
    treats a NULL start_time as "unknown, don't assume no restart
    happened" rather than silently skipping the check.
    """
    start_time = None
    if mssql_conn is not None:
        try:
            cur = mssql_conn.cursor()
            cur.execute("SELECT sqlserver_start_time FROM sys.dm_os_sys_info")
            row = cur.fetchone()
            if row:
                start_time = row[0]
        except Exception as e:
            logger.warning(f"Could not read sqlserver_start_time: {e}")

    with pg_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO mssql_dmv_snapshot (instance_id, collector_version, sqlserver_start_time) "
            "VALUES (%s, %s, %s) RETURNING snapshot_id",
            (instance_id, "1.0", start_time)
        )
        return cur.fetchone()[0]


# ══════════════════════ SERVER-SCOPED COLLECTORS ══════════════════════

def _collect_wait_stats(conn, pg_conn, snapshot_id) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT wait_type, waiting_tasks_count, wait_time_ms,
                   max_wait_time_ms, signal_wait_time_ms
            FROM sys.dm_os_wait_stats
            WHERE wait_time_ms > 0
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_wait_stats_delta
                    (snapshot_id, wait_type, waiting_tasks_count, wait_time_ms,
                     max_wait_time_ms, signal_wait_time_ms)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, wait_type) DO NOTHING
            """, (snapshot_id, r[0], r[1], r[2], r[3], r[4]))
        n += 1
    return n


def _collect_blocking(conn, pg_conn, snapshot_id) -> int:
    # dm_exec_requests + dm_tran_locks, joined -- column names for this
    # join confirmed during the design phase. CROSS APPLY picks one
    # representative WAITING lock row per session (the schema is one
    # row per session per snapshot, not one row per lock -- a session
    # can hold/wait on several locks at once, and wait_resource already
    # gives the compact summary; resource_type/request_mode add the
    # structured detail for whichever lock it's actively waiting on).
    #
    # Only sessions with a GENUINE blocker (blocking_session_id > 0)
    # are captured -- a real bug found on a real first run of the
    # blocking rule category: the original condition here was
    # "blocking_session_id > 0 OR wait_type IS NOT NULL", which
    # captured ANY session with ANY active wait, including entirely
    # benign ones (idle connections waiting on the client for their
    # next command, background tasks) that were never blocked by
    # another session at all. blocking_session_id = 0 is SQL Server's
    # own sentinel for "not blocked" -- a real run showed 27 rows, all
    # with blocked by 0, several with wait times over 18,000 seconds
    # (5+ hours), which MSSQL_BLOCK_002 then correctly-by-its-own-logic
    # but wrongly-in-substance flagged as "sustained blocking" -- 10
    # false positives from data that was never genuine blocking to
    # begin with. General wait activity (not tied to a specific
    # blocker) is already covered by mssql_wait_stats_delta -- no
    # coverage is lost by narrowing this table to what its name and
    # the rules built against it actually mean: genuine blocking.
    #
    # An empty result here is a GOOD sign (no blocking right now), not
    # a collection failure.
    #
    # blocked_object_name/blocked_index_name/blocked_statement_text:
    # added after a real DBA question -- "session 74 blocked by 77"
    # tells a DBA nothing they can act on without knowing which table
    # and which query. Resolution logic verified against multiple
    # sources (including Microsoft's own sys.dm_tran_locks reference)
    # before writing this: resource_associated_entity_id IS the
    # object_id directly for OBJECT-type locks, but is a hobt_id
    # requiring a join through sys.partitions for PAGE/KEY/RID types --
    # these are NOT interchangeable, and treating them the same would
    # silently resolve wrong or NULL names for one or the other.
    # blocked_statement_text uses the same sql_handle +
    # statement_start/end_offset substring extraction pattern already
    # used elsewhere in this project for "what exact statement was
    # this session running" -- OUTER APPLY (not CROSS APPLY) so a
    # session with no resolvable sql_handle still keeps its row rather
    # than being silently dropped.
    with conn.cursor() as cur:
        cur.execute("""
            SELECT r.session_id, DB_NAME(r.database_id), r.blocking_session_id,
                   r.wait_type, r.wait_time, r.wait_resource,
                   r.cpu_time, r.total_elapsed_time, r.logical_reads, r.command,
                   tl.resource_type, tl.request_mode, tl.request_status,
                   CASE
                       WHEN tl.resource_type = 'OBJECT' THEN OBJECT_NAME(tl.resource_associated_entity_id, r.database_id)
                       WHEN tl.resource_type IN ('KEY', 'PAGE', 'RID') THEN OBJECT_NAME(p.object_id, r.database_id)
                       ELSE NULL
                   END AS blocked_object_name,
                   CASE WHEN p.object_id IS NOT NULL THEN idx.name ELSE NULL END AS blocked_index_name,
                   stmt.blocked_statement_text
            FROM sys.dm_exec_requests r
            OUTER APPLY (
                SELECT TOP 1 resource_type, request_mode, request_status, resource_associated_entity_id
                FROM sys.dm_tran_locks
                WHERE request_session_id = r.session_id AND request_status = 'WAIT'
            ) tl
            LEFT JOIN sys.partitions p
                ON tl.resource_type IN ('KEY', 'PAGE', 'RID') AND p.hobt_id = tl.resource_associated_entity_id
            LEFT JOIN sys.indexes idx ON idx.object_id = p.object_id AND idx.index_id = p.index_id
            OUTER APPLY (
                SELECT SUBSTRING(st.text, (r.statement_start_offset / 2) + 1,
                         ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE r.statement_end_offset END
                           - r.statement_start_offset) / 2) + 1) AS blocked_statement_text
                FROM sys.dm_exec_sql_text(r.sql_handle) st
            ) stmt
            WHERE r.blocking_session_id > 0
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_blocking_snapshot
                    (snapshot_id, database_name, session_id, blocking_session_id,
                     wait_type, wait_time_ms, wait_resource, resource_type,
                     request_mode, request_status, cpu_time_ms,
                     total_elapsed_time_ms, logical_reads, command,
                     blocked_object_name, blocked_index_name, blocked_statement_text)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, session_id) DO NOTHING
            """, (snapshot_id, r[1], r[0], r[2], r[3], r[4], r[5], r[10], r[11], r[12],
                  r[6], r[7], r[8], r[9], r[13], r[14], r[15]))
        n += 1
    return n


def _collect_perf_counters(conn, pg_conn, snapshot_id) -> int:
    # Broad category pull, not individually-named-metric cherry-picking
    # -- matches the "store raw, compute derived ratios (e.g. Buffer
    # cache hit ratio needs its 'base' counterpart divided in) at read
    # time" architecture, and sidesteps needing to get every exact
    # counter_name string right in this collector. LIKE, not exact
    # match, on object_name -- default vs named instance use different
    # prefixes ("SQLServer:" vs "MSSQL$InstanceName:").
    #
    # object_name/counter_name/instance_name are nchar(128) -- FIXED
    # WIDTH, always padded with trailing spaces out to 128 characters
    # (confirmed directly against Microsoft's own column-type
    # documentation). A real run against Ganesh's instance returned 0
    # rows here across every category before this fix -- the pattern
    # '%:Buffer Manager' requires the string to end exactly after
    # "Manager", but the actual stored value is "SQLServer:Buffer
    # Manager" plus ~103 trailing spaces, so it never matched. Fixed
    # two ways: a trailing % on the LIKE pattern (matches regardless
    # of padding), and RTRIM on the way into Postgres so the padding
    # doesn't get carried forward into stored data either -- otherwise
    # this same issue would resurface as an awkward RTRIM-everywhere
    # requirement for anything downstream (the rules engine) that
    # later compares or joins on these columns.
    categories = ["Buffer Manager", "Memory Manager", "Resource Pool Stats",
                  "General Statistics", "SQL Statistics", "Locks"]
    n = 0
    with conn.cursor() as cur:
        for category in categories:
            cur.execute("""
                SELECT RTRIM(object_name), RTRIM(counter_name), RTRIM(instance_name),
                       cntr_value, cntr_type
                FROM sys.dm_os_performance_counters
                WHERE object_name LIKE ?
            """, f"%:{category}%")
            rows = cur.fetchall()
            for r in rows:
                with pg_conn.cursor() as pg_cur:
                    pg_cur.execute("""
                        INSERT INTO mssql_perf_counters
                            (snapshot_id, object_name, counter_name, instance_name, cntr_value, cntr_type)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON CONFLICT (snapshot_id, object_name, counter_name, instance_name) DO NOTHING
                    """, (snapshot_id, r[0], r[1], r[2] or '', r[3], r[4]))
                n += 1
    return n


def _collect_memory_clerks(conn, pg_conn, snapshot_id) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT type, name, pages_kb, virtual_memory_committed_kb
            FROM sys.dm_os_memory_clerks
            WHERE pages_kb > 0
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_memory_clerks
                    (snapshot_id, clerk_type, clerk_name, pages_kb, virtual_memory_committed_kb)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, clerk_type, clerk_name) DO NOTHING
            """, (snapshot_id, r[0], r[1] or '', r[2], r[3]))
        n += 1
    return n


def _collect_file_io(conn, pg_conn, snapshot_id) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT DB_NAME(vfs.database_id), vfs.file_id, mf.name,
                   vfs.num_of_reads, vfs.num_of_bytes_read, vfs.io_stall_read_ms,
                   vfs.num_of_writes, vfs.num_of_bytes_written, vfs.io_stall_write_ms,
                   vfs.size_on_disk_bytes
            FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
            JOIN sys.master_files mf
                ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_file_io_delta
                    (snapshot_id, database_name, file_id, logical_file_name,
                     num_of_reads, num_of_bytes_read, io_stall_read_ms,
                     num_of_writes, num_of_bytes_written, io_stall_write_ms, size_on_disk_bytes)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, database_name, file_id) DO NOTHING
            """, (snapshot_id, r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]))
        n += 1
    return n


def _collect_volume_stats(conn, pg_conn, snapshot_id) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT DISTINCT vs.volume_mount_point, vs.total_bytes, vs.available_bytes
            FROM sys.master_files mf
            CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_volume_stats
                    (snapshot_id, volume_mount_point, total_bytes, available_bytes)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (snapshot_id, volume_mount_point) DO NOTHING
            """, (snapshot_id, r[0], r[1], r[2]))
        n += 1
    return n


def _collect_plan_cache(conn, pg_conn, snapshot_id) -> int:
    # Top N by usecounts, not every cached plan -- plan cache can hold
    # tens of thousands of entries, and only the extremes (very high
    # reuse, or single-use bloat) are actually useful for the rules
    # this feeds. Bounded the same way MAX_INTERVALS_PER_RUN bounds
    # the Query Store collector's per-run work.
    with conn.cursor() as cur:
        cur.execute("""
            SELECT TOP 200
                   qs.query_hash, qs.query_plan_hash, cp.objtype, cp.usecounts, cp.size_in_bytes,
                   qs.execution_count, qs.total_worker_time, qs.total_elapsed_time,
                   qs.total_logical_reads, qs.total_physical_reads
            FROM sys.dm_exec_query_stats qs
            JOIN sys.dm_exec_cached_plans cp ON qs.plan_handle = cp.plan_handle
            ORDER BY cp.usecounts DESC
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        query_hash_hex = r[0].hex() if r[0] else None
        plan_hash_hex = r[1].hex() if r[1] else None
        if not query_hash_hex:
            continue
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_plan_cache_stats
                    (snapshot_id, query_hash, query_plan_hash, objtype, usecounts, size_in_bytes,
                     execution_count, total_worker_time_us, total_elapsed_time_us,
                     total_logical_reads, total_physical_reads)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, query_hash, query_plan_hash) DO NOTHING
            """, (snapshot_id, query_hash_hex, plan_hash_hex, r[2], r[3], r[4],
                  r[5], r[6], r[7], r[8], r[9]))
        n += 1
    return n


def _collect_scheduler_stats(conn, pg_conn, snapshot_id) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT scheduler_id, cpu_id, is_online, runnable_tasks_count,
                   current_tasks_count, work_queue_count, pending_disk_io_count, load_factor
            FROM sys.dm_os_schedulers
            WHERE scheduler_id < 1048576
        """)  # excludes hidden/internal schedulers (DAC etc.), matching common convention
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_scheduler_stats
                    (snapshot_id, scheduler_id, cpu_id, is_online, runnable_tasks_count,
                     current_tasks_count, work_queue_count, pending_disk_io_count, load_factor)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, scheduler_id) DO NOTHING
            """, (snapshot_id, r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7]))
        n += 1
    return n


def _collect_session_stats(conn, pg_conn, snapshot_id) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT s.session_id, s.login_name, s.host_name, s.program_name, s.status,
                   s.cpu_time, s.memory_usage, s.reads, s.writes, s.logical_reads,
                   c.client_net_address, c.connect_time
            FROM sys.dm_exec_sessions s
            LEFT JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
            WHERE s.is_user_process = 1
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_session_stats
                    (snapshot_id, session_id, login_name, host_name, program_name, status,
                     cpu_time_ms, memory_usage_kb, reads, writes, logical_reads,
                     client_net_address, connect_time)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, session_id) DO NOTHING
            """, (snapshot_id, r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9],
                  r[10], to_naive_utc(r[11])))
        n += 1
    return n


# ══════════════════════ DATABASE-SCOPED COLLECTORS ══════════════════════

def _collect_index_usage(conn, pg_conn, snapshot_id, db_name) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT SCHEMA_NAME(o.schema_id), o.name, i.name, i.index_id,
                   ius.user_seeks, ius.user_scans, ius.user_lookups, ius.user_updates,
                   ios.leaf_insert_count, ios.leaf_delete_count, ios.leaf_update_count,
                   ios.page_latch_wait_count, ios.page_latch_wait_in_ms,
                   ios.page_io_latch_wait_count, ios.page_io_latch_wait_in_ms,
                   ios.row_lock_wait_count, ios.row_lock_wait_in_ms
            FROM sys.indexes i
            JOIN sys.objects o ON i.object_id = o.object_id
            LEFT JOIN sys.dm_db_index_usage_stats ius
                ON ius.database_id = DB_ID() AND ius.object_id = i.object_id AND ius.index_id = i.index_id
            OUTER APPLY sys.dm_db_index_operational_stats(DB_ID(), i.object_id, i.index_id, NULL) ios
            WHERE o.type = 'U'  -- user tables only
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_index_usage_delta
                    (snapshot_id, database_name, schema_name, object_name, index_name, index_id,
                     user_seeks, user_scans, user_lookups, user_updates,
                     leaf_insert_count, leaf_delete_count, leaf_update_count,
                     page_latch_wait_count, page_latch_wait_in_ms,
                     page_io_latch_wait_count, page_io_latch_wait_in_ms,
                     row_lock_wait_count, row_lock_wait_in_ms)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, database_name, object_name, index_id) DO NOTHING
            """, (snapshot_id, db_name, r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7],
                  r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15], r[16]))
        n += 1
    return n


def _collect_tempdb_session(conn, pg_conn, snapshot_id, db_name) -> int:
    # Server-scoped DMV (TempDB usage is tracked instance-wide, not
    # per-user-database) -- called once per database connection here
    # purely for connection convenience, not because the data is
    # actually database-scoped. Deduped naturally via
    # ON CONFLICT (snapshot_id, session_id) if collected redundantly.
    with conn.cursor() as cur:
        cur.execute("""
            SELECT su.session_id, s.login_name, su.user_objects_alloc_page_count,
                   su.internal_objects_alloc_page_count
            FROM sys.dm_db_session_space_usage su
            JOIN sys.dm_exec_sessions s ON su.session_id = s.session_id
            WHERE s.is_user_process = 1
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_tempdb_session_usage
                    (snapshot_id, session_id, login_name, user_objects_alloc_page_count,
                     internal_objects_alloc_page_count)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, session_id) DO NOTHING
            """, (snapshot_id, r[0], r[1], r[2], r[3]))
        n += 1
    return n


def _collect_tempdb_task(conn, pg_conn, snapshot_id, db_name) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT session_id, request_id, internal_objects_alloc_page_count,
                   internal_objects_dealloc_page_count
            FROM sys.dm_db_task_space_usage
        """)
        rows = cur.fetchall()
    n = 0
    for r in rows:
        with pg_conn.cursor() as pg_cur:
            pg_cur.execute("""
                INSERT INTO mssql_tempdb_task_usage
                    (snapshot_id, session_id, request_id, internal_objects_alloc_page_count,
                     internal_objects_dealloc_page_count)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (snapshot_id, session_id, request_id) DO NOTHING
            """, (snapshot_id, r[0], r[1], r[2], r[3]))
        n += 1
    return n


def _collect_config(conn, pg_conn, snapshot_id, db_name) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT
                (SELECT CAST(value_in_use AS BIGINT) FROM sys.configurations WHERE name = 'max server memory (MB)'),
                (SELECT CAST(value_in_use AS BIGINT) FROM sys.configurations WHERE name = 'min server memory (MB)'),
                (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'max degree of parallelism'),
                (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'cost threshold for parallelism'),
                (SELECT cpu_count FROM sys.dm_os_sys_info),
                (SELECT physical_memory_kb FROM sys.dm_os_sys_info),
                (SELECT recovery_model_desc FROM sys.databases WHERE name = DB_NAME()),
                (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME())
        """)
        row = cur.fetchone()
    if not row:
        return 0
    with pg_conn.cursor() as pg_cur:
        pg_cur.execute("""
            INSERT INTO mssql_config_snapshot
                (snapshot_id, max_server_memory_mb, min_server_memory_mb, max_dop,
                 cost_threshold_for_parallelism, cpu_count, physical_memory_kb,
                 database_name, recovery_model_desc, compatibility_level)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (snapshot_id, database_name) DO NOTHING
        """, (snapshot_id, row[0], row[1], row[2], row[3], row[4], row[5], db_name, row[6], row[7]))
    return 1


# ══════════════════════════════ CLI ══════════════════════════════

def _main():
    import argparse
    import getpass

    parser = argparse.ArgumentParser(
        description="MS SQL cumulative-DMV collector -- polls wait stats, "
                     "blocking, index usage, memory, config, file I/O, TempDB "
                     "pressure, plan cache, scheduler, and session data into "
                     "the mssql_* tables."
    )
    parser.add_argument("--host", required=True, help="SQL Server host name/IP")
    parser.add_argument("--port", type=int, default=None, help="Port (omit for default 1433)")
    parser.add_argument("--instance-name", default="MSSQLSERVER",
                         help="Named instance (default: MSSQLSERVER, i.e. the default instance)")
    parser.add_argument("--trusted-connection", action="store_true",
                         help="Use Windows Authentication instead of a SQL Server login.")
    parser.add_argument("--username", default=None,
                         help="SQL Server login (SQL auth). Required unless --trusted-connection is set.")
    parser.add_argument("--password", default=None,
                         help="SQL Server password. Prompted securely if omitted.")
    parser.add_argument("--database", action="append", dest="databases",
                         help="Database name to collect (repeatable). If omitted, "
                              "every online database on the instance is used.")
    parser.add_argument("--min-interval-minutes", type=int, default=None,
                         help="Skip collection if a snapshot was already taken within this "
                              "many minutes -- keeps manual/out-of-band runs from creating "
                              "extra, irregularly-spaced snapshots between scheduled ones. "
                              "Omit to always take a new snapshot (the old, unguarded behavior).")
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

    print(f"\n{'='*60}")
    print(f"MS SQL Cumulative-DMV Collector")
    print(f"{'='*60}")
    print(f"Host:      {args.host}")
    print(f"Instance:  {args.instance_name}")
    print(f"Auth:      {'Windows (trusted connection)' if args.trusted_connection else f'SQL Server login ({args.username})'}")
    print(f"Databases: {', '.join(args.databases) if args.databases else '(auto-discover)'}")
    print(f"{'='*60}\n")

    result = run_dmv_collection(cfg, database_names=args.databases, min_interval_minutes=args.min_interval_minutes)

    print(f"\n{'='*60}")
    print(f"RESULT")
    print(f"{'='*60}")
    print(f"Snapshot ID: {result['snapshot_id']}")
    print(f"Tables collected:")
    for table, count in result["tables_collected"].items():
        print(f"  {table}: {count} rows")
    print(f"Databases processed: {result['databases_processed']}")
    print(f"Databases skipped:   {result['databases_skipped']}")
    if result["errors"]:
        print(f"Errors:")
        for e in result["errors"]:
            print(f"  - {e}")
    print(f"{'='*60}\n")

    # Real bug found from real data: this used to fall through to an
    # implicit exit 0 regardless of what result actually contained --
    # a caller (like mssql_collector_scheduler.py) checking only
    # subprocess returncode==0 would see "completed successfully" even
    # when the collector never got past instance resolution, since a
    # caught, logged error here was never distinct from genuine
    # success at the process-exit level. result["skipped"]==True is
    # NOT a failure -- min_interval_minutes deliberately declining to
    # take a new snapshot yet is expected, correct behavior, so it's
    # excluded from this check on purpose.
    if result["errors"] or (result["snapshot_id"] is None and not result.get("skipped")):
        sys.exit(1)


if __name__ == "__main__":
    _main()
