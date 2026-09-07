-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Cumulative DMV Delta Tables (Tier 1 + Tier 2)
-- Avekshaa Technologies
-- ============================================================
--
-- Run AFTER mssql_core_tables.sql. Every table here references
-- mssql_dmv_snapshot(snapshot_id) -- the "cumulative-counter delta
-- snapshot" model (Analysis Model doc Section 4.2). These DMVs reset
-- on restart and only ever grow; the collector polls on a fixed
-- interval, stores the raw cumulative value each time, and computes
-- (current - previous) / elapsed_seconds for rate-based metrics --
-- the same pattern already used for Oracle's cumulative instance
-- statistics. Getting the delta computation right is the collector's
-- job (modules/mssql/dmv_delta_collector.py, not yet built) -- these
-- tables store the raw polled values, not pre-computed deltas, so a
-- correctness bug in delta math never corrupts stored history.
--
-- Related tables sharing an obvious natural key (dm_exec_requests +
-- dm_tran_locks + dm_os_waiting_tasks for blocking; dm_db_index_usage_stats
-- + dm_db_index_operational_stats for index I/O; dm_exec_cached_plans
-- + dm_exec_query_stats for plan cache; dm_exec_sessions +
-- dm_exec_connections for sessions) are consolidated into one table
-- each rather than mirrored 1:1 per DMV, since they're always queried
-- together in practice and share the same join key.
-- ============================================================

\echo 'Creating MS SQL cumulative-DMV tables...'

-- ══════════════════ TIER 1 ══════════════════

