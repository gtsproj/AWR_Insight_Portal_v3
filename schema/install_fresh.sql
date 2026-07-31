-- ============================================================
-- AWR Insight Portal v3 — Fresh Installation Script
-- Avekshaa Technologies
-- ============================================================
--
-- This single script performs a complete fresh installation:
--   1. Creates tablespaces (prompts for directory paths)
--   2. Creates schema owner role with prompted password
--   3. Creates all database objects (79 tables, 86 indexes,
--      2 views, 11 materialized views, 1 extra table)
--   4. Seeds default portal_config values
--   5. Seeds default admin user (admin / Admin@123)
--   6. Seeds all 60 Oracle wait event classifications
--
-- ── BEFORE RUNNING ───────────────────────────────────────────
--   • Run as PostgreSQL superuser (postgres)
--   • Create the tablespace directories FIRST (mkdir)
--   • Set the 3 variables in the CONFIGURATION section below
--   • psql -U postgres -d postgres -f install.sql
--
-- ── AFTER RUNNING ────────────────────────────────────────────
--   • Run: py bulk_import.py   (import Grafana dashboards)
--   • Open http://localhost:8000
--   • Login: admin / Admin@123
--   • Settings → Access Control: update portal_url and grafana_url
--   • Settings → License: enter your license key
-- ============================================================

\echo ''
\echo '============================================================'
\echo ' AWR Insight Portal v3 — Installation'
\echo ' Avekshaa Technologies'
\echo '============================================================'

SET client_min_messages = WARNING;
SET search_path = public;

-- ============================================================
-- SECTION 1: CONFIGURATION — EDIT BEFORE RUNNING
-- ============================================================
--
-- 3 things to edit before running this script:
--
-- ① TABLESPACE PATHS (Section 2, ~line 70):
--     Edit the LOCATION paths in both CREATE TABLESPACE statements.
--     The directories must exist first.
--     Windows: C:\PostgreSQL\tablespaces\awrparser
--     Linux:   /opt/postgresql/tablespaces/awrparser
--
-- ② SCHEMA OWNER PASSWORD (Section 3, ~line 115):
--     Change 'YourSecurePassword123' in the DO $$ block.
--
-- ③ CREATE THE DIRECTORIES FIRST (run in cmd/shell):
--     Windows:
--       mkdir C:\PostgreSQL\tablespaces\awrparser
--       mkdir C:\PostgreSQL\tablespaces\awrparser_idx
--     Linux:
--       mkdir -p /opt/postgresql/tablespaces/awrparser
--       mkdir -p /opt/postgresql/tablespaces/awrparser_idx
--       chown postgres:postgres /opt/postgresql/tablespaces/awrparser*
--
-- Then run:
--   psql -U postgres -d postgres -f schema\install_fresh.sql
-- ============================================================


-- ============================================================
-- SECTION 2: TABLESPACES
-- ============================================================
-- NOTE: The directories must exist on the filesystem before
-- PostgreSQL can create tablespaces in them.
--
-- Windows: mkdir C:\PostgreSQL\tablespaces\awrparser
--          mkdir C:\PostgreSQL\tablespaces\awrparser_idx
-- Linux:   mkdir -p /opt/postgresql/tablespaces/awrparser
--          mkdir -p /opt/postgresql/tablespaces/awrparser_idx
--          chown postgres:postgres /opt/postgresql/tablespaces/awrparser*
-- ============================================================

\echo 'Step 1/6: Creating tablespaces...'

-- ── Step 1a: Edit the paths below before running ────────────────────
-- Windows: C:\PostgreSQL\tablespaces\awrparser
-- Linux:   /opt/postgresql/tablespaces/awrparser
-- The directories MUST exist before PostgreSQL can create tablespaces.

CREATE TABLESPACE awrparser
    OWNER postgres
    LOCATION 'C:\PostgreSQL\tablespaces\awrparser';
    -- ^^^ EDIT THIS PATH before running

CREATE TABLESPACE awrparser_idx
    OWNER postgres
    LOCATION 'C:\PostgreSQL\tablespaces\awrparser_idx';
    -- ^^^ EDIT THIS PATH before running

-- NOTE: If you prefer NOT to use custom tablespaces, comment out the
-- two CREATE TABLESPACE statements above, then run this script which
-- creates fallback aliases so all subsequent DDL succeeds without change:
--
--   CREATE TABLESPACE awrparser     OWNER postgres LOCATION '/tmp/ts_data';
--   CREATE TABLESPACE awrparser_idx OWNER postgres LOCATION '/tmp/ts_idx';
--
-- Or edit every TABLESPACE clause in Section 4 from awrparser to pg_default.

\echo '  Tablespaces: done'


-- ============================================================
-- SECTION 3: SCHEMA OWNER ROLE
-- ============================================================
-- Creates a dedicated role that owns all portal objects.
-- Password is set interactively via \password after creation.
-- For non-interactive setup, replace \password with:
--   ALTER ROLE awr_owner PASSWORD 'YourPasswordHere';
-- ============================================================

\echo 'Step 2/6: Creating schema owner role...'

-- Create the role if it does not already exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'awr_owner') THEN
        CREATE ROLE awr_owner LOGIN
            PASSWORD 'YourSecurePassword123';
            -- ^^^ EDIT THIS PASSWORD before running
        RAISE NOTICE 'Role awr_owner created';
    ELSE
        -- Update password if role already exists
        ALTER ROLE awr_owner PASSWORD 'YourSecurePassword123';
            -- ^^^ EDIT THIS PASSWORD before running
        RAISE NOTICE 'Role awr_owner already exists — password updated';
    END IF;
END $$;

-- Grant connection and schema privileges to the owner role
GRANT CONNECT ON DATABASE postgres TO awr_owner;
GRANT CREATE  ON SCHEMA public     TO awr_owner;
GRANT USAGE   ON SCHEMA public     TO awr_owner;

-- Optional: to connect to the portal as awr_owner instead of postgres,
-- update config/settings.yaml: database.user = awr_owner
-- and set database.password to the password set above.

\echo '  Schema owner role: done'


-- ============================================================
-- SECTION 4: DATABASE OBJECTS
-- 79 tables + 1 (sar_anomalies) + 86 indexes + 2 views +
-- 11 materialized views
-- ============================================================

\echo 'Step 3/6: Creating database objects...'
\echo '  (79 tables, 86 indexes, 2 views, 11 materialized views)'

-- ============================================================
-- AWR Insight Portal v3 — Complete Database Schema
-- Generated: 2026-07-30 17:02:27
-- Tool: extract_ddl.py
-- ============================================================
-- Run as: psql -U postgres -d postgres -f awr_portal_full_schema.sql
-- ============================================================

SET client_min_messages = WARNING;
SET search_path = public;



-- ============================================================
-- TABLESPACES
-- ============================================================

-- NOTE: Update location path for your environment

-- NOTE: Update location path for your environment



-- ============================================================
-- CUSTOM TYPES / ENUMS
-- ============================================================


-- ============================================================
-- TABLES (119 total)
-- ============================================================

