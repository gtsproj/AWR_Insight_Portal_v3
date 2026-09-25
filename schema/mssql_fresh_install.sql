-- ============================================================
-- DAR Portal — MS SQL Server Support — Consolidated Fresh-Install Schema
-- Avekshaa Technologies
-- ============================================================
-- Single-file installer: run this once on a fresh PostgreSQL database
-- to create the complete MS SQL Server side of DAR Portal's schema,
-- in the correct dependency order, instead of running each of the
-- individual schema/mssql_*.sql files by hand in the right sequence.
--
-- PREREQUISITE, CONFIRMED BY ACTUALLY RUNNING THIS SCRIPT ON A FRESH
-- DATABASE, NOT ASSUMED: the "dar_portal_user" role must already
-- exist before running this file. This script does not create it --
-- it's created as part of the Oracle-side DAR Portal install this
-- MS SQL support is added on top of (mirroring
-- grant_tablespace_permissions.sql's existing pattern for the
-- awrparser/awrparser_idx tablespaces). Running this file against a
-- database that has never had the Oracle-side schema installed, with
-- no dar_portal_user role, will fail on the two tablespace GRANT
-- statements near the top (everything else still succeeds -- those
-- two are non-fatal to the rest of the script, but should still be
-- fixed by creating the role first, not ignored).
--
-- Assembled from these individual files, concatenated in dependency
-- order (each file's own IF NOT EXISTS / ADD COLUMN IF NOT EXISTS
-- guards are preserved as-is, not rewritten) -- safe to re-run on an
-- already-installed database too, same as every file it's built from
-- (verified directly: ran this file twice in a row against the same
-- database, zero errors and identical table/row counts both times):
--   1.  mssql_tablespace_grants.sql        (tablespaces -- must be first)
--   2.  mssql_core_tables.sql              (instance/snapshot/QS-interval)
--   3.  mssql_wait_event_master_table.sql  (wait-type reference table)
--   4.  mssql_dmv_tables.sql               (13 cumulative-DMV tables)
--   5.  mssql_qs_tables.sql                (5 Query Store tables)
--   6.  mssql_deadlock_table.sql           (2 deadlock tables)
--   7.  mssql_connections_table.sql        (credentials/scheduler config)
--   8.  mssql_recommendation_tables.sql    (recommendation engine)
--   9.  mssql_sqlwr_auto_generation.sql    (sqlserver_start_time + report tracking)
--   10. mssql_cpu_utilization_history.sql  (CPU utilization history)
--   11. mssql_plan_cache_summary.sql       (plan cache bloat summary)
--   12. mssql_blocking_snapshot_add_object_columns.sql (blocking detail columns)
--   13. mssql_dmv_snapshot_time_utc_fix.sql            (UTC snapshot_time fix)
--   14. mssql_file_io_type_desc.sql                    (file type classification)
--   15. mssql_index_usage_delta_extend.sql              (Segment Statistics columns)
--   16. mssql_wait_event_master_data.sql   (wait-type seed data, 1360 rows)
--
-- Deliberately NOT included (not schema, or not applicable to a fresh
-- install):
--   - mssql_deadlock_events_add_rcsi_columns.sql -- redundant: those
--     columns are already part of mssql_deadlock_table.sql's own
--     CREATE TABLE (step 6 above); this file only exists for an
--     installation that predates that column being added there.
--   - mssql_instance_master_sync_from_db_master.sql -- a one-time data
--     sync FROM an existing awr_db_master table, meaningless on a
--     database that doesn't have one yet.
--   - mssql_truncate_dmv_history.sql -- a destructive maintenance
--     script (truncates collected data), never appropriate in an
--     installer.
--
-- Verified end-to-end on a genuinely fresh, empty PostgreSQL database
-- (not just the accumulated project dev database): 30 tables created
-- (exactly matching the sum of every base table file's own table
-- count -- nothing silently missing), 1360 wait-event seed rows
-- loaded, all four ALTER-added columns from the patch files present
-- (mssql_blocking_snapshot.blocked_object_name,
-- mssql_dmv_snapshot.sqlserver_start_time,
-- mssql_file_io_delta.file_type_desc,
-- mssql_index_usage_delta.range_scan_count), and confirmed
-- mssql_dmv_snapshot.snapshot_time's default is the corrected
-- "now() AT TIME ZONE 'utc'" -- not the older, buggy local-time
-- default -- so a fresh install starts correct rather than needing
-- the UTC fix applied as an afterthought.
--
-- If the individual files above change in the future, regenerate this
-- file from them rather than hand-editing it directly, so it never
-- silently drifts from the source files it's assembled from.
-- ============================================================


-- ============================================================
-- Source: schema/mssql_tablespace_grants.sql
-- ============================================================
-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Tablespace Setup and Grants
-- Avekshaa Technologies
-- ============================================================
--
-- Confirmed tablespace names (per Ganesh, MS SQL Analysis Model
-- design doc v1.2/v1.3 Section 5): mssqlparser / mssqlparser_idx --
-- mirrors the existing awrparser/awrparser_idx split exactly. Same
-- PostgreSQL database as the Oracle schema, separate tablespace only.
--
-- Run this ONCE, before any of the mssql_*_tables.sql scripts, on
-- either a fresh install or an existing installation being extended
-- to MS SQL Server support. Safe to re-run (IF NOT EXISTS guards
-- throughout, matching every other schema script in this project).
-- ============================================================

\echo 'Creating MS SQL Server tablespaces...'