-- ── mssql_wait_stats_delta ────────────────────────────────────────
-- sys.dm_os_wait_stats. Instance-wide, fine-grained wait_type (not
-- the category-level granularity of mssql_qs_wait_stats) -- the
-- companion table for the Analysis Model doc Section 3.1 two-tier
-- wait rule design.
CREATE TABLE IF NOT EXISTS mssql_wait_stats_delta (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    wait_type                      TEXT NOT NULL,
    waiting_tasks_count            BIGINT,
    wait_time_ms                   BIGINT,
    max_wait_time_ms               BIGINT,
    signal_wait_time_ms            BIGINT,
    CONSTRAINT mssql_wait_stats_delta_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_wsd_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_wait_stats_delta UNIQUE (snapshot_id, wait_type) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_wait_stats_delta IS 'sys.dm_os_wait_stats, raw cumulative values per poll. Instance-wide wait_type granularity.';

-- ── mssql_blocking_snapshot ────────────────────────────────────────
-- Combines sys.dm_exec_requests (blocking_session_id, wait info) with
-- sys.dm_tran_locks / sys.dm_os_waiting_tasks context. One row per
-- blocked session captured at poll time -- inherently point-in-time,
-- not a delta (a blocking snapshot from 2 minutes ago tells you
-- nothing about right now), so no row_hash/dedup needed beyond the
-- natural (snapshot_id, session_id) key.
CREATE TABLE IF NOT EXISTS mssql_blocking_snapshot (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    database_name                  TEXT,
    session_id                     INTEGER NOT NULL,
    blocking_session_id            INTEGER,
    wait_type                      TEXT,
    wait_time_ms                   BIGINT,
    wait_resource                  TEXT,
    resource_type                  TEXT,          -- from dm_tran_locks, e.g. 'OBJECT', 'PAGE', 'KEY'
    request_mode                   TEXT,           -- from dm_tran_locks, e.g. 'X', 'S', 'IX'
    request_status                 TEXT,           -- from dm_tran_locks, 'WAIT' or 'GRANT'
    cpu_time_ms                    BIGINT,
    total_elapsed_time_ms          BIGINT,
    logical_reads                  BIGINT,
    command                        TEXT,
    CONSTRAINT mssql_blocking_snapshot_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_block_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_blocking_snapshot UNIQUE (snapshot_id, session_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_blocking_snapshot IS 'sys.dm_exec_requests + sys.dm_tran_locks + sys.dm_os_waiting_tasks, consolidated. One row per session captured with an active wait/block at poll time.';

CREATE INDEX IF NOT EXISTS idx_mssql_blocking_head ON public.mssql_blocking_snapshot USING btree (snapshot_id, blocking_session_id) TABLESPACE mssqlparser_idx;

-- ── mssql_index_usage_delta ────────────────────────────────────────
-- Combines sys.dm_db_index_usage_stats (seeks/scans/lookups/updates)
-- with sys.dm_db_index_operational_stats (latch/lock waits, leaf
-- insert/update/delete) -- the segment-statistics equivalent.
CREATE TABLE IF NOT EXISTS mssql_index_usage_delta (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    database_name                  TEXT NOT NULL,
    schema_name                    TEXT,
    object_name                    TEXT NOT NULL,
    index_name                     TEXT,
    index_id                       INTEGER,
    user_seeks                     BIGINT,
    user_scans                     BIGINT,
    user_lookups                   BIGINT,
    user_updates                   BIGINT,
    leaf_insert_count              BIGINT,
    leaf_delete_count              BIGINT,
    leaf_update_count              BIGINT,
    page_latch_wait_count          BIGINT,
    page_latch_wait_in_ms          BIGINT,
    page_io_latch_wait_count       BIGINT,
    page_io_latch_wait_in_ms       BIGINT,
    row_lock_wait_count            BIGINT,
    row_lock_wait_in_ms            BIGINT,
    CONSTRAINT mssql_index_usage_delta_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_iud_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_index_usage_delta UNIQUE (snapshot_id, database_name, object_name, index_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_index_usage_delta IS 'sys.dm_db_index_usage_stats + sys.dm_db_index_operational_stats, consolidated. Segment-statistics equivalent.';

CREATE INDEX IF NOT EXISTS idx_mssql_iud_object ON public.mssql_index_usage_delta USING btree (database_name, object_name) TABLESPACE mssqlparser_idx;

-- ── mssql_perf_counters ────────────────────────────────────────────
-- sys.dm_os_performance_counters. Mixed gauge/cumulative counter
-- types (cntr_type governs which) -- the collector is responsible for
-- treating each correctly at read time, this table just stores what
-- was read.
CREATE TABLE IF NOT EXISTS mssql_perf_counters (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    object_name                    TEXT NOT NULL,
    counter_name                   TEXT NOT NULL,
    instance_name                  TEXT NOT NULL DEFAULT '',
    cntr_value                     BIGINT,
    cntr_type                      INTEGER,
    CONSTRAINT mssql_perf_counters_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_pc_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_perf_counters UNIQUE (snapshot_id, object_name, counter_name, instance_name) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_perf_counters IS 'sys.dm_os_performance_counters. Buffer cache hit ratio, Page Life Expectancy, Memory Grants Pending, etc. -- instance-efficiency equivalent.';

-- ── mssql_memory_clerks ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_memory_clerks (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    clerk_type                     TEXT NOT NULL,
    clerk_name                     TEXT,
    pages_kb                       BIGINT,
    virtual_memory_committed_kb    BIGINT,
    CONSTRAINT mssql_memory_clerks_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_mc_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_memory_clerks UNIQUE (snapshot_id, clerk_type, clerk_name) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_memory_clerks IS 'sys.dm_os_memory_clerks. Current memory allocation by subsystem -- supports "near cap and PLE is low" style rules, not a true sizing advisor (Analysis Model doc Section 9.2 -- SQL Server has no SGA/PGA-advisor equivalent).';

-- ── mssql_config_snapshot ──────────────────────────────────────────
-- Combines sys.configurations (server-level settings) with
-- sys.dm_os_sys_info and sys.databases (recovery model, compat
-- level) -- mostly static context captured once per snapshot, not a
-- per-item delta table.
CREATE TABLE IF NOT EXISTS mssql_config_snapshot (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    max_server_memory_mb           BIGINT,
    min_server_memory_mb           BIGINT,
    max_dop                        INTEGER,
    cost_threshold_for_parallelism INTEGER,
    cpu_count                      INTEGER,
    physical_memory_kb             BIGINT,
    database_name                  TEXT,
    recovery_model_desc            TEXT,
    compatibility_level             INTEGER,
    CONSTRAINT mssql_config_snapshot_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_cfg_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_config_snapshot UNIQUE (snapshot_id, database_name) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_config_snapshot IS 'sys.configurations + sys.dm_os_sys_info + sys.databases, consolidated. Mostly-static context, one row per database per snapshot (server-level columns repeat per row, database-level columns vary).';

-- ══════════════════ TIER 2 ══════════════════

-- ── mssql_file_io_delta ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_file_io_delta (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    database_name                  TEXT NOT NULL,
    file_id                        INTEGER NOT NULL,
    logical_file_name              TEXT,
    num_of_reads                   BIGINT,
    num_of_bytes_read              BIGINT,
    io_stall_read_ms               BIGINT,
    num_of_writes                  BIGINT,
    num_of_bytes_written           BIGINT,
    io_stall_write_ms              BIGINT,
    size_on_disk_bytes             BIGINT,
    CONSTRAINT mssql_file_io_delta_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_fid_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_file_io_delta UNIQUE (snapshot_id, database_name, file_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_file_io_delta IS 'sys.dm_io_virtual_file_stats. File/tablespace-I/O equivalent.';

-- ── mssql_volume_stats ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_volume_stats (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    volume_mount_point             TEXT NOT NULL,
    total_bytes                    BIGINT,
    available_bytes                BIGINT,
    CONSTRAINT mssql_volume_stats_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_vs_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_volume_stats UNIQUE (snapshot_id, volume_mount_point) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_volume_stats IS 'sys.dm_os_volume_stats. Free space per volume hosting database files.';

-- ── mssql_tempdb_session_usage ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_tempdb_session_usage (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    session_id                     INTEGER NOT NULL,
    login_name                     TEXT,
    user_objects_alloc_page_count  BIGINT,
    internal_objects_alloc_page_count BIGINT,
    CONSTRAINT mssql_tempdb_session_usage_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_tsu_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_tempdb_session_usage UNIQUE (snapshot_id, session_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_tempdb_session_usage IS 'sys.dm_db_session_space_usage. TempDB pressure by session (cumulative across the session''s lifetime).';

-- ── mssql_tempdb_task_usage ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_tempdb_task_usage (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    session_id                     INTEGER NOT NULL,
    request_id                     INTEGER NOT NULL DEFAULT 0,
    internal_objects_alloc_page_count BIGINT,
    internal_objects_dealloc_page_count BIGINT,
    CONSTRAINT mssql_tempdb_task_usage_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_ttu_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_tempdb_task_usage UNIQUE (snapshot_id, session_id, request_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_tempdb_task_usage IS 'sys.dm_db_task_space_usage. TempDB pressure by currently-executing task -- point-in-time, unlike session_usage''s cumulative view.';

-- ── mssql_plan_cache_stats ─────────────────────────────────────────
-- Combines sys.dm_exec_cached_plans (plan cache metadata) with
-- sys.dm_exec_query_stats (aggregated execution stats per plan). Uses
-- query_hash/query_plan_hash (stable across recompiles) rather than
-- the raw plan_handle/sql_handle binary tokens, which aren't
-- meaningful to persist across polls once a plan ages out of cache.
CREATE TABLE IF NOT EXISTS mssql_plan_cache_stats (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    query_hash                     TEXT NOT NULL,
    query_plan_hash                TEXT,
    objtype                        TEXT,
    usecounts                      BIGINT,
    size_in_bytes                  BIGINT,
    execution_count                BIGINT,
    total_worker_time_us           BIGINT,
    total_elapsed_time_us          BIGINT,
    total_logical_reads            BIGINT,
    total_physical_reads           BIGINT,
    CONSTRAINT mssql_plan_cache_stats_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_pcs_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_plan_cache_stats UNIQUE (snapshot_id, query_hash, query_plan_hash) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_plan_cache_stats IS 'sys.dm_exec_cached_plans + sys.dm_exec_query_stats, consolidated. Surfaces plan reuse and single-use plan bloat (parameter sniffing / ad-hoc query volume).';

-- ── mssql_scheduler_stats ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_scheduler_stats (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    scheduler_id                   INTEGER NOT NULL,
    cpu_id                         INTEGER,
    is_online                      BOOLEAN,
    runnable_tasks_count           INTEGER,
    current_tasks_count            INTEGER,
    work_queue_count               BIGINT,
    pending_disk_io_count           INTEGER,
    load_factor                    INTEGER,
    CONSTRAINT mssql_scheduler_stats_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_ss_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_scheduler_stats UNIQUE (snapshot_id, scheduler_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_scheduler_stats IS 'sys.dm_os_schedulers. CPU pressure/scheduling contention -- runnable_tasks_count queue depth is the key signal, distinct from raw CPU-time-per-query.';

-- ── mssql_session_stats ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_session_stats (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    session_id                     INTEGER NOT NULL,
    login_name                     TEXT,
    host_name                      TEXT,
    program_name                   TEXT,
    status                         TEXT,
    cpu_time_ms                    BIGINT,
    memory_usage_kb                BIGINT,
    reads                          BIGINT,
    writes                         BIGINT,
    logical_reads                  BIGINT,
    client_net_address             TEXT,
    connect_time                   TIMESTAMP WITHOUT TIME ZONE,
    CONSTRAINT mssql_session_stats_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_sess_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_session_stats UNIQUE (snapshot_id, session_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_session_stats IS 'sys.dm_exec_sessions + sys.dm_exec_connections, consolidated.';

\echo '  Cumulative-DMV tables: done (13 tables, Tier 1 + Tier 2)'