-- Table: awr_advisory_pga
CREATE TABLE IF NOT EXISTS awr_advisory_pga (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    pga_target_est_mb              NUMERIC,
    size_factor                    NUMERIC,
    w_a_mb_processed               NUMERIC,
    estd_extra_written_to_disk     NUMERIC,
    estd_pga_cache_hit_pct         NUMERIC,
    estd_pga_overalloc_count       BIGINT,
    estd_time                      NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_advisory_pga_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_adv_pga UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_advisory_sga
CREATE TABLE IF NOT EXISTS awr_advisory_sga (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sga_target_size_m              NUMERIC,
    sga_size_factor                NUMERIC,
    est_db_time_s                  NUMERIC,
    est_physical_reads             BIGINT,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_advisory_sga_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_adv_sga UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_ai_learnings
CREATE TABLE IF NOT EXISTS awr_ai_learnings (
    id                             SERIAL,
    trigger_pattern                TEXT NOT NULL,
    context_summary                TEXT,
    accepted_recommendation        TEXT NOT NULL,
    times_accepted                 INTEGER DEFAULT 1,
    last_seen                      TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT awr_ai_learnings_pkey PRIMARY KEY (id),
    CONSTRAINT uq_learning UNIQUE (trigger_pattern)
);

-- Table: awr_ai_recommendations
CREATE TABLE IF NOT EXISTS awr_ai_recommendations (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT,
    begin_snap                     INTEGER,
    end_snap                       INTEGER,
    trigger_type                   TEXT NOT NULL,
    trigger_value                  TEXT NOT NULL,
    severity                       TEXT,
    ai_provider                    TEXT,
    ai_model                       TEXT,
    ai_prompt                      TEXT,
    ai_response                    TEXT NOT NULL,
    root_cause                     TEXT,
    recommendation                 TEXT,
    status                         TEXT DEFAULT 'pending'::text,
    dba_feedback                   TEXT,
    revised_prompt                 TEXT,
    revised_response               TEXT,
    accepted_at                    TIMESTAMP WITHOUT TIME ZONE,
    rejected_at                    TIMESTAMP WITHOUT TIME ZONE,
    revised_at                     TIMESTAMP WITHOUT TIME ZONE,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT awr_ai_recommendations_pkey PRIMARY KEY (id)
);

-- Table: awr_anomalies
CREATE TABLE IF NOT EXISTS awr_anomalies (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    begin_snap                     INTEGER NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    metric_source                  TEXT NOT NULL,
    metric_name                    TEXT NOT NULL,
    object_name                    TEXT,
    metric_value                   NUMERIC,
    baseline_mean                  NUMERIC,
    baseline_stddev                NUMERIC,
    z_score                        NUMERIC,
    severity                       TEXT,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_anomalies_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_anomaly UNIQUE (dbname, dbname, dbname, dbname, dbname, dbname, instance, instance, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, begin_snap, begin_snap, metric_source, metric_source, metric_source, metric_source, metric_source, metric_source, metric_name, metric_name, metric_name, metric_name, metric_name, metric_name, object_name, object_name, object_name, object_name, object_name, object_name)
);

-- Table: awr_background_wait_events
CREATE TABLE IF NOT EXISTS awr_background_wait_events (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    event                          TEXT,
    waits                          NUMERIC,
    total_wait_time_s              NUMERIC,
    avg_wait_ms                    NUMERIC,
    waits_per_txn                  NUMERIC,
    pct_bg_time                    NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_background_wait_events_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_bg_wait_events UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_buffer_wait_statistics
CREATE TABLE IF NOT EXISTS awr_buffer_wait_statistics (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    class                          TEXT,
    waits                          BIGINT,
    total_wait_time_s              NUMERIC,
    avg_time_ms                    NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_buffer_wait_statistics_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_buf_waits UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_change_log
CREATE TABLE IF NOT EXISTS awr_change_log (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    event_time                     TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    change_type                    TEXT,
    description                    TEXT NOT NULL,
    changed_by                     TEXT,
    impact                         TEXT,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_change_log_pkey PRIMARY KEY (id)
);

-- Table: awr_comparison_tags
CREATE TABLE IF NOT EXISTS awr_comparison_tags (
    id                             SERIAL,
    tag_name                       TEXT NOT NULL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT,
    snap_start                     INTEGER NOT NULL,
    snap_end                       INTEGER NOT NULL,
    tag_type                       TEXT NOT NULL,
    notes                          TEXT,
    created_by                     TEXT DEFAULT 'DBA'::text,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_comparison_tags_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_tag UNIQUE (dbname, dbname, dbname, tag_name, tag_name, tag_name, tag_type, tag_type, tag_type)
);

-- Table: awr_db_info
CREATE TABLE IF NOT EXISTS awr_db_info (
    id                             SERIAL,
    db_name                        TEXT NOT NULL,
    edition                        TEXT,
    release                        TEXT,
    instance                       TEXT NOT NULL,
    rac                            TEXT,
    host_name                      TEXT,
    platform                       TEXT,
    cpu                            INTEGER,
    cores                          INTEGER,
    sockets                        INTEGER,
    memory                         NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    cdb                            TEXT,
    pdb_name                       TEXT,
    rac_nodes                      INTEGER,
    source_type                    TEXT DEFAULT 'local_file'::text,
    repo_path                      TEXT,
    CONSTRAINT awr_db_info_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_db_info UNIQUE (db_name, db_name, db_name, instance, instance, instance, row_hash, row_hash, row_hash)
);

-- Table: awr_db_master
CREATE TABLE IF NOT EXISTS awr_db_master (
    id                             SERIAL,
    db_name                        TEXT NOT NULL,
    instance_name                  TEXT,
    inst_no                        INTEGER DEFAULT 1,
    host_name                      TEXT,
    db_type                        TEXT DEFAULT 'STANDALONE'::text,
    description                    TEXT,
    active                         BOOLEAN DEFAULT true,
    added_at                       TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    added_by                       TEXT DEFAULT 'admin'::text,
    CONSTRAINT awr_db_master_pkey PRIMARY KEY (id),
    CONSTRAINT uq_db_master_db_inst UNIQUE (db_name, db_name, inst_no, inst_no)
);

COMMENT ON TABLE awr_db_master IS 'Licensed database registry. Only DBs in this table will be parsed by the queue processor.';

-- Table: awr_enqueue_statistics
CREATE TABLE IF NOT EXISTS awr_enqueue_statistics (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    enqueue_type_request_reason    TEXT,
    requests                       BIGINT,
    succ_gets                      BIGINT,
    failed_gets                    BIGINT,
    waits                          BIGINT,
    wt_time_s                      NUMERIC,
    av_wt_time_ms                  NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_enqueue_statistics_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_enqueue_stats UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_execution_plans
CREATE TABLE IF NOT EXISTS awr_execution_plans (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT,
    sql_id                         TEXT NOT NULL,
    plan_hash_value                TEXT,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    begin_snap                     INTEGER,
    step_id                        INTEGER,
    parent_id                      INTEGER,
    operation                      TEXT,
    options                        TEXT,
    object_owner                   TEXT,
    object_name                    TEXT,
    object_type                    TEXT,
    cost                           NUMERIC,
    cardinality                    NUMERIC,
    bytes                          NUMERIC,
    time_secs                      NUMERIC,
    partition_start                TEXT,
    partition_stop                 TEXT,
    access_predicates              TEXT,
    filter_predicates              TEXT,
    projection                     TEXT,
    note                           TEXT,
    upload_source                  TEXT DEFAULT 'paste'::text,
    uploaded_at                    TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    row_hash                       CHAR(32),
    has_full_scan                  BOOLEAN DEFAULT false,
    has_cartesian                  BOOLEAN DEFAULT false,
    has_sort_spill                 BOOLEAN DEFAULT false,
    plan_warning                   TEXT,
    CONSTRAINT awr_execution_plans_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exec_plan UNIQUE (dbname, dbname, dbname, dbname, sql_id, sql_id, sql_id, sql_id, plan_hash_value, plan_hash_value, plan_hash_value, plan_hash_value, step_id, step_id, step_id, step_id)
);

-- Table: awr_file_io_stats
CREATE TABLE IF NOT EXISTS awr_file_io_stats (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    tablespace                     TEXT,
    filename                       TEXT,
    reads                          BIGINT,
    avg_read_sec                   NUMERIC,
    avg_read_ms                    NUMERIC,
    writes                         BIGINT,
    write_avg_sec                  NUMERIC,
    buffer_waits                   BIGINT,
    avg_buffer_wait_ms             NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_file_io_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_file_io UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_foreground_wait_class
CREATE TABLE IF NOT EXISTS awr_foreground_wait_class (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    wait_class                     TEXT,
    waits                          BIGINT,
    total_wait_time_s              NUMERIC,
    avg_wait_ms                    NUMERIC,
    pct_db_time                    NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_foreground_wait_class_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_fg_wait_class UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_foreground_wait_events
CREATE TABLE IF NOT EXISTS awr_foreground_wait_events (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    event                          TEXT,
    waits                          NUMERIC,
    total_wait_time_s              NUMERIC,
    avg_wait_ms                    NUMERIC,
    waits_per_txn                  NUMERIC,
    pct_db_time                    NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_foreground_wait_events_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_fg_wait_events UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_instance_activity_stats
CREATE TABLE IF NOT EXISTS awr_instance_activity_stats (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    name                           TEXT,
    statistic                      TEXT,
    total                          BIGINT,
    per_second                     NUMERIC,
    per_trans                      NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_instance_activity_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_inst_activity UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_instance_efficiency
CREATE TABLE IF NOT EXISTS awr_instance_efficiency (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    metric                         TEXT,
    value                          NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_instance_efficiency_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_instance_eff UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_io_profile
CREATE TABLE IF NOT EXISTS awr_io_profile (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    metric                         TEXT,
    read_per_sec                   NUMERIC,
    write_per_sec                  NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_io_profile_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_io_profile UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_iostat_filetype
CREATE TABLE IF NOT EXISTS awr_iostat_filetype (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    filetype_name                  TEXT,
    reads_mb                       BIGINT,
    reads_reqs_per_sec             NUMERIC,
    reads_data_per_sec_mb          NUMERIC,
    writes_mb                      BIGINT,
    writes_reqs_per_sec            NUMERIC,
    writes_data_per_sec_mb         NUMERIC,
    small_read_ms                  NUMERIC,
    large_read_ms                  NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_iostat_filetype_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_iostat_filetype UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_iostat_func_filetype
CREATE TABLE IF NOT EXISTS awr_iostat_func_filetype (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    function_file_name             TEXT,
    reads_mb                       BIGINT,
    reads_reqs_per_sec             NUMERIC,
    reads_data_per_sec_mb          NUMERIC,
    writes_mb                      BIGINT,
    writes_reqs_per_sec            NUMERIC,
    writes_data_per_sec_mb         NUMERIC,
    waits                          BIGINT,
    avg_time_ms                    NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_iostat_func_filetype_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_iostat_func_filetype UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_iostat_function
CREATE TABLE IF NOT EXISTS awr_iostat_function (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    function_name                  TEXT,
    reads_mb                       BIGINT,
    reads_reqs_per_sec             NUMERIC,
    reads_data_per_sec_mb          NUMERIC,
    writes_mb                      BIGINT,
    writes_reqs_per_sec            NUMERIC,
    writes_data_per_sec_mb         NUMERIC,
    waits                          BIGINT,
    avg_time_ms                    NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_iostat_function_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_iostat_function UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_license_audit
CREATE TABLE IF NOT EXISTS awr_license_audit (
    id                             SERIAL,
    event_type                     TEXT NOT NULL,
    message                        TEXT,
    db_count                       INTEGER,
    sar_count                      INTEGER,
    event_time                     TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT awr_license_audit_pkey PRIMARY KEY (id)
);

-- Table: awr_licensed_dbs
CREATE TABLE IF NOT EXISTS awr_licensed_dbs (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    db_type                        TEXT DEFAULT 'STANDALONE'::text,
    cdb_name                       TEXT,
    is_pdb                         BOOLEAN DEFAULT false,
    rac_cluster                    TEXT,
    host                           TEXT,
    registered_at                  TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    registered_by                  TEXT,
    active                         BOOLEAN DEFAULT true,
    notes                          TEXT,
    CONSTRAINT awr_licensed_dbs_pkey PRIMARY KEY (id),
    CONSTRAINT awr_licensed_dbs_dbname_key UNIQUE (dbname)
);

-- Table: awr_load_profile
CREATE TABLE IF NOT EXISTS awr_load_profile (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    metric                         TEXT,
    per_sec                        NUMERIC,
    per_transaction                NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    is_pdb                         BOOLEAN DEFAULT false,
    cdb_name                       TEXT,
    db_role                        TEXT,
    db_type                        TEXT DEFAULT 'STANDALONE'::text,
    CONSTRAINT awr_load_profile_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_load_profile UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_object_metadata
CREATE TABLE IF NOT EXISTS awr_object_metadata (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    owner                          TEXT NOT NULL,
    object_name                    TEXT NOT NULL,
    object_type                    TEXT NOT NULL,
    num_rows                       BIGINT,
    blocks                         BIGINT,
    avg_row_len                    INTEGER,
    last_analyzed                  TIMESTAMP WITHOUT TIME ZONE,
    partitioned                    TEXT,
    row_movement                   TEXT,
    compression                    TEXT,
    index_type                     TEXT,
    uniqueness                     TEXT,
    blevel                         INTEGER,
    leaf_blocks                    BIGINT,
    distinct_keys                  BIGINT,
    clustering_factor              BIGINT,
    status                         TEXT,
    index_columns                  JSONB,
    partition_type                 TEXT,
    partition_count                INTEGER,
    subpartition_type              TEXT,
    source                         TEXT DEFAULT 'csv'::text,
    uploaded_at                    TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT awr_object_metadata_pkey PRIMARY KEY (id),
    CONSTRAINT uq_object UNIQUE (dbname, dbname, dbname, dbname, owner, owner, owner, owner, object_name, object_name, object_name, object_name, object_type, object_type, object_type, object_type)
);

-- Table: awr_oracle_connections
CREATE TABLE IF NOT EXISTS awr_oracle_connections (
    id                             SERIAL,
    db_name                        TEXT NOT NULL,
    display_name                   TEXT,
    host                           TEXT NOT NULL,
    port                           INTEGER DEFAULT 1521,
    service_name                   TEXT NOT NULL,
    username                       TEXT NOT NULL,
    password_enc                   TEXT NOT NULL,
    snap_interval_hrs              NUMERIC(4,1) DEFAULT 1,
    enabled                        BOOLEAN DEFAULT true,
    last_run_at                    TIMESTAMP WITHOUT TIME ZONE,
    last_snap_id                   INTEGER,
    added_at                       TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    added_by                       TEXT DEFAULT 'admin'::text,
    CONSTRAINT awr_oracle_connections_pkey PRIMARY KEY (id),
    CONSTRAINT uq_oracle_conn_db UNIQUE (db_name)
);

COMMENT ON TABLE awr_oracle_connections IS 'Oracle DB connection config for direct AWR report generation. One row per Oracle database. Used by the Direct Oracle DB AWR fetcher.';

-- Table: awr_oracle_failed_snaps
CREATE TABLE IF NOT EXISTS awr_oracle_failed_snaps (
    id                             SERIAL,
    conn_id                        INTEGER NOT NULL,
    db_name                        TEXT NOT NULL,
    snap_date                      DATE NOT NULL,
    begin_snap                     INTEGER NOT NULL,
    end_snap                       INTEGER NOT NULL,
    dbid                           BIGINT,
    instance_number                INTEGER,
    error_msg                      TEXT,
    retry_count                    INTEGER DEFAULT 0,
    max_retries                    INTEGER DEFAULT 3,
    first_failed_at                TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    last_tried_at                  TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    resolved                       BOOLEAN DEFAULT false,
    CONSTRAINT awr_oracle_failed_snaps_pkey PRIMARY KEY (id),
    CONSTRAINT uq_failed_snap UNIQUE (conn_id, conn_id, conn_id, begin_snap, begin_snap, begin_snap, end_snap, end_snap, end_snap),
    CONSTRAINT awr_oracle_failed_snaps_conn_id_fkey FOREIGN KEY (conn_id)
        REFERENCES awr_oracle_connections (id) ON DELETE CASCADE
);

COMMENT ON TABLE awr_oracle_failed_snaps IS 'Retry queue for AWR report generation failures. Scheduler retries each failed pair up to max_retries times. Resolved = TRUE once successfully generated or max retries exceeded.';

-- Table: awr_os_statistics
CREATE TABLE IF NOT EXISTS awr_os_statistics (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    statistic                      TEXT,
    value                          NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_os_statistics_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_os_stats UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_recommendation_rules
CREATE TABLE IF NOT EXISTS awr_recommendation_rules (
    category                       TEXT NOT NULL,
    rule_key                       TEXT NOT NULL,
    rule_text                      TEXT NOT NULL,
    CONSTRAINT awr_recommendation_rules_pkey PRIMARY KEY (category, category, rule_key, rule_key)
);

-- Table: awr_recommendations
CREATE TABLE IF NOT EXISTS awr_recommendations (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    begin_snap                     INTEGER NOT NULL,
    end_snap                       INTEGER NOT NULL,
    rule_id                        TEXT NOT NULL,
    category                       TEXT,
    severity                       TEXT,
    title                          TEXT,
    event_or_object                TEXT,
    root_cause                     TEXT,
    resolution_json                JSONB,
    ai_summary                     TEXT,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_recommendations_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_rec UNIQUE (dbname, dbname, dbname, dbname, begin_snap, begin_snap, begin_snap, begin_snap, end_snap, end_snap, end_snap, end_snap, rule_id, rule_id, rule_id, rule_id)
);

-- Table: awr_repo_scan_log
CREATE TABLE IF NOT EXISTS awr_repo_scan_log (
    id                             SERIAL,
    repo_path                      TEXT NOT NULL,
    db_name                        TEXT NOT NULL,
    instance                       TEXT,
    pdb_name                       TEXT,
    filename                       TEXT NOT NULL,
    file_hash                      CHAR(32),
    scanned_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status                         TEXT DEFAULT 'PENDING'::text,
    error                          TEXT,
    CONSTRAINT awr_repo_scan_log_pkey PRIMARY KEY (id),
    CONSTRAINT uq_repo_scan UNIQUE (repo_path, repo_path, repo_path, repo_path, db_name, db_name, db_name, db_name, filename, filename, filename, filename, file_hash, file_hash, file_hash, file_hash)
);

-- Table: awr_seg_buff_busy_waits
CREATE TABLE IF NOT EXISTS awr_seg_buff_busy_waits (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    buffer_busy_waits              NUMERIC,
    pct_of_capture                 NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_buff_busy_waits_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_seg_buff_busy_waits UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_cr_blk_rec
CREATE TABLE IF NOT EXISTS awr_seg_cr_blk_rec (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    cr_blocks_received             NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_cr_blk_rec_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_cr_blk_rec UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_cur_blk_rec
CREATE TABLE IF NOT EXISTS awr_seg_cur_blk_rec (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    current_blocks_received        NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_cur_blk_rec_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_cur_blk_rec UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_db_blk_chg
CREATE TABLE IF NOT EXISTS awr_seg_db_blk_chg (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    db_block_changes               NUMERIC,
    pct_of_capture                 NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_db_blk_chg_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_db_blk_chg UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_direct_phy_reads
CREATE TABLE IF NOT EXISTS awr_seg_direct_phy_reads (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    direct_reads                   NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_direct_phy_reads_pkey PRIMARY KEY (id),
    CONSTRAINT uq_direct_phy_reads UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_direct_phy_writes
CREATE TABLE IF NOT EXISTS awr_seg_direct_phy_writes (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    direct_writes                  NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_direct_phy_writes_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_direct_phy_writes UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_gbl_cache_buff_busy
CREATE TABLE IF NOT EXISTS awr_seg_gbl_cache_buff_busy (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    gc_buffer_busy                 NUMERIC,
    pct_of_capture                 NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_gbl_cache_buff_busy_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_gbl_cache_buff_busy UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_itl_waits
CREATE TABLE IF NOT EXISTS awr_seg_itl_waits (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    itl_waits                      NUMERIC,
    pct_of_capture                 NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_itl_waits_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_itl_waits UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_logical_reads
CREATE TABLE IF NOT EXISTS awr_seg_logical_reads (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    logical_reads                  NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_logical_reads_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_seg_logical_reads UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_opt_reads
CREATE TABLE IF NOT EXISTS awr_seg_opt_reads (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    optimized_reads                NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_opt_reads_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_opt_reads UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_phy_read_req
CREATE TABLE IF NOT EXISTS awr_seg_phy_read_req (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    phys_read_requests             NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_phy_read_req_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_phy_read_req UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_phy_reads
CREATE TABLE IF NOT EXISTS awr_seg_phy_reads (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    physical_reads                 NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_phy_reads_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_phy_reads UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_phy_write_req
CREATE TABLE IF NOT EXISTS awr_seg_phy_write_req (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    phys_write_requests            NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_phy_write_req_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_phy_write_req UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_phy_writes
CREATE TABLE IF NOT EXISTS awr_seg_phy_writes (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    physical_writes                NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_phy_writes_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_phy_writes UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_row_lck_waits
CREATE TABLE IF NOT EXISTS awr_seg_row_lck_waits (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    row_lock_waits                 NUMERIC,
    pct_of_capture                 NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_row_lck_waits_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_row_lck_waits UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_table_scan
CREATE TABLE IF NOT EXISTS awr_seg_table_scan (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    table_scans                    NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_seg_table_scan_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_table_scan UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_seg_unopt_reads
CREATE TABLE IF NOT EXISTS awr_seg_unopt_reads (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    owner                          TEXT,
    tablespace_name                TEXT,
    object_name                    TEXT,
    subobject_name                 TEXT,
    obj_type                       TEXT,
    unoptimized_reads              NUMERIC,
    pcttotal                       NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_seg_unopt_reads_pkey PRIMARY KEY (id),
    CONSTRAINT uq_seg_unopt_reads UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_cluster_wait_time
CREATE TABLE IF NOT EXISTS awr_sql_cluster_wait_time (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_module                     TEXT,
    executions                     NUMERIC,
    pct_total                      NUMERIC,
    pct_cpu                        NUMERIC,
    pct_io                         NUMERIC,
    elapsed_time_s                 NUMERIC,
    pct_clu                        NUMERIC,
    cluster_wait_time_s            NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_cluster_wait_time_pkey PRIMARY KEY (id),
    CONSTRAINT uq_cluster_wait_time UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_cpu_time
CREATE TABLE IF NOT EXISTS awr_sql_cpu_time (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_module                     TEXT,
    executions                     NUMERIC,
    pct_total                      NUMERIC,
    pct_cpu                        NUMERIC,
    pct_io                         NUMERIC,
    elapsed_time_s                 NUMERIC,
    cpu_time_s                     NUMERIC,
    cpu_per_exec_s                 NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_cpu_time_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sql_cpu_time UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_elapsed_time
CREATE TABLE IF NOT EXISTS awr_sql_elapsed_time (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_module                     TEXT,
    executions                     NUMERIC,
    pct_total                      NUMERIC,
    pct_cpu                        NUMERIC,
    pct_io                         NUMERIC,
    elapsed_time_s                 NUMERIC,
    elapsed_time_per_exec_s        NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_elapsed_time_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sql_elapsed_time UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_executions
CREATE TABLE IF NOT EXISTS awr_sql_executions (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_module                     TEXT,
    executions                     NUMERIC,
    pct_cpu                        NUMERIC,
    pct_io                         NUMERIC,
    elapsed_time_s                 NUMERIC,
    rows_processed                 NUMERIC,
    rows_per_exec                  NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_executions_pkey PRIMARY KEY (id),
    CONSTRAINT uq_executions UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_gets
CREATE TABLE IF NOT EXISTS awr_sql_gets (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_module                     TEXT,
    executions                     NUMERIC,
    pct_total                      NUMERIC,
    pct_cpu                        NUMERIC,
    pct_io                         NUMERIC,
    elapsed_time_s                 NUMERIC,
    buffer_gets                    NUMERIC,
    gets_per_exec                  NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_gets_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sql_gets UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_parsed_calls
CREATE TABLE IF NOT EXISTS awr_sql_parsed_calls (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_module                     TEXT,
    executions                     NUMERIC,
    parse_calls                    NUMERIC,
    pct_total_parses               NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_parsed_calls_pkey PRIMARY KEY (id),
    CONSTRAINT uq_parsed_calls UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_phy_reads_unopt
CREATE TABLE IF NOT EXISTS awr_sql_phy_reads_unopt (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_module                     TEXT,
    executions                     NUMERIC,
    pct_total                      NUMERIC,
    unoptimized_read_reqs          NUMERIC,
    physical_read_reqs             NUMERIC,
    unoptimized_reqs_per_exec      NUMERIC,
    pctopt                         NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_phy_reads_unopt_pkey PRIMARY KEY (id),
    CONSTRAINT uq_phy_reads_unopt UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_reads
CREATE TABLE IF NOT EXISTS awr_sql_reads (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_module                     TEXT,
    executions                     NUMERIC,
    pct_total                      NUMERIC,
    pct_cpu                        NUMERIC,
    pct_io                         NUMERIC,
    elapsed_time_s                 NUMERIC,
    physical_reads                 NUMERIC,
    reads_per_exec                 NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_reads_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sql_reads UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_text
CREATE TABLE IF NOT EXISTS awr_sql_text (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_text                       TEXT,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_text_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sql_text UNIQUE (dbname, dbname, dbname, sql_id, sql_id, sql_id, row_hash, row_hash, row_hash)
);

-- Table: awr_sql_user_io_time
CREATE TABLE IF NOT EXISTS awr_sql_user_io_time (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    sql_id                         TEXT,
    sql_module                     TEXT,
    executions                     NUMERIC,
    pct_total                      NUMERIC,
    pct_cpu                        NUMERIC,
    pct_io                         NUMERIC,
    elapsed_time_s                 NUMERIC,
    user_io_time_s                 NUMERIC,
    uio_per_exec_s                 NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_sql_user_io_time_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sql_user_io_time UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_tablespace_io_stats
CREATE TABLE IF NOT EXISTS awr_tablespace_io_stats (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    tablespace                     TEXT,
    reads                          NUMERIC,
    avg_read_sec                   NUMERIC,
    avg_read_ms                    NUMERIC,
    writes                         NUMERIC,
    write_avg_sec                  NUMERIC,
    write_avg_ms                   NUMERIC,
    buffer_waits                   NUMERIC,
    avg_buffer_wait_ms             NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_tablespace_io_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_tblspc_io UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_time_model_stats
CREATE TABLE IF NOT EXISTS awr_time_model_stats (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    statistic_name                 TEXT,
    time_s                         NUMERIC,
    pct_of_db_time                 NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_time_model_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_time_model UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_undo_statistics
CREATE TABLE IF NOT EXISTS awr_undo_statistics (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    num_undo_blocks                BIGINT,
    number_of_transactions         BIGINT,
    max_qry_len_s                  NUMERIC,
    max_tx_concy                   NUMERIC,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_undo_statistics_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_undo_stats UNIQUE (dbname, dbname, dbname, dbname, instance, instance, instance, instance, begin_snap, begin_snap, begin_snap, begin_snap, row_hash, row_hash, row_hash, row_hash)
);

-- Table: awr_wait_event_master
CREATE TABLE IF NOT EXISTS awr_wait_event_master (
    event                          TEXT NOT NULL,
    wait_class                     TEXT,
    corr_type                      TEXT,
    seg_filter                     TEXT,
    has_specific_rule              BOOLEAN DEFAULT false,
    guidance_text                  TEXT,
    CONSTRAINT awr_wait_event_master_pkey PRIMARY KEY (event)
);
-- Table: exec_plan_headers
CREATE TABLE IF NOT EXISTS exec_plan_headers (
    id                             SERIAL,
    sql_id                         TEXT,
    dbname                         TEXT,
    plan_hash_value                TEXT,
    plan_label                     VARCHAR(200) NOT NULL,
    plan_type                      VARCHAR(20) DEFAULT 'baseline'::character varying,
    plan_text_raw                  TEXT,
    sql_text                       TEXT,
    total_cost                     NUMERIC,
    step_count                     INTEGER,
    has_full_scan                  BOOLEAN DEFAULT false,
    has_nested_loop                BOOLEAN DEFAULT false,
    tags                           VARCHAR(500),
    notes                          TEXT,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT exec_plan_headers_pkey PRIMARY KEY (id)
);

-- Table: portal_config
CREATE TABLE IF NOT EXISTS portal_config (
    key                            VARCHAR(100) NOT NULL,
    value                          TEXT,
    description                    VARCHAR(300),
    section                        VARCHAR(50),
    updated_by                     VARCHAR(50),
    updated_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT portal_config_pkey PRIMARY KEY (key)
);

-- Table: portal_users
CREATE TABLE IF NOT EXISTS portal_users (
    id                             SERIAL,
    username                       VARCHAR(50) NOT NULL,
    password_hash                  VARCHAR(255) NOT NULL,
    role                           VARCHAR(20) DEFAULT 'viewer'::character varying NOT NULL,
    full_name                      VARCHAR(100),
    email                          VARCHAR(100),
    active                         BOOLEAN DEFAULT true,
    last_login                     TIMESTAMP WITHOUT TIME ZONE,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT portal_users_pkey PRIMARY KEY (id),
    CONSTRAINT portal_users_username_key UNIQUE (username)
);

-- Table: remote_fetch_log
CREATE TABLE IF NOT EXISTS remote_fetch_log (
    id                             SERIAL,
    source_type                    TEXT NOT NULL,
    source_id                      TEXT NOT NULL,
    filename                       TEXT NOT NULL,
    status                         TEXT NOT NULL,
    error_msg                      TEXT,
    fetched_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT remote_fetch_log_pkey PRIMARY KEY (id)
);

-- Table: sar_cpu_stats
CREATE TABLE IF NOT EXISTS sar_cpu_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    cpu                            TEXT NOT NULL,
    usr_pct                        NUMERIC,
    nice_pct                       NUMERIC,
    system_pct                     NUMERIC,
    iowait_pct                     NUMERIC,
    steal_pct                      NUMERIC,
    idle_pct                       NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_cpu_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_cpu UNIQUE (hostname, hostname, hostname, hostname, snap_time, snap_time, snap_time, snap_time, cpu, cpu, cpu, cpu, row_hash, row_hash, row_hash, row_hash)
);

-- Table: sar_ctxswitch_stats
CREATE TABLE IF NOT EXISTS sar_ctxswitch_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    proc_per_sec                   NUMERIC,
    cswch_per_sec                  NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_ctxswitch_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_ctxswitch UNIQUE (hostname, hostname, hostname, snap_time, snap_time, snap_time, row_hash, row_hash, row_hash)
);

-- Table: sar_disk_stats
CREATE TABLE IF NOT EXISTS sar_disk_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    device                         TEXT NOT NULL,
    tps                            NUMERIC,
    read_mb_per_sec                NUMERIC,
    write_mb_per_sec               NUMERIC,
    await_ms                       NUMERIC,
    svctm_ms                       NUMERIC,
    util_pct                       NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_disk_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_disk UNIQUE (hostname, hostname, hostname, hostname, snap_time, snap_time, snap_time, snap_time, device, device, device, device, row_hash, row_hash, row_hash, row_hash)
);

-- Table: sar_hugepage_stats
CREATE TABLE IF NOT EXISTS sar_hugepage_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    kbhugfree                      BIGINT,
    kbhugused                      BIGINT,
    hugused_pct                    NUMERIC,
    kbhugrsvd                      BIGINT,
    kbhugsurp                      BIGINT,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_hugepage_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_hugepage UNIQUE (hostname, hostname, hostname, snap_time, snap_time, snap_time, row_hash, row_hash, row_hash)
);

-- Table: sar_loadavg_stats
CREATE TABLE IF NOT EXISTS sar_loadavg_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    runq_sz                        NUMERIC,
    plist_sz                       NUMERIC,
    ldavg_1                        NUMERIC,
    ldavg_5                        NUMERIC,
    ldavg_15                       NUMERIC,
    blocked                        NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_loadavg_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_loadavg UNIQUE (hostname, hostname, hostname, snap_time, snap_time, snap_time, row_hash, row_hash, row_hash)
);

-- Table: sar_memory_stats
CREATE TABLE IF NOT EXISTS sar_memory_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    mem_free_mb                    NUMERIC,
    mem_used_mb                    NUMERIC,
    mem_used_pct                   NUMERIC,
    buffers_mb                     NUMERIC,
    cached_mb                      NUMERIC,
    commit_mb                      NUMERIC,
    commit_pct                     NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_memory_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_mem UNIQUE (hostname, hostname, hostname, snap_time, snap_time, snap_time, row_hash, row_hash, row_hash)
);

-- Table: sar_network_stats
CREATE TABLE IF NOT EXISTS sar_network_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    iface                          TEXT NOT NULL,
    rxpck_per_sec                  NUMERIC,
    txpck_per_sec                  NUMERIC,
    rxkb_per_sec                   NUMERIC,
    txkb_per_sec                   NUMERIC,
    rxcmp_per_sec                  NUMERIC,
    txcmp_per_sec                  NUMERIC,
    rxmcst_per_sec                 NUMERIC,
    ifutil_pct                     NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_network_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_network UNIQUE (hostname, hostname, hostname, hostname, snap_time, snap_time, snap_time, snap_time, iface, iface, iface, iface, row_hash, row_hash, row_hash, row_hash)
);

-- Table: sar_paging_stats
CREATE TABLE IF NOT EXISTS sar_paging_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    pgpgin_per_sec                 NUMERIC,
    pgpgout_per_sec                NUMERIC,
    fault_per_sec                  NUMERIC,
    majflt_per_sec                 NUMERIC,
    pgfree_per_sec                 NUMERIC,
    pgscank_per_sec                NUMERIC,
    pgscand_per_sec                NUMERIC,
    pgsteal_per_sec                NUMERIC,
    vmeff_pct                      NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_paging_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_paging UNIQUE (hostname, hostname, hostname, snap_time, snap_time, snap_time, row_hash, row_hash, row_hash)
);

-- Table: sar_socket_stats
CREATE TABLE IF NOT EXISTS sar_socket_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    totsck                         INTEGER,
    tcpsck                         INTEGER,
    udpsck                         INTEGER,
    rawsck                         INTEGER,
    ip_frag                        INTEGER,
    tcp_tw                         INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_socket_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_socket UNIQUE (hostname, hostname, hostname, snap_time, snap_time, snap_time, row_hash, row_hash, row_hash)
);

-- Table: sar_ssh_connections
CREATE TABLE IF NOT EXISTS sar_ssh_connections (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    display_name                   TEXT,
    ssh_host                       TEXT NOT NULL,
    ssh_port                       INTEGER DEFAULT 22,
    ssh_user                       TEXT NOT NULL,
    ssh_key_path                   TEXT,
    password_enc                   TEXT,
    remote_sar_path                TEXT DEFAULT '/var/log/sa'::text,
    pull_interval_hrs              NUMERIC(4,1) DEFAULT 1,
    enabled                        BOOLEAN DEFAULT true,
    last_pull_at                   TIMESTAMP WITHOUT TIME ZONE,
    last_pull_time                 TIME WITHOUT TIME ZONE,
    last_pull_date                 DATE,
    added_at                       TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    added_by                       TEXT DEFAULT 'admin'::text,
    CONSTRAINT sar_ssh_connections_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_ssh_hostname UNIQUE (hostname)
);

COMMENT ON TABLE sar_ssh_connections IS 'SSH connection config for SAR delta extraction from Linux servers. One row per server. Delta extracted via: sar -A -s HH:MM -e HH:MM -f saDD then downloaded as text — no binary pull, no WSL conversion needed.';

-- Table: sar_swap_stats
CREATE TABLE IF NOT EXISTS sar_swap_stats (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    swap_free_mb                   NUMERIC,
    swap_used_mb                   NUMERIC,
    swap_used_pct                  NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_swap_stats_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_swap UNIQUE (hostname, hostname, hostname, snap_time, snap_time, snap_time, row_hash, row_hash, row_hash)
);

-- Table: wait_event_trend
CREATE TABLE IF NOT EXISTS wait_event_trend (
    timestamp                      TIMESTAMP WITHOUT TIME ZONE,
    db_name                        TEXT,
    instance                       INTEGER,
    event                          TEXT,
    total_wait_time_s              DOUBLE PRECISION,
    db_time_pct                    DOUBLE PRECISION,
    avg_wait                       TEXT
);


-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_ai_rec_dbname ON awr_ai_recommendations USING btree (dbname, begin_snap);
CREATE INDEX IF NOT EXISTS idx_ai_rec_status ON awr_ai_recommendations USING btree (status);
CREATE INDEX IF NOT EXISTS idx_ai_rec_trigger ON awr_ai_recommendations USING btree (trigger_type, trigger_value);

CREATE INDEX IF NOT EXISTS idx_awr_anomaly_db_snap ON awr_anomalies USING btree (dbname, instance, begin_snap, severity);
CREATE INDEX IF NOT EXISTS idx_awr_anomaly_time ON awr_anomalies USING btree (snap_time DESC);

CREATE INDEX IF NOT EXISTS idx_change_log_db_time ON awr_change_log USING btree (dbname, event_time);

CREATE INDEX IF NOT EXISTS idx_db_master_db_name ON awr_db_master USING btree (db_name, active);

CREATE INDEX IF NOT EXISTS idx_exec_plan_fts ON awr_execution_plans USING gin (to_tsvector('english'::regconfig, ((COALESCE(object_name, ''::text) || ' '::text) || COALESCE(operation, ''::text))));
CREATE INDEX IF NOT EXISTS idx_exec_plan_obj ON awr_execution_plans USING btree (object_owner, object_name);
CREATE INDEX IF NOT EXISTS idx_exec_plan_snap ON awr_execution_plans USING btree (dbname, begin_snap);
CREATE INDEX IF NOT EXISTS idx_exec_plan_sql ON awr_execution_plans USING btree (dbname, sql_id);

CREATE INDEX IF NOT EXISTS idx_awrfw_pdb ON awr_foreground_wait_events USING btree (dbname, pdb_name, snap_time);

CREATE INDEX IF NOT EXISTS idx_lic_audit_time ON awr_license_audit USING btree (event_time DESC);

CREATE INDEX IF NOT EXISTS idx_obj_meta_db ON awr_object_metadata USING btree (dbname);
CREATE INDEX IF NOT EXISTS idx_obj_meta_owner ON awr_object_metadata USING btree (owner, object_name);
CREATE INDEX IF NOT EXISTS idx_obj_meta_type ON awr_object_metadata USING btree (object_type);

CREATE INDEX IF NOT EXISTS idx_oracle_conn_enabled ON awr_oracle_connections USING btree (enabled, db_name);

CREATE INDEX IF NOT EXISTS idx_failed_snaps_pending ON awr_oracle_failed_snaps USING btree (conn_id, resolved, retry_count) WHERE (resolved = false);

CREATE INDEX IF NOT EXISTS idx_awr_rec_category ON awr_recommendations USING btree (category, severity);
CREATE INDEX IF NOT EXISTS idx_awr_rec_db_snap ON awr_recommendations USING btree (dbname, begin_snap, end_snap);
CREATE INDEX IF NOT EXISTS idx_awr_rec_severity ON awr_recommendations USING btree (severity, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_repo_scan_db ON awr_repo_scan_log USING btree (db_name, status);
CREATE INDEX IF NOT EXISTS idx_repo_scan_status ON awr_repo_scan_log USING btree (status, scanned_at);

CREATE INDEX IF NOT EXISTS idx_awrseg_pdb ON awr_seg_logical_reads USING btree (dbname, pdb_name, snap_time);

CREATE INDEX IF NOT EXISTS idx_cluster ON awr_sql_cluster_wait_time USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_cpu ON awr_sql_cpu_time USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_awrsql_pdb ON awr_sql_elapsed_time USING btree (dbname, pdb_name, snap_time);
CREATE INDEX IF NOT EXISTS idx_elapsed ON awr_sql_elapsed_time USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_gets ON awr_sql_gets USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_parse ON awr_sql_parsed_calls USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_phy ON awr_sql_phy_reads_unopt USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_reads ON awr_sql_reads USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_sql_text_trgm ON awr_sql_text USING gin (sql_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS ix_sql_text_snap ON awr_sql_text USING btree (dbname, instance, begin_snap);

CREATE INDEX IF NOT EXISTS idx_uio ON awr_sql_user_io_time USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_plan_hdr_created ON exec_plan_headers USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_plan_hdr_dbname ON exec_plan_headers USING btree (dbname);
CREATE INDEX IF NOT EXISTS idx_plan_hdr_sql ON exec_plan_headers USING btree (sql_id);

CREATE INDEX IF NOT EXISTS idx_fetch_log_src ON remote_fetch_log USING btree (source_type, source_id, fetched_at DESC);

CREATE INDEX IF NOT EXISTS idx_sar_anomaly_host_time ON sar_anomalies USING btree (hostname, snap_time DESC, severity);
CREATE INDEX IF NOT EXISTS idx_sar_anomaly_severity ON sar_anomalies USING btree (severity, snap_time DESC);

CREATE INDEX IF NOT EXISTS idx_sar_cpu_host_time ON sar_cpu_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_cpu_iowait ON sar_cpu_stats USING btree (hostname, iowait_pct DESC);

CREATE INDEX IF NOT EXISTS idx_sar_ctxswitch_cswch ON sar_ctxswitch_stats USING btree (hostname, cswch_per_sec DESC);
CREATE INDEX IF NOT EXISTS idx_sar_ctxswitch_host_time ON sar_ctxswitch_stats USING btree (hostname, snap_time);

CREATE INDEX IF NOT EXISTS idx_sar_disk_host_time ON sar_disk_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_disk_util ON sar_disk_stats USING btree (hostname, util_pct DESC);

CREATE INDEX IF NOT EXISTS idx_sar_hugepage_host_time ON sar_hugepage_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_hugepage_pct ON sar_hugepage_stats USING btree (hostname, hugused_pct DESC);

CREATE INDEX IF NOT EXISTS idx_sar_loadavg_blocked ON sar_loadavg_stats USING btree (hostname, blocked DESC);
CREATE INDEX IF NOT EXISTS idx_sar_loadavg_host_time ON sar_loadavg_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_loadavg_runq ON sar_loadavg_stats USING btree (hostname, runq_sz DESC);

CREATE INDEX IF NOT EXISTS idx_sar_mem_host_time ON sar_memory_stats USING btree (hostname, snap_time);

CREATE INDEX IF NOT EXISTS idx_sar_network_host_time ON sar_network_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_network_iface ON sar_network_stats USING btree (iface);

CREATE INDEX IF NOT EXISTS idx_sar_paging_host_time ON sar_paging_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_paging_majflt ON sar_paging_stats USING btree (hostname, majflt_per_sec DESC);

CREATE INDEX IF NOT EXISTS idx_sar_socket_host_time ON sar_socket_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_socket_tcptw ON sar_socket_stats USING btree (hostname, tcp_tw DESC);

CREATE INDEX IF NOT EXISTS idx_sar_ssh_enabled ON sar_ssh_connections USING btree (enabled, hostname);

CREATE INDEX IF NOT EXISTS idx_sar_swap_host_time ON sar_swap_stats USING btree (hostname, snap_time);


-- ============================================================
-- VIEWS (9 total)
-- ============================================================

-- View: awr_seg_score_by_snap
CREATE OR REPLACE VIEW awr_seg_score_by_snap AS
 SELECT awr_segment_summary_mv.dbname,
    awr_segment_summary_mv.instance,
    awr_segment_summary_mv.begin_snap,
    lower(awr_segment_summary_mv.owner) AS owner,
    lower(awr_segment_summary_mv.object_name) AS object_name,
    awr_segment_summary_mv.obj_type,
    avg(awr_segment_summary_mv.severity_score) AS seg_score_snap
   FROM awr_segment_summary_mv
  GROUP BY awr_segment_summary_mv.dbname, awr_segment_summary_mv.instance, awr_segment_summary_mv.begin_snap, (lower(awr_segment_summary_mv.owner)), (lower(awr_segment_summary_mv.object_name)), awr_segment_summary_mv.obj_type;;

-- View: awr_sql_score_by_snap
CREATE OR REPLACE VIEW awr_sql_score_by_snap AS
 SELECT awr_sql_summary_mv.dbname,
    awr_sql_summary_mv.instance,
    awr_sql_summary_mv.begin_snap,
    lower(awr_sql_summary_mv.sql_id) AS sql_id,
    avg(awr_sql_summary_mv.severity_score) AS sql_score_snap
   FROM awr_sql_summary_mv
  GROUP BY awr_sql_summary_mv.dbname, awr_sql_summary_mv.instance, awr_sql_summary_mv.begin_snap, (lower(awr_sql_summary_mv.sql_id));;

-- ============================================================
-- MATERIALIZED VIEWS (11 total)
-- ============================================================

-- Materialized View: awr_bg_wait_event_summary_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_bg_wait_event_summary_mv AS
 SELECT e.dbname,
    e.instance,
    e.begin_snap,
    min(e.snap_time) AS snap_time,
    COALESCE(m.wait_class, 'Other'::text) AS wait_class,
    e.event,
    sum(e.waits) AS total_waits,
    sum(e.total_wait_time_s) AS total_wait_time_s,
    round(avg(e.avg_wait_ms), 2) AS avg_wait_ms,
    round(avg(e.waits_per_txn), 2) AS waits_per_txn,
    round(avg(e.pct_db_time), 2) AS pct_db_time,
        CASE
            WHEN (avg(e.pct_db_time) >= (20)::numeric) THEN 5
            WHEN (avg(e.pct_db_time) >= (10)::numeric) THEN 4
            WHEN (avg(e.pct_db_time) >= (5)::numeric) THEN 3
            WHEN (avg(e.pct_db_time) >= (2)::numeric) THEN 2
            ELSE 1
        END AS severity_score,
    row_number() OVER () AS mv_id
   FROM (awr_foreground_wait_events e
     LEFT JOIN awr_wait_event_master m ON ((btrim(lower(e.event)) = btrim(lower(m.event)))))
  WHERE (e.pct_db_time > (5)::numeric)
  GROUP BY e.dbname, e.instance, e.begin_snap, m.wait_class, e.event;
WITH DATA;

-- Materialized View: awr_bg_wait_summary_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_bg_wait_summary_mv AS
 WITH bg_waits AS (
         SELECT awr_background_wait_events.dbname,
            awr_background_wait_events.instance,
            awr_background_wait_events.begin_snap,
            min(awr_background_wait_events.snap_time) AS snap_time,
            awr_background_wait_events.event AS wait_event,
            sum(awr_background_wait_events.waits) AS total_waits,
            sum(awr_background_wait_events.total_wait_time_s) AS total_wait_time_s,
            round(avg(awr_background_wait_events.avg_wait_ms), 3) AS avg_wait_ms,
            max(awr_background_wait_events.avg_wait_ms) AS max_wait_ms,
            min(awr_background_wait_events.avg_wait_ms) AS min_wait_ms,
            round(avg(awr_background_wait_events.pct_bg_time), 2) AS avg_pct_bg_time
           FROM awr_background_wait_events
          WHERE (awr_background_wait_events.pct_bg_time > (5)::numeric)
          GROUP BY awr_background_wait_events.dbname, awr_background_wait_events.instance, awr_background_wait_events.begin_snap, awr_background_wait_events.event
        )
 SELECT b.dbname,
    b.instance,
    b.begin_snap,
    b.snap_time,
    b.wait_event,
    b.total_waits,
    b.total_wait_time_s,
    b.avg_wait_ms,
    b.max_wait_ms,
    b.min_wait_ms,
    b.avg_pct_bg_time,
    round((((COALESCE(b.avg_pct_bg_time, (0)::numeric) * 0.5) + (COALESCE(b.total_wait_time_s, (0)::numeric) * 0.3)) + (COALESCE(b.avg_wait_ms, (0)::numeric) * 0.2)), 2) AS severity_score,
    row_number() OVER () AS mv_id
   FROM bg_waits b
  WHERE (b.total_wait_time_s > (0)::numeric)
  ORDER BY (round((((COALESCE(b.avg_pct_bg_time, (0)::numeric) * 0.5) + (COALESCE(b.total_wait_time_s, (0)::numeric) * 0.3)) + (COALESCE(b.avg_wait_ms, (0)::numeric) * 0.2)), 2)) DESC;
WITH DATA;

-- Materialized View: awr_fg_wait_event_summary_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_fg_wait_event_summary_mv AS
 SELECT e.dbname,
    e.instance,
    e.begin_snap,
    min(e.snap_time) AS snap_time,
    COALESCE(m.wait_class, 'Other'::text) AS wait_class,
    e.event,
    sum(e.waits) AS total_waits,
    sum(e.total_wait_time_s) AS total_wait_time_s,
    round(avg(e.avg_wait_ms), 2) AS avg_wait_ms,
    round(avg(e.waits_per_txn), 2) AS waits_per_txn,
    round(avg(e.pct_db_time), 2) AS pct_db_time,
        CASE
            WHEN (avg(e.pct_db_time) >= (20)::numeric) THEN 5
            WHEN (avg(e.pct_db_time) >= (10)::numeric) THEN 4
            WHEN (avg(e.pct_db_time) >= (5)::numeric) THEN 3
            WHEN (avg(e.pct_db_time) >= (2)::numeric) THEN 2
            ELSE 1
        END AS severity_score,
    row_number() OVER () AS mv_id
   FROM (awr_foreground_wait_events e
     LEFT JOIN awr_wait_event_master m ON ((btrim(lower(e.event)) = btrim(lower(m.event)))))
  WHERE (e.pct_db_time > (5)::numeric)
  GROUP BY e.dbname, e.instance, e.begin_snap, m.wait_class, e.event;
WITH DATA;

-- Materialized View: awr_fg_wait_summary_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_fg_wait_summary_mv AS
 WITH fg_waits AS (
         SELECT awr_foreground_wait_events.dbname,
            awr_foreground_wait_events.instance,
            awr_foreground_wait_events.begin_snap,
            min(awr_foreground_wait_events.snap_time) AS snap_time,
            awr_foreground_wait_events.event AS wait_event,
            sum(awr_foreground_wait_events.waits) AS total_waits,
            sum(awr_foreground_wait_events.total_wait_time_s) AS total_wait_time_s,
            round(avg(awr_foreground_wait_events.avg_wait_ms), 3) AS avg_wait_ms,
            max(awr_foreground_wait_events.avg_wait_ms) AS max_wait_ms,
            min(awr_foreground_wait_events.avg_wait_ms) AS min_wait_ms,
            round(avg(awr_foreground_wait_events.pct_db_time), 2) AS avg_pct_db_time
           FROM awr_foreground_wait_events
          WHERE (awr_foreground_wait_events.pct_db_time > (5)::numeric)
          GROUP BY awr_foreground_wait_events.dbname, awr_foreground_wait_events.instance, awr_foreground_wait_events.begin_snap, awr_foreground_wait_events.event
        )
 SELECT f.dbname,
    f.instance,
    f.begin_snap,
    f.snap_time,
    f.wait_event,
    f.total_waits,
    f.total_wait_time_s,
    f.avg_wait_ms,
    f.max_wait_ms,
    f.min_wait_ms,
    f.avg_pct_db_time,
    round((((COALESCE(f.avg_pct_db_time, (0)::numeric) * 0.5) + (COALESCE(f.total_wait_time_s, (0)::numeric) * 0.3)) + (COALESCE(f.avg_wait_ms, (0)::numeric) * 0.2)), 2) AS severity_score,
    row_number() OVER () AS mv_id
   FROM fg_waits f
  WHERE (f.total_wait_time_s > (0)::numeric)
  ORDER BY (round((((COALESCE(f.avg_pct_db_time, (0)::numeric) * 0.5) + (COALESCE(f.total_wait_time_s, (0)::numeric) * 0.3)) + (COALESCE(f.avg_wait_ms, (0)::numeric) * 0.2)), 2)) DESC;
WITH DATA;

-- Materialized View: awr_seg_summary_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_seg_summary_mv AS
 WITH logical_reads AS (
         SELECT awr_seg_logical_reads.dbname,
            awr_seg_logical_reads.instance,
            awr_seg_logical_reads.begin_snap,
            min(awr_seg_logical_reads.snap_time) AS snap_time,
            awr_seg_logical_reads.owner,
            awr_seg_logical_reads.tablespace_name,
            awr_seg_logical_reads.object_name,
            awr_seg_logical_reads.subobject_name,
            awr_seg_logical_reads.obj_type,
            avg(awr_seg_logical_reads.logical_reads) AS logical_reads
           FROM awr_seg_logical_reads
          GROUP BY awr_seg_logical_reads.dbname, awr_seg_logical_reads.instance, awr_seg_logical_reads.begin_snap, awr_seg_logical_reads.owner, awr_seg_logical_reads.tablespace_name, awr_seg_logical_reads.object_name, awr_seg_logical_reads.subobject_name, awr_seg_logical_reads.obj_type
        ), physical_reads AS (
         SELECT awr_seg_phy_reads.dbname,
            awr_seg_phy_reads.instance,
            awr_seg_phy_reads.begin_snap,
            awr_seg_phy_reads.owner,
            awr_seg_phy_reads.tablespace_name,
            awr_seg_phy_reads.object_name,
            awr_seg_phy_reads.subobject_name,
            awr_seg_phy_reads.obj_type,
            avg(awr_seg_phy_reads.physical_reads) AS physical_reads
           FROM awr_seg_phy_reads
          GROUP BY awr_seg_phy_reads.dbname, awr_seg_phy_reads.instance, awr_seg_phy_reads.begin_snap, awr_seg_phy_reads.owner, awr_seg_phy_reads.tablespace_name, awr_seg_phy_reads.object_name, awr_seg_phy_reads.subobject_name, awr_seg_phy_reads.obj_type
        ), physical_writes AS (
         SELECT awr_seg_phy_writes.dbname,
            awr_seg_phy_writes.instance,
            awr_seg_phy_writes.begin_snap,
            awr_seg_phy_writes.owner,
            awr_seg_phy_writes.tablespace_name,
            awr_seg_phy_writes.object_name,
            awr_seg_phy_writes.subobject_name,
            awr_seg_phy_writes.obj_type,
            avg(awr_seg_phy_writes.physical_writes) AS physical_writes
           FROM awr_seg_phy_writes
          GROUP BY awr_seg_phy_writes.dbname, awr_seg_phy_writes.instance, awr_seg_phy_writes.begin_snap, awr_seg_phy_writes.owner, awr_seg_phy_writes.tablespace_name, awr_seg_phy_writes.object_name, awr_seg_phy_writes.subobject_name, awr_seg_phy_writes.obj_type
        ), direct_reads AS (
         SELECT awr_seg_direct_phy_reads.dbname,
            awr_seg_direct_phy_reads.instance,
            awr_seg_direct_phy_reads.begin_snap,
            awr_seg_direct_phy_reads.owner,
            awr_seg_direct_phy_reads.tablespace_name,
            awr_seg_direct_phy_reads.object_name,
            awr_seg_direct_phy_reads.subobject_name,
            awr_seg_direct_phy_reads.obj_type,
            avg(awr_seg_direct_phy_reads.direct_reads) AS direct_reads
           FROM awr_seg_direct_phy_reads
          GROUP BY awr_seg_direct_phy_reads.dbname, awr_seg_direct_phy_reads.instance, awr_seg_direct_phy_reads.begin_snap, awr_seg_direct_phy_reads.owner, awr_seg_direct_phy_reads.tablespace_name, awr_seg_direct_phy_reads.object_name, awr_seg_direct_phy_reads.subobject_name, awr_seg_direct_phy_reads.obj_type
        ), direct_writes AS (
         SELECT awr_seg_direct_phy_writes.dbname,
            awr_seg_direct_phy_writes.instance,
            awr_seg_direct_phy_writes.begin_snap,
            awr_seg_direct_phy_writes.owner,
            awr_seg_direct_phy_writes.tablespace_name,
            awr_seg_direct_phy_writes.object_name,
            awr_seg_direct_phy_writes.subobject_name,
            awr_seg_direct_phy_writes.obj_type,
            avg(awr_seg_direct_phy_writes.direct_writes) AS direct_writes
           FROM awr_seg_direct_phy_writes
          GROUP BY awr_seg_direct_phy_writes.dbname, awr_seg_direct_phy_writes.instance, awr_seg_direct_phy_writes.begin_snap, awr_seg_direct_phy_writes.owner, awr_seg_direct_phy_writes.tablespace_name, awr_seg_direct_phy_writes.object_name, awr_seg_direct_phy_writes.subobject_name, awr_seg_direct_phy_writes.obj_type
        ), phys_read_requests AS (
         SELECT awr_seg_phy_read_req.dbname,
            awr_seg_phy_read_req.instance,
            awr_seg_phy_read_req.begin_snap,
            awr_seg_phy_read_req.owner,
            awr_seg_phy_read_req.tablespace_name,
            awr_seg_phy_read_req.object_name,
            awr_seg_phy_read_req.subobject_name,
            awr_seg_phy_read_req.obj_type,
            avg(awr_seg_phy_read_req.phys_read_requests) AS phys_read_requests
           FROM awr_seg_phy_read_req
          GROUP BY awr_seg_phy_read_req.dbname, awr_seg_phy_read_req.instance, awr_seg_phy_read_req.begin_snap, awr_seg_phy_read_req.owner, awr_seg_phy_read_req.tablespace_name, awr_seg_phy_read_req.object_name, awr_seg_phy_read_req.subobject_name, awr_seg_phy_read_req.obj_type
        ), phys_write_requests AS (
         SELECT awr_seg_phy_write_req.dbname,
            awr_seg_phy_write_req.instance,
            awr_seg_phy_write_req.begin_snap,
            awr_seg_phy_write_req.owner,
            awr_seg_phy_write_req.tablespace_name,
            awr_seg_phy_write_req.object_name,
            awr_seg_phy_write_req.subobject_name,
            awr_seg_phy_write_req.obj_type,
            avg(awr_seg_phy_write_req.phys_write_requests) AS phys_write_requests
           FROM awr_seg_phy_write_req
          GROUP BY awr_seg_phy_write_req.dbname, awr_seg_phy_write_req.instance, awr_seg_phy_write_req.begin_snap, awr_seg_phy_write_req.owner, awr_seg_phy_write_req.tablespace_name, awr_seg_phy_write_req.object_name, awr_seg_phy_write_req.subobject_name, awr_seg_phy_write_req.obj_type
        ), cr_blocks AS (
         SELECT awr_seg_cr_blk_rec.dbname,
            awr_seg_cr_blk_rec.instance,
            awr_seg_cr_blk_rec.begin_snap,
            awr_seg_cr_blk_rec.owner,
            awr_seg_cr_blk_rec.tablespace_name,
            awr_seg_cr_blk_rec.object_name,
            awr_seg_cr_blk_rec.subobject_name,
            awr_seg_cr_blk_rec.obj_type,
            avg(awr_seg_cr_blk_rec.cr_blocks_received) AS cr_blocks_received
           FROM awr_seg_cr_blk_rec
          GROUP BY awr_seg_cr_blk_rec.dbname, awr_seg_cr_blk_rec.instance, awr_seg_cr_blk_rec.begin_snap, awr_seg_cr_blk_rec.owner, awr_seg_cr_blk_rec.tablespace_name, awr_seg_cr_blk_rec.object_name, awr_seg_cr_blk_rec.subobject_name, awr_seg_cr_blk_rec.obj_type
        ), current_blocks AS (
         SELECT awr_seg_cur_blk_rec.dbname,
            awr_seg_cur_blk_rec.instance,
            awr_seg_cur_blk_rec.begin_snap,
            awr_seg_cur_blk_rec.owner,
            awr_seg_cur_blk_rec.tablespace_name,
            awr_seg_cur_blk_rec.object_name,
            awr_seg_cur_blk_rec.subobject_name,
            awr_seg_cur_blk_rec.obj_type,
            avg(awr_seg_cur_blk_rec.current_blocks_received) AS current_blocks_received
           FROM awr_seg_cur_blk_rec
          GROUP BY awr_seg_cur_blk_rec.dbname, awr_seg_cur_blk_rec.instance, awr_seg_cur_blk_rec.begin_snap, awr_seg_cur_blk_rec.owner, awr_seg_cur_blk_rec.tablespace_name, awr_seg_cur_blk_rec.object_name, awr_seg_cur_blk_rec.subobject_name, awr_seg_cur_blk_rec.obj_type
        ), unopt_reads AS (
         SELECT awr_seg_unopt_reads.dbname,
            awr_seg_unopt_reads.instance,
            awr_seg_unopt_reads.begin_snap,
            awr_seg_unopt_reads.owner,
            awr_seg_unopt_reads.tablespace_name,
            awr_seg_unopt_reads.object_name,
            awr_seg_unopt_reads.subobject_name,
            awr_seg_unopt_reads.obj_type,
            avg(awr_seg_unopt_reads.unoptimized_reads) AS unoptimized_reads
           FROM awr_seg_unopt_reads
          GROUP BY awr_seg_unopt_reads.dbname, awr_seg_unopt_reads.instance, awr_seg_unopt_reads.begin_snap, awr_seg_unopt_reads.owner, awr_seg_unopt_reads.tablespace_name, awr_seg_unopt_reads.object_name, awr_seg_unopt_reads.subobject_name, awr_seg_unopt_reads.obj_type
        ), table_scans AS (
         SELECT awr_seg_table_scan.dbname,
            awr_seg_table_scan.instance,
            awr_seg_table_scan.begin_snap,
            awr_seg_table_scan.owner,
            awr_seg_table_scan.tablespace_name,
            awr_seg_table_scan.object_name,
            awr_seg_table_scan.subobject_name,
            awr_seg_table_scan.obj_type,
            avg(awr_seg_table_scan.table_scans) AS table_scans
           FROM awr_seg_table_scan
          GROUP BY awr_seg_table_scan.dbname, awr_seg_table_scan.instance, awr_seg_table_scan.begin_snap, awr_seg_table_scan.owner, awr_seg_table_scan.tablespace_name, awr_seg_table_scan.object_name, awr_seg_table_scan.subobject_name, awr_seg_table_scan.obj_type
        ), db_blk_chg AS (
         SELECT awr_seg_db_blk_chg.dbname,
            awr_seg_db_blk_chg.instance,
            awr_seg_db_blk_chg.begin_snap,
            awr_seg_db_blk_chg.owner,
            awr_seg_db_blk_chg.tablespace_name,
            awr_seg_db_blk_chg.object_name,
            awr_seg_db_blk_chg.subobject_name,
            awr_seg_db_blk_chg.obj_type,
            avg(awr_seg_db_blk_chg.db_block_changes) AS db_block_changes
           FROM awr_seg_db_blk_chg
          GROUP BY awr_seg_db_blk_chg.dbname, awr_seg_db_blk_chg.instance, awr_seg_db_blk_chg.begin_snap, awr_seg_db_blk_chg.owner, awr_seg_db_blk_chg.tablespace_name, awr_seg_db_blk_chg.object_name, awr_seg_db_blk_chg.subobject_name, awr_seg_db_blk_chg.obj_type
        ), row_lck AS (
         SELECT awr_seg_row_lck_waits.dbname,
            awr_seg_row_lck_waits.instance,
            awr_seg_row_lck_waits.begin_snap,
            awr_seg_row_lck_waits.owner,
            awr_seg_row_lck_waits.tablespace_name,
            awr_seg_row_lck_waits.object_name,
            awr_seg_row_lck_waits.subobject_name,
            awr_seg_row_lck_waits.obj_type,
            avg(awr_seg_row_lck_waits.row_lock_waits) AS row_lock_waits
           FROM awr_seg_row_lck_waits
          GROUP BY awr_seg_row_lck_waits.dbname, awr_seg_row_lck_waits.instance, awr_seg_row_lck_waits.begin_snap, awr_seg_row_lck_waits.owner, awr_seg_row_lck_waits.tablespace_name, awr_seg_row_lck_waits.object_name, awr_seg_row_lck_waits.subobject_name, awr_seg_row_lck_waits.obj_type
        ), itl AS (
         SELECT awr_seg_itl_waits.dbname,
            awr_seg_itl_waits.instance,
            awr_seg_itl_waits.begin_snap,
            awr_seg_itl_waits.owner,
            awr_seg_itl_waits.tablespace_name,
            awr_seg_itl_waits.object_name,
            awr_seg_itl_waits.subobject_name,
            awr_seg_itl_waits.obj_type,
            avg(awr_seg_itl_waits.itl_waits) AS itl_waits
           FROM awr_seg_itl_waits
          GROUP BY awr_seg_itl_waits.dbname, awr_seg_itl_waits.instance, awr_seg_itl_waits.begin_snap, awr_seg_itl_waits.owner, awr_seg_itl_waits.tablespace_name, awr_seg_itl_waits.object_name, awr_seg_itl_waits.subobject_name, awr_seg_itl_waits.obj_type
        ), buff_busy AS (
         SELECT awr_seg_buff_busy_waits.dbname,
            awr_seg_buff_busy_waits.instance,
            awr_seg_buff_busy_waits.begin_snap,
            awr_seg_buff_busy_waits.owner,
            awr_seg_buff_busy_waits.tablespace_name,
            awr_seg_buff_busy_waits.object_name,
            awr_seg_buff_busy_waits.subobject_name,
            awr_seg_buff_busy_waits.obj_type,
            avg(awr_seg_buff_busy_waits.buffer_busy_waits) AS buffer_busy_waits
           FROM awr_seg_buff_busy_waits
          GROUP BY awr_seg_buff_busy_waits.dbname, awr_seg_buff_busy_waits.instance, awr_seg_buff_busy_waits.begin_snap, awr_seg_buff_busy_waits.owner, awr_seg_buff_busy_waits.tablespace_name, awr_seg_buff_busy_waits.object_name, awr_seg_buff_busy_waits.subobject_name, awr_seg_buff_busy_waits.obj_type
        ), gc_busy AS (
         SELECT awr_seg_gbl_cache_buff_busy.dbname,
            awr_seg_gbl_cache_buff_busy.instance,
            awr_seg_gbl_cache_buff_busy.begin_snap,
            awr_seg_gbl_cache_buff_busy.owner,
            awr_seg_gbl_cache_buff_busy.tablespace_name,
            awr_seg_gbl_cache_buff_busy.object_name,
            awr_seg_gbl_cache_buff_busy.subobject_name,
            awr_seg_gbl_cache_buff_busy.obj_type,
            avg(awr_seg_gbl_cache_buff_busy.gc_buffer_busy) AS gc_buffer_busy
           FROM awr_seg_gbl_cache_buff_busy
          GROUP BY awr_seg_gbl_cache_buff_busy.dbname, awr_seg_gbl_cache_buff_busy.instance, awr_seg_gbl_cache_buff_busy.begin_snap, awr_seg_gbl_cache_buff_busy.owner, awr_seg_gbl_cache_buff_busy.tablespace_name, awr_seg_gbl_cache_buff_busy.object_name, awr_seg_gbl_cache_buff_busy.subobject_name, awr_seg_gbl_cache_buff_busy.obj_type
        )
 SELECT l.dbname,
    l.instance,
    l.begin_snap,
    l.snap_time,
    l.owner,
    l.tablespace_name,
    l.object_name,
    l.subobject_name,
    l.obj_type,
    l.logical_reads,
    pr.physical_reads,
    pw.physical_writes,
    dr.direct_reads,
    dw.direct_writes,
    rreq.phys_read_requests,
    wreq.phys_write_requests,
    cr.cr_blocks_received,
    cur.current_blocks_received,
    u.unoptimized_reads,
    ts.table_scans,
    bc.db_block_changes,
    rl.row_lock_waits,
    i.itl_waits,
    bb.buffer_busy_waits,
    g.gc_buffer_busy,
    ((((((((((((((((COALESCE(l.logical_reads, (0)::numeric) + (COALESCE(pr.physical_reads, (0)::numeric) * (2)::numeric)) + (COALESCE(pw.physical_writes, (0)::numeric) * (2)::numeric)) + (COALESCE(dr.direct_reads, (0)::numeric) * (2)::numeric)) + (COALESCE(dw.direct_writes, (0)::numeric) * (2)::numeric)) + COALESCE(rreq.phys_read_requests, (0)::numeric)) + COALESCE(wreq.phys_write_requests, (0)::numeric)) + COALESCE(cr.cr_blocks_received, (0)::numeric)) + COALESCE(cur.current_blocks_received, (0)::numeric)) + COALESCE(u.unoptimized_reads, (0)::numeric)) + COALESCE(ts.table_scans, (0)::numeric)) + COALESCE(bc.db_block_changes, (0)::numeric)) + COALESCE(rl.row_lock_waits, (0)::numeric)) + COALESCE(i.itl_waits, (0)::numeric)) + COALESCE(bb.buffer_busy_waits, (0)::numeric)) + COALESCE(g.gc_buffer_busy, (0)::numeric)))::numeric(18,4) AS severity_score,
    row_number() OVER () AS mv_id
   FROM (((((((((((((((logical_reads l
     LEFT JOIN physical_reads pr ON (((pr.dbname = l.dbname) AND (pr.instance = l.instance) AND (pr.begin_snap = l.begin_snap) AND (pr.object_name = l.object_name))))
     LEFT JOIN physical_writes pw ON (((pw.dbname = l.dbname) AND (pw.instance = l.instance) AND (pw.begin_snap = l.begin_snap) AND (pw.object_name = l.object_name))))
     LEFT JOIN direct_reads dr ON (((dr.dbname = l.dbname) AND (dr.instance = l.instance) AND (dr.begin_snap = l.begin_snap) AND (dr.object_name = l.object_name))))
     LEFT JOIN direct_writes dw ON (((dw.dbname = l.dbname) AND (dw.instance = l.instance) AND (dw.begin_snap = l.begin_snap) AND (dw.object_name = l.object_name))))
     LEFT JOIN phys_read_requests rreq ON (((rreq.dbname = l.dbname) AND (rreq.instance = l.instance) AND (rreq.begin_snap = l.begin_snap) AND (rreq.object_name = l.object_name))))
     LEFT JOIN phys_write_requests wreq ON (((wreq.dbname = l.dbname) AND (wreq.instance = l.instance) AND (wreq.begin_snap = l.begin_snap) AND (wreq.object_name = l.object_name))))
     LEFT JOIN cr_blocks cr ON (((cr.dbname = l.dbname) AND (cr.instance = l.instance) AND (cr.begin_snap = l.begin_snap) AND (cr.object_name = l.object_name))))
     LEFT JOIN current_blocks cur ON (((cur.dbname = l.dbname) AND (cur.instance = l.instance) AND (cur.begin_snap = l.begin_snap) AND (cur.object_name = l.object_name))))
     LEFT JOIN unopt_reads u ON (((u.dbname = l.dbname) AND (u.instance = l.instance) AND (u.begin_snap = l.begin_snap) AND (u.object_name = l.object_name))))
     LEFT JOIN table_scans ts ON (((ts.dbname = l.dbname) AND (ts.instance = l.instance) AND (ts.begin_snap = l.begin_snap) AND (ts.object_name = l.object_name))))
     LEFT JOIN db_blk_chg bc ON (((bc.dbname = l.dbname) AND (bc.instance = l.instance) AND (bc.begin_snap = l.begin_snap) AND (bc.object_name = l.object_name))))
     LEFT JOIN row_lck rl ON (((rl.dbname = l.dbname) AND (rl.instance = l.instance) AND (rl.begin_snap = l.begin_snap) AND (rl.object_name = rl.object_name))))
     LEFT JOIN itl i ON (((i.dbname = l.dbname) AND (i.instance = l.instance) AND (i.begin_snap = l.begin_snap) AND (i.object_name = i.object_name))))
     LEFT JOIN buff_busy bb ON (((bb.dbname = l.dbname) AND (bb.instance = l.instance) AND (bb.begin_snap = l.begin_snap) AND (bb.object_name = bb.object_name))))
     LEFT JOIN gc_busy g ON (((g.dbname = l.dbname) AND (g.instance = l.instance) AND (g.begin_snap = l.begin_snap) AND (g.object_name = g.object_name))));
WITH DATA;

-- Materialized View: awr_segment_summary_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_segment_summary_mv AS
 WITH logical_reads AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            min(t.snap_time) AS snap_time,
            t.tablespace_name,
            t.obj_type,
            t.owner,
            t.object_name,
            t.subobject_name,
            sum(t.logical_reads) AS logical_reads
           FROM awr_seg_logical_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.tablespace_name, t.obj_type, t.owner, t.object_name, t.subobject_name
        ), physical_reads AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.physical_reads) AS physical_reads
           FROM awr_seg_phy_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), physical_writes AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.physical_writes) AS physical_writes
           FROM awr_seg_phy_writes t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), direct_reads AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.direct_reads) AS direct_reads
           FROM awr_seg_direct_phy_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), direct_writes AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.direct_writes) AS direct_writes
           FROM awr_seg_direct_phy_writes t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), read_req AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.phys_read_requests) AS phys_read_requests
           FROM awr_seg_phy_read_req t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), write_req AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.phys_write_requests) AS phys_write_requests
           FROM awr_seg_phy_write_req t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), cr_blocks AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.cr_blocks_received) AS cr_blocks_received
           FROM awr_seg_cr_blk_rec t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), cur_blocks AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.current_blocks_received) AS current_blocks_received
           FROM awr_seg_cur_blk_rec t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), unopt_reads AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.unoptimized_reads) AS unoptimized_reads
           FROM awr_seg_unopt_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), opt_reads AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.optimized_reads) AS optimized_reads
           FROM awr_seg_opt_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), table_scans AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.table_scans) AS table_scans
           FROM awr_seg_table_scan t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), db_block_changes AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.db_block_changes) AS db_block_changes
           FROM awr_seg_db_blk_chg t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), row_lock AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.row_lock_waits) AS row_lock_waits
           FROM awr_seg_row_lck_waits t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), itl AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.itl_waits) AS itl_waits
           FROM awr_seg_itl_waits t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), buff_busy AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.buffer_busy_waits) AS buffer_busy_waits
           FROM awr_seg_buff_busy_waits t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        ), gc_busy AS (
         SELECT t.dbname,
            t.instance,
            t.begin_snap,
            t.owner,
            t.object_name,
            t.subobject_name,
            t.obj_type,
            sum(t.gc_buffer_busy) AS gc_buffer_busy
           FROM awr_seg_gbl_cache_buff_busy t
          GROUP BY t.dbname, t.instance, t.begin_snap, t.owner, t.object_name, t.subobject_name, t.obj_type
        )
 SELECT l.dbname,
    l.instance,
    l.begin_snap,
    l.snap_time,
    l.tablespace_name,
    l.owner,
    l.obj_type,
    l.object_name,
    l.subobject_name,
    l.logical_reads,
    pr.physical_reads,
    pw.physical_writes,
    dr.direct_reads,
    dw.direct_writes,
    rr.phys_read_requests,
    wr.phys_write_requests,
    cb.cr_blocks_received,
    cur.current_blocks_received,
    un.unoptimized_reads,
    opt.optimized_reads,
    ts.table_scans,
    dbc.db_block_changes,
    rl.row_lock_waits,
    it.itl_waits,
    bb.buffer_busy_waits,
    gc.gc_buffer_busy,
    ((((((((((((((COALESCE(pr.physical_reads, (0)::numeric) * 0.15) + ((COALESCE(dr.direct_reads, (0)::numeric) + COALESCE(dw.direct_writes, (0)::numeric)) * 0.10)) + (COALESCE(l.logical_reads, (0)::numeric) * 0.10)) + ((COALESCE(cb.cr_blocks_received, (0)::numeric) + COALESCE(cur.current_blocks_received, (0)::numeric)) * 0.10)) + (COALESCE(ts.table_scans, (0)::numeric) * 0.05)) + (COALESCE(un.unoptimized_reads, (0)::numeric) * 0.05)) + ((COALESCE(rr.phys_read_requests, (0)::numeric) + COALESCE(wr.phys_write_requests, (0)::numeric)) * 0.03)) + (COALESCE(opt.optimized_reads, (0)::numeric) * 0.02)) + (COALESCE(dbc.db_block_changes, (0)::numeric) * 0.10)) + (COALESCE(rl.row_lock_waits, (0)::numeric) * 0.10)) + (COALESCE(it.itl_waits, (0)::numeric) * 0.05)) + (COALESCE(bb.buffer_busy_waits, (0)::numeric) * 0.10)) + (COALESCE(gc.gc_buffer_busy, (0)::numeric) * 0.05)))::numeric(18,4) AS severity_score,
    row_number() OVER () AS mv_id
   FROM ((((((((((((((((logical_reads l
     LEFT JOIN physical_reads pr ON (((pr.dbname = l.dbname) AND (pr.instance = l.instance) AND (pr.begin_snap = l.begin_snap) AND (pr.owner = l.owner) AND (pr.object_name = l.object_name) AND (NOT (pr.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN physical_writes pw ON (((pw.dbname = l.dbname) AND (pw.instance = l.instance) AND (pw.begin_snap = l.begin_snap) AND (pw.owner = l.owner) AND (pw.object_name = l.object_name) AND (NOT (pw.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN direct_reads dr ON (((dr.dbname = l.dbname) AND (dr.instance = l.instance) AND (dr.begin_snap = l.begin_snap) AND (dr.owner = l.owner) AND (dr.object_name = l.object_name) AND (NOT (dr.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN direct_writes dw ON (((dw.dbname = l.dbname) AND (dw.instance = l.instance) AND (dw.begin_snap = l.begin_snap) AND (dw.owner = l.owner) AND (dw.object_name = l.object_name) AND (NOT (dw.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN read_req rr ON (((rr.dbname = l.dbname) AND (rr.instance = l.instance) AND (rr.begin_snap = l.begin_snap) AND (rr.owner = l.owner) AND (rr.object_name = l.object_name) AND (NOT (rr.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN write_req wr ON (((wr.dbname = l.dbname) AND (wr.instance = l.instance) AND (wr.begin_snap = l.begin_snap) AND (wr.owner = l.owner) AND (wr.object_name = l.object_name) AND (NOT (wr.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN cr_blocks cb ON (((cb.dbname = l.dbname) AND (cb.instance = l.instance) AND (cb.begin_snap = l.begin_snap) AND (cb.owner = l.owner) AND (cb.object_name = l.object_name) AND (NOT (cb.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN cur_blocks cur ON (((cur.dbname = l.dbname) AND (cur.instance = l.instance) AND (cur.begin_snap = l.begin_snap) AND (cur.owner = l.owner) AND (cur.object_name = l.object_name) AND (NOT (cur.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN unopt_reads un ON (((un.dbname = l.dbname) AND (un.instance = l.instance) AND (un.begin_snap = l.begin_snap) AND (un.owner = l.owner) AND (un.object_name = l.object_name) AND (NOT (un.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN opt_reads opt ON (((opt.dbname = l.dbname) AND (opt.instance = l.instance) AND (opt.begin_snap = l.begin_snap) AND (opt.owner = l.owner) AND (opt.object_name = l.object_name) AND (NOT (opt.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN table_scans ts ON (((ts.dbname = l.dbname) AND (ts.instance = l.instance) AND (ts.begin_snap = l.begin_snap) AND (ts.owner = l.owner) AND (ts.object_name = l.object_name) AND (NOT (ts.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN db_block_changes dbc ON (((dbc.dbname = l.dbname) AND (dbc.instance = l.instance) AND (dbc.begin_snap = l.begin_snap) AND (dbc.owner = l.owner) AND (dbc.object_name = l.object_name) AND (NOT (dbc.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN row_lock rl ON (((rl.dbname = l.dbname) AND (rl.instance = l.instance) AND (rl.begin_snap = l.begin_snap) AND (rl.owner = l.owner) AND (rl.object_name = l.object_name) AND (NOT (rl.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN itl it ON (((it.dbname = l.dbname) AND (it.instance = l.instance) AND (it.begin_snap = l.begin_snap) AND (it.owner = l.owner) AND (it.object_name = l.object_name) AND (NOT (it.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN buff_busy bb ON (((bb.dbname = l.dbname) AND (bb.instance = l.instance) AND (bb.begin_snap = l.begin_snap) AND (bb.owner = l.owner) AND (bb.object_name = l.object_name) AND (NOT (bb.subobject_name IS DISTINCT FROM l.subobject_name)))))
     LEFT JOIN gc_busy gc ON (((gc.dbname = l.dbname) AND (gc.instance = l.instance) AND (gc.begin_snap = l.begin_snap) AND (gc.owner = l.owner) AND (gc.object_name = l.object_name) AND (NOT (gc.subobject_name IS DISTINCT FROM l.subobject_name)))));
WITH DATA;

-- Materialized View: awr_sql_object_map_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_sql_object_map_mv AS
 WITH t AS (
         SELECT awr_sql_text_norm.sql_id,
            awr_sql_text_norm.sql_text_clean
           FROM awr_sql_text_norm
        ), dml AS (
         SELECT t.sql_id,
            m.m[1] AS owner,
            m.m[2] AS object
           FROM t,
            LATERAL regexp_matches(t.sql_text_clean, '(?:insert\s+into|update|delete\s+from|merge\s+into)\s+"?([a-z0-9_#$]+)"?\."?([a-z0-9_#$]+)"?'::text, 'gi'::text) m(m)
        UNION ALL
         SELECT t.sql_id,
            NULL::text AS owner,
            m.m[1] AS object
           FROM t,
            LATERAL regexp_matches(t.sql_text_clean, '(?:insert\s+into|update|delete\s+from|merge\s+into)\s+"?([a-z0-9_#$]+)"?'::text, 'gi'::text) m(m)
        ), from_join AS (
         SELECT t.sql_id,
            m.m[1] AS owner,
            m.m[2] AS object
           FROM t,
            LATERAL regexp_matches(t.sql_text_clean, '(?:from|join)\s+"?([a-z0-9_#$]+)"?\."?([a-z0-9_#$]+)"?'::text, 'gi'::text) m(m)
        UNION ALL
         SELECT t.sql_id,
            NULL::text AS owner,
            m.m[1] AS object
           FROM t,
            LATERAL regexp_matches(t.sql_text_clean, '(?:from|join)\s+"?([a-z0-9_#$]+)"?'::text, 'gi'::text) m(m)
        )
 SELECT DISTINCT lower(u.sql_id) AS sql_id,
    lower(COALESCE(u.owner, ''::text)) AS owner,
    lower(u.object) AS object,
    ((u.owner IS NOT NULL) AND (u.owner <> ''::text)) AS has_owner,
    row_number() OVER () AS mv_id
   FROM ( SELECT dml.sql_id,
            dml.owner,
            dml.object
           FROM dml
        UNION ALL
         SELECT from_join.sql_id,
            from_join.owner,
            from_join.object
           FROM from_join) u
  WHERE ((u.object IS NOT NULL) AND (u.object <> ''::text));
WITH DATA;

-- Materialized View: awr_sql_summary_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_sql_summary_mv AS
 WITH elapsed AS (
         SELECT awr_sql_elapsed_time.dbname,
            awr_sql_elapsed_time.instance,
            awr_sql_elapsed_time.begin_snap,
            min(awr_sql_elapsed_time.snap_time) AS snap_time,
            awr_sql_elapsed_time.sql_id,
            sum(awr_sql_elapsed_time.executions) AS executions,
            avg(awr_sql_elapsed_time.elapsed_time_per_exec_s) AS elapsed_time_per_exec_s,
            avg(awr_sql_elapsed_time.pct_cpu) AS pct_cpu,
            avg(awr_sql_elapsed_time.pct_io) AS pct_io
           FROM awr_sql_elapsed_time
          GROUP BY awr_sql_elapsed_time.dbname, awr_sql_elapsed_time.instance, awr_sql_elapsed_time.begin_snap, awr_sql_elapsed_time.sql_id
        ), cpu AS (
         SELECT awr_sql_cpu_time.dbname,
            awr_sql_cpu_time.instance,
            awr_sql_cpu_time.begin_snap,
            awr_sql_cpu_time.sql_id,
            avg(awr_sql_cpu_time.cpu_per_exec_s) AS cpu_per_exec_s
           FROM awr_sql_cpu_time
          GROUP BY awr_sql_cpu_time.dbname, awr_sql_cpu_time.instance, awr_sql_cpu_time.begin_snap, awr_sql_cpu_time.sql_id
        ), uio AS (
         SELECT awr_sql_user_io_time.dbname,
            awr_sql_user_io_time.instance,
            awr_sql_user_io_time.begin_snap,
            awr_sql_user_io_time.sql_id,
            avg(awr_sql_user_io_time.uio_per_exec_s) AS user_io_wait_per_exec_s
           FROM awr_sql_user_io_time
          GROUP BY awr_sql_user_io_time.dbname, awr_sql_user_io_time.instance, awr_sql_user_io_time.begin_snap, awr_sql_user_io_time.sql_id
        ), gets AS (
         SELECT awr_sql_gets.dbname,
            awr_sql_gets.instance,
            awr_sql_gets.begin_snap,
            awr_sql_gets.sql_id,
            avg(awr_sql_gets.gets_per_exec) AS buffer_gets_per_exec
           FROM awr_sql_gets
          GROUP BY awr_sql_gets.dbname, awr_sql_gets.instance, awr_sql_gets.begin_snap, awr_sql_gets.sql_id
        ), reads AS (
         SELECT awr_sql_reads.dbname,
            awr_sql_reads.instance,
            awr_sql_reads.begin_snap,
            awr_sql_reads.sql_id,
            avg(awr_sql_reads.reads_per_exec) AS disk_reads_per_exec
           FROM awr_sql_reads
          GROUP BY awr_sql_reads.dbname, awr_sql_reads.instance, awr_sql_reads.begin_snap, awr_sql_reads.sql_id
        ), unopt AS (
         SELECT awr_sql_phy_reads_unopt.dbname,
            awr_sql_phy_reads_unopt.instance,
            awr_sql_phy_reads_unopt.begin_snap,
            awr_sql_phy_reads_unopt.sql_id,
            avg(awr_sql_phy_reads_unopt.unoptimized_reqs_per_exec) AS unoptimized_reqs_per_exec,
            avg(awr_sql_phy_reads_unopt.pctopt) AS pct_opt
           FROM awr_sql_phy_reads_unopt
          GROUP BY awr_sql_phy_reads_unopt.dbname, awr_sql_phy_reads_unopt.instance, awr_sql_phy_reads_unopt.begin_snap, awr_sql_phy_reads_unopt.sql_id
        ), execs AS (
         SELECT awr_sql_executions.dbname,
            awr_sql_executions.instance,
            awr_sql_executions.begin_snap,
            awr_sql_executions.sql_id,
            sum(awr_sql_executions.executions) AS total_executions
           FROM awr_sql_executions
          GROUP BY awr_sql_executions.dbname, awr_sql_executions.instance, awr_sql_executions.begin_snap, awr_sql_executions.sql_id
        ), parses AS (
         SELECT awr_sql_parsed_calls.dbname,
            awr_sql_parsed_calls.instance,
            awr_sql_parsed_calls.begin_snap,
            awr_sql_parsed_calls.sql_id,
            sum(awr_sql_parsed_calls.parse_calls) AS parse_calls,
            avg(awr_sql_parsed_calls.pct_total_parses) AS pct_total_parses
           FROM awr_sql_parsed_calls
          GROUP BY awr_sql_parsed_calls.dbname, awr_sql_parsed_calls.instance, awr_sql_parsed_calls.begin_snap, awr_sql_parsed_calls.sql_id
        ), clu AS (
         SELECT awr_sql_cluster_wait_time.dbname,
            awr_sql_cluster_wait_time.instance,
            awr_sql_cluster_wait_time.begin_snap,
            awr_sql_cluster_wait_time.sql_id,
            avg(awr_sql_cluster_wait_time.cluster_wait_time_s) AS cluster_wait_time_per_exec_s,
            avg(awr_sql_cluster_wait_time.pct_clu) AS pct_clu
           FROM awr_sql_cluster_wait_time
          GROUP BY awr_sql_cluster_wait_time.dbname, awr_sql_cluster_wait_time.instance, awr_sql_cluster_wait_time.begin_snap, awr_sql_cluster_wait_time.sql_id
        )
 SELECT e.dbname,
    e.instance,
    e.begin_snap,
    e.snap_time,
    e.sql_id,
    e.executions,
    e.elapsed_time_per_exec_s,
    c.cpu_per_exec_s,
    u.user_io_wait_per_exec_s,
    g.buffer_gets_per_exec,
    r.disk_reads_per_exec,
    un.unoptimized_reqs_per_exec,
    un.pct_opt,
    ex.total_executions,
    p.parse_calls,
    p.pct_total_parses,
    cl.cluster_wait_time_per_exec_s,
    cl.pct_clu,
    (((((((((COALESCE(e.elapsed_time_per_exec_s, (0)::numeric) * 0.25) + (COALESCE(c.cpu_per_exec_s, (0)::numeric) * 0.25)) + ((COALESCE(g.buffer_gets_per_exec, (0)::numeric) / 10000.0) * 0.15)) + ((COALESCE(r.disk_reads_per_exec, (0)::numeric) / 1000.0) * 0.10)) + (COALESCE(u.user_io_wait_per_exec_s, (0)::numeric) * 0.10)) + ((COALESCE(un.unoptimized_reqs_per_exec, (0)::numeric) / 1000.0) * 0.05)) + ((COALESCE(p.parse_calls, (0)::numeric) / 1000.0) * 0.05)) + (COALESCE(cl.cluster_wait_time_per_exec_s, (0)::numeric) * 0.05)))::numeric(18,4) AS severity_score,
    row_number() OVER () AS mv_id
   FROM ((((((((elapsed e
     LEFT JOIN cpu c ON (((c.dbname = e.dbname) AND (c.instance = e.instance) AND (c.begin_snap = e.begin_snap) AND (c.sql_id = e.sql_id))))
     LEFT JOIN uio u ON (((u.dbname = e.dbname) AND (u.instance = e.instance) AND (u.begin_snap = e.begin_snap) AND (u.sql_id = e.sql_id))))
     LEFT JOIN gets g ON (((g.dbname = e.dbname) AND (g.instance = e.instance) AND (g.begin_snap = e.begin_snap) AND (g.sql_id = e.sql_id))))
     LEFT JOIN reads r ON (((r.dbname = e.dbname) AND (r.instance = e.instance) AND (r.begin_snap = e.begin_snap) AND (r.sql_id = e.sql_id))))
     LEFT JOIN unopt un ON (((un.dbname = e.dbname) AND (un.instance = e.instance) AND (un.begin_snap = e.begin_snap) AND (un.sql_id = e.sql_id))))
     LEFT JOIN execs ex ON (((ex.dbname = e.dbname) AND (ex.instance = e.instance) AND (ex.begin_snap = e.begin_snap) AND (ex.sql_id = e.sql_id))))
     LEFT JOIN parses p ON (((p.dbname = e.dbname) AND (p.instance = e.instance) AND (p.begin_snap = e.begin_snap) AND (p.sql_id = e.sql_id))))
     LEFT JOIN clu cl ON (((cl.dbname = e.dbname) AND (cl.instance = e.instance) AND (cl.begin_snap = e.begin_snap) AND (cl.sql_id = e.sql_id))));
WITH DATA;

-- Materialized View: awr_sql_text_norm
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_sql_text_norm AS
 WITH src AS (
         SELECT DISTINCT lower(awr_sql_text.sql_id) AS sql_id,
            awr_sql_text.sql_text
           FROM awr_sql_text
        ), norm AS (
         SELECT src.sql_id,
            regexp_replace(regexp_replace(regexp_replace(lower(src.sql_text), '''([^'']|'''')*'''::text, ' '::text, 'g'::text), '--.*?(\n|$)'::text, ' '::text, 'g'::text), '/\*.*?\*/'::text, ' '::text, 'gs'::text) AS t
           FROM src
        )
 SELECT norm.sql_id,
    regexp_replace(norm.t, '\s+'::text, ' '::text, 'g'::text) AS sql_text_clean
   FROM norm;
WITH DATA;

-- Materialized View: awr_sql_text_norm_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_sql_text_norm_mv AS
 WITH src AS (
         SELECT DISTINCT lower(awr_sql_text.sql_id) AS sql_id,
            awr_sql_text.sql_text
           FROM awr_sql_text
        ), norm AS (
         SELECT src.sql_id,
            regexp_replace(regexp_replace(regexp_replace(lower(src.sql_text), '''([^'']|'''')*'''::text, ' '::text, 'g'::text), '--.*?(\n|$)'::text, ' '::text, 'g'::text), '/\*.*?\*/'::text, ' '::text, 'gs'::text) AS t
           FROM src
        )
 SELECT norm.sql_id,
    regexp_replace(norm.t, '\s+'::text, ' '::text, 'g'::text) AS sql_text_clean,
    row_number() OVER () AS mv_id
   FROM norm;
WITH DATA;

-- Materialized View: awr_wait_summary_mv
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_wait_summary_mv AS
 WITH fg AS (
         SELECT e.dbname,
            e.instance,
            e.begin_snap,
            min(e.snap_time) AS snap_time,
            COALESCE(m.wait_class, 'Other'::text) AS wait_class,
            e.event,
            sum(e.waits) AS waits,
            sum(e.total_wait_time_s) AS total_wait_time_s,
            round(avg(e.avg_wait_ms), 2) AS avg_wait_ms,
            round(avg(e.waits_per_txn), 2) AS waits_per_txn,
            round(avg(e.pct_db_time), 2) AS pct_time,
            'Foreground'::text AS wait_scope
           FROM (awr_foreground_wait_events e
             LEFT JOIN awr_wait_event_master m ON ((btrim(lower(e.event)) = btrim(lower(m.event)))))
          WHERE (e.pct_db_time > (5)::numeric)
          GROUP BY e.dbname, e.instance, e.begin_snap, m.wait_class, e.event
        ), bg AS (
         SELECT e.dbname,
            e.instance,
            e.begin_snap,
            min(e.snap_time) AS snap_time,
            COALESCE(m.wait_class, 'Other'::text) AS wait_class,
            e.event,
            sum(e.waits) AS waits,
            sum(e.total_wait_time_s) AS total_wait_time_s,
            round(avg(e.avg_wait_ms), 2) AS avg_wait_ms,
            round(avg(e.waits_per_txn), 2) AS waits_per_txn,
            round(avg(e.pct_bg_time), 2) AS pct_time,
            'Background'::text AS wait_scope
           FROM (awr_background_wait_events e
             LEFT JOIN awr_wait_event_master m ON ((btrim(lower(e.event)) = btrim(lower(m.event)))))
          WHERE (e.pct_bg_time > (5)::numeric)
          GROUP BY e.dbname, e.instance, e.begin_snap, m.wait_class, e.event
        )
 SELECT combined.dbname,
    combined.instance,
    combined.begin_snap,
    combined.snap_time,
    combined.wait_scope,
    combined.wait_class,
    combined.event,
    combined.waits,
    combined.total_wait_time_s,
    combined.avg_wait_ms,
    combined.waits_per_txn,
    combined.pct_time,
    round((((COALESCE(combined.pct_time, (0)::numeric) * 0.7) + ((COALESCE(combined.total_wait_time_s, (0)::numeric) / 100.0) * 0.2)) + ((COALESCE(combined.avg_wait_ms, (0)::numeric) / 10.0) * 0.1)), 2) AS severity_score,
    row_number() OVER () AS mv_id
   FROM ( SELECT fg.dbname,
            fg.instance,
            fg.begin_snap,
            fg.snap_time,
            fg.wait_class,
            fg.event,
            fg.waits,
            fg.total_wait_time_s,
            fg.avg_wait_ms,
            fg.waits_per_txn,
            fg.pct_time,
            fg.wait_scope
           FROM fg
        UNION ALL
         SELECT bg.dbname,
            bg.instance,
            bg.begin_snap,
            bg.snap_time,
            bg.wait_class,
            bg.event,
            bg.waits,
            bg.total_wait_time_s,
            bg.avg_wait_ms,
            bg.waits_per_txn,
            bg.pct_time,
            bg.wait_scope
           FROM bg) combined
  ORDER BY (round((((COALESCE(combined.pct_time, (0)::numeric) * 0.7) + ((COALESCE(combined.total_wait_time_s, (0)::numeric) / 100.0) * 0.2)) + ((COALESCE(combined.avg_wait_ms, (0)::numeric) / 10.0) * 0.1)), 2)) DESC;
WITH DATA;


-- ============================================================
-- MATERIALIZED VIEW INDEXES
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_bg_wait_event_summary_mv_id ON awr_bg_wait_event_summary_mv USING btree (mv_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_bg_wait_summary_mv_id ON awr_bg_wait_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_bg_wait_summary_dbinstsnap ON awr_bg_wait_summary_mv USING btree (dbname, instance, begin_snap);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_fg_wait_event_summary_mv_id ON awr_fg_wait_event_summary_mv USING btree (mv_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_fg_wait_summary_mv_id ON awr_fg_wait_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_fg_wait_summary_dbinstsnap ON awr_fg_wait_summary_mv USING btree (dbname, instance, begin_snap);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_seg_summary_mv_id ON awr_seg_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_seg_summary_dbinstsnap ON awr_seg_summary_mv USING btree (dbname, instance, begin_snap);
CREATE INDEX IF NOT EXISTS idx_seg_summary_score ON awr_seg_summary_mv USING btree (severity_score DESC);

CREATE INDEX IF NOT EXISTS idx_seg_summary_mv_dbname_snap ON awr_segment_summary_mv USING btree (dbname, instance, begin_snap);
CREATE INDEX IF NOT EXISTS idx_seg_summary_mv_owner_object ON awr_segment_summary_mv USING btree (dbname, owner, object_name);
CREATE INDEX IF NOT EXISTS idx_seg_summary_mv_severity ON awr_segment_summary_mv USING btree (dbname, instance, begin_snap, severity_score DESC);
CREATE INDEX IF NOT EXISTS ix_seg_mv_snap ON awr_segment_summary_mv USING btree (dbname, instance, begin_snap);
CREATE UNIQUE INDEX IF NOT EXISTS uq_seg_mv_id ON awr_segment_summary_mv USING btree (mv_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_sql_object_map_mv_id ON awr_sql_object_map_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_awr_sql_object_map_obj ON awr_sql_object_map_mv USING btree (object);
CREATE INDEX IF NOT EXISTS idx_awr_sql_object_map_sql ON awr_sql_object_map_mv USING btree (sql_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_sql_summary_mv_id ON awr_sql_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS ix_sql_summary_snap ON awr_sql_summary_mv USING btree (dbname, instance, begin_snap);

CREATE INDEX IF NOT EXISTS idx_awr_sql_text_norm_id ON awr_sql_text_norm USING btree (sql_id);
CREATE INDEX IF NOT EXISTS idx_awr_sql_text_norm_mv_sql_id ON awr_sql_text_norm USING btree (sql_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_sql_text_norm_mv_id ON awr_sql_text_norm_mv USING btree (mv_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_wait_summary_mv_id ON awr_wait_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_wait_summary_dbinstsnap ON awr_wait_summary_mv USING btree (dbname, instance, begin_snap, wait_scope, wait_class);
CREATE INDEX IF NOT EXISTS ix_wait_mv_snap ON awr_wait_summary_mv USING btree (dbname, instance, begin_snap);


-- ============================================================
-- REFRESH MATERIALIZED VIEWS
-- ============================================================

-- Run after initial data load:
-- REFRESH MATERIALIZED VIEW awr_bg_wait_event_summary_mv;
-- REFRESH MATERIALIZED VIEW awr_bg_wait_summary_mv;
-- REFRESH MATERIALIZED VIEW awr_fg_wait_event_summary_mv;
-- REFRESH MATERIALIZED VIEW awr_fg_wait_summary_mv;
-- REFRESH MATERIALIZED VIEW awr_seg_summary_mv;
-- REFRESH MATERIALIZED VIEW awr_segment_summary_mv;
-- REFRESH MATERIALIZED VIEW awr_sql_object_map_mv;
-- REFRESH MATERIALIZED VIEW awr_sql_summary_mv;
-- REFRESH MATERIALIZED VIEW awr_sql_text_norm;
-- REFRESH MATERIALIZED VIEW awr_sql_text_norm_mv;
-- REFRESH MATERIALIZED VIEW awr_wait_summary_mv;



-- ============================================================
-- ADDITIONAL TABLE: sar_anomalies
-- ============================================================
-- This table is created by anomaly_detector.py at runtime
-- but is included here for clean fresh installation.
-- Stores SAR OS-level anomaly detection results.
-- ============================================================

CREATE TABLE IF NOT EXISTS sar_anomalies (
    id              SERIAL PRIMARY KEY,
    hostname        TEXT        NOT NULL,
    snap_time       TIMESTAMP   NOT NULL,
    metric_source   TEXT        NOT NULL,  -- CPU | Memory | Disk | Network | Paging
    metric_name     TEXT        NOT NULL,  -- e.g. %iowait, kbmemused, %util
    object_name     TEXT,                  -- device/iface name for Disk/Network metrics
    metric_value    NUMERIC,               -- observed value
    baseline_mean   NUMERIC,               -- rolling baseline average
    baseline_stddev NUMERIC,               -- rolling baseline standard deviation
    z_score         NUMERIC,               -- deviation from baseline in std deviations
    severity        TEXT,                  -- Critical | Alert | Warning
    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_sar_anomaly
        UNIQUE (hostname, snap_time, metric_source, metric_name, object_name)
) TABLESPACE awrparser;

-- Index: fast lookup by host + time for dashboard queries
CREATE INDEX IF NOT EXISTS idx_sar_anomaly_host_time
    ON sar_anomalies (hostname, snap_time DESC, severity);

-- Index: severity filter for alerting
CREATE INDEX IF NOT EXISTS idx_sar_anomaly_severity
    ON sar_anomalies (severity, snap_time DESC);


\echo '  Database objects: done'


-- ============================================================
-- SECTION 5: SEED DATA — portal_config + portal_users
-- ============================================================

\echo 'Step 4/6: Seeding portal_config (default configuration)...'

INSERT INTO portal_config (key, value, section, updated_by, updated_at) VALUES
-- ── AI / Recommendation Engine ─────────────────────────────
-- ai_mode: rules = built-in 61-rule engine (default, no API needed)
--          local = send context to local LLM (Ollama) at ai_local_url
--          cloud = send context to Anthropic Claude API
('ai_mode',              'rules',                  'ai',        'install', NOW()),
('ai_local_url',         'http://localhost:11434',  'ai',        'install', NOW()),
('ai_local_model',       'llama3',                 'ai',        'install', NOW()),
('ai_cloud_provider',    'anthropic',              'ai',        'install', NOW()),
('ai_cloud_api_key',     '',                       'ai',        'install', NOW()),
('ai_cloud_model',       'claude-sonnet-4-6',      'ai',        'install', NOW()),
-- Monthly API call limit for cloud AI (prevents runaway costs)
('ai_monthly_limit',     '1000',                   'ai',        'install', NOW()),

-- ── Anomaly Detection ──────────────────────────────────────
-- z_threshold: number of standard deviations from baseline to flag as anomaly
--   2.0 = Alert (5% probability), 3.0 = Critical (0.3% probability)
('anomaly_z_threshold',  '2.0',                    'anomaly',   'install', NOW()),
-- baseline_days: number of days of history used to calculate mean/stddev
('anomaly_baseline_days','30',                     'anomaly',   'install', NOW()),
-- min_samples: minimum data points required before anomaly detection fires
('anomaly_min_samples',  '5',                      'anomaly',   'install', NOW()),

-- ── AWR Source ────────────────────────────────────────────
-- awr_source_type: local  = watch local awr_reports\ folder
--                  direct_db = auto-generate via Oracle connection (oracledb)
('awr_source_type',      'local',                  'awr_source','install', NOW()),
('awr_local_path',       'awr_reports',            'awr_source','install', NOW()),
('awr_network_path',     '',                       'awr_source','install', NOW()),
('awr_db_host',          '',                       'awr_source','install', NOW()),
('awr_db_port',          '1521',                   'awr_source','install', NOW()),
('awr_db_service',       '',                       'awr_source','install', NOW()),
('awr_db_user',          '',                       'awr_source','install', NOW()),
('awr_db_password',      '',                       'awr_source','install', NOW()),

-- ── SAR Source ────────────────────────────────────────────
-- sar_source_type: local = watch local sar_drop\ folder
--                  ssh   = delta pull from Linux servers via SSH
('sar_source_type',      'local',                  'sar_source','install', NOW()),
-- sar_tz_offset: timezone for binary SAR file conversion (WSL sadf)
('sar_tz_offset',        'Asia/Kolkata',           'sar_source','install', NOW()),
('sar_local_path',       'sar_drop',               'sar_source','install', NOW()),

-- ── License ────────────────────────────────────────────────
-- Enter license key and customer details via Settings → License
('license_key',          '',                       'license',   'install', NOW()),
('license_customer',     '',                       'license',   'install', NOW()),
('license_db_count',     '0',                      'license',   'install', NOW()),
('license_sar_count',    '0',                      'license',   'install', NOW()),
('license_expiry',       '',                       'license',   'install', NOW()),
('license_mac_override', '',                       'license',   'install', NOW()),

-- ── Access Control ─────────────────────────────────────────
-- Update portal_url and grafana_url to your server hostname/IP
-- after installation: Settings → Access Control
('portal_login_required','false',                  'access',    'install', NOW()),
('portal_url',           'http://localhost:8000',  'access',    'install', NOW()),
('grafana_url',          'http://localhost:3000',  'access',    'install', NOW()),
-- session_timeout_mins: portal session duration (480 = 8 hours)
('session_timeout_mins', '480',                    'access',    'install', NOW()),
-- admin_reset_pin: PIN used on the Forgot Password page
('admin_reset_pin',      '1234',                   'access',    'install', NOW()),
-- metadata_refresh_days: days before object metadata is considered stale
('metadata_refresh_days','30',                     'access',    'install', NOW())

ON CONFLICT (key) DO NOTHING;

\echo '  portal_config: done (33 keys)'


-- ── Default admin user ─────────────────────────────────────────────────
-- Username : admin
-- Password : Admin@123  (bcrypt cost 12)
-- IMPORTANT: Change this password immediately after first login
--   Settings → Users → Change Password
\echo 'Step 5/6: Seeding portal_users (admin / Admin@123)...'

INSERT INTO portal_users
    (username, full_name, password_hash, role, is_active, created_at, updated_at)
VALUES
    ('admin',
     'Administrator',
     '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TiGniMDPbFMnb9h1TCcB8V2/.SvS',
     'admin',
     TRUE,
     NOW(),
     NOW())
ON CONFLICT (username) DO NOTHING;

\echo '  portal_users: done'


-- ============================================================
-- SECTION 6: ORACLE WAIT EVENT CLASSIFICATIONS
-- 60 events across all Oracle wait classes with correlation
-- metadata for the AWR Intelligence dashboard
-- ============================================================

\echo 'Step 6/6: Seeding awr_wait_event_master (60 Oracle wait events)...'

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file sequential read','User I/O','io_read','index_only',true,
'Single-block I/O — index leaf/branch reads or ROWID table access after an index lookup. Root cause: deep B-tree (high BLEVEL), poor clustering factor, or buffer cache miss on hot index blocks. (1) Check BLEVEL of hot indexes — rebuild if BLEVEL > 4. (2) Check clustering_factor vs num_rows — if ratio > 0.5, consider reorganising the table. (3) Increase DB_CACHE_SIZE or assign hot indexes to the KEEP buffer pool.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('direct path read','User I/O','io_read','table_only',true,
'Multi-block read bypassing buffer cache — full table scan, parallel query, or large LOB read. Root cause: missing partition pruning, missing selective index, or intentional analytics scan. (1) Check for missing indexes on high-selectivity filter columns. (2) For analytics: validate partition pruning is active and parallel degree is appropriate. (3) For LOB reads: consider SecureFile LOB with CACHE option.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file scattered read','User I/O','io_read','table_only',true,
'Multi-block scattered read — full table or fast full index scan in non-parallel context. Root cause: missing indexes or large range scans. (1) Identify the full-scan SQL in Top SQL dashboard. (2) Set DB_FILE_MULTIBLOCK_READ_COUNT appropriately (128 for SSD). (3) Consider parallel query to shift reads to direct path for large analytics.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell smart table scan','User I/O','io_read','table_only',false,
'Exadata smart scan of a table — full segment scan offloaded to storage cell. Root cause: missing partition pruning or large analytics scan. (1) Enable storage index via partition pruning. (2) Check cell offload eligibility. (3) Review predicate pushdown to storage cells.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell smart index scan','User I/O','io_read','index_only',false,
'Exadata smart scan of an index — index read offloaded to storage cell. Root cause: deep B-tree or large index range scan. (1) Check BLEVEL of hot indexes. (2) Ensure cell offload is enabled for index scans. (3) Review index selectivity.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell single block physical read','User I/O','io_read','index_only',false,
'Exadata single-block physical read — equivalent to db file sequential read on Exadata. Root cause: index block read or ROWID lookup. (1) Check BLEVEL and clustering factor of hot indexes. (2) Review buffer cache hit ratio. (3) Assign hot indexes to the KEEP buffer pool.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell single block read request','User I/O','io_read','index_only',false,
'Exadata single-block read request — index or ROWID read submitted to storage cell. Root cause same as db file sequential read. (1) Check hot indexes for high BLEVEL. (2) Review buffer cache sizing. (3) Check storage cell response times.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell multiblock physical read','User I/O','io_read','table_only',false,
'Exadata multiblock physical read — full table or LOB scan on storage cells. (1) Review partition pruning on scanned tables. (2) Validate storage cell offload efficiency. (3) Check if parallel query is appropriate for the scan pattern.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell multiblock read request','User I/O','io_read','table_only',false,
'Exadata multiblock read request — storage cell multiblock read for table/LOB scans. (1) Review partition pruning. (2) Check cell offload eligibility. (3) Validate parallel degree for large scans.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell list of blocks physical read','User I/O','io_read','all',false,
'Exadata list-of-blocks physical read — targeted block read from storage cells. Can involve any segment type. (1) Identify the SQL driving this read pattern. (2) Review execution plan for the targeted segment. (3) Check storage cell performance.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell list of blocks read request','User I/O','io_read','all',false,
'Exadata list-of-blocks read request — targeted block list read submitted to cells. Can involve any segment type. (1) Identify the SQL driving this. (2) Review execution plan. (3) Check storage cell response times.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file parallel read','User I/O','io_read','all',false,
'Parallel block read — used during parallel recovery or parallel prefetch. All segment types may be involved. (1) If during normal operations: check for parallel query prefetch activity. (2) If during recovery: normal and expected. (3) Review storage I/O throughput on SAR dashboard.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('local write wait','User I/O','io_write','all',false,
'Session waiting for a local write to complete — typically a dirty buffer being written before it can be reused. Root cause: slow storage or DBWn contention. (1) Check data file storage latency on SAR dashboard. (2) Review DB_WRITER_PROCESSES. (3) Enable async I/O.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file single write','User I/O','io_write','all',false,
'Single-block write — file header update or single block flush. Root cause: slow storage on file header device or checkpoint activity. (1) Check file header I/O latency. (2) Review checkpoint frequency. (3) Verify all datafile paths have adequate I/O performance.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('securefile direct-read completion','User I/O','io_read','table_only',false,
'SecureFile LOB direct read completion — reading LOB data outside the buffer cache. Root cause: LOB NOCACHE or large LOB access frequency. (1) Convert to SecureFile LOBs with CACHE option. (2) Consider LOB compression for large objects. (3) Review whether LOB data should be externalised for very large files.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('securefile direct-write completion','User I/O','io_write','table_only',false,
'SecureFile LOB direct write completion — writing LOB data directly to storage. Root cause: high-frequency LOB writes. (1) Review LOB write frequency in application. (2) Consider SecureFile with compression. (3) Ensure LOB tablespace is on fast storage.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('read by other session','User I/O','buffer_busy','all',true,
'Session waiting for another session to finish loading a block from disk. Root cause: buffer cache too small causing repeated cold reads of hot blocks. (1) Increase DB_CACHE_SIZE to retain hot blocks. (2) Assign critical lookup tables to KEEP buffer pool. (3) Reduce full scans that evict hot blocks from cache.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('buffer read retry','User I/O','buffer_busy','all',false,
'Block read retry — block being read was found to be invalid or in flux, requiring a retry. Root cause: hot block being concurrently modified. (1) Check for buffer busy waits on the same segments. (2) Increase INITRANS on hot tables/indexes. (3) Review concurrent DML patterns on hot objects.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('direct path write','User I/O','io_write','all',true,
'Direct path write — bulk load (CTAS, INSERT APPEND) bypassing buffer cache, or sort/hash spill to temp. (1) Check PGA usage — increase PGA_AGGREGATE_TARGET to reduce sort/hash spills. (2) For bulk loads: ensure NOLOGGING is used where applicable. (3) Validate temp tablespace I/O throughput on SAR dashboard.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('direct path read temp','User I/O','none','none',false,
'Temp tablespace read — sort/hash workarea spilling to temp. No user segment involved. (1) Increase PGA_AGGREGATE_TARGET. (2) Identify spilling SQL via V$SQL_WORKAREA_ACTIVE. (3) Ensure temp tablespace is on fast SSD storage.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('direct path write temp','User I/O','none','none',false,
'Temp tablespace write — sort/hash workarea spilling to temp. No user segment involved. (1) Increase PGA_AGGREGATE_TARGET. (2) Review execution plans for large sort/hash joins. (3) Add sort-elimination indexes where ORDER BY is frequent.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e, (SELECT wait_class FROM awr_wait_event_master WHERE lower(event)=lower(e) LIMIT 1),
            'none','none',false,
            'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file parallel write','System I/O','io_write','all',true,
'DBWR writing dirty buffers to datafiles. Root cause: data file device latency, insufficient DBWn processes, or checkpoint storms. (1) Check data file storage latency on SAR I/O dashboard. (2) Increase DB_WRITER_PROCESSES. (3) Enable async I/O (FILESYSTEMIO_OPTIONS=SETALL or use ASM).')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('DBWR slave I/O','System I/O','io_write','all',false,
'DBWR slave process writing dirty buffers — same root cause as db file parallel write. (1) Check data file storage latency on SAR I/O dashboard. (2) Increase DB_WRITER_PROCESSES if this slave is bottlenecked. (3) Enable async I/O.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('control file sequential read','System I/O','none','none',true,
'Control file read by background process (ARCn, RMAN, CKPT). No user segment involved. (1) Ensure all control file copies are on fast storage. (2) Reduce log switch frequency by increasing redo log file size. (3) Review RMAN backup schedule — frequent backups update the control file repeatedly.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('control file parallel write','System I/O','none','none',true,
'Control file write by background process (log switches, checkpoints, RMAN). No user segment involved. (1) Ensure all control file copies are on fast storage (avoid NFS-mounted paths). (2) Reduce log switch frequency. (3) Review RMAN backup frequency during peak hours.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('control file single write','System I/O','none','none',false,
'Control file single-block write — usually a file header or checkpoint record update. No user segment involved. (1) Ensure control file copies are on fast storage. (2) This is typically low-frequency and benign unless it dominates wait time. (3) Correlate with log switch frequency if elevated.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('log file parallel write','System I/O','none','none',true,
'LGWR writing redo to redo log files — redo storage latency. No segment involved. (1) Move redo logs to dedicated SSD. (2) Enable write-back cache on the redo log storage device. (3) Verify redo log multiplexing does not include slow members.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'System I/O','none','none',false,
            'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.')
    ON CONFLICT (event) DO UPDATE SET
      corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,
      has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('log file sync','Commit','none','none',true,
'Session waiting for LGWR to flush redo on commit. No segment involved — this is redo I/O latency. (1) Move redo logs to dedicated fast storage (SSDs). (2) Batch application commits to reduce flush frequency. (3) Increase LOG_BUFFER to 256MB–1GB.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Commit','none','none',false,
            'Commit/redo synchronisation wait — no user segment involved. Root cause: redo I/O latency or distributed transaction coordination overhead. (1) Check redo log storage latency on SAR dashboard. (2) Review distributed transaction (dblink) commit frequency. (3) Batch commits where possible to reduce LGWR flush overhead.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('free buffer waits','Configuration','buffer_busy','all',true,
'Server process cannot find a free buffer — DBWn not writing dirty buffers fast enough. (1) Check data file I/O latency on SAR dashboard. (2) Increase DB_WRITER_PROCESSES. (3) Increase DB_CACHE_SIZE if memory allows.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('write complete waits','Configuration','buffer_busy','all',false,
'Session waiting for a buffer write to complete before it can be modified. Root cause: slow storage causing write-side buffer contention. (1) Check data file storage latency. (2) Review DB_WRITER_PROCESSES count. (3) Enable async I/O if not already enabled.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('write complete waits: flash cache','Configuration','buffer_busy','all',false,
'Session waiting for a flash cache write to complete. Root cause: flash cache device latency or saturation. (1) Check flash cache device health and performance. (2) Review flash cache sizing (DB_FLASH_CACHE_SIZE). (3) Consider disabling flash cache if device is consistently bottlenecked.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('enq: TX - allocate ITL entry','Configuration','buffer_busy','all',false,
'Insufficient ITL (Interested Transaction List) entries in a block — concurrent transactions cannot fit their ITL entries. (1) Increase INITRANS on the hot table or index. (2) Increase PCTFREE to leave more space for ITL expansion. (3) Review concurrent DML patterns on the affected object.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('undo segment extension','Configuration','none','none',false,
'Undo segment needing to extend — undo tablespace space or extent allocation delay. No user data segment involved. (1) Increase undo tablespace size. (2) Increase UNDO_RETENTION to reduce premature undo reuse. (3) Enable RETENTION GUARANTEE on the undo tablespace.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('undo segment tx slot','Configuration','none','none',false,
'No free transaction slot available in the undo segment header. Root cause: undo segment too small or too many concurrent transactions. (1) Ensure UNDO_MANAGEMENT=AUTO and undo tablespace is adequately sized. (2) Increase number of undo segments (or ensure auto-undo is not constrained). (3) Review concurrent transaction count.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,(SELECT wait_class FROM awr_wait_event_master WHERE lower(event)=lower(e) LIMIT 1),
            'none','none',
            (e IN ('log buffer space','log file switch (checkpoint incomplete)','log file switch (archiving needed)')),
            msgs[i])
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Configuration','none','none',false,
            'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('buffer busy waits','Concurrency','buffer_busy','all',true,
'Multiple sessions competing for the same buffer block. Root cause: hot segment blocks — frequently updated index leaf blocks or hot table rows. (1) Increase INITRANS on hot tables/indexes. (2) For index leaf contention: consider reverse-key index or hash partitioning. (3) For sequence inserts: use sequence cache to reduce monotonic clustering.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('enq: TX - index contention','Concurrency','buffer_busy','index_only',false,
'Index block split contention — a session is waiting for another to complete an index block split. Root cause: right-side index block splits on monotonically increasing keys (sequences, timestamps). (1) Consider reverse-key index for sequence-generated keys. (2) Use hash partitioning to distribute inserts. (3) Increase index INITRANS to reduce split frequency.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Concurrency','buffer_busy','table_only',false,
            'In-Memory buffer contention — concurrent access to an In-Memory Column Store (IMCS) buffer for a table. Root cause: high concurrent read/write on an In-Memory populated table. (1) Review IMCS population status and compression. (2) Check for concurrent DML invalidating IMCS buffers. (3) Review INMEMORY_MAX_POPULATE_SERVERS setting.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('latch: cache buffers chains','Concurrency','none','none',true,
'Hot block contention at the latch level — a buffer block is accessed by so many concurrent sessions that the latch serialises access. (1) Identify the hot block using X$BH (addr, obj, tch columns). (2) For sequence inserts: enable sequence caching, consider reverse-key index. (3) Hash partition the hot segment to spread block access.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('latch: shared pool','Concurrency','none','none',true,
'Shared pool latch contention — heavy parse activity or fragmentation. (1) Enforce bind variable usage across all application SQL. (2) Increase SHARED_POOL_SIZE. (3) Pin critical packages with DBMS_SHARED_POOL.KEEP.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('latch: row cache objects','Concurrency','none','none',true,
'Data dictionary (row cache) latch contention. (1) Avoid DDL during peak hours. (2) Increase SHARED_POOL_SIZE. (3) Reduce metadata-intensive operations.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cursor: pin S wait on X','Concurrency','none','none',true,
'Cursor pin contention — a session holds an exclusive cursor pin while others wait for shared. (1) Enforce bind variable usage to reduce hard parse rate. (2) Avoid DDL on hot objects during peak. (3) Review CURSOR_INVALIDATION parameter (12.2+).')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('library cache lock','Concurrency','none','none',true,
'Library cache object lock contention — DDL on a hot object or procedure recompilation. (1) Avoid DDL on hot procedures/packages during peak hours. (2) Check DBA_OBJECTS for INVALID objects auto-recompiling. (3) Review dependency chains — compilations cascade to dependents.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('library cache load lock','Concurrency','none','none',true,
'Library cache load contention — multiple sessions loading the same object simultaneously. (1) Pin critical packages with DBMS_SHARED_POOL.KEEP. (2) Pre-warm library cache after startup. (3) Reduce invalidation frequency.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('library cache: mutex X','Concurrency','none','none',true,
'Library cache mutex contention — high parse rate. (1) Enforce bind variable usage. (2) Review CURSOR_SHARING parameter. (3) Tune SESSION_CACHED_CURSORS and OPEN_CURSORS.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Concurrency','none','none',false,
            'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('enq: TX - row lock contention','Application','row_lock','all',true,
'Row-level lock contention — sessions blocking each other on the same rows. (1) Identify blocking sessions from AWR Active Session History. (2) Ensure frequent commits in high-DML batch processes. (3) Review INITRANS on hot tables — increase to allow more concurrent row-level modifications.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('enq: TM - contention','Application','row_lock','all',true,
'Table-level lock contention — most commonly caused by DML on a parent table with an unindexed foreign key on the child. (1) Identify unindexed FK columns: query DBA_CONSTRAINTS joined to DBA_IND_COLUMNS. (2) Create indexes on all FK columns in child tables. (3) Avoid concurrent DDL on high-DML tables.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('Wait for Table Lock','Application','row_lock','table_only',false,
'Waiting for a table-level lock held by another session. Root cause: DDL-DML contention or explicit LOCK TABLE statement. (1) Identify the blocking session and its lock type from V$LOCK and V$SESSION. (2) Avoid DDL (ALTER, DROP, TRUNCATE) on tables with concurrent DML during peak hours. (3) Review application for unnecessary LOCK TABLE statements.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Application','none','none',false,
            'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('gc buffer busy acquire','Cluster','gc_cluster','all',true,
'RAC global cache block contention — hot blocks being transferred between instances. (1) Configure service affinity to route related transactions to the same instance. (2) Partition hot tables and pin partitions to specific instances. (3) Review interconnect bandwidth on SAR network dashboard.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('gc buffer busy release','Cluster','gc_cluster','all',true,
'RAC global cache block release wait. (1) Configure service affinity. (2) Review interconnect latency — target < 1ms. (3) Check for unindexed FK columns causing cross-instance TM lock shipping.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('gc cr request','Cluster','gc_cluster','all',true,
'RAC consistent-read block transfer — instance requesting a CR copy from another instance. (1) Configure read workload affinity per service. (2) Increase buffer cache size to reduce cross-instance reads. (3) Verify interconnect latency < 1ms on SAR dashboard.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('gc current request','Cluster','gc_cluster','all',true,
'RAC current block transfer — requesting writable copy from another instance. (1) Route DML transactions to a single primary instance via services. (2) Hash partition high-DML tables with partition-wise service routing. (3) Check for unindexed FK columns.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Cluster','gc_cluster','all',false,
            'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Cluster','none','none',false,
            'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('SQL*Net message from client','Idle','none','none',true,
'Idle wait — session waiting for the next request from the client. Not a database bottleneck. (1) If this dominates DB time, focus on the non-idle waits. (2) Review connection pool min/max sizing. (3) Implement idle session timeout to release unused connections.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('SQL*Net more data to client','Network','none','none',true,
'Large resultset transfer to client — network or fetch bottleneck. (1) Implement result pagination (ROWNUM/ROW_NUMBER). (2) Avoid SELECT * on wide tables. (3) Increase SDU for batch/reporting connections.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('SQL*Net message from dblink','Network','none','none',false,
'Session waiting for a response from a remote database over a database link. No local segment involved. (1) Check network latency between local and remote DB. (2) Review the query using the dblink — avoid fetching large result sets row-by-row. (3) Consider materialising frequently-accessed remote data locally.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,(SELECT wait_class FROM awr_wait_event_master WHERE lower(event)=lower(e) LIMIT 1),
            'none','none',false,
            'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('resmgr:cpu quantum','Scheduler','none','none',true,
'Sessions throttled by Oracle Resource Manager — CPU quantum exhausted. (1) Review Resource Manager plan and consumer group CPU allocations. (2) Identify which sessions/users are being throttled. (3) Increase CPU allocation for critical consumer groups or adjust SWITCH_TIME thresholds.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Scheduler','none','none',false,
            'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Administrative','none','none',false,
            'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Queueing','none','none',false,
            'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('latch free','Other','none','none',true,
'Generic latch wait — a session is waiting for an unspecified latch. (1) Identify the specific latch from AWR Latch Activity section. (2) Correlate with other concurrent wait events for the primary driver. (3) Use the specific latch rule in the Recommendations panel if available.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('reliable message','Other','none','none',true,
'Background inter-process messaging wait. (1) Investigate only if this dominates alongside other symptoms. (2) Correlate with specific background process (AQ, XStream, Replication). (3) Check alert log for related background process errors.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('rdbms ipc reply','Other','none','none',true,
'Foreground session waiting for a background process to complete an operation. (1) Identify the background process from ASH (PROGRAM column). (2) If SMON: check for heavy coalescing or undo management. (3) If ARCn: check archivelog I/O and destination space.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('DFS lock handle','Other','none','none',true,
'RAC global lock manager (DLM) contention. (1) Identify the specific resource from ASH (P1/P2 values). (2) Review object partitioning and service affinity to reduce DLM contention. (3) Check GCS/GES background process activity and interconnect latency.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('PX Deq Credit: send blkd','Idle','none','none',true,
'PX producer slave blocked — consumer slaves cannot process rows fast enough. (1) Identify the bottleneck operation in the parallel plan. (2) Review join methods — hash joins consume faster than nested loops. (3) Reduce DOP if consumer is overloaded.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('PX Deq: Execute Reply','Idle','none','none',true,
'Parallel query coordinator waiting for slave replies. (1) Check for data distribution imbalance across partitions. (2) Review PARALLEL_MAX_SERVERS and available PX server pool. (3) Consider reducing degree of parallelism if server pool is saturated.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;


\echo '  awr_wait_event_master: done (60 events)'


-- ============================================================
-- GRANT OBJECT PERMISSIONS TO SCHEMA OWNER
-- ============================================================
-- Grant all table/sequence/view permissions to awr_owner
-- so the portal service can connect as awr_owner if desired.
-- The portal currently connects as postgres (settings.yaml);
-- update database.user to awr_owner to use this role.

DO $$
DECLARE
    r RECORD;
BEGIN
    -- Grant on all tables
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO awr_owner', r.tablename);
    END LOOP;
    -- Grant on all sequences (for SERIAL columns)
    FOR r IN SELECT sequencename FROM pg_sequences WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE public.%I TO awr_owner', r.sequencename);
    END LOOP;
    -- Grant on all materialized views
    FOR r IN SELECT matviewname FROM pg_matviews WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT SELECT ON TABLE public.%I TO awr_owner', r.matviewname);
    END LOOP;
    RAISE NOTICE 'Permissions granted to awr_owner on all objects';
END $$;


-- ============================================================
-- VERIFY INSTALLATION
-- ============================================================
-- Run these queries to confirm the installation is complete.

\echo ''
\echo '============================================================'
\echo ' INSTALLATION COMPLETE — Verification'
\echo '============================================================'

SELECT 'Tables' AS object_type, COUNT(*) AS count
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'Materialized Views', COUNT(*)
FROM pg_matviews WHERE schemaname = 'public'
UNION ALL
SELECT 'Views', COUNT(*)
FROM information_schema.views WHERE table_schema = 'public'
UNION ALL
SELECT 'Indexes', COUNT(*)
FROM pg_indexes WHERE schemaname = 'public'
UNION ALL
SELECT 'portal_config rows', COUNT(*) FROM portal_config
UNION ALL
SELECT 'portal_users rows',  COUNT(*) FROM portal_users
UNION ALL
SELECT 'wait_event_master rows', COUNT(*) FROM awr_wait_event_master
ORDER BY 1;

\echo ''
\echo 'Expected: 80 tables, 11 MVs, 2 views, 86+ indexes'
\echo '          33 portal_config rows'
\echo '          1  portal_users row (admin)'
\echo '          60 wait_event_master rows'
\echo ''
\echo 'Next steps:'
\echo '  1. py -m pip install -r requirements.txt'
\echo '  2. py -m pip install oracledb paramiko'
\echo '  3. Edit config\settings.yaml (DB password, portal/grafana URLs)'
\echo '  4. install_services.bat  (register Windows services)'
\echo '  5. py bulk_import.py     (import Grafana dashboards)'
\echo '  6. Open http://localhost:8000  login: admin / Admin@123'
\echo '  7. Settings -> Access Control: update portal_url and grafana_url'
\echo '  8. Settings -> License: enter your license key'
\echo '  9. CHANGE THE ADMIN PASSWORD immediately'
\echo '============================================================'