-- NOTE: PostgreSQL's CREATE TABLESPACE has no IF NOT EXISTS clause
-- (confirmed against PostgreSQL 16's own \h CREATE TABLESPACE output),
-- AND cannot run inside a DO block/function at all (tested directly --
-- "CREATE TABLESPACE cannot be executed from a function"). The \gexec
-- pattern below is PostgreSQL's standard, correct way to make DDL like
-- this idempotent when IF NOT EXISTS isn't available -- verified with
-- two consecutive runs, second run produces zero errors and creates
-- nothing.
--
-- Worth knowing: install_fresh.sql's existing
-- "CREATE TABLESPACE IF NOT EXISTS awrparser" has the same invalid
-- syntax -- it would only surface as an error if someone re-runs that
-- installer on a system where the tablespace already exists, which
-- the file's own header describes as safe to do. Not fixed here since
-- it's out of scope for MS SQL schema work and touches the existing
-- Oracle install script -- flagging for you to decide whether/when to
-- address separately.
SELECT 'CREATE TABLESPACE mssqlparser OWNER postgres LOCATION ''C:\PostgreSQL\tablespaces\mssqlparser'''
WHERE NOT EXISTS (SELECT 1 FROM pg_tablespace WHERE spcname = 'mssqlparser')
\gexec
-- ^^^ EDIT THIS PATH before running

SELECT 'CREATE TABLESPACE mssqlparser_idx OWNER postgres LOCATION ''C:\PostgreSQL\tablespaces\mssqlparser_idx'''
WHERE NOT EXISTS (SELECT 1 FROM pg_tablespace WHERE spcname = 'mssqlparser_idx')
\gexec
-- ^^^ EDIT THIS PATH before running

\echo '  MS SQL tablespaces: done'

-- DAR_PORTAL_USER already exists and already owns the Oracle schema --
-- its own comment in install_fresh.sql already anticipates this
-- ("Designed to own objects across multiple DB platform modules:
-- Oracle AWR, MS SQL Server, PostgreSQL, MySQL, MariaDB, etc.") --
-- so no new role is needed, only the tablespace-level grant, exactly
-- mirroring grant_tablespace_permissions.sql's existing pattern for
-- awrparser/awrparser_idx.
\echo 'Granting DAR_PORTAL_USER access to MS SQL tablespaces...'

GRANT CREATE ON TABLESPACE mssqlparser     TO DAR_PORTAL_USER;
GRANT CREATE ON TABLESPACE mssqlparser_idx TO DAR_PORTAL_USER;

\echo '  Grants: done'
\echo ''
\echo 'Next: run mssql_core_tables.sql, then mssql_qs_tables.sql,'
\echo 'then mssql_dmv_tables.sql, then mssql_deadlock_table.sql.'

-- ============================================================
-- Source: schema/mssql_core_tables.sql
-- ============================================================
-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Core Tables: Instance Registry, DMV Snapshot Anchor, QS Interval
-- Avekshaa Technologies
-- ============================================================
--
-- Run AFTER mssql_tablespace_grants.sql. Naming convention: mssql_*
-- prefix throughout, mirroring the existing awr_* convention exactly
-- (per the MS SQL Analysis Model design doc, Section 5).
--
-- Every table below is scoped by instance_id (FK to
-- mssql_instance_master), the analog to Oracle's dbname+instance
-- columns -- but note this is genuinely a different scoping model,
-- not a renamed copy: SQL Server's "instance" already IS the whole
-- server-level unit DAR Portal registers (there's no separate
-- "database name at the instance level" ambiguity the way Oracle's
-- dbname+instance pair resolves RAC nodes), so a single instance_id
-- FK is sufficient here where Oracle needed two columns.
-- ============================================================

\echo 'Creating MS SQL core tables...'

-- ── mssql_instance_master ──────────────────────────────────────
-- The licensed instance registry -- analog to awr_db_master ("Licensed
-- database registry. Only DBs in this table will be parsed by the
-- queue processor."). Deliberately a SEPARATE table, not an overload
-- of awr_db_master -- that table's columns (inst_no, PDB-adjacent
-- concepts) are genuinely Oracle-specific, not generic across
-- platforms, despite the generic-sounding name.
--
-- host_name + instance_name is the natural key, matching how SQL
-- Server itself identifies an instance (default instance = just the
-- host name; named instance = "HOSTNAME\INSTANCENAME").
CREATE TABLE IF NOT EXISTS mssql_instance_master (
    id                             SERIAL,
    host_name                      TEXT NOT NULL,
    instance_name                  TEXT NOT NULL DEFAULT 'MSSQLSERVER',
    display_name                   TEXT,
    sql_version                    TEXT,
    sql_edition                    TEXT,
    is_named_instance              BOOLEAN DEFAULT false,
    active                         BOOLEAN DEFAULT true,
    added_at                       TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    added_by                       TEXT DEFAULT 'admin'::text,
    app_name                       TEXT,
    app_code                       TEXT,
    app_usage                      TEXT DEFAULT 'OTHER'::text,
    app_category                   TEXT DEFAULT 'OTHER'::text,
    -- Reserved for the parked Availability Group design (Analysis
    -- Model doc Section 9.1) -- not populated by anything in Phase 1,
    -- included now so a future AG implementation doesn't need a
    -- migration just to add these three columns.
    ag_group_id                    TEXT,
    ag_name                        TEXT,
    ag_replica_role                TEXT,
    CONSTRAINT mssql_instance_master_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT uq_mssql_instance UNIQUE (host_name, instance_name) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_instance_master IS 'Licensed MS SQL Server instance registry. Only instances in this table will be collected by the MS SQL collector. Mirrors awr_db_master''s role for Oracle.';

CREATE INDEX IF NOT EXISTS idx_mssql_instance_active ON public.mssql_instance_master USING btree (active) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_instance_app_category ON public.mssql_instance_master USING btree (app_category) TABLESPACE mssqlparser_idx;

-- ── mssql_dmv_snapshot ──────────────────────────────────────────
-- One row per DMV polling event (Analysis Model doc Section 4.2's
-- "cumulative-counter delta snapshot" model). Every mssql_*_delta
-- table (mssql_dmv_tables.sql) references this via snapshot_id -- the
-- anchor every delta computation is computed against, analogous in
-- spirit to an AWR begin_snap/end_snap pair, though this is a single
-- poll-event row, not a range.
CREATE TABLE IF NOT EXISTS mssql_dmv_snapshot (
    snapshot_id                    SERIAL,
    instance_id                    INTEGER NOT NULL,
    snapshot_time                  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    collector_version               TEXT,
    CONSTRAINT mssql_dmv_snapshot_pkey PRIMARY KEY (snapshot_id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_dmv_snapshot_instance
        FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id)
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_dmv_snapshot IS 'One row per cumulative-DMV polling event. All mssql_*_delta tables reference this by snapshot_id -- the analog to an AWR begin_snap, but for a single poll rather than a range.';

CREATE INDEX IF NOT EXISTS idx_mssql_dmv_snap_inst_time ON public.mssql_dmv_snapshot USING btree (instance_id, snapshot_time) TABLESPACE mssqlparser_idx;

-- ── mssql_qs_interval ───────────────────────────────────────────
-- Pulled directly from sys.query_store_runtime_stats_interval -- the
-- analog to an AWR snapshot, except Query Store already produces this
-- aggregation natively (Analysis Model doc Section 4.2's "native
-- interval pull" model -- no delta math needed here, unlike
-- mssql_dmv_snapshot above).
--
-- Scoped by (instance_id, database_name) -- NOT instance_id alone.
-- This is the schema correctness point the licensing discussion
-- surfaced (Analysis Model doc Section 5): Query Store is enabled and
-- scoped PER DATABASE, and one instance routinely hosts many
-- databases, each with its own independent Query Store interval
-- numbering. qs_interval_id is only unique within one database's
-- Query Store, not across the whole instance.
CREATE TABLE IF NOT EXISTS mssql_qs_interval (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    database_name                  TEXT NOT NULL,
    qs_interval_id                 BIGINT NOT NULL,
    start_time                     TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    end_time                       TIMESTAMP WITHOUT TIME ZONE,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_qs_interval_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_qs_interval_instance
        FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_qs_interval UNIQUE (instance_id, database_name, qs_interval_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_qs_interval IS 'sys.query_store_runtime_stats_interval per instance+database. Query Store already aggregates into these intervals natively -- this table just records which ones have been pulled.';

CREATE INDEX IF NOT EXISTS idx_mssql_qs_interval_time ON public.mssql_qs_interval USING btree (instance_id, database_name, start_time) TABLESPACE mssqlparser_idx;

\echo '  Core tables: done (mssql_instance_master, mssql_dmv_snapshot, mssql_qs_interval)'

-- ============================================================
-- Source: schema/mssql_wait_event_master_table.sql
-- ============================================================
-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Wait Event Master Table
-- Avekshaa Technologies
-- ============================================================
-- Mirrors awr_wait_event_master's role for Oracle: a broad reference
-- table used to ground AI narrative generation (Analysis Model doc
-- Section 10.4's equivalent for MS SQL, once built) and to give the
-- portal UI/rules engine a single source of truth for which events
-- have dedicated rules versus which are catalogued but not yet
-- individually covered.
--
-- Two tiers in one table (tier column), not two separate tables --
-- MS SQL genuinely has two distinct wait namespaces that don't
-- overlap: wait_type (sys.dm_os_wait_stats, ~1,300+ raw values) and
-- wait_category (sys.query_store_wait_stats, a fixed 24-value enum).
-- Both need guidance text and rule-coverage tracking, so both live
-- here rather than inventing a second master table.
--
-- Same honest scope as Oracle's own master table: broad NAME and
-- wait_class coverage across the full catalog, but only a SUBSET
-- (the ones this project has actually researched -- rule-covered
-- events plus the confirmed-benign list) get real, sourced
-- guidance_text. The rest have wait_class classification (derived
-- from naming convention, reasonable confidence) but NULL guidance --
-- left honestly blank rather than filled with unverified text.
-- ============================================================

\echo 'Creating mssql_wait_event_master...'

CREATE TABLE IF NOT EXISTS mssql_wait_event_master (
    id                  SERIAL,
    tier                TEXT NOT NULL,      -- 'wait_type' or 'wait_category'
    event_name          TEXT NOT NULL,
    wait_class          TEXT,               -- broad grouping (I/O, Lock, CPU, Memory,
                                             -- Parallelism, Transaction Log, Network,
                                             -- Preemptive, Internal, etc.) -- classified
                                             -- from naming convention where guidance_text
                                             -- research hasn't been done individually
    is_benign           BOOLEAN DEFAULT false,   -- matches BENIGN_WAIT_TYPES in rule_engine.py
                                                  -- for tier='wait_type'; NULL/false otherwise
    has_specific_rule   BOOLEAN DEFAULT false,   -- true if a rule in
                                                  -- recommendation_rules_mssql_v1.json
                                                  -- targets this event_name
    rule_ids            TEXT,               -- comma-separated rule_id(s) covering this
                                             -- event, if has_specific_rule is true
    guidance_text       TEXT,               -- populated only where actually researched
                                             -- this project -- NULL is honest, not a gap
                                             -- to silently paper over
    source              TEXT,               -- where guidance_text's claims came from,
                                             -- for traceability (e.g. a URL or "Paul
                                             -- Randal, sqlskills.com") -- NULL where
                                             -- guidance_text itself is NULL
    CONSTRAINT mssql_wait_event_master_pkey PRIMARY KEY (tier, event_name) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_wait_event_master IS 'Wait event reference catalog covering both sys.dm_os_wait_stats (tier=wait_type) and sys.query_store_wait_stats (tier=wait_category). Mirrors awr_wait_event_master''s role -- broad name/class coverage, guidance_text populated only where actually researched.';

CREATE INDEX IF NOT EXISTS idx_mssql_wait_event_master_class ON public.mssql_wait_event_master USING btree (wait_class) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_wait_event_master_has_rule ON public.mssql_wait_event_master USING btree (has_specific_rule) TABLESPACE mssqlparser_idx;

\echo '  mssql_wait_event_master: done'

-- ============================================================
-- Source: schema/mssql_dmv_tables.sql
-- ============================================================
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
    blocked_object_name            TEXT,           -- resolved at collection time via OBJECT_NAME() --
                                                    -- OBJECT-type locks resolve resource_associated_entity_id
                                                    -- directly; PAGE/KEY/RID types resolve via sys.partitions
                                                    -- (object_id alone is meaningless outside its source database,
                                                    -- same reasoning as mssql_qs_query.object_name)
    blocked_index_name             TEXT,           -- only populated for PAGE/KEY/RID (row/page-level) locks --
                                                    -- an OBJECT-level (table-level) lock has no single index to name
    blocked_statement_text         TEXT,           -- the actual statement text the blocked session was executing,
                                                    -- via sys.dm_exec_sql_text + statement_start/end_offset
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

-- ============================================================
-- Source: schema/mssql_qs_tables.sql
-- ============================================================
-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Query Store Tables (Tier 1 — Query Performance)
-- Avekshaa Technologies
-- ============================================================
--
-- Run AFTER mssql_core_tables.sql. Mirrors sys.query_store_query_text
-- / query / plan / runtime_stats / wait_stats.
--
-- Every table here is scoped (instance_id, database_name, native_id)
-- -- not just instance_id -- because Query Store IDs (query_id,
-- plan_id, query_text_id) are only unique WITHIN one database's
-- Query Store, not across the whole instance. This is the schema
-- correctness point the licensing discussion surfaced (Analysis
-- Model doc Section 5) -- getting this wrong here would be the same
-- class of bug as the RAC instance-scoping issues fixed repeatedly
-- on the Oracle side this project.
-- ============================================================

\echo 'Creating MS SQL Query Store tables...'

-- ── mssql_qs_query_text ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_qs_query_text (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    database_name                  TEXT NOT NULL,
    qs_query_text_id               BIGINT NOT NULL,
    query_sql_text                 TEXT,
    statement_sql_handle           BYTEA,
    first_seen_at                  TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT mssql_qs_query_text_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_qs_qt_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_qs_query_text UNIQUE (instance_id, database_name, qs_query_text_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_qs_query_text IS 'sys.query_store_query_text. SQL text is stored once per distinct statement, referenced by mssql_qs_query.';

-- ── mssql_qs_query ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_qs_query (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    database_name                  TEXT NOT NULL,
    qs_query_id                    BIGINT NOT NULL,
    qs_query_text_id               BIGINT NOT NULL,
    object_id                      BIGINT,
    object_name                    TEXT,
    query_parameterization_type_desc TEXT,
    is_internal_query              BOOLEAN,
    first_execution_time           TIMESTAMP WITHOUT TIME ZONE,
    last_execution_time            TIMESTAMP WITHOUT TIME ZONE,
    CONSTRAINT mssql_qs_query_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_qs_q_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_qs_query UNIQUE (instance_id, database_name, qs_query_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_qs_query IS 'sys.query_store_query. object_name resolved at collection time from object_id (OBJECT_NAME()) since object_id alone is meaningless outside its source database.';

CREATE INDEX IF NOT EXISTS idx_mssql_qs_query_text_ref ON public.mssql_qs_query USING btree (instance_id, database_name, qs_query_text_id) TABLESPACE mssqlparser_idx;

-- ── mssql_qs_plan ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_qs_plan (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    database_name                  TEXT NOT NULL,
    qs_plan_id                     BIGINT NOT NULL,
    qs_query_id                    BIGINT NOT NULL,
    query_plan                     TEXT,          -- XML plan, stored as text (large; consider TOAST-friendly compression at collection time)
    is_parallel_plan               BOOLEAN,
    is_forced_plan                 BOOLEAN,
    first_seen_at                  TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT mssql_qs_plan_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_qs_p_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_qs_plan UNIQUE (instance_id, database_name, qs_plan_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_qs_plan IS 'sys.query_store_plan. This is the direct analog to Oracle execution plan storage (awr_execution_plans) -- feeds a future MS SQL equivalent of Execution Plan Analysis / multi-plan regression detection.';

CREATE INDEX IF NOT EXISTS idx_mssql_qs_plan_query_ref ON public.mssql_qs_plan USING btree (instance_id, database_name, qs_query_id) TABLESPACE mssqlparser_idx;

-- ── mssql_qs_runtime_stats ────────────────────────────────────────
-- The core "SQL ordered by Elapsed/CPU/..." analog. avg_* columns are
-- Query Store's own pre-aggregated per-interval averages -- no delta
-- math needed here (Analysis Model doc Section 4.2's "native interval
-- pull" model), unlike the DMV delta tables in mssql_dmv_tables.sql.
CREATE TABLE IF NOT EXISTS mssql_qs_runtime_stats (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    database_name                  TEXT NOT NULL,
    qs_runtime_stats_id            BIGINT NOT NULL,
    qs_plan_id                     BIGINT NOT NULL,
    qs_interval_id                 BIGINT NOT NULL,
    execution_type_desc            TEXT,
    count_executions                BIGINT,
    avg_duration_us                NUMERIC,   -- microseconds, matching Query Store's own unit
    avg_cpu_time_us                NUMERIC,
    avg_logical_io_reads           NUMERIC,
    avg_physical_io_reads          NUMERIC,
    avg_logical_io_writes          NUMERIC,
    avg_dop                        NUMERIC,
    avg_query_max_used_memory_kb   NUMERIC,
    avg_rowcount                   NUMERIC,
    avg_log_bytes_used             NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_qs_runtime_stats_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_qs_rs_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_qs_runtime_stats UNIQUE (instance_id, database_name, qs_runtime_stats_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_qs_runtime_stats IS 'sys.query_store_runtime_stats. The core Query Performance data source -- analog to AWR SQL Statistics.';

CREATE INDEX IF NOT EXISTS idx_mssql_qs_rs_plan ON public.mssql_qs_runtime_stats USING btree (instance_id, database_name, qs_plan_id) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_qs_rs_interval ON public.mssql_qs_runtime_stats USING btree (instance_id, database_name, qs_interval_id) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_qs_rs_cpu ON public.mssql_qs_runtime_stats USING btree (avg_cpu_time_us DESC) TABLESPACE mssqlparser_idx;

-- ── mssql_qs_wait_stats ───────────────────────────────────────────
-- Per-query wait attribution, category-level (Analysis Model doc
-- Section 3.1's honest granularity note: this is closer to Oracle's
-- wait CLASS than individual wait EVENTS -- the finer wait_type
-- breakdown only exists instance-wide, in mssql_wait_stats_delta).
CREATE TABLE IF NOT EXISTS mssql_qs_wait_stats (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    database_name                  TEXT NOT NULL,
    qs_wait_stats_id               BIGINT NOT NULL,
    qs_plan_id                     BIGINT NOT NULL,
    qs_interval_id                 BIGINT NOT NULL,
    wait_category_desc             TEXT,
    execution_type_desc            TEXT,
    total_query_wait_time_ms       NUMERIC,
    avg_query_wait_time_ms         NUMERIC,
    max_query_wait_time_ms         NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_qs_wait_stats_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_qs_ws_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_qs_wait_stats UNIQUE (instance_id, database_name, qs_wait_stats_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_qs_wait_stats IS 'sys.query_store_wait_stats (SQL Server 2017+ only). Per-query wait category attribution -- the analog to Oracle wait events, but category-granularity, not individual wait-type granularity.';

CREATE INDEX IF NOT EXISTS idx_mssql_qs_ws_plan ON public.mssql_qs_wait_stats USING btree (instance_id, database_name, qs_plan_id) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_qs_ws_category ON public.mssql_qs_wait_stats USING btree (wait_category_desc, total_query_wait_time_ms DESC) TABLESPACE mssqlparser_idx;

\echo '  Query Store tables: done (query_text, query, plan, runtime_stats, wait_stats)'

-- ============================================================
-- Source: schema/mssql_deadlock_table.sql
-- ============================================================
-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Deadlock Capture Tables
-- Avekshaa Technologies
-- ============================================================
--
-- Run AFTER mssql_core_tables.sql. Sourced from the system_health
-- Extended Events session's FILE TARGET, not the ring buffer --
-- confirmed against a real SQL Server 2022 source (our exact version
-- floor) that the ring buffer returns zero rows for
-- xml_deadlock_report events on 2022, even when the events are
-- genuinely captured and visible in the file target. Using the ring
-- buffer, as originally planned in the Analysis Model design doc
-- Section 9.1.4, would have silently produced empty results --
-- caught before writing the collector, not after.
--
-- Two tables, not one, adapted from Ganesh's own deadlock-extraction
-- scripts: an event has ONE contested resource but potentially MORE
-- THAN TWO participating processes (his third script explicitly
-- shreds every process via CROSS APPLY rather than assuming exactly
-- 2) -- cramming "process 1"/"process 2" columns into one row breaks
-- down for that case, so process-level detail gets its own table in
-- a natural one-to-many relationship with the event.
-- ============================================================

\echo 'Creating MS SQL deadlock capture tables...'

-- ── mssql_deadlock_events ──────────────────────────────────────
-- One row per captured deadlock EVENT -- the contested resource and
-- an overall root-cause classification (mirroring the deadlock_cause
-- CASE logic from Ganesh's own analysis script) live here.
CREATE TABLE IF NOT EXISTS mssql_deadlock_events (
    id                              SERIAL,
    instance_id                     INTEGER NOT NULL,
    deadlock_time                   TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    database_name                   TEXT,          -- resolved from the deadlock graph's own
                                                    -- currentdb attribute (DB_NAME()) -- needed to
                                                    -- look up that database's actual RCSI status,
                                                    -- not assumed/guessed
    victim_process_id               TEXT,          -- the deadlock graph's own process id (e.g. "process861a...")
                                                    -- for the victim -- joins to mssql_deadlock_processes.process_id
    process_count                   INTEGER,
    contested_table                 TEXT,
    contested_index                 TEXT,
    lock_mode_1                     TEXT,
    lock_mode_2                     TEXT,
    rcsi_enabled                    BOOLEAN,       -- the database's actual is_read_committed_snapshot_on
                                                    -- value AT COLLECTION TIME -- not necessarily the value
                                                    -- at the moment the deadlock happened, if it changed
                                                    -- since, but far more accurate than assuming
    deadlock_cause                  TEXT,          -- classified at collection time using rcsi_enabled,
                                                    -- same categories as Ganesh's script but with the
                                                    -- Read-Write conflict message adapted to whether RCSI
                                                    -- is actually on ('not enabled', 'despite RCSI being
                                                    -- enabled', or a plain '?' when the database couldn't
                                                    -- be resolved at all)
    deadlock_graph_xml              TEXT,          -- full raw XML, for anything the structured columns don't capture
    row_hash                        CHAR(32) NOT NULL,
    created_at                      TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_deadlock_events_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_deadlock_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_deadlock_events UNIQUE (instance_id, row_hash) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_deadlock_events IS 'Deadlock graphs extracted from the system_health Extended Events session''s FILE target (not ring buffer -- confirmed unreliable on SQL Server 2022). row_hash dedups against re-extracting the same event across collector runs.';

CREATE INDEX IF NOT EXISTS idx_mssql_deadlock_time ON public.mssql_deadlock_events USING btree (instance_id, deadlock_time DESC) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_deadlock_cause ON public.mssql_deadlock_events USING btree (deadlock_cause) TABLESPACE mssqlparser_idx;

-- ── mssql_deadlock_processes ───────────────────────────────────
-- One row per PROCESS participating in a deadlock event -- mirrors
-- the process-level detail Ganesh's third script extracts (role,
-- session/login/app context, isolation level, and critically the
-- exact DML statement each process was executing at deadlock time).
CREATE TABLE IF NOT EXISTS mssql_deadlock_processes (
    id                              SERIAL,
    deadlock_event_id               INTEGER NOT NULL,
    process_id                      TEXT,          -- the deadlock graph's own process id string
    role                            TEXT,          -- 'VICTIM' or 'SURVIVOR'
    spid                            INTEGER,
    client_app                      TEXT,
    login_name                      TEXT,
    host_name                       TEXT,
    isolation_level                 TEXT,
    tran_count                      INTEGER,
    input_buffer                    TEXT,          -- outermost EXEC call or ad-hoc SQL
    executing_proc                  TEXT,          -- stored procedure name, if any, from the innermost execution frame
    executing_line                  INTEGER,
    exact_dml_statement              TEXT,          -- the actual statement text at the point of deadlock --
                                                    -- falls back to input_buffer if the execution frame's own
                                                    -- text wasn't captured, same fallback Ganesh's script uses
    caller_proc                     TEXT,          -- one level up the call stack, if the executing proc was
                                                    -- itself called from another procedure
    caller_line                     INTEGER,
    CONSTRAINT mssql_deadlock_processes_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_deadlock_process_event FOREIGN KEY (deadlock_event_id) REFERENCES mssql_deadlock_events(id)
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_deadlock_processes IS 'One row per process participating in a deadlock event -- role, session context, and the exact DML statement each was executing, mirroring Ganesh''s own deadlock-analysis script''s process-level extraction.';

CREATE INDEX IF NOT EXISTS idx_mssql_deadlock_processes_event ON public.mssql_deadlock_processes USING btree (deadlock_event_id) TABLESPACE mssqlparser_idx;

\echo '  Deadlock tables: done'
\echo ''
\echo '============================================================'
\echo 'MS SQL Server Phase 1 schema install complete.'
\echo '23 tables total: 3 core + 5 Query Store + 13 cumulative-DMV + 2 deadlock'
\echo '============================================================'

-- ============================================================
-- Source: schema/mssql_connections_table.sql
-- ============================================================
-- ============================================================
-- mssql_connections -- credential/config storage for the QS and
-- DMV collectors, supporting multiple SQL Server instances, each
-- with multiple databases. Mirrors awr_oracle_connections' role
-- for Oracle, adapted for SQL Server's instance-vs-database
-- relationship: Oracle credentials are typically tied to one
-- service_name (one row per database there), but SQL Server
-- authentication is instance-level -- the same login authenticates
-- against every database on that instance -- so this is one row
-- per INSTANCE, with a list of which databases to collect on it.
-- ============================================================

CREATE TABLE IF NOT EXISTS mssql_connections (
    id                             SERIAL,
    host_name                      TEXT NOT NULL,
    instance_name                  TEXT NOT NULL DEFAULT 'MSSQLSERVER',
    display_name                   TEXT,
    port                           INTEGER,        -- NULL = default 1433, matches the
                                                     -- collectors' own --port "omit for default" convention
    auth_type                      TEXT NOT NULL DEFAULT 'trusted',  -- 'trusted' | 'sql'
    username                       TEXT,            -- required when auth_type='sql'
    password_enc                   TEXT,            -- required when auth_type='sql'; base64
                                                     -- obfuscation, NOT encryption -- same honest
                                                     -- framing as awr_oracle_connections.password_enc,
                                                     -- prevents plain-text storage, not a real secret store
    databases                      TEXT[],          -- NULL/empty = collect every online database on
                                                     -- this instance (matches dmv_delta_collector.py's
                                                     -- own "omit --database for all" convention);
                                                     -- non-empty = collect only these specific databases
    snap_interval_minutes          INTEGER NOT NULL DEFAULT 60,  -- must be one of SQL Server's own
                                                     -- valid QUERY_STORE INTERVAL_LENGTH_MINUTES values
    enabled                        BOOLEAN DEFAULT true,
    last_run_at                    TIMESTAMP WITHOUT TIME ZONE,
    last_dmv_snapshot_id           INTEGER,
    last_run_status                TEXT,            -- 'success' | 'failed' | 'skipped' | NULL (never run)
    last_run_error                 TEXT,
    added_at                       TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    added_by                       TEXT DEFAULT 'admin'::text,
    CONSTRAINT mssql_connections_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT uq_mssql_conn UNIQUE (host_name, instance_name) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT chk_mssql_conn_auth CHECK (
        (auth_type = 'trusted') OR
        (auth_type = 'sql' AND username IS NOT NULL AND password_enc IS NOT NULL)
    ),
    CONSTRAINT chk_mssql_conn_interval CHECK (snap_interval_minutes IN (1, 5, 10, 15, 30, 60, 1440))
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_connections IS 'SQL Server instance connection config for the QS/DMV collectors. One row per instance (not per database -- SQL Server auth is instance-level). Mirrors awr_oracle_connections'' role for Oracle. Read by mssql_collector_scheduler.py --from-config.';

CREATE INDEX IF NOT EXISTS idx_mssql_conn_enabled ON public.mssql_connections USING btree (enabled) TABLESPACE mssqlparser_idx;

-- ============================================================
-- Source: schema/mssql_recommendation_tables.sql
-- ============================================================
-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Recommendation Engine + Ground-Truth Feedback Tables
-- Avekshaa Technologies
-- ============================================================
-- Two tables, deliberately separate: mssql_recommendations holds
-- what was generated (a fact -- this recommendation was produced at
-- this time from this evidence), mssql_recommendation_feedback holds
-- a human's review of it (mutable -- can be updated as understanding
-- of a given recommendation changes, without touching the original
-- generated record).
--
-- The feedback table is the actual ground-truth mechanism: without
-- it, "80-90% accuracy" is an assertion, not a number. Once enough
-- recommendations have been reviewed, accuracy = confirmed_real /
-- (confirmed_real + false_positive) is a real, computable metric,
-- not a guess.
-- ============================================================

\echo 'Creating MS SQL recommendation + feedback tables...'

CREATE TABLE IF NOT EXISTS mssql_recommendations (
    id                      SERIAL,
    instance_id             INTEGER NOT NULL,
    generated_at            TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    category                TEXT NOT NULL,       -- 'wait_analysis' for now; extensible
                                                  -- ('blocking', 'deadlock', 'index', ...)
                                                  -- as more rule categories are built
    severity                TEXT NOT NULL,        -- highest severity among contributing findings
    title                   TEXT NOT NULL,
    summary                 TEXT,                 -- human-readable synthesis across every
                                                   -- finding that contributed to this recommendation
    contributing_rule_ids   TEXT,                 -- comma-separated (e.g. "MSSQL_WAIT_002,MSSQL_WAIT_006")
                                                   -- -- which rules' findings were correlated together
    correlated              BOOLEAN DEFAULT false, -- true if 2+ independent findings (e.g. a
                                                    -- wait_type AND a wait_category finding for the
                                                    -- same underlying issue) corroborated each other --
                                                    -- a stronger signal than a single finding alone
    evidence_json           TEXT,                  -- structured JSON of the raw finding(s) that
                                                    -- contributed, for full traceability back to
                                                    -- the actual metrics that triggered this
    database_name           TEXT,
    affected_object          TEXT,                 -- table/wait_type/wait_category/query, whichever
                                                    -- is most specific for this recommendation
    row_hash                CHAR(32) NOT NULL,     -- dedups against re-generating the same
                                                    -- recommendation on every run while the
                                                    -- underlying condition persists
    created_at               TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_recommendations_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_recommendations_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_recommendations UNIQUE (instance_id, row_hash) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_recommendations IS 'Orchestrated, correlated recommendations synthesized from one or more rule-engine findings -- the output of recommendation_engine.py, not raw per-metric findings (those live only transiently in the rule engine''s own evaluation).';

CREATE INDEX IF NOT EXISTS idx_mssql_recommendations_instance ON public.mssql_recommendations USING btree (instance_id, generated_at DESC) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_recommendations_category ON public.mssql_recommendations USING btree (category) TABLESPACE mssqlparser_idx;


CREATE TABLE IF NOT EXISTS mssql_recommendation_feedback (
    id                      SERIAL,
    recommendation_id       INTEGER NOT NULL,
    feedback_status         TEXT NOT NULL DEFAULT 'UNREVIEWED',
                                                  -- UNREVIEWED, CONFIRMED_REAL, FALSE_POSITIVE,
                                                  -- NEEDS_INVESTIGATION
    reviewed_by             TEXT,
    reviewed_at             TIMESTAMP WITHOUT TIME ZONE,
    notes                   TEXT,
    created_at               TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_recommendation_feedback_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_feedback_recommendation FOREIGN KEY (recommendation_id) REFERENCES mssql_recommendations(id),
    CONSTRAINT uq_mssql_feedback_recommendation UNIQUE (recommendation_id) USING INDEX TABLESPACE mssqlparser_idx
    -- One feedback row per recommendation, updatable -- not a history
    -- table. If a fuller audit trail (who changed status when, more
    -- than once) turns out to matter later, that's a genuine schema
    -- change worth making deliberately then, not speculatively now.
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_recommendation_feedback IS 'The actual ground-truth mechanism: a DBA''s review of whether a generated recommendation was a real issue or a false positive. Once populated at meaningful volume, accuracy = confirmed_real / (confirmed_real + false_positive) is a computable number, not an assertion.';

CREATE INDEX IF NOT EXISTS idx_mssql_feedback_status ON public.mssql_recommendation_feedback USING btree (feedback_status) TABLESPACE mssqlparser_idx;

\echo '  Recommendation + feedback tables: done'

-- ============================================================
-- Source: schema/mssql_sqlwr_auto_generation.sql
-- ============================================================
-- ============================================================
-- 1. sqlserver_start_time on mssql_dmv_snapshot -- needed to detect
--    a SQL Server restart between two consecutive snapshots. Every
--    DMV counter (wait_time_ms, etc.) is cumulative SINCE SQL SERVER
--    STARTUP, not since portal installation -- if the instance
--    restarted between two snapshots, computing a delta across that
--    pair would produce a NEGATIVE, meaningless value (the post-
--    restart counters start back at zero, lower than the pre-restart
--    ones, even though real activity occurred in between). Storing
--    SQL Server's own start_time on each snapshot lets a restart be
--    detected directly: if two consecutive snapshots for the same
--    instance show DIFFERENT start_time values, a restart happened
--    between them, and no report should be generated for that pair.
--    Instance-level, not per-database, so it belongs on the snapshot
--    registry itself, not the database-scoped mssql_config_snapshot.
-- ============================================================

ALTER TABLE mssql_dmv_snapshot ADD COLUMN IF NOT EXISTS sqlserver_start_time TIMESTAMP WITHOUT TIME ZONE;

-- ============================================================
-- 2. mssql_sqlwr_report -- tracks which (begin_snapshot_id,
--    end_snapshot_id) pairs already have a generated SQLWR report,
--    so the auto-generation orchestration (a) never regenerates the
--    same report twice and (b) has something to query for the
--    pending/in-process/completed/failed dashboard Ganesh described
--    earlier in this project. One row per report; status tracks the
--    generation outcome, not the report's own content (that's parsed
--    into the normal mssql_* tables once Step 3, the parser, exists).
-- ============================================================

CREATE TABLE IF NOT EXISTS mssql_sqlwr_report (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    begin_snapshot_id              INTEGER NOT NULL,
    end_snapshot_id                INTEGER NOT NULL,
    report_path                    TEXT,
    status                         TEXT NOT NULL DEFAULT 'pending',  -- pending | completed | failed | skipped_restart
    error_message                  TEXT,
    generated_at                   TIMESTAMP WITHOUT TIME ZONE,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT mssql_sqlwr_report_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT uq_mssql_sqlwr_report_pair UNIQUE (instance_id, begin_snapshot_id, end_snapshot_id)
        USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_sqlwr_report_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT fk_mssql_sqlwr_report_begin FOREIGN KEY (begin_snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT fk_mssql_sqlwr_report_end FOREIGN KEY (end_snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT chk_mssql_sqlwr_report_status CHECK (status IN ('pending', 'completed', 'failed', 'skipped_restart'))
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_report IS 'Tracks auto-generated SQLWR reports, one row per (begin_snapshot_id, end_snapshot_id) pair -- the MSSQL analog to an AWR report''s begin_snap/end_snap identity.';

CREATE INDEX IF NOT EXISTS idx_mssql_sqlwr_report_status ON public.mssql_sqlwr_report USING btree (status) TABLESPACE mssqlparser_idx;

\echo 'sqlserver_start_time added to mssql_dmv_snapshot, mssql_sqlwr_report created.'

-- ============================================================
-- Source: schema/mssql_cpu_utilization_history.sql
-- ============================================================
-- ============================================================
-- mssql_cpu_utilization_history -- SQL Server process/idle/other CPU
-- utilization over time, from sys.dm_os_ring_buffers'
-- RING_BUFFER_SCHEDULER_MONITOR -- the standard, well-documented
-- source for this (Glenn Berry's/Brent Ozar's diagnostic query
-- pattern), holding up to ~256 historical samples at roughly
-- 1-minute intervals, independent of this project's own snapshot
-- schedule. One row per distinct SQL Server sample, not per
-- collection cycle -- repeated collection naturally re-sees the same
-- samples (the ~10-minute collection cadence is coarser than the
-- ring buffer's own ~1-minute sampling), deduplicated by
-- (instance_id, event_time).
--
-- event_time is stored as UTC explicitly (the collector uses
-- SYSUTCDATETIME(), not GETDATE(), specifically to avoid the exact
-- local-vs-UTC mismatch that mssql_dmv_snapshot.snapshot_time hit
-- earlier in this project) -- safe to compare directly against
-- snapshot_time for a report's time-window filtering.
-- ============================================================

CREATE TABLE IF NOT EXISTS mssql_cpu_utilization_history (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    event_time                     TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    sql_process_pct                SMALLINT,
    system_idle_pct                SMALLINT,
    other_process_pct              SMALLINT,
    collected_at_snapshot_id       INTEGER,
    CONSTRAINT mssql_cpu_util_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT uq_mssql_cpu_util UNIQUE (instance_id, event_time) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_cpu_util_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id)
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_cpu_utilization_history IS 'SQL Server CPU utilization over time from sys.dm_os_ring_buffers (RING_BUFFER_SCHEDULER_MONITOR). sql_process_pct = used by SQL Server, system_idle_pct = free, other_process_pct = used by other processes on the host.';

CREATE INDEX IF NOT EXISTS idx_mssql_cpu_util_inst_time
    ON public.mssql_cpu_utilization_history USING btree (instance_id, event_time) TABLESPACE mssqlparser_idx;

\echo 'mssql_cpu_utilization_history created.'

-- ============================================================
-- Source: schema/mssql_plan_cache_summary.sql
-- ============================================================
-- ============================================================
-- mssql_plan_cache_summary -- one row per snapshot, accurate
-- full-plan-cache aggregate counts for single-use/ad-hoc plan bloat.
--
-- The existing mssql_plan_cache_stats only keeps the TOP 200 plans
-- by usecounts (deliberately bounded, per that collector's own
-- comment, since the cache can hold tens of thousands of entries) --
-- which biases toward highly-reused plans and would UNDERCOUNT
-- single-use plans in any busy, ad-hoc-query-heavy environment where
-- more than 200 distinct plans exist. Rather than build a "single-use
-- plan bloat" report section from data that's structurally biased
-- against showing single-use plans, this is a small, separate,
-- lightweight aggregate query against the FULL cache (COUNT/SUM only,
-- not storing every individual plan) -- accurate regardless of how
-- many total plans exist.
-- ============================================================

CREATE TABLE IF NOT EXISTS mssql_plan_cache_summary (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    total_plan_count               BIGINT,
    total_plan_size_mb             NUMERIC,
    single_use_plan_count          BIGINT,     -- usecounts = 1, across the ENTIRE cache
    single_use_plan_size_mb        NUMERIC,
    adhoc_plan_count                BIGINT,     -- objtype = 'Adhoc', across the ENTIRE cache
    adhoc_plan_size_mb              NUMERIC,
    CONSTRAINT mssql_plan_cache_summary_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_pcs_summary_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_plan_cache_summary UNIQUE (snapshot_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_plan_cache_summary IS 'Accurate, full-plan-cache aggregate counts (single-use/ad-hoc bloat) -- unlike mssql_plan_cache_stats, not limited to the top 200 by usecounts.';

\echo 'mssql_plan_cache_summary created.'

-- ============================================================
-- Source: schema/mssql_blocking_snapshot_add_object_columns.sql
-- ============================================================
-- ============================================================
-- Migration: add table/index/statement-text columns to
-- mssql_blocking_snapshot
-- ============================================================
-- For Ganesh's existing table (created before this enhancement).
-- Run once. Existing rows will have NULL for all three new columns
-- -- only future collector runs will populate them, same reasoning
-- as the earlier RCSI-columns migration on the deadlock table.
-- ============================================================

ALTER TABLE mssql_blocking_snapshot ADD COLUMN IF NOT EXISTS blocked_object_name TEXT;
ALTER TABLE mssql_blocking_snapshot ADD COLUMN IF NOT EXISTS blocked_index_name TEXT;
ALTER TABLE mssql_blocking_snapshot ADD COLUMN IF NOT EXISTS blocked_statement_text TEXT;

\echo 'mssql_blocking_snapshot: blocked_object_name/blocked_index_name/blocked_statement_text columns added'

-- ============================================================
-- Source: schema/mssql_dmv_snapshot_time_utc_fix.sql
-- ============================================================
-- ============================================================
-- Fix mssql_dmv_snapshot.snapshot_time's default -- a real,
-- significant bug this exposed: plain now() returns the value in
-- whatever timezone the Postgres SESSION is configured with, not
-- necessarily UTC. Every Query Store timestamp this column gets
-- compared against (mssql_qs_interval.start_time/end_time, via
-- sqlwr_report_generator.py's snapshot-window overlap query) is
-- EXPLICITLY normalized to naive UTC first (connection.py's
-- to_naive_utc(), used specifically because DATETIMEOFFSET carries
-- an unambiguous UTC offset and every downstream comparison needs a
-- single, consistent time reference). If snapshot_time was actually
-- being stored in local server time (IST, UTC+5:30, in the specific
-- case this was found from) while being compared directly against
-- UTC interval timestamps as if they were the same reference, that
-- mismatch alone explains an apparent "5+ hour gap" in Query Store
-- activity that never actually existed -- Query Store itself was
-- working completely normally the whole time.
--
-- (now() AT TIME ZONE 'utc') converts the current instant to an
-- explicit UTC wall-clock value regardless of the session's own
-- timezone setting -- correct and safe no matter what Postgres
-- happens to be configured with, not dependent on guessing or
-- confirming the exact prior misconfiguration first.
-- ============================================================

ALTER TABLE mssql_dmv_snapshot ALTER COLUMN snapshot_time SET DEFAULT (now() AT TIME ZONE 'utc');

\echo 'mssql_dmv_snapshot.snapshot_time default fixed to explicit UTC.'
\echo 'Existing rows are UNCHANGED by this -- their snapshot_time values were captured under the'
\echo 'old, timezone-dependent default and are not retroactively corrected. Only snapshots taken'
\echo 'from this point forward will be correctly comparable against Query Store''s UTC timestamps.'

-- ============================================================
-- Source: schema/mssql_file_io_type_desc.sql
-- ============================================================
-- ============================================================
-- Add file_type_desc to mssql_file_io_delta -- unblocks two
-- previously-deferred requests (log-specific Load Profile metrics,
-- datafile-vs-logfile I/O stalls) that both needed the same missing
-- piece: reliable data-vs-log file classification. File naming
-- (e.g. "TESTDB_log") is not a safe signal on its own -- some DBAs
-- name files differently -- so this uses sys.master_files.type_desc
-- directly ('ROWS', 'LOG', 'FILESTREAM', 'FULLTEXT'), the same
-- column the file-I/O collector already joins against for
-- logical_file_name, now captured alongside it rather than a second
-- lookup.
-- ============================================================

ALTER TABLE mssql_file_io_delta ADD COLUMN IF NOT EXISTS file_type_desc TEXT;

\echo 'mssql_file_io_delta.file_type_desc added.'

-- ============================================================
-- Source: schema/mssql_index_usage_delta_extend.sql
-- ============================================================
-- ============================================================
-- Extend mssql_index_usage_delta with additional
-- sys.dm_db_index_operational_stats columns, plus current size --
-- prompted by reference queries Ganesh shared for a richer Segment
-- Statistics breakdown (separate "Segments by..." views matching
-- Oracle AWR's own multi-section structure: logical reads, physical
-- reads, writes, table scans, row lock waits, buffer busy waits).
--
-- range_scan_count/singleton_lookup_count: a more granular read
-- breakdown than user_seeks/scans/lookups alone (range vs point
-- lookups specifically, from the operational stats DMV rather than
-- the usage-stats DMV).
-- page_lock_wait_count/page_lock_wait_in_ms: row/page-level LOCK
-- waits -- distinct from page_latch_wait_* (in-memory latching, no
-- lock manager involved) already collected.
-- leaf_page_merge_count: page-merge operations from leaf-level
-- deletes, a B-tree maintenance signal.
-- row_count/size_mb: current size at the END snapshot -- unlike
-- every other column here, this is NOT delta'd (it's "how big is
-- this object right now", not an activity count), captured directly
-- from sys.dm_db_partition_stats rather than computed from two
-- snapshots' difference.
-- ============================================================

ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS range_scan_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS singleton_lookup_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS page_lock_wait_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS page_lock_wait_in_ms BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS leaf_page_merge_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS row_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS size_mb NUMERIC;

\echo 'mssql_index_usage_delta extended with additional operational-stats columns and current size.'

-- ============================================================
-- Source: schema/mssql_wait_event_master_data.sql
-- ============================================================
-- ============================================================
-- mssql_wait_event_master data population
-- Auto-generated from the wait-event CSV + Query Store category
-- list Ganesh provided -- see generate_mssql_wait_event_master.py
-- for the classification logic. Run AFTER
-- mssql_wait_event_master_table.sql.
-- 1360 rows: 50 benign, 89 rule-covered, 18 with researched guidance_text.
-- ============================================================

\echo 'Populating mssql_wait_event_master...'

INSERT INTO mssql_wait_event_master
    (tier, event_name, wait_class, is_benign, has_specific_rule, rule_ids, guidance_text, source)
VALUES
    ('wait_type', 'MISCELLANEOUS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LCK_M_SCH_S', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SCH_M', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_S', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_U', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_X', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_IS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_IU', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_IX', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SIU', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SIX', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_UIX', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_BU', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RS_S', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RS_U', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_NL', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_S', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_U', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_X', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RX_S', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RX_U', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RX_X', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LATCH_NL', 'Latch', false, false, NULL, NULL, NULL),
    ('wait_type', 'LATCH_KP', 'Latch', false, false, NULL, NULL, NULL),
    ('wait_type', 'LATCH_SH', 'Latch', false, false, NULL, NULL, NULL),
    ('wait_type', 'LATCH_UP', 'Latch', false, false, NULL, NULL, NULL),
    ('wait_type', 'LATCH_EX', 'Latch', false, true, 'MSSQL_WAIT_016', 'Exclusive latch on a non-page internal structure -- distinct from PAGELATCH/PAGEIOLATCH. Common cause: a data/log file autogrow event briefly serializing access.', 'MSSQL_WAIT_016 root_cause, this project'),
    ('wait_type', 'LATCH_DT', 'Latch', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_LATCH_ONLY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PAGELATCH_NL', 'Buffer Latch', false, true, 'MSSQL_WAIT_012', NULL, NULL),
    ('wait_type', 'PAGELATCH_KP', 'Buffer Latch', false, true, 'MSSQL_WAIT_012', NULL, NULL),
    ('wait_type', 'PAGELATCH_SH', 'Buffer Latch', false, true, 'MSSQL_WAIT_012', NULL, NULL),
    ('wait_type', 'PAGELATCH_UP', 'Buffer Latch', false, true, 'MSSQL_WAIT_012', NULL, NULL),
    ('wait_type', 'PAGELATCH_EX', 'Buffer Latch', false, true, 'MSSQL_WAIT_012', NULL, NULL),
    ('wait_type', 'PAGELATCH_DT', 'Buffer Latch', false, true, 'MSSQL_WAIT_012', NULL, NULL),
    ('wait_type', 'PAGEIOLATCH_NL', 'Buffer IO', false, true, 'MSSQL_WAIT_001', NULL, NULL),
    ('wait_type', 'PAGEIOLATCH_KP', 'Buffer IO', false, true, 'MSSQL_WAIT_001', NULL, NULL),
    ('wait_type', 'PAGEIOLATCH_SH', 'Buffer IO', false, true, 'MSSQL_WAIT_001', 'Waiting for a data page to be read from disk into the buffer pool (shared/read access). High values indicate buffer pool pressure, missing/stale statistics, or storage-layer latency.', 'MSSQL_WAIT_001 root_cause, this project'),
    ('wait_type', 'PAGEIOLATCH_UP', 'Buffer IO', false, true, 'MSSQL_WAIT_001', NULL, NULL),
    ('wait_type', 'PAGEIOLATCH_EX', 'Buffer IO', false, true, 'MSSQL_WAIT_001', 'Waiting for a data page to be read from disk into the buffer pool (exclusive/write access). Same root causes as PAGEIOLATCH_SH.', 'MSSQL_WAIT_001 root_cause, this project'),
    ('wait_type', 'PAGEIOLATCH_DT', 'Buffer IO', false, true, 'MSSQL_WAIT_001', NULL, NULL),
    ('wait_type', 'TRAN_MARKLATCH_NL', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'TRAN_MARKLATCH_KP', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'TRAN_MARKLATCH_SH', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'TRAN_MARKLATCH_UP', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'TRAN_MARKLATCH_EX', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'TRAN_MARKLATCH_DT', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_TASK', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'RESOURCE_QUEUE', 'Other', true, false, NULL, NULL, NULL),
    ('wait_type', 'THREADPOOL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_SCHEDULER_YIELD', 'CPU/Scheduler', false, true, 'MSSQL_WAIT_004', 'A task voluntarily yielded the CPU and had to wait for its turn again -- genuine CPU-pressure signal distinct from I/O or lock waits.', 'MSSQL_WAIT_004 root_cause, this project'),
    ('wait_type', 'SOS_VIRTUALMEMORY_LOW', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_MEMORY_TOPLEVELBLOCKALLOCATOR', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_PHYS_PAGE_CACHE', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'CMEMTHREAD', 'Memory', false, false, NULL, NULL, NULL),
    ('wait_type', 'CMEMPARTITIONED', 'Memory', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOSHOST_INTERNAL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOSHOST_SLEEP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOSHOST_WAITFORDONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOSHOST_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOSHOST_EVENT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOSHOST_SEMAPHORE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOSHOST_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOSHOST_TRACELOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SERVER_IDLE_CHECK', 'Other', true, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_PROCESS_AFFINITY_MUTEX', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_STACKSTORE_INIT_MUTEX', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_SYNC_TASK_ENQUEUE_EVENT', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_OBJECT_STORE_DESTROY_MUTEX', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'INTERNAL_TESTING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DUMPTRIGGER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TIMEPRIV_TIMEPERIOD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DISPATCHER_QUEUE_SEMAPHORE', 'Internal', true, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_DISPATCHER_MUTEX', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_DISPATCHER_JOIN', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'RG_RECONFIG', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RESMGR_THROTTLED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_MEMORY_USAGE_ADJUSTMENT', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SOSHOST', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SOSTESTING', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_STRESSDRIVER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_PAGEHEAP', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_SMALL_PAGE_ALLOC', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'DISPATCHER_PRIORITY_QUEUE_SEMAPHORE', 'Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'RESOURCE_GOVERNOR_IDLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOG_RATE_GOVERNOR', 'Transaction Log', false, false, NULL, NULL, NULL),
    ('wait_type', 'POOL_LOG_RATE_GOVERNOR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_MEMORYPOOL_ALLOCATEPAGES', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_WORKSPACE_ALLOCATEPAGE', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_RETRY_VIRTUALALLOC', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'MEMORY_ALLOCATION_EXT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_SLEEP_LOWMEM_GUARD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RESERVED_MEMORY_ALLOCATION_EXT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IO_QUEUE_LIMIT', 'Other Disk IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'SESSION_WAIT_STATS_CHILDREN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_DISPATCHER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_BUFFERMGR_ALLPROCESSED_EVENT', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_BUFFERMGR_FREEBUF_EVENT', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_CALLBACKEXECUTE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_SESSION_CREATE_SYNC', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_GETTARGETSTATE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_ENGINEINIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_CALLBACK_LIST', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_OLS_LOCK', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_PROXY_ADDSESSION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_PROXY_REMOVESESSION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_PROXY_PROCESSBUFFER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_MODULEMGR_SYNC', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_SERVICES_MUTEX', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_SERVICES_RWLOCK', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_SERVICES_EVENTMANUAL', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_SESSION_SYNC', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_SESSION_FLUSH', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_SESSIONCOMMIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_TARGETINIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_TARGETFINALIZE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_STM_CREATE', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_TIMER_MUTEX', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_TIMER_TASK_DONE', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_TIMERRUN', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_TIMER_EVENT', 'Extended Events', true, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_PREEMPTIVE_XE_STUB_LISTENER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_DISPATCHER_WAIT', 'Extended Events', true, false, NULL, NULL, NULL),
    ('wait_type', 'XE_DISPATCHER_CONFIG_SESSION_LIST', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_STUBMGR_CLOSE', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_WORK_DISPATCHER', 'CPU/Scheduler', true, false, NULL, 'Benign -- idle SQLOS worker threads waiting for work to dispatch. Commonly the #1 wait on SQL Server 2019+. Excluded from findings.', 'Paul Randal, sqlskills.com, verified this project'),
    ('wait_type', 'SOS_WORKER_MIGRATION', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_FILE_MAPPING', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'DISPATCHER_JOIN', 'Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'WMI_REGISTRATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CMEMDETOUR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_RG_MEM_TARGET_LOCK', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLPAL_PREEMPTIVE_WAIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SPINLOCK_EXT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LAZYWRITER_SLEEP', 'Other', true, false, NULL, NULL, NULL),
    ('wait_type', 'IO_COMPLETION', 'Other Disk IO', false, true, 'MSSQL_WAIT_014', 'Non-buffer-pool I/O completion -- most commonly backup/restore or DBCC CHECKDB I/O. Expected during known maintenance windows; a real signal outside them.', 'MSSQL_WAIT_014 root_cause, this project'),
    ('wait_type', 'ASYNC_IO_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ASYNC_NETWORK_IO', 'Network IO', false, true, 'MSSQL_WAIT_011', 'SQL Server has results ready but is waiting for the client to consume them -- very often a slow-consuming client application (row-by-row fetch), not genuine network latency.', 'MSSQL_WAIT_011 root_cause, this project'),
    ('wait_type', 'PREFAULT_IO_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_BPOOL_FLUSH', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_BPOOL_STEAL', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'CHKPT', 'Checkpoint', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_DBSTARTUP', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_MASTERMDREADY', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_MASTERUPGRADED', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_MASTERDBREADY', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_TEMPDBSTARTUP', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_SAFEMODE', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOCK_SAFEMODE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOCK_UPDATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_DCOMSTARTUP', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_SYSTEMTASK', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'RESOURCE_SEMAPHORE', 'Memory', false, true, 'MSSQL_WAIT_013', 'A query''s memory grant request (for sorts/hash joins) couldn''t be satisfied because other concurrent queries hold the memory. Can escalate to error 8645 if sustained.', 'MSSQL_WAIT_013 root_cause, this project; Microsoft Books Online'),
    ('wait_type', 'DTC', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'OLEDB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PLPGSQL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FAILPOINT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ASYNC_DISKPOOL_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DEBUG', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REPLICA_WRITES', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_RECEIVE_WAITFOR', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'DBMIRRORING_CMD', 'Mirroring', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_FOR_RESULTS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOS_CALLBACK_REMOVAL', 'CPU/Scheduler', false, false, NULL, NULL, NULL),
    ('wait_type', 'ONDEMAND_TASK_QUEUE', 'Other', true, false, NULL, NULL, NULL),
    ('wait_type', 'LOGMGR_QUEUE', 'Transaction Log', true, false, NULL, NULL, NULL),
    ('wait_type', 'REQUEST_FOR_DEADLOCK_SEARCH', 'Other', true, false, NULL, NULL, NULL),
    ('wait_type', 'CHECKPOINT_QUEUE', 'Checkpoint', true, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_BACKUP_QUEUE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FABRIC_ENDPOINT_SYNC_EVENT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SEEDING_COMPLETED_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DUMP_LOG_COORDINATOR_QUEUE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOWFAIL_MEMMGR_QUEUE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BACKUP', 'Backup/Restore', false, false, NULL, NULL, NULL),
    ('wait_type', 'BACKUPBUFFER', 'Backup/Restore', false, false, NULL, NULL, NULL),
    ('wait_type', 'BACKUPIO', 'Backup/Restore', false, false, NULL, NULL, NULL),
    ('wait_type', 'BACKUPTHREAD', 'Backup/Restore', false, false, NULL, NULL, NULL),
    ('wait_type', 'DBMIRROR_DBM_MUTEX', 'Mirroring', false, false, NULL, NULL, NULL),
    ('wait_type', 'DBMIRROR_DBM_EVENT', 'Mirroring', true, false, NULL, NULL, NULL),
    ('wait_type', 'DBMIRROR_SEND', 'Mirroring', false, false, NULL, NULL, NULL),
    ('wait_type', 'DBMIRROR_EVENTS_QUEUE', 'Mirroring', true, false, NULL, NULL, NULL),
    ('wait_type', 'DBMIRROR_WORKER_QUEUE', 'Mirroring', true, false, NULL, NULL, NULL),
    ('wait_type', 'HTTP_START', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'HTTP_ENUMERATION', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOAP_READ', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOAP_WRITE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DUMP_LOG_COORDINATOR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DISKIO_SUSPEND', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IMPPROV_IOWAIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DEADLOCK_TASK_SEARCH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REPL_SCHEMA_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'REPL_MEM_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'REPL_TIMER_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'REPL_CACHE_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'KSOURCE_WAKEUP', 'Other', true, false, NULL, NULL, NULL),
    ('wait_type', 'SQLSORT_SORTMUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLSORT_NORMMUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLTRACE_WAIT_ENTRIES', 'Other', true, false, NULL, NULL, NULL),
    ('wait_type', 'SQLTRACE_FILE_BUFFER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', 'Other', true, false, NULL, NULL, NULL)
ON CONFLICT (tier, event_name) DO UPDATE SET
    wait_class = EXCLUDED.wait_class, is_benign = EXCLUDED.is_benign,
    has_specific_rule = EXCLUDED.has_specific_rule, rule_ids = EXCLUDED.rule_ids,
    guidance_text = EXCLUDED.guidance_text, source = EXCLUDED.source;

INSERT INTO mssql_wait_event_master
    (tier, event_name, wait_class, is_benign, has_specific_rule, rule_ids, guidance_text, source)
VALUES
    ('wait_type', 'SQLTRACE_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QUERY_TRACEOUT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTC_STATE', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTC_INFO_DMV', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_TRANSMITTER', 'Service Broker', true, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_SERVICE', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_SHUTDOWN', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_MASTERSTART', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_REGISTERALLENDPOINTS', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_EVENTHANDLER', 'Service Broker', true, false, NULL, NULL, NULL),
    ('wait_type', 'FCB_REPLICA_WRITE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FCB_REPLICA_READ', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WRITELOG', 'Transaction Log', false, true, 'MSSQL_WAIT_008', 'Waiting for the transaction log buffer to be flushed to disk on COMMIT/CHECKPOINT/log-block-full. Low avg_wait_ms with high volume points at commit frequency (many small transactions); high avg_wait_ms points at genuine log I/O latency.', 'MSSQL_WAIT_008 root_cause, this project; Redgate Monitor alert thresholds'),
    ('wait_type', 'EXCHANGE', 'Parallelism', false, false, NULL, NULL, NULL),
    ('wait_type', 'EC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TEMPOBJ', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XACTLOCKINFO', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGMGR', 'Transaction Log', false, false, NULL, NULL, NULL),
    ('wait_type', 'CXPACKET', 'Parallelism', false, true, 'MSSQL_WAIT_003', 'Parallel query threads waiting for each other to synchronize -- the actionable side of parallelism. High volume often means Cost Threshold for Parallelism is too low or MAXDOP is mismatched to the workload.', 'MSSQL_WAIT_003 root_cause, this project'),
    ('wait_type', 'CXSYNC_CONSUMER', 'Parallelism', false, false, NULL, NULL, NULL),
    ('wait_type', 'CXSYNC_PORT', 'Parallelism', false, true, 'MSSQL_WAIT_007', 'New in SQL Server 2022 -- exchange port synchronization overhead between parallel producer/consumer threads. Genuinely actionable, most often accompanies a blocking operator (sort/hash/spool) feeding an exchange.', 'MSSQL_WAIT_007 root_cause, this project'),
    ('wait_type', 'CXCONSUMER', 'Parallelism', true, false, NULL, 'The benign, expected side of parallelism (a consumer thread waiting for a producer to provide rows) -- deliberately split from CXPACKET so it wouldn''t be mistaken for a problem. Excluded from findings.', 'Paul Randal / multiple DBA sources, verified this project'),
    ('wait_type', 'HTREPARTITION', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'HTBUILD', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'HTMEMO', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'HTDELETE', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'HTREINIT', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'BMPREPARTITION', 'Bitmap', false, false, NULL, NULL, NULL),
    ('wait_type', 'BMPALLOCATION', 'Bitmap', false, false, NULL, NULL, NULL),
    ('wait_type', 'BMPREPLICATION', 'Bitmap', false, false, NULL, NULL, NULL),
    ('wait_type', 'BMPBUILD', 'Bitmap', false, false, NULL, NULL, NULL),
    ('wait_type', 'SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAITFOR', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'EXECSYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTCPNTSYNC', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'MSQL_XP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'MSQL_DQ', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGBUFFER', 'Transaction Log', false, false, NULL, NULL, NULL),
    ('wait_type', 'TRANSACTION_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_MSDBSTARTUP', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'MSSEARCH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XACTWORKSPACE_MUTEX', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'TRACEWRITE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAITSTAT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAITFOR_TASKSHUTDOWN', 'Idle/Sleep', true, false, NULL, NULL, NULL),
    ('wait_type', 'GUARDIAN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_TASK_START', 'CLR', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_JOIN', 'CLR', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_CRST', 'CLR', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_SEMAPHORE', 'CLR', true, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_MANUAL_EVENT', 'CLR', true, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_AUTO_EVENT', 'CLR', true, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_MONITOR', 'CLR', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_RWLOCK_READER', 'CLR', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_RWLOCK_WRITER', 'CLR', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLCLR_QUANTUM_PUNISHMENT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLCLR_APPDOMAIN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLCLR_ASSEMBLY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'KTM_ENLISTMENT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'KTM_RECOVERY_RESOLUTION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'KTM_RECOVERY_MANAGER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLCLR_DEADLOCK_DETECTION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QPJOB_WAITFOR_ABORT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QPJOB_KILL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BAD_PAGE_PROCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BACKUP_OPERATOR', 'Backup/Restore', false, false, NULL, NULL, NULL),
    ('wait_type', 'PRINT_ROLLBACK_PROGRESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ENABLE_VERSIONING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DISABLE_VERSIONING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REQUEST_DISPENSER_PAUSE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DROPTEMP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_RESTART_CRAWL', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGMGR_RESERVE_APPEND', 'Transaction Log', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGMGR_FLUSH', 'Transaction Log', false, false, NULL, NULL, NULL),
    ('wait_type', 'XACT_OWN_TRANSACTION', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'XACT_RECLAIM_SESSION', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTC_WAITFOR_OUTCOME', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTC_RESOLVE', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'CL_RESOLVE_WAIT_FOR_UPGRADE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SEC_DROP_TEMP_KEY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SRVPROC_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_INIT', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_CONNECTION_RECEIVE_TASK', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'NET_WAITFOR_PACKET', 'Network IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTC_ABORT_REQUEST', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTC_TMDOWN_REQUEST', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'RECOVER_CHANGEDB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WORKTBL_DROP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SNI_WRITE_ASYNC', 'Network IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'SNI_HTTP_WAITFOR_0_DISCON', 'Network IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'UTIL_PAGE_ALLOC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DEADLOCK_ENUM_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'VIEW_DEFINITION_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QUERY_NOTIFICATION_MGR_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QUERY_NOTIFICATION_TABLE_MGR_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QUERY_NOTIFICATION_SUBSCRIPTION_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QUERY_NOTIFICATION_UNITTEST_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RESOURCE_SEMAPHORE_MUTEX', 'Memory', false, false, NULL, NULL, NULL),
    ('wait_type', 'IO_AUDIT_MUTEX', 'Other Disk IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'BUILTIN_HASHKEY_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'MSQL_XACT_MGR_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'MSQL_XACT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QRY_MEM_GRANT_INFO_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SNI_CRITICAL_SECTION', 'Network IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'EE_PMOLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QUERY_OPTIMIZER_PRINT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DLL_LOADING_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RESOURCE_SEMAPHORE_QUERY_COMPILE', 'Memory', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_ENDPOINT_STATE_MUTEX', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'QUERY_EXECUTION_INDEX_SORT_EVENT_OPEN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ERROR_REPORTING_MANAGER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EE_SPECPROC_MAP_INIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FULLTEXT GATHERER', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'SEQUENTIAL_GUID', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_TASK_STOP', 'Service Broker', true, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_PRIORITIZED_TASK_STOP', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_TASK_SHUTDOWN', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_TASK_SUBMIT', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'SNI_TASK_COMPLETION', 'Network IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'SNI_LISTENER_ACCESS', 'Network IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXECUTION_PIPE_EVENT_INTERNAL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLR_MEMORY_SPY', 'CLR', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLRHOST_STATE_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DAC_INIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ASSEMBLY_LOAD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'VIA_ACCEPT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CHECK_PRINT_RECORD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SCAN_CHAR_HASH_ARRAY_INITIALIZATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FS_GARBAGE_COLLECTOR_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FSAGENT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FILESTREAM_WORKITEM_QUEUE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FILESTREAM_FILE_OBJECT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FILESTREAM_FCB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FILESTREAM_CACHE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ABR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WCC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_TO_FLUSH', 'Service Broker', true, false, NULL, NULL, NULL),
    ('wait_type', 'NODE_CACHE_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SECURITY_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FS_HEADER_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FS_LOGTRUNC_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FS_FC_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FSTR_CONFIG_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FSTR_CONFIG_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FSA_FORCE_OWN_XACT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'COMMIT_TABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CXROWSET_SYNC', 'Parallelism', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GENERICOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_AUTHENTICATIONOPS', 'Preemptive', false, true, 'MSSQL_WAIT_017', 'Waiting on a Windows authentication API call. Small values routine; genuinely high/sustained values can indicate a real Active Directory/Domain Controller problem.', 'MSSQL_WAIT_017 root_cause, this project'),
    ('wait_type', 'PREEMPTIVE_OS_ACCEPTSECURITYCONTEXT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_ACQUIRECREDENTIALSHANDLE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_COMPLETEAUTHTOKEN', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DECRYPTMESSAGE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DELETESECURITYCONTEXT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_ENCRYPTMESSAGE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_FREECREDENTIALSHANDLE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_INITIALIZESECURITYCONTEXT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_LOGONUSER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_QUERYSECURITYCONTEXTTOKEN', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_QUERYCONTEXTATTRIBUTES', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_VERIFYSIGNATURE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_AUTHORIZATIONOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_AUTHZGETINFORMATIONFROMCONTEXT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_AUTHZINITIALIZECONTEXTFROMSID', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_AUTHZINITIALIZERESOURCEMANAGER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_LOOKUPACCOUNTSID', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_REVERTTOSELF', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_SETNAMEDSECURITYINFO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_CLUSTEROPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_CLUSAPI_CLUSTERRESOURCECONTROL', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_COMOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_COCREATEINSTANCE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_COGETCLASSOBJECT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_CREATEACCESSOR', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_DELETEROWS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_GETCOMMANDTEXT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_GETDATA', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_GETNEXTROWS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_GETRESULT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_GETROWSBYBOOKMARK', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_LBFLUSH', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_LBLOCKREGION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_LBREADAT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_LBSETSIZE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_LBSTAT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_LBUNLOCKREGION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_LBWRITEAT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_QUERYINTERFACE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_RELEASE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_RELEASEACCESSOR', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_RELEASEROWS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_RELEASESESSION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_RESTARTPOSITION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_SEQSTRMREAD', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_SEQSTRMREADANDWRITE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_SETDATAFAILURE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_SETPARAMETERINFO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_SETPARAMETERPROPERTIES', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_STRMLOCKREGION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_STRMSEEKANDREAD', 'Preemptive', false, false, NULL, NULL, NULL)
ON CONFLICT (tier, event_name) DO UPDATE SET
    wait_class = EXCLUDED.wait_class, is_benign = EXCLUDED.is_benign,
    has_specific_rule = EXCLUDED.has_specific_rule, rule_ids = EXCLUDED.rule_ids,
    guidance_text = EXCLUDED.guidance_text, source = EXCLUDED.source;

INSERT INTO mssql_wait_event_master
    (tier, event_name, wait_class, is_benign, has_specific_rule, rule_ids, guidance_text, source)
VALUES
    ('wait_type', 'PREEMPTIVE_COM_STRMSEEKANDWRITE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_STRMSETSIZE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_STRMSTAT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COM_STRMUNLOCKREGION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_CRYPTOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_CRYPTACQUIRECONTEXT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_CRYPTIMPORTKEY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DEVICEOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_RSFXDEVICEOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DIRSVC_NETWORKOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DSGETDCNAME', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_NETGROUPGETUSERS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_NETLOCALGROUPGETMEMBERS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_NETUSERGETGROUPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_NETUSERGETLOCALGROUPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_NETUSERMODALSGET', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_NETVALIDATEPASSWORDPOLICY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_NETVALIDATEPASSWORDPOLICYFREE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DOMAINSERVICESOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DTCOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DTC_ABORT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DTC_ABORTREQUESTDONE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DTC_BEGINTRANSACTION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DTC_COMMITREQUESTDONE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DTC_ENLIST', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DTC_PREPAREREQUESTDONE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_FILEOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_CLOSEHANDLE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_COPYFILE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_CREATEDIRECTORY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_CREATEFILE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DELETEFILE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DEVICEIOCONTROL', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_FINDFILE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_FILESIZEGET', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_FLUSHFILEBUFFERS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETCOMPRESSEDFILESIZE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETDISKFREESPACE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETFILEATTRIBUTES', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETFILESIZE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETLONGPATHNAME', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETVOLUMEPATHNAME', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETVOLUMENAMEFORVOLUMEMOUNTPOINT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_MOVEFILE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_OPENDIRECTORY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_REMOVEDIRECTORY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_SETENDOFFILE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_SETFILEPOINTER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_SETFILEVALIDDATA', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_WRITEFILE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_WRITEFILEGATHER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_LIBRARYOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_FREELIBRARY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETPROCADDRESS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_LOADLIBRARY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_MESSAGEQUEUEOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_ODBCOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_HTTP_REQUEST', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_HTTP_EVENT_WAIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDBOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_ABORTTRAN', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_ABORTORCOMMITTRAN', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_GETDATASOURCE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_GETLITERALINFO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_GETPROPERTIES', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_GETPROPERTYINFO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_GETSCHEMALOCK', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_JOINTRANSACTION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_RELEASE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLEDB_SETPROPERTIES', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_PIPEOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_DISCONNECTNAMEDPIPE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_PROCESSOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_SECURITYOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_SERVICEOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_SQLCLROPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_WINSOCKOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETADDRINFO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_WSASETLASTERROR', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_FORMATMESSAGE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_REPORTEVENT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_BACKUPREAD', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_WAITFORSINGLEOBJECT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_QUERYREGISTRY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_CLOSEBACKUPMEDIA', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_CLOSEBACKUPTAPE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_CLOSEBACKUPVDIDEVICE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_VSSOPS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_VSS_CREATESNAPSHOT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_VSS_CREATEVOLUMESNAPSHOT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DFSADDLINK', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DFSLINKEXISTCHECK', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DFSLINKHEALTHCHECK', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DFSREMOVELINK', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DFSREMOVEROOT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DFSROOTFOLDERCHECK', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DFSROOTINIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DFSROOTSHARECHECK', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OLE_UNINIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_FSAOLEDB_ABORTTRANSACTION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_FSAOLEDB_COMMITTRANSACTION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_FSAOLEDB_STARTTRANSACTION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_FSRECOVER_UNCONDITIONALUNDO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SERVER_STARTUP', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_GETDATA', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_CONSOLEWRITE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_TESTING', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XETESTING', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SB_STOPENDPOINT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_STARTRM', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_GETRMINFO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SETRMINFO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_ROLLFORWARDREDO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_ROLLFORWARDUNDO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_RESIZELOG', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_REENLIST', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_TRANSIMPORT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_UNMARSHALPROPAGATIONTOKEN', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_CREATEPARAM', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_STREAMFCB_RECOVER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_STREAMFCB_CHECKPOINT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SNIOPEN', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_DEBUG', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_MSS_RELEASE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_LOCKMONITOR', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLEAR_DB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_ABR', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGGENERATION', 'Transaction Log', false, false, NULL, NULL, NULL),
    ('wait_type', 'IO_RETRY', 'Other Disk IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'WRITE_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'AUDIT_XE_SESSION_MGR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_AUDIT_CLOSE_EXPIRED_LOGS_MGR_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'AUDIT_ON_DEMAND_TARGET_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_AUDIT_SESSIONS_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_AUDIT_SESSIONS_WAIT_TO_EXEC_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_AUDIT_SESSIONS_WAIT_TO_REFRESH_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_AUTO_START_AUDIT_SESSIONS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_PREEMPTIVE_AUDIT_ACCESS_WINDOWSLOG', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'AUDIT_LOGINCACHE_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'AUDIT_GROUPCACHE_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_METADATA_MUTEX', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_IFTSHC_MUTEX', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_IFTSISM_MUTEX', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_IFTS_RWLOCK', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_COMPROWSET_RWLOCK', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_MASTER_MERGE', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'TRACE_EVTNOTIF', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'MD_LAZYCACHE_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'MD_AGENT_YIELD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IOAFF_RANGE_QUEUE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_IFTS_SCHEDULER_IDLE_WAIT', 'Full Text Search', true, false, NULL, NULL, NULL),
    ('wait_type', 'REPL_HISTORYCACHE_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'REPL_TRANHASHTABLE_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'REPL_TRANTEXTINFO_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'REPL_TRANFSINFO_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'SERVER_RECONFIGURE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CHANGE_TRACKING_WAITFORCHANGES', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_MD_RELATION_CACHE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_MD_SERVER_CACHE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_MD_LOGIN_STATS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_PROPERTYLIST_CACHE', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'PERFORMANCE_COUNTERS_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XIO_CREDENTIAL_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XIO_CREDENTIAL_MGR_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XIO_EDS_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XIO_EDS_MGR_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XIO_LEASE_RENEW_MGR_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_XIO_REQUEST_IN_PROGRESS_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XIO_IOSTATS_BLOBLIST_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XIO_IOSTATS_FCBLIST_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SECURITY_KEYRING_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLTRACE_FILE_WRITE_IO_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLTRACE_FILE_READ_IO_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SQLTRACE_PENDING_BUFFER_WRITERS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_PDH_WMI_INIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_TRANSMISSION_WORK', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_TRANSMISSION_OBJECT', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_TRANSMISSION_TABLE', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_DISPATCHER', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_FORWARDER', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'UCS_MANAGER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'UCS_TRANSPORT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'UCS_MEMORY_NOTIFICATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'UCS_ENDPOINT_CHANGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'UCS_TRANSPORT_STREAM_CHANGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QUERY_TASK_ENQUEUE_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SP_PREEMPTIVE_SERVER_DIAGNOSTICS_SLEEP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SP_SERVER_DIAGNOSTICS_INIT_MUTEX', 'Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'DBCC_SCALE_OUT_EXPR_CACHE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'GDMA_GET_RESOURCE_OWNER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_ALL_COMPONENTS_INITIALIZED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_LIVE_TARGET_TVF', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SP_SERVER_DIAGNOSTICS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'SP_SERVER_DIAGNOSTICS_SLEEP', 'Internal', true, false, NULL, NULL, NULL),
    ('wait_type', 'AM_INDBUILD_ALLOCATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'STARTUP_DEPENDENCY_MANAGER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XDES_HISTORY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XDES_SNAPSHOT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FT_MASTER_MERGE_COORDINATOR', 'Full Text Search', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_RESOURCE_SEMAPHORE_FT_PARALLEL_QUERY_SYNC', 'Other', false, false, NULL, NULL, NULL)
ON CONFLICT (tier, event_name) DO UPDATE SET
    wait_class = EXCLUDED.wait_class, is_benign = EXCLUDED.is_benign,
    has_specific_rule = EXCLUDED.has_specific_rule, rule_ids = EXCLUDED.rule_ids,
    guidance_text = EXCLUDED.guidance_text, source = EXCLUDED.source;

INSERT INTO mssql_wait_event_master
    (tier, event_name, wait_class, is_benign, has_specific_rule, rule_ids, guidance_text, source)
VALUES
    ('wait_type', 'REDO_THREAD_PENDING_WORK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REDO_THREAD_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'COUNTRECOVERYMGR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DB_COMMAND', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_TRANSPORT_SESSION', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_CLUSAPI_CALL', 'Replication/HA', true, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_CHANGE_NOTIFIER_TERMINATION_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_ACTION_COMPLETED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_OFFLINE_COMPLETED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_ONLINE_COMPLETED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_FAILOVER_COMPLETED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_WORKITEM_COMPLETED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_WORK_POOL', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_WORK_QUEUE', 'Replication/HA', true, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_LOGCAPTURE_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_CLUSTER_INTEGRATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGCAPTURE_LOGPOOLTRUNCPOINT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGPOOL_CACHESIZE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGPOOL_FREEPOOLS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGPOOL_REPLACEMENTSET', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGPOOL_CONSUMERSET', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGPOOL_MGRSET', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGPOOL_CONSUMER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGPOOL_CONSUMER_DELETABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGPOOLREFCOUNTEDOBJECT_REFDONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_SYNC_COMMIT', 'Replication/HA', false, true, 'MSSQL_WAIT_015', 'Always On Availability Groups synchronous commit -- primary waiting for log hardening confirmation from ALL synchronous secondaries. Points at secondary/network latency, not local storage.', 'MSSQL_WAIT_015 root_cause, this project'),
    ('wait_type', 'HADR_AG_MUTEX', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_SERVER_READY_CONNECTIONS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_FILESTREAM_MANAGER', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_FILESTREAM_BLOCK_FLUSH', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_FILESTREAM_IOMGR', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_FILESTREAM_IOMGR_IOCOMPLETION', 'Replication/HA', true, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_FILESTREAM_PREPROC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'UCS_SESSION_REGISTRATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ENABLE_EMPTY_VERSIONING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DB_OP_START_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DB_OP_COMPLETION_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_LOGPROGRESS_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_TRANSPORT_DBRLIST', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_CONNECTIVITY_INFO', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'XDESTSVERMGR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'GHOSTCLEANUPSYNCMGR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_AR_UNLOAD_COMPLETED', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_PARTNER_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DBSTATECHANGE_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'DIRTY_PAGE_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DIRTY_PAGE_POLL', 'Other', true, false, NULL, NULL, NULL),
    ('wait_type', 'HTTP_STORAGE_CONNECTION', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'SECURITY_CRYPTO_CONTEXT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SECURITY_RULETABLE_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SEMPLAT_DSI_BUILD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FILESTREAM_CHUNKER_INIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FILESTREAM_CHUNKER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_RSFX_COMM', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_RSFX_WAIT_FOR_MEMORY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_STARTUP_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_RECOVERY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NSO_FCB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NSO_FCB_PARENT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NSO_FCB_FIND', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NSO_FCB_RELEASE_CACHED_ENTRIES', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NSO_FILEOBJECT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NSO_DB_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NSO_DB_KILL_FLAG', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NSO_TABLE_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_STORE_DB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_STORE_TABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_STORE_ROWSET_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NTFS_STORE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_FILESTREAM_FILE_REQUEST', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_MD_UPGRADE_CONFIG', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_COOP_SCAN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QRY_PARALLEL_THREAD_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_QRY_BPMEMORY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAITFOR_PER_QUEUE', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'CREATE_DATINISERVICE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'AM_SCHEMAMGR_UNSHARED_CACHE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_REPLICAINFO_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_COMPRESSED_CACHE_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_AR_MANAGER_MUTEX', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_NOTIFICATION_WORKER_TERMINATION_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_NOTIFICATION_DEQUEUE', 'Replication/HA', true, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_ARCONTROLLER_NOTIFICATIONS_SUBSCRIBER_LIST', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DBR_SUBSCRIBER_FILTER_LIST', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DBR_SUBSCRIBER', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_NOTIFICATION_WORKER_STARTUP_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_NOTIFICATION_WORKER_EXCLUSIVE_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_RECOVERY_WAIT_FOR_UNDO', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DATABASE_WAIT_FOR_RESTART', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DATABASE_WAIT_FOR_RECOVERY', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_XRF_STACK_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_RECOVERY_WAIT_FOR_CONNECTION', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_TRANSPORT_FLOW_CONTROL', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DATABASE_FLOW_CONTROL', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_POST_ONLINE_COMPLETED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DATABASE_WAIT_FOR_TRANSITION_TO_VERSIONING', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'XDES_OUT_OF_ORDER_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_BACKUP_BULK_LOCK', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_BACKUP_QUEUE', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_LOGCAPTURE_WAIT', 'Replication/HA', true, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_AR_CRITICAL_SECTION_ENTRY', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_TDS_LISTENER_SYNC', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_READ_ALL_NETWORKS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_TDS_LISTENER_SYNC_PROCESSING', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_XTP_FSSTORAGE_MAINTENANCE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_GUEST', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_TASK_SHUTDOWN', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'XTPPROC_PARTITIONED_STACK_CREATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_HADR_LEASE_MECHANISM', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_TIMER_TASK', 'Replication/HA', true, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_EVENT_SESSION_INIT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_REPLICA_ONLINE_INIT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_GROUP_COMMIT', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_SYNCHRONIZING_THROTTLE', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DATABASE_VERSIONING_STATE', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'XTPPROC_CACHE_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SP_SERVER_DIAGNOSTICS_BUFFER_ACCESS', 'Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_FILESTREAM_FILE_CLOSE', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'VERSIONING_COMMITTING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FILETABLE_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PRU_ROLLBACK_DEFERRED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_TRAN_DEPENDENCY', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_HOST_WAIT', 'In-Memory OLTP', true, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_XTP_HOST_STORAGE_WAIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_FABRIC_CALLBACK', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'WINFAB_REPORT_FAULT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ASYNC_OP_CONTEXT_READ', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ASYNC_OP_CONTEXT_WRITE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ASYNC_OP_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FABRIC_REPLICA_PUBLISHER_SUBSCRIBER_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FABRIC_REPLICA_CONTROLLER_STATE_AND_CONFIG', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FABRIC_REPLICA_CONTROLLER_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FABRIC_HADR_TRANSPORT_CONNECTION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FABRIC_WAIT_FOR_BUILD_REPLICA_EVENT_PROCESSING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_FABRIC_REPLICA_CONTROLLER_DATA_LOSS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'VDI_CLIENT_GETCOMMAND', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'VDI_CLIENT_COMPLETECOMMAND', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'VDI_CLIENT_OTHER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'VDI_CLIENT_OPERATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DBSEEDING', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DBSEEDING_LIST', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLO_UPDATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_RECOVERY', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', 'In-Memory OLTP', true, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_OFFLINE_CKPT_LOG_IO', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_OFFLINE_CKPT_BEFORE_REDO', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_PROCEDURE_ENTRY', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_CKPT_ENABLED', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_CKPT_AGENT_WAKEUP', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_CKPT_CLOSE', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_CKPT_STATE_LOCK', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_ASYNC_TX_COMPLETION', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'LCK_M_SCH_S_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SCH_M_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_S_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_U_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_X_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_IS_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_IU_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_IX_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SIU_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SIX_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_UIX_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_BU_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RS_S_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RS_U_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_NL_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_S_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_U_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_X_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RX_S_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RX_U_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RX_X_LOW_PRIORITY', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SCH_S_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SCH_M_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_S_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_U_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_X_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_IS_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_IU_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_IX_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SIU_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_SIX_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_UIX_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_BU_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RS_S_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RS_U_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_NL_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_S_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_U_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RIn_X_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RX_S_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RX_U_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'LCK_M_RX_X_ABORT_BLOCKERS', 'Lock', false, true, 'MSSQL_WAIT_002', NULL, NULL),
    ('wait_type', 'TERMINATE_LISTENER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_SCRIPTDEPLOYMENT_REQUEST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_SCRIPTDEPLOYMENT_WORKER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FEATURE_SWITCHES_UPDATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XTP_HOST_DB_COLLECTION', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'XTP_HOST_LOG_ACTIVITY', 'In-Memory OLTP', false, false, NULL, NULL, NULL)
ON CONFLICT (tier, event_name) DO UPDATE SET
    wait_class = EXCLUDED.wait_class, is_benign = EXCLUDED.is_benign,
    has_specific_rule = EXCLUDED.has_specific_rule, rule_ids = EXCLUDED.rule_ids,
    guidance_text = EXCLUDED.guidance_text, source = EXCLUDED.source;

INSERT INTO mssql_wait_event_master
    (tier, event_name, wait_class, is_benign, has_specific_rule, rule_ids, guidance_text, source)
VALUES
    ('wait_type', 'QDS_DYN_VECTOR', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_STMT', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_CTXS', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_BCKG_TASK', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_DB_DISK', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_STMT_DISK', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_ASYNC_PERSIST_TASK', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_LOADDB', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_ASYNC_PERSIST_TASK_START', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_ASYNC_CHECK_CONSISTENCY_TASK', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_TASK_START', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', 'Query Store Internal', true, false, NULL, 'Benign -- Query Store''s own persistence task sleeping between its ~60-second checks, not query workload. Excluded from findings.', 'Paul Randal, sqlskills.com, verified this project'),
    ('wait_type', 'QDS_TASK_SHUTDOWN', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_SHUTDOWN_QUEUE', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_EXCLUSIVE_ACCESS', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_CX_FILE_OPEN', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_CX_FILE_READ', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'WINFAB_API_CALL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_CX_HTTP_CALL', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_LOG_CONSOLIDATION_POLL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_LOG_CONSOLIDATION_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'COLUMNSTORE_BUILD_THROTTLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'COLUMNSTORE_ATTRIBUTE_CONTAINER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DBSEEDING_OPERATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DBSEEDING_FLOWCONTROL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PHYSICAL_SEEDING_DMV', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DROP_DATABASE_TIMER_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SNI_CONN_DUP', 'Network IO', false, false, NULL, NULL, NULL),
    ('wait_type', 'SEQUENCE_GENERATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RTDATA_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADR_JOIN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WINFAB_REPLICA_BUILD_OPERATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FABRIC_REPLICA_PUBLISHER_EVENT_PUBLISH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', 'Query Store Internal', true, false, NULL, 'Benign -- Query Store''s cleanup task''s own sleep loop, same nature as QDS_PERSIST_TASK_MAIN_LOOP_SLEEP.', 'Paul Randal, sqlskills.com, verified this project'),
    ('wait_type', 'TDS_PROXY_CONTAINER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_THROTTLE_LOG_RATE_GOVERNOR', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'XDB_CONN_DUP_HASH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_HADRSIM', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_VERIFYTRUST', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'BROKER_START', 'Service Broker', false, false, NULL, NULL, NULL),
    ('wait_type', 'XTP_TRUNCATION_LSN', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'ROWGROUP_OP_STATS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BPSORT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ROWGROUP_VERSION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XTP_PREEMPTIVE_TASK', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'INSTANCE_LOG_RATE_GOVERNOR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'NETWORKSXMLMGRLOAD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BLOB_METADATA', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FORWARDER_TRANSITION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FILE_OWNERSHIP_TABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'GLOBAL_TRAN_CREATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CONNECTION_ENDPOINT_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TDS_BANDWIDTH_STATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTCNEW_RECOVERY', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTCNEW_TRANSACTION_ENLISTMENT', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTCNEW_ENLIST', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTCNEW_PREPARE', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTCNEW_TM', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTC_PRECOMMIT', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'HCCO_CACHE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TDS_INIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WINDOW_AGGREGATES_MULTIPASS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REMOTE_DATA_ARCHIVE_MIGRATION_DMV', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REMOTE_DATA_ARCHIVE_SCHEMA_DMV', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REMOTE_DATA_ARCHIVE_SCHEMA_TASK_QUEUE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'GLOBAL_TRAN_UCS_SESSION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_FILE_TARGET_TVF', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'GLOBAL_QUERY_PRODUCER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'GLOBAL_QUERY_CONSUMER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'GLOBAL_QUERY_CANCEL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'GLOBAL_QUERY_CLOSE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'GLOBAL_QUERY_EXTRACTOR_EXECUTE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_BUFFERPOOL_HELPLW', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_ASYNC_QUEUE', 'Query Store Internal', true, false, NULL, 'Benign -- Query Store''s async persist-queue task sleeping between scheduled writes. Flushes to sys.dm_os_wait_stats in bursts, not continuously, so large values are expected, not alarming.', 'Paul Randal (forum reply: ''entirely expected''), verified this project'),
    ('wait_type', 'CHECK_SCANNER_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DIRECTLOGCONSUMER_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_DIRECTLOGCONSUMER_GETNEXT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CHECK_TABLES_INITIALIZATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CHECK_TABLES_SINGLE_SCAN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CHECK_TABLES_THREAD_BARRIER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_BLOOM_FILTER', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'SHARED_DELTASTORE_CREATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FILE_VALIDATION_THREADS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETFINALFILEPATHBYHANDLE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'SATELLITE_SERVICE_SETUP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SATELLITE_CARGO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SMSYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XTP_HOST_PARALLEL_RECOVERY', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_SWITCH_TO_INACTIVE', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'HKCS_PARALLEL_RECOVERY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SATELLITE_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DPT_ENTRY_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RECOVERY_MGR_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_REDO_FLOW_CONTROL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_REDO_WORKER_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_REDO_DRAIN_WORKER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_REDO_TRAN_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_REDO_LOG_CACHE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_REDO_WORKER_WAIT_WORK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_REDO_TRAN_TURN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SOCKETDUPLICATEQUEUE_CLEANUP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FFT_NSO_FCB_STATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QE_WARN_LIST_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HKCS_PARALLEL_MIGRATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HK_RESTORE_FILEMAP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOG_POOL_SCAN', 'Transaction Log', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_SEEDING_LIMIT_BACKUPS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_SEEDING_CANCELLATION', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_SEEDING_SYNC_COMPLETION', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_SEEDING_TIMEOUT_TASK', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_SEEDING_FILE_LIST', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_SEEDING_WAIT_FOR_COMPLETION', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_SCRIPT_PREPARE_SERVICE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_SCRIPT_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_EXTERNAL_SCRIPT_DIRECTORY_PERMISSION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_RG_UPDATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_QDS_CAPTURE_INIT', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', '"EXTERNAL_WAIT_ON_LAUNCHER,"', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ASYNC_SOCKETDUP_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ASSEMBLY_FILTER_HASHTABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SECURITY_DBE_STATE_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGMGR_PMM_LOG', 'Transaction Log', false, false, NULL, NULL, NULL),
    ('wait_type', 'COLUMNSTORE_COLUMNDATASET_SESSION_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'GHOSTCLEANUP_UPDATE_STATS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SECURITY_CNG_PROVIDER_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TEMPORAL_BACKGROUND_PROCEED_CLEANUP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'QDS_HOST_INIT', 'Query Store Internal', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_SCRIPT_NETWORK_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_SERVICE_BLOB_MESSAGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_SERVICE_CONNECTION_CLOSE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'STREAMING_SERVICE_RESTART_FINISHED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'STREAMING_SERVICE_SEND_KILL_PROCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XDB_PKG_LAUNCHER_CONNECTION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_THROTTLE_LOG_RATE_LOG_SIZE', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_THROTTLE_LOG_RATE_SEND_RECV_QUEUE_SIZE', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_THROTTLE_LOG_RATE_SEEDING', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_THROTTLE_LOG_RATE_MISMATCHED_SLO', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_THROTTLE_LOG_RATE_SLO_DOWNGRADE', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'QRY_PROFILE_LIST_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RESTORE_FILEHANDLECACHE_ENTRYLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RESTORE_FILEHANDLECACHE_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'MEMORY_GRANT_UPDATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_TRANSPORT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SBS_FILE_OPERATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SBS_API_STATS_PUBLISH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SBS_IOAPI_STATS_PUBLISH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_DBCC_FREEZEIO_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_DBCC_THAWIO_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_DISPATCH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_RECEIVE_TRANSPORT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_TRANSPORT_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_TRANSPORT_BUFFER_DEREFERENCE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_COMPILE_WAIT', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XTP_SERIAL_RECOVERY', 'In-Memory OLTP', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_PREEMPTIVE_APP_USAGE_TIMER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REMOTE_BLOCK_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_PS_ACTOR_COLLECTION_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_COMPLETE_LOG_READ', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_CONNECTION_MGR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_UNINITIALIZE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_AWAIT_RESPONSE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_COMM_RETRY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_COMM_UNINITIALIZE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_INITIALIZE_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_FCB_DEFERRED_IO_FN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_FCB_DEFERRED_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_WAIT_VLF', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOGREAD_SIGNAL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_BGTHREAD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_GAPFILLERTHREAD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_BROKER_WAITFULL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_BROKER_WAITMAXALLOWED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_SPACEMGR_INITIALIZE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_BROKER_WAIT_PAGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_BROKER_UNLINKING_IN_PROGRESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FOREIGN_REDO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FOREIGN_FILE_VALIDATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BLOB_CONTAINER_TABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RESTORE_MSDA_THREAD_BARRIER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BACKUP_INMEM_DIFFLIST_READ_ACCESS', 'Backup/Restore', false, false, NULL, NULL, NULL),
    ('wait_type', 'BACKUP_INMEM_DIFFLIST_WRITE_ACCESS', 'Backup/Restore', false, false, NULL, NULL, NULL),
    ('wait_type', 'BACKUP_BACKUP_MGR_MIHYBRIDINFO_RWLOCK', 'Backup/Restore', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_SETUP', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XE_PROXY_SESSIONCOMMIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'UCS_CNG_PROVIDER_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_BCRYPTIMPORTKEY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_NCRYPTIMPORTKEY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_EXTERNAL_SCRIPT_LIBMGMT_DIR_PERMS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_NTJOB_CALLS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'VERSION_STORE_MGR_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PVS_CLEANUP_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PVS_SHRINK_SYNC_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_PHYSMASTERDBREADY', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLOG_APPEND', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLOG_TRUNCATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_NSO_PROCESS_HASHTABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_WAITFORSINGLEOBJECT_SBS_API', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_WAITFORSINGLEOBJECT_SBS_IO', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_LOG_LEASE_HASH_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_WPR_MUTEX', 'Other', false, false, NULL, NULL, NULL)
ON CONFLICT (tier, event_name) DO UPDATE SET
    wait_class = EXCLUDED.wait_class, is_benign = EXCLUDED.is_benign,
    has_specific_rule = EXCLUDED.has_specific_rule, rule_ids = EXCLUDED.rule_ids,
    guidance_text = EXCLUDED.guidance_text, source = EXCLUDED.source;

INSERT INTO mssql_wait_event_master
    (tier, event_name, wait_class, is_benign, has_specific_rule, rule_ids, guidance_text, source)
VALUES
    ('wait_type', 'WAIT_WPR_TABLEACCESS_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REMOTE_CS_GC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PROTECTED_SHARED_BUFFER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CATALOG_DB_INFO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_WPR_STACK_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CS_BLOB_BPOOL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'NATIVE_SHUFFLE_PROCESS_INPUT_BATCHES', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'NATIVE_SHUFFLE_SBS_BUFFER_WRITES', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'NATIVE_SHUFFLE_WRITE_BUFFER_DEQUEUE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_NSO_PROCESS_OPENHANDLE_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'NATIVE_SHUFFLE_SBS_READS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_READFILE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_RG_RESPONSEFROMSERVER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_RG_HTTP', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'CLONEDB_CHECKDB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_WAITFORSINGLEOBJECT_SBS_IOCP', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_SYNC_IO_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TIERED_STORAGE_REENCRYPTION_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_REDO_CATCHUP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TIERED_STORAGE_PERSIST_LRU_INFO_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_CATALOG_COMMUNICATION_HUB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_DYNAMIC_INTERNAL_TABLE_BASE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'NATIVE_SHUFFLE_SHARED_BUFFER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'VLDB_DUMP_LOG_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'MANAGED_INSTANCE_FILE_SYNCH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TIERED_STORAGE_SCANNER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TIERED_STORAGE_MIGRATION_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'COLUMNSTORE_ATTRIBUTE_ACCESSOR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LOGPOOL_CONSUMER_SCAN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_SCRIPT_LAUNCHPAD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_PREEMPTIVE_GET_APP_PATH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_RG_STORAGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_RG_STORAGE_CHECKPOINT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_RG_DESTAGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_RG_REPLICA', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_RG_GEOREPLICA', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PVS_TRACK_PAGES_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_CTR_ABORTED_XDESID_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_SCRIPT_CREATE_CERTIFICATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_TOSITER_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_ATTACH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_POOL_QUERY_WAIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_POOL_FILLER_SLEEP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_POOL_FILLER_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_XLOG_POOL_EVICT_SLEEP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_POOL_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TIERED_STORAGE_CACHE_HIT_STATS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_WRITE_WAIT_TABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'VERSION_LEASE_HASH_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PVS_ENABLE_EVENT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_COPY_IO_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FEDERATION_NODE_API_CALL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IQ_QUERY_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_EDC', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_REPORTING', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_EMC', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'EDC_INIT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EDC_INIT_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EMC_INIT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IQ_CHANNEL_HASH_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XA_START', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XA_OPERATION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XA_RECOVER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_DBHEALTH_INFOMAP_ACCESS', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_TRANSITION_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IQ_REQUEST_HASH_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EDC_FABRIC_RESOLVE_SERVICE_URI', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EMC_FABRIC_RESOLVE_SERVICE_URI', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_EXTENSIBILITY_CLEANUP_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RESERVOIR_SAMPLE_CRITICAL_SECTION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_AUTHENTICATE_LAUNCHPADD', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'INTERFACE_ENDPOINTS_LIST_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TESTTHREAD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CSATTRIBUTECACHE_UNITTEST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DATA_EXPORT_COMPLETION_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_EXTERNAL_LIBRARY_API_CALL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_RG_LOCALDESTAGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IQ_CONFIG_HASH_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IQ_RESOLVE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_ON_SYNC_STATISTICS_REFRESH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RETRY_INIT_PVS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XCS_LIBRARY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XCS_SCHEMA_FILE_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XCS_SCHEMA_RESOLUTION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XCS_PARQUET_SEGMENT_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XCS_SHARED_FILE_OP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XCS_LOCATOR_FETCH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XCS_GENERIC_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_FCS_MD_RESOLVE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IQ_CLIENT_HASH_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_DB_RESTART', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_DBSTATECHANGE_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_DB_TRANS_PRIMARY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_DBTRANSPRIMARY_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RG_MEM_TARGET_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EDC_EXEC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'REPORTING_EXEC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EMC_EXEC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_CTR_ABORTED_XDES_FORGET_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SP_PREPARE_HANDLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HK_CREATE_TABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HK_STORAGE_UNDEPLOYMENT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_AETM_COMPARATOR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_AE_DEFERRED_XACT_MGR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_LAUNCHPAD_SERVICE_DISPATCHER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_GLMS_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_FIDO_GLMS_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_GLMS_LOG', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_GLMS_LOG_BLOCK_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_ODBC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_SEQUENCE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_RETENTION_POLICY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'COLUMNSTORE_CSI_CACHE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LCK_REQ_TSK_PROXY', 'Lock', false, false, NULL, NULL, NULL),
    ('wait_type', 'RG_MANAGER_THREAD_POOL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RG_MANAGER_THREAD_POOL_TASK_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TOAD_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_LOOKUPACCOUNTNAME', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'SEEDING_RECEIVE_BUFFER_READ_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SEEDING_RECEIVE_BUFFER_WRITE_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DW_TRAN_CREATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_LM_CREATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BDC_CONTROLLER_REQUEST_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BLOCKCHAIN_SATELLITE_CONNECTION_OPEN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BTREE_INSERT_FLOW_CONTROL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PVS_PAGE_TRACKER_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_AELOB_PROCESS_SERIALIZER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_AETM_CALL_SERIALIZER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_VSM_ATTEST_LIBLOAD_SERIALIZER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_EXTERNAL_SCRIPT_LANGMGMT_DIR_PERMS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_EXTERNAL_SERVICE_HUB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_EXTERNAL_SERVICE_SEND_MESSAGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_FIND_ALLOCATE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_ATTACH', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_DESTROY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_GET_GLOBAL_PARAMS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_ACK_RELEASE', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_GET_DIST_COUNT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_FREE_REGION', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_CHECK_REGION_READY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SHAREDMEM_RELEASE_BUFFER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'POLYBASE_SHAREDMEM_TASK_FINISH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAITFOR_ALLOC_REF_COUNT_TO_ZERO', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'DPT_PARTITION_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PVS_PREALLOCATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'POPULATE_LOCK_ORDINALS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TOAD_PRODUCER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IMPPROV_IOWAIT_EXT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'IMPPROV_IOWAIT_EXT_CLOSE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_WAIT_FOR_PAGE_SERVER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ACTIVATE_SF_CODEPACKAGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BDC_CONTROLLER_HTTP_SEND', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BDC_CONTROLLER_READ_SECRETS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_SEEDING_READY_FOR_RESTORE_STREAM', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'SHRINK_CLEANER_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TOAD_FUTURE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TOAD_QUEUE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XFILE_DISPATCH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XFILE_OBJECT_POOL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BLOB_LIST_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_LCKMGR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XCS_THRIFT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_XCS_SNAPPY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'COLLECTOR_VIEW_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_TRANSPORT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_AE_INITIALIZED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DIRTY_PAGE_THROTTLING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'THROTTLE_LOG_RATE_LOG_STORAGE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HADR_THROTTLE_REFRESH_MAX_SIZE', 'Replication/HA', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_PHYSICAL_CATALOG', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RG_SERVER_CONFIGS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'NATIVE_SHUFFLE_OPEN_HANDLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_CONTEXT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SBS_LRU_EVICTION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XFILE_CACHE_XACT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XFILE_TASK_PROXY_ABORT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'STRIPE_META_UPDATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SP_RESOLVE_DEFERRED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BACKUP_LOG_IO_STALL', 'Backup/Restore', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_AETM_ENCLAVE_WORKER_SLEEP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_AETM_HOST_WORKER_SLEEP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_AETM_CRITICAL_SECTION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_TOSFILE_GET_ITER_PROXY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RG_MANAGER_VHD_GROWTH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BLOB_LIST_LIMIT_IO_REQUESTS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FCB_DISKSPACE_COUNTERS_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_EOL_REQUEST_NOTIFICATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LSN_LOC_MAP_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BDC_CACHE_TABLE_CREATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_FULLTEXT_CRAWL_MANAGER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TOAD_DISCOVERY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TOAD_RESOURCE_SEMAPHORE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'INDEX_BUILD_BUCKETIZATION_BARRIER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'INDEX_BUILD_BUCKETIZATION_INFO_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'INDEX_BUILD_BUCKETIZATION_INFO_MAP_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARQUET_INDEX_BUILD_MANIFEST_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CONNECTION_MGR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_LC_SEEDING_VDL_ADVANCE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_LC_FWD_SEEDING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XLOG_LC_REVERSE_SEEDING', 'Other', false, false, NULL, NULL, NULL)
ON CONFLICT (tier, event_name) DO UPDATE SET
    wait_class = EXCLUDED.wait_class, is_benign = EXCLUDED.is_benign,
    has_specific_rule = EXCLUDED.has_specific_rule, rule_ids = EXCLUDED.rule_ids,
    guidance_text = EXCLUDED.guidance_text, source = EXCLUDED.source;

INSERT INTO mssql_wait_event_master
    (tier, event_name, wait_class, is_benign, has_specific_rule, rule_ids, guidance_text, source)
VALUES
    ('wait_type', 'PWAIT_PREEMPTIVE_OS_CRYPTOPENSTORAGEPROVIDER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_PREEMPTIVE_OS_VSMATTESTATIONSERVICE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_PREEMPTIVE_OS_AUTHENTICATEDWEBCALL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_PREEMPTIVE_OS_AUTHENTICATIONTOKEN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PRU_PAGE_LSN_CACHE_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_COSMOSDB', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'COSMOSDB_INIT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_BPOOL_DEALLOCATION_WORKER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_PREDICT_API', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'LEDGER_TRUNCATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'LEDGER_BLOCK_GENERATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SESSION_MGR', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXECUTED_REQ_TABLE_STATE_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_VLDB_PLANNED_FAILOVER_START_THROTTLING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_VLDB_PLANNED_FAILOVER_STOP_THROTTLING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_VLDB_PLANNED_FAILOVER_FORWARDER_THROTTLING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_RM_RBIOCONNECTION_INIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SNI_SOCKET_BIND', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SNI_SOCKET_LISTEN', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'START_BACKGROUND_TASK_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TELEMETRY_SNAP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_TSQL_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_GLM_CONTROLLER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_GLM_SYNC_CLIENT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_GLM_DB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_TOAD_TUNING_ZONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_TOAD_DELTA_FORCE_ZONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_TOAD_STAR_CELL_ZONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FULL_BACKUP_SELF_THROTTLING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_GLM_DEK_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBIO_RG_MIGRATION_TARGET', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'MULTITHREADED_VERSION_CLEANUP_WAIT_WORK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CDC_SCHEDULERCACHE_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CDC_THROTTLE_LOG_RATE_LOG_SIZE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DIFF_BACKUP_SELF_THROTTLING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DTCNEW_DWSHELLDB_PROPERTIES', 'Transaction', false, false, NULL, NULL, NULL),
    ('wait_type', 'POLARIS_TSQL_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_TOAD_CELL_ZONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_TOAD_OCCI_ZONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_VLF_IO_TRACKER_DRAIN_IO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_LOG_REPLICA_MGR_HASH_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_LOG_REPLICA_WRITE_LEASE_PROPERTY_HASH_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_LOG_REPLICA_ROLE_STABILITY_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_XLOG_REPLICA_BG_TASK_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'BUFFERPOOL_SCAN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_RBIO_IC_ACQUIRE_PAYLOAD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ORDLOCK_POPULATE_SYNC', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_GC_IO_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_DELTA_CACHE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBPEX_WRITEBEHIND_DB_STATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBPEX_CREATESNAPSHOT_RETRY', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_PDH_WMI_QUERY', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_FOR_MS_POLL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_AE_KEYADD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_PS_RBPEX_HOT_PAGES_RWLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_INDEXSTORE_COMPUTE_PARTITION_BUCKETS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_INDEXSTORE_LIMIT_REQUESTS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_GOVERNANCE_POLICY_UPDATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_COMMIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_PUBLISH', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_CAPTURE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_DATA_EXPORT_SESSION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_UPDATE_TABLE_STATUS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_POPULATE_METADATA', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_DB_CLEANUP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_GET_CURRENT_DB_LSN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', '"PWAIT_SYNAPSE_LINK_GET_TABLE_HASHTABLE,"', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', '"PWAIT_SYNAPSE_LINK_GET_DB_LIST,"', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_FIDO_INDEXSTORE_CONNECTIONS_MANAGER_HASHTABLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SYNAPSESTREAMING_HTTP_EVENT_WAIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_AAD_HTTP_EVENT_WAIT', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBPEXSHRINKTASK_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SLEEP_RBPEXSHRINKTASK', 'Idle/Sleep', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_FCS_MD_READ_AHEAD', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'ROW_GROUP_POPULATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SEEDING_SELF_THROTTLING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_SERVICE_CONTROL_MANGER', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'TOAD_DELETEBITMAP_ZONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TOAD_AUTOSTATISTICS_ZONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TOAD_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PARALLEL_DB_SEEDING_SEMAPHORE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FIDO_CLIENT_STARTUP', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HTTP_EXTERNAL_CONNECTION', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'PREEMPTIVE_OS_GETQUEUEDCOMPLETIONSTATUS', 'Preemptive', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_FIDO_GLMS_ASYNC_WORKER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_FIDO_GLMS_UT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'EXTERNAL_GOVERNANCE_PULL_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'FIDO_AUTOSTATISTICS_TASK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'VLDB_SNAPSHOT_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'RBPEX_CHANGE_FILE_SIZE_MUTEX', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DIRECTORY_CONTENT_LIST_CLERK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_END_HISTORY_SESSION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_LZN_API_CALL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_MEM_CAP_THROTTLE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_SYNAPSE_LINK_PUBLISHER_DONE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CORRUPTED_PAGE_PROCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HTTP_EXTERNAL_CONNECTION_ALLOW_LIST', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_EXTERNAL_GOVERNANCE_POLICY_PROVIDER', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SYNAPSELINK_CAPTURE_JOBTASK_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SYNAPSELINK_PUBLISH_JOBTASK_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SYNAPSELINK_COMMIT_JOBTASK_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SYNAPSELINK_SNAPSHOT_JOBTASK_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'SYNAPSELINK_FAILBATCH_ACCESS', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_SYNC_LAG_PARTNERS_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HTTP_EXTERNAL_CONNECTION_IPV4_BLOCK_LIST', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_PREDICATE_HEAP_ALLOC', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_PREDICATE_HEAP_FREE', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_SQL_TEXT_HEAP_ALLOC', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_SQL_TEXT_HEAP_FREE', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_SQL_TEXT_PREDICATE', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'ARC_IMDS_RESOURCE_INFO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'MANAGED_DISKS_CONFIGURATION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PWAIT_S3_TEMP_CREDENTIAL', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_DW_TX_EXTERNALIZATION_IO_COMPLETION', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_RING_TARGET_MUTEX', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', 'XE_LIVE_TARGET_MUTEX', 'Extended Events', false, false, NULL, NULL, NULL),
    ('wait_type', '"EXTERNAL_GOVERNANCE_ATTR_SYNC_BACKGROUND "', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', '"EDC_DOPP_LOCK "', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', '"EDC_DOPP_BACKGROUND "', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', '"SQP_STATS_REPORTING "', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_RBPEX_WRITEBEHIND_CKPT_CONSISTENCY_LOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_EXTERNAL_GOVERNANCE_POLICY_SESSION_AUDIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_EXTERNAL_GOVERNANCE_POLICY_SESSIONS_AUDIT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'PURVIEW_POLICY_SDK_PREEMPTIVE_SCHEDULING', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DW_WS_DB_LIST', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'DW_DB', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_EXTERNAL_GOVERNANCE_POLICY_AAD_GROUP_INFO', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CDC_SCAN_FINISHED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_EXTERNAL_GOVERNANCE_PERMCACHE_RESOURCELOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'WAIT_EXTERNAL_GOVERNANCE_PERMCACHE_DECISIONLOCK', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'HTTP_EXTERNAL_CONNECTION_IPV6_BLOCK_LIST', 'Hash Join', false, false, NULL, NULL, NULL),
    ('wait_type', 'COLUMNSTORE_TRANSCODER_CREATE', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'TRIDENT_ONELAKE_ENDPOINT', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'NOTIFY_COMPUTE_PAGESERVER_SHUTDOWN', 'Other', false, false, NULL, NULL, NULL),
    ('wait_type', 'CDC_CLEANUP_FINISHED', 'Other', false, false, NULL, NULL, NULL),
    ('wait_category', 'Unknown', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'CPU', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Parallelism', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Memory', NULL, false, true, 'MSSQL_WAIT_010', NULL, NULL),
    ('wait_category', 'Latch', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Compilation', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Network IO', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Buffer Latch', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Buffer IO', NULL, false, true, 'MSSQL_WAIT_005', NULL, NULL),
    ('wait_category', 'Other Disk IO', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Lock', NULL, false, true, 'MSSQL_WAIT_006', NULL, NULL),
    ('wait_category', 'Access Methods', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'External Resource', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'User Wait', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Tracing', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Transaction Log', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Replication', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Sparse Column', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'CLR', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Mirroring', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Transaction', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Idle', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Preemptive', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Worker Termination', NULL, false, false, NULL, NULL, NULL),
    ('wait_category', 'Tran Log IO', NULL, false, true, 'MSSQL_WAIT_009', 'The actual observed wait_category_desc string from live sys.query_store_wait_stats data (confirmed against a real instance run) -- differs from ''Transaction Log'', the formal enum name in Microsoft''s own reference documentation. MSSQL_WAIT_009 targets this real string.', 'Verified against a real instance run, this project')
ON CONFLICT (tier, event_name) DO UPDATE SET
    wait_class = EXCLUDED.wait_class, is_benign = EXCLUDED.is_benign,
    has_specific_rule = EXCLUDED.has_specific_rule, rule_ids = EXCLUDED.rule_ids,
    guidance_text = EXCLUDED.guidance_text, source = EXCLUDED.source;

\echo 'mssql_wait_event_master population: done'
SELECT tier, count(*), count(*) FILTER (WHERE is_benign), count(*) FILTER (WHERE has_specific_rule), count(*) FILTER (WHERE guidance_text IS NOT NULL)
FROM mssql_wait_event_master GROUP BY tier;
