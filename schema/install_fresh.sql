-- ============================================================
-- AWR Insight Portal v3 — Fresh Installation Script
-- Avekshaa Technologies
-- ============================================================
--
-- Complete single-script installation:
--   Section 1 — Configuration guide (read before running)
--   Section 2 — Tablespaces (edit paths before running)
--   Section 3 — Schema owner role (edit password before running)
--   Section 4 — Database objects
--                 80 tables  (79 from schema + sar_anomalies)
--                 88 indexes (78 regular + 10 unique)
--                 2  views
--                 11 materialized views
--   Section 5 — Seed data
--                 portal_config   : 46 keys (all from live DB)
--                 portal_users    : 1 row  (admin / Admin@123)
--                 awr_wait_event_master : 1918 rows (full Oracle
--                   wait event catalog with correlation metadata)
--   Section 6 — Grant permissions to DAR_PORTAL_USER role
--   Section 7 — Verify installation
--
-- ── RECOMMENDED: Use the interactive batch installer ────────
--   install_dar_portal.bat
--   (Prompts for all values, creates directories, runs this SQL)
--
-- ── ALTERNATIVE: Run this SQL directly ───────────────────────
--   1. Create tablespace directories (mkdir)
--   2. Edit tablespace LOCATION paths in Section 2 below
--   3. Edit DAR_PORTAL_USER password in Section 3 below
--   4. Run: psql -U postgres -d postgres -f install_fresh.sql
--
-- ── AFTER RUNNING ───────────────────────────────────────────
--   py bulk_import.py          → import Grafana dashboards
--   http://localhost:8000      → login: admin / Admin@123
--   Settings → Access Control  → update portal_url, grafana_url
--   Settings → License         → enter license key
--   Settings → Users           → CHANGE admin password
-- ============================================================

\echo ''
\echo '============================================================'
\echo ' AWR Insight Portal v3 — Fresh Installation'
\echo ' Avekshaa Technologies'
\echo '============================================================'

SET client_min_messages = WARNING;
SET search_path = public;


-- ============================================================
-- SECTION 1: CONFIGURATION
-- ============================================================
--
-- RECOMMENDED: Use install_dar_portal.bat (Windows) which:
--   • Prompts for all values interactively
--   • Creates tablespace directories automatically
--   • Substitutes paths and passwords before running this SQL
--
-- MANUAL SETUP (if running this SQL directly):
--   ① Create tablespace directories first:
--       Windows:
--         mkdir C:\PostgreSQL\tablespaces\awrparser
--         mkdir C:\PostgreSQL\tablespaces\awrparser_idx
--       Linux:
--         mkdir -p /opt/postgresql/tablespaces/awrparser
--         mkdir -p /opt/postgresql/tablespaces/awrparser_idx
--         chown postgres:postgres /opt/postgresql/tablespaces/awrparser*
--
--   ② Edit the two LOCATION paths in Section 2 below
--       Look for: -- ^^^ EDIT THIS PATH
--
--   ③ Edit the DAR_PORTAL_USER password in Section 3 below
--       Look for: -- ^^^ EDIT THIS PASSWORD
--
--   ④ No-tablespace option: comment out the CREATE TABLESPACE
--       statements and instead run:
--         CREATE TABLESPACE awrparser     OWNER postgres LOCATION '<dir1>';
--         CREATE TABLESPACE awrparser_idx OWNER postgres LOCATION '<dir2>';
--       Or replace all TABLESPACE awrparser with TABLESPACE pg_default.
-- ============================================================


-- ============================================================
-- SECTION 2: TABLESPACES
-- ── Tablespace LOCATION paths ───────────────────────────────
-- If using install_dar_portal.bat: paths are substituted
-- automatically — do not edit here.
-- If running this SQL directly: edit the two LOCATION paths.
-- ============================================================
\echo 'Step 1/6: Creating tablespaces...'

-- Data tablespace: stores all AWR/SAR/multi-DB analysis tables
CREATE TABLESPACE IF NOT EXISTS awrparser
    OWNER postgres
    LOCATION 'C:\PostgreSQL\tablespaces\awrparser';
    -- ^^^ EDIT THIS PATH (or use install_dar_portal.bat for prompt)

-- Index tablespace: stores all indexes (separate disk = better I/O)
CREATE TABLESPACE IF NOT EXISTS awrparser_idx
    OWNER postgres
    LOCATION 'C:\PostgreSQL\tablespaces\awrparser_idx';
    -- ^^^ EDIT THIS PATH (or use install_dar_portal.bat for prompt)

-- Grant DAR_PORTAL_USER permission to create objects in both tablespaces.
-- Without this, CREATE TABLE ... TABLESPACE awrparser fails with:
--   ERROR: permission denied for tablespace awrparser
GRANT CREATE ON TABLESPACE awrparser     TO DAR_PORTAL_USER;
GRANT CREATE ON TABLESPACE awrparser_idx TO DAR_PORTAL_USER;

\echo '  Tablespaces: done'


-- ============================================================
-- SECTION 3: SCHEMA OWNER ROLE
-- ── DAR_PORTAL_USER — schema owner for all DAR Portal objects ──
-- DAR = Database Analysis and Recommendations
-- Designed to own objects across multiple DB platform modules:
--   Oracle AWR, MS SQL Server, PostgreSQL, MySQL, MariaDB, etc.
--
-- If using install_dar_portal.bat: password is prompted and
-- substituted automatically — do not edit here.
-- If running this SQL directly: replace YourSecurePassword123.
-- ============================================================
\echo 'Step 2/6: Creating schema owner DAR_PORTAL_USER...'

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'DAR_PORTAL_USER') THEN
        CREATE ROLE DAR_PORTAL_USER LOGIN PASSWORD 'YourSecurePassword123';
        -- ^^^ EDIT THIS PASSWORD (or use install_dar_portal.bat for prompt)
        RAISE NOTICE 'DAR_PORTAL_USER created successfully';
    ELSE
        ALTER ROLE DAR_PORTAL_USER PASSWORD 'YourSecurePassword123';
        -- ^^^ EDIT THIS PASSWORD (or use install_dar_portal.bat for prompt)
        RAISE NOTICE 'DAR_PORTAL_USER already exists — password updated';
    END IF;
END $$;

-- Grant minimum required privileges to DAR_PORTAL_USER
GRANT CONNECT  ON DATABASE postgres TO DAR_PORTAL_USER;
GRANT CREATE   ON SCHEMA public     TO DAR_PORTAL_USER;
GRANT USAGE    ON SCHEMA public     TO DAR_PORTAL_USER;

-- To connect as DAR_PORTAL_USER instead of postgres:
--   config/settings.yaml:
--     database:
--       user:     DAR_PORTAL_USER
--       password: <password set above>

\echo '  DAR_PORTAL_USER: done'


-- ============================================================
-- SECTION 4: DATABASE OBJECTS
-- 80 tables, 88 indexes, 2 views, 11 materialized views
-- ============================================================
\echo 'Step 3/6: Creating database objects...'
\echo '  80 tables, 88 indexes, 2 views, 11 materialized views'

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
-- Table: portal_users
-- Stores portal login accounts. role: admin | viewer.
-- active=FALSE disables login without deleting the account.
CREATE TABLE IF NOT EXISTS portal_users (
    id            SERIAL       PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,        -- bcrypt hash (cost 12)
    role          VARCHAR(20)  NOT NULL DEFAULT 'viewer',  -- admin | viewer
    full_name     VARCHAR(100),
    email         VARCHAR(100),
    active        BOOLEAN      DEFAULT TRUE,
    last_login    TIMESTAMP,
    created_at    TIMESTAMP    DEFAULT NOW()
) TABLESPACE awrparser;

CREATE INDEX IF NOT EXISTS idx_sar_anomaly_host_time
    ON sar_anomalies (hostname, snap_time DESC, severity);
CREATE INDEX IF NOT EXISTS idx_sar_anomaly_severity
    ON sar_anomalies (severity, snap_time DESC);

\echo '  Database objects: done'

-- ============================================================
-- SECTION 5: SEED DATA — portal_config
-- All 46 keys from the live database, with comments.
-- ON CONFLICT DO NOTHING — safe to re-run.
-- ============================================================

\echo 'Step 4/6: Seeding portal_config (46 keys)...'

INSERT INTO portal_config (key, value, section, updated_by, updated_at) VALUES

-- ── AI / Recommendation Engine ────────────────────────────────────────────
-- ai_mode: rules = built-in JSON rule engine (default, no external API needed)
--          local = supplement with local LLM via Ollama at ai_local_url
--          cloud = supplement with Anthropic Claude API
('ai_mode',              'rules',                  'ai',        'install', NOW()),
('ai_local_url',         'http://localhost:11434',  'ai',        'install', NOW()),
('ai_local_model',       'llama3',                 'ai',        'install', NOW()),
('ai_cloud_provider',    'anthropic',              'ai',        'install', NOW()),
('ai_cloud_api_key',     '',                       'ai',        'install', NOW()),
('ai_cloud_model',       'claude-sonnet-4-6',      'ai',        'install', NOW()),
-- Monthly cap on cloud AI API calls to prevent unexpected costs
('ai_monthly_limit',     '1000',                   'ai',        'install', NOW()),
-- BFSI sector warning flag for regulated environments
('ai_bfsi_warning',      'false',                  'ai',        'install', NOW()),

-- ── Anomaly Detection ─────────────────────────────────────────────────────
-- z_threshold: standard deviations from baseline to flag as anomaly
--   2.0 = ~5% probability (Alert), 3.0 = ~0.3% probability (Critical)
('anomaly_z_threshold',  '2.0',                    'anomaly',   'install', NOW()),
-- baseline_days: rolling window of historical data for mean/stddev calculation
('anomaly_baseline_days','30',                     'anomaly',   'install', NOW()),
-- min_samples: minimum data points needed before anomaly detection activates
('anomaly_min_samples',  '5',                      'anomaly',   'install', NOW()),

-- ── AWR Source ────────────────────────────────────────────────────────────
-- awr_source_type: local     = watch awr_reports\ folder (manual drop)
--                  direct_db = auto-generate via Oracle connection (oracledb)
('awr_source_type',      'local',                  'awr_source','install', NOW()),
('awr_local_path',       'awr_reports',            'awr_source','install', NOW()),
('awr_network_path',     '',                       'awr_source','install', NOW()),
-- Legacy single Oracle connection (now use awr_oracle_connections table instead)
('awr_db_host',          '',                       'awr_source','install', NOW()),
('awr_db_port',          '1521',                   'awr_source','install', NOW()),
('awr_db_service',       '',                       'awr_source','install', NOW()),
('awr_db_user',          '',                       'awr_source','install', NOW()),
('awr_db_password',      '',                       'awr_source','install', NOW()),

-- ── SAR Source ────────────────────────────────────────────────────────────
-- sar_source_type: local = watch sar_drop\ folder
--                  ssh   = multi-server delta pull via sar_ssh_connections table
('sar_source_type',      'local',                  'sar_source','install', NOW()),
-- Timezone for binary SAR conversion via WSL sadf
('sar_tz_offset',        'Asia/Kolkata',           'sar_source','install', NOW()),
('sar_local_path',       'sar_drop',               'sar_source','install', NOW()),
-- Legacy single-server SSH keys (kept for backward compatibility;
-- multi-server SSH is now managed via sar_ssh_connections table)
('sar_ssh_host',         '',                       'sar_source','install', NOW()),
('sar_ssh_port',         '22',                     'sar_source','install', NOW()),
('sar_ssh_user',         '',                       'sar_source','install', NOW()),
('sar_ssh_key_path',     '',                       'sar_source','install', NOW()),
('sar_ssh_remote_path',  '/var/log/sa',            'sar_source','install', NOW()),
('sar_ssh_password',     '',                       'sar_source','install', NOW()),
-- WinSCP path (legacy binary SAR transfer method; SSH delta is now preferred)
('winscp_path',          '',                       'sar_source','install', NOW()),

-- ── License ───────────────────────────────────────────────────────────────
-- Enter license details via Settings → License after installation
('license_key',          '',                       'license',   'install', NOW()),
('license_customer',     '',                       'license',   'install', NOW()),
('license_tier',         '',                       'license',   'install', NOW()),
('license_db_count',     '0',                      'license',   'install', NOW()),
('license_sar_count',    '0',                      'license',   'install', NOW()),
('license_expiry',       '',                       'license',   'install', NOW()),
('license_mac_override', '',                       'license',   'install', NOW()),

-- ── Database Reader Roles (for read-only Grafana access) ─────────────────
-- Optional: configure dedicated DBA and reader roles for tighter security
('db_dba_user',          '',                       'access',    'install', NOW()),
('db_reader_user',       '',                       'access',    'install', NOW()),
-- PostgreSQL connection details for the portal backend DB
('db_host',              'localhost',              'access',    'install', NOW()),
('db_port',              '5432',                  'access',    'install', NOW()),
('db_name',              'postgres',              'access',    'install', NOW()),

-- ── Access Control ────────────────────────────────────────────────────────
-- Update portal_url and grafana_url to your server hostname/IP:
--   Settings → Access Control
('portal_login_required','false',                  'access',    'install', NOW()),
('portal_url',           'http://localhost:8000',  'access',    'install', NOW()),
('grafana_url',          'http://localhost:3000',  'access',    'install', NOW()),
-- Portal session duration in minutes (480 = 8 hours)
('session_timeout_mins', '480',                    'access',    'install', NOW()),
-- PIN shown on the Forgot Password page — change after installation
('admin_reset_pin',      '1234',                   'access',    'install', NOW()),
-- Days before uploaded object metadata is flagged as stale
('metadata_refresh_days','30',                     'access',    'install', NOW())

ON CONFLICT (key) DO NOTHING;

\echo '  portal_config: done (46 keys)'

-- ── Default admin user ───────────────────────────────────────────────────
-- Username : admin
-- Password : Admin@123  (bcrypt hash, cost 12)
-- CHANGE THIS PASSWORD immediately after first login:
--   Settings → Users → Change Password
\echo 'Step 5/6: Seeding portal_users (admin / Admin@123)...'

INSERT INTO portal_users
    (username, full_name, password_hash, role, active, created_at)
VALUES
    ('admin', 'Administrator',
     '$2b$12$dBp784c.REpF8DPqAnAVwevDAgiHOiL4Fm8BIrxyc724HgKDyDWBm',
     'admin', TRUE, NOW())
ON CONFLICT (username) DO UPDATE
    SET password_hash = EXCLUDED.password_hash,
        role          = 'admin',
        active        = TRUE;

\echo '  portal_users: done'


-- ============================================================
-- SECTION 6: ORACLE WAIT EVENT CLASSIFICATIONS
-- ============================================================
-- 1918 rows covering the full Oracle wait event catalog.
-- Includes: event name, wait class, corr_type (correlation type
-- for AWR Intelligence), seg_filter, has_specific_rule flag,
-- and guidance_text for the recommendation engine.
--
-- corr_type values:
--   io_read     → correlate with physical_reads segments
--   io_write    → correlate with physical_writes segments
--   buffer_busy → correlate with buffer_busy_waits segments
--   row_lock    → correlate with row_lock_waits segments
--   gc_cluster  → correlate with gc_buffer_busy segments
--   none        → no segment correlation applicable
--   NULL        → not yet classified (Other/Idle wait class)
--
-- ON CONFLICT DO UPDATE — idempotent, updates guidance_text
-- if the event already exists from a previous installation.
-- ============================================================
\echo 'Step 6/6: Seeding awr_wait_event_master (1918 Oracle wait events)...'

INSERT INTO awr_wait_event_master
    (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES
    ('PBR logfile block write','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('recovery read','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('RFS sequential i/o','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('RFS random i/o','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('RFS write','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('log file sequential read','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('log file single write','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('log file pmem persist write','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('log file pmem persist read','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('db file async I/O submit','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('flashback log file write','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('flashback log file read','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('cell smart incremental backup','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('cell smart restore from backup','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('ASM sync relocation I/O','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('ASM async relocation I/O','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('kfk: async disk IO','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('iowp io','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('cell manager opening cell','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('cell manager closing cell','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('RMAN lost write reread','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('RMAN backup & recovery I/O','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('Log archive I/O','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('Clonedb bitmap file write','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('Archiver slave I/O','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('LGWR slave I/O','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('RMAN Tape slave I/O','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('RMAN Disk slave I/O','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('cell manager discovering disks','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('io done','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('undo segment tx slot','Configuration','none','none',FALSE,'No free transaction slot available in the undo segment header. Root cause: undo segment too small or too many concurrent transactions. (1) Ensure UNDO_MANAGEMENT=AUTO and undo tablespace is adequately sized. (2) Increase number of undo segments (or ensure auto-undo is not constrained). (3) Review concurrent transaction count.'),
    ('log file switch (checkpoint incomplete)','Configuration','none','none',TRUE,'Log switch blocked — checkpoint for reuse group not yet complete. (1) Increase redo log file size (min 500MB, target 1–4GB). (2) Add more redo log groups. (3) Increase DB_WRITER_PROCESSES.'),
    ('log file switch (archiving needed)','Configuration','none','none',TRUE,'URGENT — Log switch blocked; ARCn cannot archive fast enough. (1) Check archive destination space immediately. (2) Increase LOG_ARCHIVE_MAX_PROCESSES to 4–8. (3) Increase redo log file size as immediate relief.'),
    ('ASM background timer','Idle',NULL,NULL,FALSE,NULL),
    ('ASM cluster membership changes','Idle',NULL,NULL,FALSE,NULL),
    ('iowp msg','Idle',NULL,NULL,FALSE,NULL),
    ('iowp file id','Idle',NULL,NULL,FALSE,NULL),
    ('netp network','Idle',NULL,NULL,FALSE,NULL),
    ('gopp msg','Idle',NULL,NULL,FALSE,NULL),
    ('auto-sqltune: wait graph update','Idle',NULL,NULL,FALSE,NULL),
    ('WCR: replay client notify','Idle',NULL,NULL,FALSE,NULL),
    ('WCR: replay clock','Idle',NULL,NULL,FALSE,NULL),
    ('WCR: replay paused','Idle',NULL,NULL,FALSE,NULL),
    ('JS external job','Idle',NULL,NULL,FALSE,NULL),
    ('cell worker idle','Idle',NULL,NULL,FALSE,NULL),
    ('recovery receiver idle','Idle',NULL,NULL,FALSE,NULL),
    ('recovery coordinator idle','Idle',NULL,NULL,FALSE,NULL),
    ('recovery logmerger idle','Idle',NULL,NULL,FALSE,NULL),
    ('block compare coord process idle','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Txn Recovery Start','Idle',NULL,NULL,FALSE,NULL),

    ('PX Deq: Txn Recovery Reply','Idle',NULL,NULL,FALSE,NULL),
    ('fbar timer','Idle',NULL,NULL,FALSE,NULL),
    ('smon timer','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Metadata Update','Idle',NULL,NULL,FALSE,NULL),
    ('Space Manager: slave idle wait','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Index Merge Reply','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Index Merge Execute','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Index Merge Close','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: kdcph_mai','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: kdcphc_ack','Idle',NULL,NULL,FALSE,NULL),
    ('imco timer','Idle',NULL,NULL,FALSE,NULL),
    ('IMFS defer writes scheduler','Idle',NULL,NULL,FALSE,NULL),
    ('memoptimize write drain idle','Idle',NULL,NULL,FALSE,NULL),
    ('virtual circuit next request','Idle',NULL,NULL,FALSE,NULL),
    ('shared server idle wait','Idle',NULL,NULL,FALSE,NULL),
    ('dispatcher timer','Idle',NULL,NULL,FALSE,NULL),
    ('cmon timer','Idle',NULL,NULL,FALSE,NULL),
    ('pool server timer','Idle',NULL,NULL,FALSE,NULL),
    ('lreg timer','Idle',NULL,NULL,FALSE,NULL),
    ('JOX Jit Process Sleep','Idle',NULL,NULL,FALSE,NULL),
    ('jobq slave wait','Idle',NULL,NULL,FALSE,NULL),
    ('pipe get','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deque wait','Idle',NULL,NULL,FALSE,NULL),
    ('PX Idle Wait','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq Credit: need buffer','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Msg Fragment','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Parse Reply','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Execution Msg','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Table Q Normal','Idle',NULL,NULL,FALSE,NULL),
    ('PX Deq: Table Q Sample','Idle',NULL,NULL,FALSE,NULL),
    ('REPL Apply: txns','Idle',NULL,NULL,FALSE,NULL),
    ('REPL Capture/Apply: messages','Idle',NULL,NULL,FALSE,NULL),
    ('REPL Capture: archive log','Idle',NULL,NULL,FALSE,NULL),
    ('single-task message','Idle',NULL,NULL,FALSE,NULL),
    ('SQL*Net vector message from client','Idle',NULL,NULL,FALSE,NULL),
    ('SQL*Net vector message from dblink','Idle',NULL,NULL,FALSE,NULL),
    ('PL/SQL lock timer','Idle',NULL,NULL,FALSE,NULL),
    ('Streams AQ: emn coordinator idle wait','Idle',NULL,NULL,FALSE,NULL),
    ('EMON slave idle wait','Idle',NULL,NULL,FALSE,NULL),
    ('Emon coordinator main loop','Idle',NULL,NULL,FALSE,NULL),
    ('Emon slave main loop','Idle',NULL,NULL,FALSE,NULL),
    ('Streams AQ: waiting for messages in the queue','Idle',NULL,NULL,FALSE,NULL),
    ('Streams AQ: waiting for time management or cleanup tasks','Idle',NULL,NULL,FALSE,NULL),
    ('Streams AQ: delete acknowledged messages','Idle',NULL,NULL,FALSE,NULL),
    ('Streams AQ: deallocate messages from Streams Pool','Idle',NULL,NULL,FALSE,NULL),
    ('Streams AQ: qmn coordinator idle wait','Idle',NULL,NULL,FALSE,NULL),
    ('Streams AQ: qmn slave idle wait','Idle',NULL,NULL,FALSE,NULL),
    ('AQ: 12c message cache init wait','Idle',NULL,NULL,FALSE,NULL),
    ('AQ Cross Master idle','Idle',NULL,NULL,FALSE,NULL),
    ('AQPC idle','Idle',NULL,NULL,FALSE,NULL),

    ('Streams AQ: load balancer idle','Idle',NULL,NULL,FALSE,NULL),
    ('Sharded Queues : Part Maintenance idle','Idle',NULL,NULL,FALSE,NULL),
    ('Sharded Queues : Part Truncate idle','Idle',NULL,NULL,FALSE,NULL),
    ('REPL Capture/Apply: RAC AQ qmn coordinator','Idle',NULL,NULL,FALSE,NULL),
    ('Streams AQ: opt idle','Idle',NULL,NULL,FALSE,NULL),
    ('HS message to agent','Idle',NULL,NULL,FALSE,NULL),
    ('VKTM Logical Idle Wait','Idle',NULL,NULL,FALSE,NULL),
    ('VKTM Init Wait for GSGA','Idle',NULL,NULL,FALSE,NULL),
    ('IORM Scheduler Slave Idle Wait','Idle',NULL,NULL,FALSE,NULL),
    ('rdbms ipc message','Idle',NULL,NULL,FALSE,NULL),
    ('i/o slave wait','Idle',NULL,NULL,FALSE,NULL),
    ('OFS Receive Queue','Idle',NULL,NULL,FALSE,NULL),
    ('OFS idle','Idle',NULL,NULL,FALSE,NULL),
    ('VKRM Idle','Idle',NULL,NULL,FALSE,NULL),
    ('wait for unread message on broadcast channel','Idle',NULL,NULL,FALSE,NULL),
    ('wait for unread message on multiple broadcast channels','Idle',NULL,NULL,FALSE,NULL),
    ('class slave wait','Idle',NULL,NULL,FALSE,NULL),
    ('RMA: IPC0 completion sync','Idle',NULL,NULL,FALSE,NULL),
    ('PING','Idle',NULL,NULL,FALSE,NULL),
    ('watchdog main loop','Idle',NULL,NULL,FALSE,NULL),
    ('process in prespawned state','Idle',NULL,NULL,FALSE,NULL),
    ('pmon timer','Idle',NULL,NULL,FALSE,NULL),
    ('pman timer','Idle',NULL,NULL,FALSE,NULL),
    ('DNFS disp IO slave idle','Idle',NULL,NULL,FALSE,NULL),
    ('DIAG idle wait','Idle',NULL,NULL,FALSE,NULL),
    ('ges remote message','Idle',NULL,NULL,FALSE,NULL),
    ('SCM slave idle','Idle',NULL,NULL,FALSE,NULL),
    ('LMS CR slave timer','Idle',NULL,NULL,FALSE,NULL),
    ('gcs remote message','Idle',NULL,NULL,FALSE,NULL),
    ('gcs yield cpu','Idle',NULL,NULL,FALSE,NULL),
    ('heartbeat monitor sleep','Idle',NULL,NULL,FALSE,NULL),
    ('GCR sleep','Idle',NULL,NULL,FALSE,NULL),
    ('SGA: MMAN sleep for component shrink','Idle',NULL,NULL,FALSE,NULL),
    ('DBWR timer','Idle',NULL,NULL,FALSE,NULL),
    ('Data Guard: Gap Manager','Idle',NULL,NULL,FALSE,NULL),
    ('Data Guard: controlfile update','Idle',NULL,NULL,FALSE,NULL),
    ('MRP redo arrival','Idle',NULL,NULL,FALSE,NULL),
    ('Data Guard: Timer','Idle',NULL,NULL,FALSE,NULL),
    ('LNS ASYNC archive log','Idle',NULL,NULL,FALSE,NULL),
    ('LNS ASYNC dest activation','Idle',NULL,NULL,FALSE,NULL),
    ('LNS ASYNC end of log','Idle',NULL,NULL,FALSE,NULL),
    ('simulated log write delay','Idle',NULL,NULL,FALSE,NULL),
    ('heartbeat redo informer','Idle',NULL,NULL,FALSE,NULL),
    ('LGWR real time apply sync','Idle',NULL,NULL,FALSE,NULL),
    ('LGWR worker group idle','Idle',NULL,NULL,FALSE,NULL),
    ('parallel recovery slave idle wait','Idle',NULL,NULL,FALSE,NULL),
    ('Backup Appliance waiting for work','Idle',NULL,NULL,FALSE,NULL),
    ('Backup Appliance waiting restore start','Idle',NULL,NULL,FALSE,NULL),
    ('Backup Appliance Surrogate wait','Idle',NULL,NULL,FALSE,NULL),
    ('Backup Appliance Servlet wait','Idle',NULL,NULL,FALSE,NULL),

    ('Backup Appliance Comm SGA setup wait','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner builder: idle','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner builder: branch','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner preparer: idle','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner reader: log (idle)','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner reader: redo (idle)','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner merger: idle','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner client: transaction','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner: other','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner: activate','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner: reset','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner: find session','Idle',NULL,NULL,FALSE,NULL),
    ('LogMiner: internal','Idle',NULL,NULL,FALSE,NULL),
    ('Logical Standby Apply Delay','Idle',NULL,NULL,FALSE,NULL),
    ('parallel recovery coordinator waits for slave cleanup','Idle',NULL,NULL,FALSE,NULL),
    ('parallel recovery coordinator idle wait','Idle',NULL,NULL,FALSE,NULL),
    ('parallel recovery control message reply','Idle',NULL,NULL,FALSE,NULL),
    ('parallel recovery slave next change','Idle',NULL,NULL,FALSE,NULL),
    ('nologging fetch slave idle','Idle',NULL,NULL,FALSE,NULL),
    ('recovery sender idle','Idle',NULL,NULL,FALSE,NULL),
    ('log file switch (private strand flush incomplete)','Configuration','none','none',FALSE,'Log switch blocked — private strand flush not yet complete. (1) Increase redo log file size. (2) Review private strand flush settings. (3) Add more redo log groups.'),
    ('log file switch completion','Configuration','none','none',FALSE,'Waiting for log file switch to complete. (1) Increase redo log file size. (2) Add more log groups. (3) Check LGWR I/O performance.'),
    ('latch: redo copy','Configuration','none','none',FALSE,'Redo copy latch contention — very high redo generation rate. (1) Increase LOG_BUFFER. (2) Batch DML to reduce redo allocation. (3) Use NOLOGGING for bulk operations.'),
    ('latch: redo writing','Configuration','none','none',FALSE,'Redo write latch contention — LGWR I/O serialisation. (1) Move redo logs to dedicated SSDs. (2) Increase LOG_BUFFER. (3) Ensure async I/O is enabled for redo.'),
    ('enq: SS - contention','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('enq: SV - contention','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('null event','Other',NULL,NULL,FALSE,NULL),
    ('events in waitclass Other','Other',NULL,NULL,FALSE,NULL),
    ('enq: WM - WLM Plan activation','Other',NULL,NULL,FALSE,NULL),
    ('latch activity','Other',NULL,NULL,FALSE,NULL),
    ('wait list latch free','Other',NULL,NULL,FALSE,NULL),
    ('kslwait unit test event 1','Other',NULL,NULL,FALSE,NULL),
    ('kslwait unit test event 2','Other',NULL,NULL,FALSE,NULL),
    ('kslwait unit test event 3','Other',NULL,NULL,FALSE,NULL),
    ('unspecified wait event','Other',NULL,NULL,FALSE,NULL),
    ('global enqueue expand wait','Other',NULL,NULL,FALSE,NULL),
    ('free process state object','Other',NULL,NULL,FALSE,NULL),
    ('inactive session','Other',NULL,NULL,FALSE,NULL),
    ('process terminate','Other',NULL,NULL,FALSE,NULL),
    ('latch: call allocation','Other',NULL,NULL,FALSE,NULL),
    ('latch: session allocation','Other',NULL,NULL,FALSE,NULL),
    ('check CPU wait times','Other',NULL,NULL,FALSE,NULL),
    ('ADG switchover completion','Other',NULL,NULL,FALSE,NULL),
    ('process allocation slot','Other',NULL,NULL,FALSE,NULL),
    ('session allocation inc count','Other',NULL,NULL,FALSE,NULL),
    ('enq: CI - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: PR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: AK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: XK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DI - contention','Other',NULL,NULL,FALSE,NULL),

    ('enq: RM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: BO - contention','Other',NULL,NULL,FALSE,NULL),
    ('ges resource enqueue open retry sleep','Other',NULL,NULL,FALSE,NULL),
    ('ksim generic wait event','Other',NULL,NULL,FALSE,NULL),
    ('enq: DE - Update Draining Test','Other',NULL,NULL,FALSE,NULL),
    ('debugger command','Other',NULL,NULL,FALSE,NULL),
    ('oradebug request slot','Other',NULL,NULL,FALSE,NULL),
    ('oradebug request completion','Other',NULL,NULL,FALSE,NULL),
    ('latch: ksm sga alloc latch','Other',NULL,NULL,FALSE,NULL),
    ('defer SGA allocation slave','Other',NULL,NULL,FALSE,NULL),
    ('SGA Allocator termination','Other',NULL,NULL,FALSE,NULL),
    ('PGA memory operation','Other',NULL,NULL,FALSE,NULL),
    ('enq: PE - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: PG - contention','Other',NULL,NULL,FALSE,NULL),
    ('ksbsrv','Other',NULL,NULL,FALSE,NULL),
    ('ksbcic','Other',NULL,NULL,FALSE,NULL),
    ('process startup','Other',NULL,NULL,FALSE,NULL),
    ('process shutdown','Other',NULL,NULL,FALSE,NULL),
    ('prior spawner clean up','Other',NULL,NULL,FALSE,NULL),
    ('latch: messages','Other',NULL,NULL,FALSE,NULL),
    ('rdbms ipc message block','Other',NULL,NULL,FALSE,NULL),
    ('latch: pdb enqueue hash chains','Other',NULL,NULL,FALSE,NULL),
    ('latch: enqueue hash chains','Other',NULL,NULL,FALSE,NULL),
    ('imm op','Other',NULL,NULL,FALSE,NULL),
    ('slave exit','Other',NULL,NULL,FALSE,NULL),
    ('enq: FP - global fob contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: RE - block repair contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: BM - clonedb bitmap file write','Other',NULL,NULL,FALSE,NULL),
    ('asynch descriptor resize','Other',NULL,NULL,FALSE,NULL),
    ('OFS interrupted req not found','Other',NULL,NULL,FALSE,NULL),
    ('enq: FO - file system operation contention','Other',NULL,NULL,FALSE,NULL),
    ('resmgr:plan change','Other',NULL,NULL,FALSE,NULL),
    ('enq: KM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: KT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: CA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: KD - determine DBRM master','Other',NULL,NULL,FALSE,NULL),
    ('broadcast mesg queue transition','Other',NULL,NULL,FALSE,NULL),
    ('broadcast mesg recovery queue transition','Other',NULL,NULL,FALSE,NULL),
    ('KSV master wait','Other',NULL,NULL,FALSE,NULL),
    ('master exit','Other',NULL,NULL,FALSE,NULL),
    ('ksv slave avail wait','Other',NULL,NULL,FALSE,NULL),
    ('enq: PV - syncstart','Other',NULL,NULL,FALSE,NULL),
    ('enq: PV - syncshut','Other',NULL,NULL,FALSE,NULL),
    ('enq: SP - contention 1','Other',NULL,NULL,FALSE,NULL),
    ('enq: SP - contention 2','Other',NULL,NULL,FALSE,NULL),
    ('enq: SP - contention 3','Other',NULL,NULL,FALSE,NULL),
    ('enq: SP - contention 4','Other',NULL,NULL,FALSE,NULL),
    ('enq: SX - contention 5','Other',NULL,NULL,FALSE,NULL),
    ('enq: SX - contention 6','Other',NULL,NULL,FALSE,NULL),
    ('first spare wait event','Other',NULL,NULL,FALSE,NULL),

    ('second spare wait event','Other',NULL,NULL,FALSE,NULL),
    ('Memory: Reg/Dereg','Other',NULL,NULL,FALSE,NULL),
    ('IPC send completion sync','Other',NULL,NULL,FALSE,NULL),
    ('OSD IPC library','Other',NULL,NULL,FALSE,NULL),
    ('IPC wait for name service busy','Other',NULL,NULL,FALSE,NULL),
    ('IPC busy async request','Other',NULL,NULL,FALSE,NULL),
    ('IPC waiting for OSD resources','Other',NULL,NULL,FALSE,NULL),
    ('ksxr poll remote instances','Other',NULL,NULL,FALSE,NULL),
    ('ksxr wait for mount shared','Other',NULL,NULL,FALSE,NULL),
    ('DBMS_LDAP: LDAP operation','Other',NULL,NULL,FALSE,NULL),
    ('wait for FMON to come up','Other',NULL,NULL,FALSE,NULL),
    ('enq: FM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: XY - contention','Other',NULL,NULL,FALSE,NULL),
    ('latch: active service list','Other',NULL,NULL,FALSE,NULL),
    ('latch: service drain list','Other',NULL,NULL,FALSE,NULL),
    ('latch: last service list','Other',NULL,NULL,FALSE,NULL),
    ('latch: java patching','Other',NULL,NULL,FALSE,NULL),
    ('enq: AS - service activation','Other',NULL,NULL,FALSE,NULL),
    ('JAVA patching','Other',NULL,NULL,FALSE,NULL),
    ('enq: PD - contention','Other',NULL,NULL,FALSE,NULL),
    ('oracle thread bootstrap','Other',NULL,NULL,FALSE,NULL),
    ('os thread creation','Other',NULL,NULL,FALSE,NULL),
    ('cleanup of aborted process','Other',NULL,NULL,FALSE,NULL),
    ('enq: XM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: RU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: RU - waiting','Other',NULL,NULL,FALSE,NULL),
    ('rolling migration: cluster quiesce','Other',NULL,NULL,FALSE,NULL),
    ('LMON global data update','Other',NULL,NULL,FALSE,NULL),
    ('rolling migration: orphans detected','Other',NULL,NULL,FALSE,NULL),
    ('process diagnostic dump','Other',NULL,NULL,FALSE,NULL),
    ('enq: MX - sync storage server info','Other',NULL,NULL,FALSE,NULL),
    ('master diskmon startup','Other',NULL,NULL,FALSE,NULL),
    ('master diskmon read','Other',NULL,NULL,FALSE,NULL),
    ('DSKM to complete cell health check','Other',NULL,NULL,FALSE,NULL),
    ('pmon dblkr tst event','Other',NULL,NULL,FALSE,NULL),
    ('latch: ksolt lwth alloc','Other',NULL,NULL,FALSE,NULL),
    ('lightweight thread operation','Other',NULL,NULL,FALSE,NULL),
    ('lightweight thread task completion','Other',NULL,NULL,FALSE,NULL),
    ('enq: WN - rw snapshot synchronization','Other',NULL,NULL,FALSE,NULL),
    ('read/write snapshot completion','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZX - repopulation file write','Other',NULL,NULL,FALSE,NULL),
    ('pmon cleanup','Other',NULL,NULL,FALSE,NULL),
    ('pmon shutdown','Other',NULL,NULL,FALSE,NULL),
    ('GL: cross instance latch free','Other',NULL,NULL,FALSE,NULL),
    ('RMA: rlog allocate','Other',NULL,NULL,FALSE,NULL),
    ('RMA: RAC reconfig','Other',NULL,NULL,FALSE,NULL),
    ('RMA: latch','Other',NULL,NULL,FALSE,NULL),
    ('DNFS disp IO slave cleanup','Other',NULL,NULL,FALSE,NULL),
    ('enq: KA - ACL control status','Other',NULL,NULL,FALSE,NULL),
    ('Nest operation','Other',NULL,NULL,FALSE,NULL),

    ('DIAG lock acquisition','Other',NULL,NULL,FALSE,NULL),
    ('latch: ges resource hash list','Other',NULL,NULL,FALSE,NULL),
    ('ges server process to shutdown','Other',NULL,NULL,FALSE,NULL),
    ('ges client process to exit','Other',NULL,NULL,FALSE,NULL),
    ('ges global resource directory to be frozen','Other',NULL,NULL,FALSE,NULL),
    ('ges resource directory to be unfrozen','Other',NULL,NULL,FALSE,NULL),
    ('gcs resource directory to be unfrozen','Other',NULL,NULL,FALSE,NULL),
    ('ges LMD to inherit communication channels','Other',NULL,NULL,FALSE,NULL),
    ('ges lmd sync during reconfig','Other',NULL,NULL,FALSE,NULL),
    ('ges wait for lmon to be ready','Other',NULL,NULL,FALSE,NULL),
    ('ges cgs registration','Other',NULL,NULL,FALSE,NULL),
    ('wait for master scn','Other',NULL,NULL,FALSE,NULL),
    ('ges yield cpu in reconfig','Other',NULL,NULL,FALSE,NULL),
    ('ges2 proc latch in rm latch get 1','Other',NULL,NULL,FALSE,NULL),
    ('ges2 proc latch in rm latch get 2','Other',NULL,NULL,FALSE,NULL),
    ('ges lmd/lmses to freeze in rcfg','Other',NULL,NULL,FALSE,NULL),
    ('ges lmd/lmses to unfreeze in rcfg','Other',NULL,NULL,FALSE,NULL),
    ('ges lms sync during dynamic remastering and reconfig','Other',NULL,NULL,FALSE,NULL),
    ('ges LMON to join CGS group','Other',NULL,NULL,FALSE,NULL),
    ('ges pmon to exit','Other',NULL,NULL,FALSE,NULL),
    ('ges lmd and pmon to attach','Other',NULL,NULL,FALSE,NULL),
    ('gcs drm freeze begin','Other',NULL,NULL,FALSE,NULL),
    ('gcs retry nowait latch get','Other',NULL,NULL,FALSE,NULL),
    ('gcs remastering wait for read latch','Other',NULL,NULL,FALSE,NULL),
    ('ges cached resource cleanup','Other',NULL,NULL,FALSE,NULL),
    ('ges generic event','Other',NULL,NULL,FALSE,NULL),
    ('ges instance reconfig name entry query','Other',NULL,NULL,FALSE,NULL),
    ('ges process with outstanding i/o','Other',NULL,NULL,FALSE,NULL),
    ('ges user error','Other',NULL,NULL,FALSE,NULL),
    ('ges enter server mode','Other',NULL,NULL,FALSE,NULL),
    ('gcs enter server mode','Other',NULL,NULL,FALSE,NULL),
    ('ges ipc enter server mode','Other',NULL,NULL,FALSE,NULL),
    ('gcs drm freeze in enter server mode','Other',NULL,NULL,FALSE,NULL),
    ('gcs ddet enter server mode','Other',NULL,NULL,FALSE,NULL),
    ('ges cancel','Other',NULL,NULL,FALSE,NULL),
    ('ges resource cleanout during enqueue open','Other',NULL,NULL,FALSE,NULL),
    ('ges resource cleanout during enqueue open-cvt','Other',NULL,NULL,FALSE,NULL),
    ('ges master to get established for SCN op','Other',NULL,NULL,FALSE,NULL),
    ('ges LMON to get to FTDONE','Other',NULL,NULL,FALSE,NULL),
    ('ges1 LMON to wake up LMD - mrcvr','Other',NULL,NULL,FALSE,NULL),
    ('ges2 LMON to wake up LMD - mrcvr','Other',NULL,NULL,FALSE,NULL),
    ('ges2 LMON to wake up lms - mrcvr 2','Other',NULL,NULL,FALSE,NULL),
    ('ges2 LMON to wake up lms - mrcvr 3','Other',NULL,NULL,FALSE,NULL),
    ('ges inquiry response','Other',NULL,NULL,FALSE,NULL),
    ('ges reusing os pid','Other',NULL,NULL,FALSE,NULL),
    ('ges LMON for send queues','Other',NULL,NULL,FALSE,NULL),
    ('ges LMD suspend for testing event','Other',NULL,NULL,FALSE,NULL),
    ('ges performance test completion','Other',NULL,NULL,FALSE,NULL),
    ('kjbopen wait for recovery domain attach','Other',NULL,NULL,FALSE,NULL),
    ('kjudomatt wait for recovery domain attach','Other',NULL,NULL,FALSE,NULL),

    ('kjudomdet wait for recovery domain detach','Other',NULL,NULL,FALSE,NULL),
    ('kjbdomalc allocate recovery domain - retry','Other',NULL,NULL,FALSE,NULL),
    ('kjbdrmcvtq lmon drm quiesce: ping completion','Other',NULL,NULL,FALSE,NULL),
    ('ges RMS0 retry add redo log','Other',NULL,NULL,FALSE,NULL),
    ('readable standby redo apply remastering','Other',NULL,NULL,FALSE,NULL),
    ('ges DFS hang analysis phase 2 acks','Other',NULL,NULL,FALSE,NULL),
    ('ges/gcs diag dump','Other',NULL,NULL,FALSE,NULL),
    ('global plug and play automatic resource creation','Other',NULL,NULL,FALSE,NULL),
    ('gcs lmon dirtydetach step completion','Other',NULL,NULL,FALSE,NULL),
    ('recovery instance recovery completion','Other',NULL,NULL,FALSE,NULL),
    ('ack for a broadcasted res from a remote instance','Other',NULL,NULL,FALSE,NULL),
    ('kill all read-only instances in cluster','Other',NULL,NULL,FALSE,NULL),
    ('latch: kjci process context latch','Other',NULL,NULL,FALSE,NULL),
    ('latch: kjci request sequence latch','Other',NULL,NULL,FALSE,NULL),
    ('DLM cross inst call completion','Other',NULL,NULL,FALSE,NULL),
    ('DLM: shared instance mode init','Other',NULL,NULL,FALSE,NULL),
    ('enq: KI - contention','Other',NULL,NULL,FALSE,NULL),
    ('latch: kjoeq omni enqueue hash bucket latch','Other',NULL,NULL,FALSE,NULL),
    ('DLM enqueue copy completion','Other',NULL,NULL,FALSE,NULL),
    ('latch: kjoer owner hash bucket','Other',NULL,NULL,FALSE,NULL),
    ('DLM Omni Enq Owner replication','Other',NULL,NULL,FALSE,NULL),
    ('KJC: Wait for msg sends to complete','Other',NULL,NULL,FALSE,NULL),
    ('ges message buffer allocation','Other',NULL,NULL,FALSE,NULL),
    ('kjctssqmg: quick message send wait','Other',NULL,NULL,FALSE,NULL),
    ('gcs domain validation','Other',NULL,NULL,FALSE,NULL),
    ('latch: gcs resource hash','Other',NULL,NULL,FALSE,NULL),
    ('affinity expansion in replay','Other',NULL,NULL,FALSE,NULL),
    ('wait for sync ack','Other',NULL,NULL,FALSE,NULL),
    ('wait for verification ack','Other',NULL,NULL,FALSE,NULL),
    ('wait for assert messages to be sent','Other',NULL,NULL,FALSE,NULL),
    ('wait for scn ack','Other',NULL,NULL,FALSE,NULL),
    ('lms flush message acks','Other',NULL,NULL,FALSE,NULL),
    ('name-service call wait','Other',NULL,NULL,FALSE,NULL),
    ('CGS wait for IPC msg','Other',NULL,NULL,FALSE,NULL),
    ('IMR hang simulation','Other',NULL,NULL,FALSE,NULL),
    ('IMR mount phase II completion','Other',NULL,NULL,FALSE,NULL),
    ('IMR disk votes','Other',NULL,NULL,FALSE,NULL),
    ('IMR rr lock release','Other',NULL,NULL,FALSE,NULL),
    ('IMR net-check message ack','Other',NULL,NULL,FALSE,NULL),
    ('IMR rr update','Other',NULL,NULL,FALSE,NULL),
    ('IMR membership resolution','Other',NULL,NULL,FALSE,NULL),
    ('IMR CSS join retry','Other',NULL,NULL,FALSE,NULL),
    ('IMR slave process init','Other',NULL,NULL,FALSE,NULL),
    ('IMR slave process shutdown','Other',NULL,NULL,FALSE,NULL),
    ('IMR slave acknowledgement msg','Other',NULL,NULL,FALSE,NULL),
    ('CGS skgxn join retry','Other',NULL,NULL,FALSE,NULL),
    ('CGS ping operation','Other',NULL,NULL,FALSE,NULL),
    ('gcs to be enabled','Other',NULL,NULL,FALSE,NULL),
    ('gcs log flush sync','Other',NULL,NULL,FALSE,NULL),
    ('KA: shared KGA not initialized','Other',NULL,NULL,FALSE,NULL),

    ('enq: PP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: HM - contention','Other',NULL,NULL,FALSE,NULL),
    ('GCR ctx lock acquisition','Other',NULL,NULL,FALSE,NULL),
    ('GCR CSS group lock','Other',NULL,NULL,FALSE,NULL),
    ('GCR CSS group join','Other',NULL,NULL,FALSE,NULL),
    ('GCR CSS group leave','Other',NULL,NULL,FALSE,NULL),
    ('GCR CSS group update','Other',NULL,NULL,FALSE,NULL),
    ('GCR CSS group query','Other',NULL,NULL,FALSE,NULL),
    ('enq: AC - acquiring partition id','Other',NULL,NULL,FALSE,NULL),
    ('LMA glob lock acquisition','Other',NULL,NULL,FALSE,NULL),
    ('LMA KGA glob lock acquisition','Other',NULL,NULL,FALSE,NULL),
    ('latch: GCS logfile block','Other',NULL,NULL,FALSE,NULL),
    ('latch: GCS logfile write queue','Other',NULL,NULL,FALSE,NULL),
    ('LMFC reconfig operation','Other',NULL,NULL,FALSE,NULL),
    ('PCFC: recovery domain valid','Other',NULL,NULL,FALSE,NULL),
    ('SGA: allocation forcing component growth','Other',NULL,NULL,FALSE,NULL),
    ('SGA: sga_target resize','Other',NULL,NULL,FALSE,NULL),
    ('enq: SC - contention','Other',NULL,NULL,FALSE,NULL),
    ('control file heartbeat','Other',NULL,NULL,FALSE,NULL),
    ('control file diagnostic dump','Other',NULL,NULL,FALSE,NULL),
    ('enq: CF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: SW - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TC - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TC - contention2','Other',NULL,NULL,FALSE,NULL),
    ('buffer exterminate','Other',NULL,NULL,FALSE,NULL),
    ('kcbw: cache protect wait','Other',NULL,NULL,FALSE,NULL),
    ('latch: cache buffers lru chain','Other',NULL,NULL,FALSE,NULL),
    ('enq: PW - perwarm status in dbw0','Other',NULL,NULL,FALSE,NULL),
    ('latch: checkpoint queue latch','Other',NULL,NULL,FALSE,NULL),
    ('latch: cache buffer handles','Other',NULL,NULL,FALSE,NULL),
    ('kcbzps','Other',NULL,NULL,FALSE,NULL),
    ('DBWR range invalidation sync','Other',NULL,NULL,FALSE,NULL),
    ('buffer deadlock','Other',NULL,NULL,FALSE,NULL),
    ('buffer latch','Other',NULL,NULL,FALSE,NULL),
    ('cr request retry','Other',NULL,NULL,FALSE,NULL),
    ('influx scn','Other',NULL,NULL,FALSE,NULL),
    ('writes stopped by instance recovery or database suspension','Other',NULL,NULL,FALSE,NULL),
    ('lock escalate retry','Other',NULL,NULL,FALSE,NULL),
    ('lock deadlock retry','Other',NULL,NULL,FALSE,NULL),
    ('prefetch warmup block being transferred','Other',NULL,NULL,FALSE,NULL),
    ('recovery buffer pinned','Other',NULL,NULL,FALSE,NULL),
    ('tablespace key change','Other',NULL,NULL,FALSE,NULL),
    ('TSE SSO wallet reopen','Other',NULL,NULL,FALSE,NULL),
    ('force-cr-override flush','Other',NULL,NULL,FALSE,NULL),
    ('enq: CR - block range reuse ckpt','Other',NULL,NULL,FALSE,NULL),
    ('enq: TR - serialize TS rekeys','Other',NULL,NULL,FALSE,NULL),
    ('enq: TR - database key open check','Other',NULL,NULL,FALSE,NULL),
    ('enq: TR - serialize system rekeys','Other',NULL,NULL,FALSE,NULL),
    ('wait for MTTR advisory state object','Other',NULL,NULL,FALSE,NULL),

    ('latch: object queue header operation','Other',NULL,NULL,FALSE,NULL),
    ('enq: BU - recovery set construct','Other',NULL,NULL,FALSE,NULL),
    ('enq: BU - recovery set takeover','Other',NULL,NULL,FALSE,NULL),
    ('retry CFTXN during close','Other',NULL,NULL,FALSE,NULL),
    ('get branch/thread/sequence enqueue','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - Test access/locking','Other',NULL,NULL,FALSE,NULL),
    ('Data Guard server operation completion','Other',NULL,NULL,FALSE,NULL),
    ('FAL archive wait 1 sec for REOPEN minimum','Other',NULL,NULL,FALSE,NULL),
    ('TEST: action sync','Other',NULL,NULL,FALSE,NULL),
    ('TEST: action hang','Other',NULL,NULL,FALSE,NULL),
    ('RSGA: RAC reconfiguration','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - RAC-wide SGA initialize','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - RAC-wide SGA write','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - RAC-wide SGA dump','Other',NULL,NULL,FALSE,NULL),
    ('MRP stop','Other',NULL,NULL,FALSE,NULL),
    ('enq: SA - standby redo logfiles','Other',NULL,NULL,FALSE,NULL),
    ('enq: WS - contention','Other',NULL,NULL,FALSE,NULL),
    ('MRP wait on process start','Other',NULL,NULL,FALSE,NULL),
    ('MRP wait on process restart','Other',NULL,NULL,FALSE,NULL),
    ('MRP wait on startup clear','Other',NULL,NULL,FALSE,NULL),
    ('MRP inactivation','Other',NULL,NULL,FALSE,NULL),
    ('MRP wait on archivelog arrival','Other',NULL,NULL,FALSE,NULL),
    ('MRP wait on archivelog archival','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - Far Sync Fail Over','Other',NULL,NULL,FALSE,NULL),
    ('enq: SA - MRP SRL access','Other',NULL,NULL,FALSE,NULL),
    ('Monitor testing','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - redo_db table update','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - redo_log table update','Other',NULL,NULL,FALSE,NULL),
    ('log switch/archive','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - Switchover To Primary','Other',NULL,NULL,FALSE,NULL),
    ('ARCH wait on c/f tx acquire 1','Other',NULL,NULL,FALSE,NULL),
    ('RFS attach','Other',NULL,NULL,FALSE,NULL),
    ('RFS create','Other',NULL,NULL,FALSE,NULL),
    ('RFS close','Other',NULL,NULL,FALSE,NULL),
    ('RFS announce','Other',NULL,NULL,FALSE,NULL),
    ('RFS register','Other',NULL,NULL,FALSE,NULL),
    ('RFS detach','Other',NULL,NULL,FALSE,NULL),
    ('RFS ping','Other',NULL,NULL,FALSE,NULL),
    ('RFS dispatch','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - RFS global state contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - SNA access/locking','Other',NULL,NULL,FALSE,NULL),
    ('LGWR simulation latency wait','Other',NULL,NULL,FALSE,NULL),
    ('LNS simulation latency wait','Other',NULL,NULL,FALSE,NULL),
    ('ASYNC Remote Write','Other',NULL,NULL,FALSE,NULL),
    ('SYNC Remote Write','Other',NULL,NULL,FALSE,NULL),
    ('ARCH Remote Write','Other',NULL,NULL,FALSE,NULL),
    ('Redo Transport Attach','Other',NULL,NULL,FALSE,NULL),
    ('Redo Transport Detach','Other',NULL,NULL,FALSE,NULL),
    ('Redo Transport Open','Other',NULL,NULL,FALSE,NULL),
    ('Redo Transport Close','Other',NULL,NULL,FALSE,NULL),

    ('Redo Transport Ping','Other',NULL,NULL,FALSE,NULL),
    ('Remote SYNC Ping','Other',NULL,NULL,FALSE,NULL),
    ('Redo Transport Slave Startup','Other',NULL,NULL,FALSE,NULL),
    ('Redo Transport Slave Shutdown','Other',NULL,NULL,FALSE,NULL),
    ('Redo Writer Remote Sync Notify','Other',NULL,NULL,FALSE,NULL),
    ('Redo Writer Remote Sync Complete','Other',NULL,NULL,FALSE,NULL),
    ('Redo Transport MISC','Other',NULL,NULL,FALSE,NULL),
    ('Redo Transport Network Throttle','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - Network Throttle','Other',NULL,NULL,FALSE,NULL),
    ('LGWR-LNS wait on channel','Other',NULL,NULL,FALSE,NULL),
    ('enq: WR - contention','Other',NULL,NULL,FALSE,NULL),
    ('Data Guard: rtrt work','Other',NULL,NULL,FALSE,NULL),
    ('Redo transport testing','Other',NULL,NULL,FALSE,NULL),
    ('enq: RZ - add element','Other',NULL,NULL,FALSE,NULL),
    ('enq: RZ - remove element','Other',NULL,NULL,FALSE,NULL),
    ('Image redo gen delay','Other',NULL,NULL,FALSE,NULL),
    ('Long operation CF pause','Other',NULL,NULL,FALSE,NULL),
    ('LGWR wait for redo copy','Other',NULL,NULL,FALSE,NULL),
    ('latch: redo allocation','Other',NULL,NULL,FALSE,NULL),
    ('log file switch (clearing log file)','Other',NULL,NULL,FALSE,NULL),
    ('log file sync: PDB shutdown abort','Other',NULL,NULL,FALSE,NULL),
    ('target log write size','Other',NULL,NULL,FALSE,NULL),
    ('LGWR any worker group','Other',NULL,NULL,FALSE,NULL),
    ('LGWR all worker groups','Other',NULL,NULL,FALSE,NULL),
    ('LGWR worker group ordering','Other',NULL,NULL,FALSE,NULL),
    ('LGWR intra group sync','Other',NULL,NULL,FALSE,NULL),
    ('LGWR intra group IO completion','Other',NULL,NULL,FALSE,NULL),
    ('enq: WL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: RN - contention','Other',NULL,NULL,FALSE,NULL),
    ('DFS db file lock','Other',NULL,NULL,FALSE,NULL),
    ('PDB close/open on another instance','Other',NULL,NULL,FALSE,NULL),
    ('database open on read-write instance','Other',NULL,NULL,FALSE,NULL),
    ('enq: DF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: IS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: IP - open/close PDB','Other',NULL,NULL,FALSE,NULL),
    ('enq: PX - PDB instance recovery','Other',NULL,NULL,FALSE,NULL),
    ('enq: FS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: FS - online log operation','Other',NULL,NULL,FALSE,NULL),
    ('enq: DM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DM - access control','Other',NULL,NULL,FALSE,NULL),
    ('enq: RP - contention','Other',NULL,NULL,FALSE,NULL),
    ('latch: gc element','Other',NULL,NULL,FALSE,NULL),
    ('redo log switch request completion','Other',NULL,NULL,FALSE,NULL),
    ('enq: RT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: RT - thread internal enable/disable','Other',NULL,NULL,FALSE,NULL),
    ('enq: IR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: IR - contention2','Other',NULL,NULL,FALSE,NULL),
    ('enq: IR - global serialization','Other',NULL,NULL,FALSE,NULL),
    ('enq: IR - local serialization','Other',NULL,NULL,FALSE,NULL),
    ('enq: IR - arbitrate instance recovery','Other',NULL,NULL,FALSE,NULL),

    ('enq: MR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: MR - standby role transition','Other',NULL,NULL,FALSE,NULL),
    ('enq: MR - multi instance redo apply','Other',NULL,NULL,FALSE,NULL),
    ('enq: MR - any role transition','Other',NULL,NULL,FALSE,NULL),
    ('enq: MR - PDB open','Other',NULL,NULL,FALSE,NULL),
    ('enq: MR - datafile online','Other',NULL,NULL,FALSE,NULL),
    ('enq: MR - adg instance recovery','Other',NULL,NULL,FALSE,NULL),
    ('enq: MR - preplugin recovery','Other',NULL,NULL,FALSE,NULL),
    ('enq: MR - datafile pre-create','Other',NULL,NULL,FALSE,NULL),
    ('shutdown after switchover to standby','Other',NULL,NULL,FALSE,NULL),
    ('cancel media recovery on switchover','Other',NULL,NULL,FALSE,NULL),
    ('PDB lock domain invalidation','Other',NULL,NULL,FALSE,NULL),
    ('Recovery: scn growth limit','Other',NULL,NULL,FALSE,NULL),
    ('parallel recovery coord wait for reply','Other',NULL,NULL,FALSE,NULL),
    ('parallel recovery coord send blocked','Other',NULL,NULL,FALSE,NULL),
    ('parallel recovery slave wait for change','Other',NULL,NULL,FALSE,NULL),
    ('enq: BR - file shrink','Other',NULL,NULL,FALSE,NULL),
    ('enq: BR - proxy-copy','Other',NULL,NULL,FALSE,NULL),
    ('enq: BR - multi-section restore header','Other',NULL,NULL,FALSE,NULL),
    ('enq: BR - multi-section restore section','Other',NULL,NULL,FALSE,NULL),
    ('enq: BR - space info datafile hdr update','Other',NULL,NULL,FALSE,NULL),
    ('enq: BR - request autobackup','Other',NULL,NULL,FALSE,NULL),
    ('enq: BR - perform autobackup','Other',NULL,NULL,FALSE,NULL),
    ('enq: BR - perform catalog recovery area','Other',NULL,NULL,FALSE,NULL),
    ('enq: ID - contention','Other',NULL,NULL,FALSE,NULL),
    ('Backup Restore Throttle sleep','Other',NULL,NULL,FALSE,NULL),
    ('Backup Restore Switch Bitmap sleep','Other',NULL,NULL,FALSE,NULL),
    ('Backup Restore Event sleep','Other',NULL,NULL,FALSE,NULL),
    ('RMAN wallet access limit','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare1','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare2','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare3','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare4','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare5','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare6','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare7','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare8','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare9','Other',NULL,NULL,FALSE,NULL),
    ('enq: BS - Backup spare0','Other',NULL,NULL,FALSE,NULL),
    ('enq: AB - ABMR process start/stop','Other',NULL,NULL,FALSE,NULL),
    ('enq: AB - ABMR process initialized','Other',NULL,NULL,FALSE,NULL),
    ('Auto BMR completion','Other',NULL,NULL,FALSE,NULL),
    ('Auto BMR RPC standby catchup','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA lock db','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA lock storage loc','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA lock timer queue','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA lock scheduler','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA lock API','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA quiesce tasks','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA check quiesce tasks','Other',NULL,NULL,FALSE,NULL),

    ('enq: ZR - ZDLRA quiesce servlets','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA check servlet quiescence','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA serialize unregister db','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA run scheduler','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA purge storage loc','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA spare enq 10','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA invalidate plans','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZR - ZDLRA protect plans','Other',NULL,NULL,FALSE,NULL),
    ('enq: BC - drop container group','Other',NULL,NULL,FALSE,NULL),
    ('enq: BC - create container','Other',NULL,NULL,FALSE,NULL),
    ('enq: BC - group - create container','Other',NULL,NULL,FALSE,NULL),
    ('enq: BC - drop container','Other',NULL,NULL,FALSE,NULL),
    ('enq: BC - group - create file','Other',NULL,NULL,FALSE,NULL),
    ('enq: BI - create file','Other',NULL,NULL,FALSE,NULL),
    ('enq: BI - identify file','Other',NULL,NULL,FALSE,NULL),
    ('enq: BI - delete file','Other',NULL,NULL,FALSE,NULL),
    ('enq: BZ - resize file','Other',NULL,NULL,FALSE,NULL),
    ('enq: BV - rebuild/validate group','Other',NULL,NULL,FALSE,NULL),
    ('Backup Appliance container synchronous read','Other',NULL,NULL,FALSE,NULL),
    ('Backup Appliance container synchronous write','Other',NULL,NULL,FALSE,NULL),
    ('Backup Appliance container I/O','Other',NULL,NULL,FALSE,NULL),
    ('Supplemental logging roles','Other',NULL,NULL,FALSE,NULL),
    ('LogMiner builder: queue full','Other',NULL,NULL,FALSE,NULL),
    ('LogMiner reader: redo slot','Other',NULL,NULL,FALSE,NULL),
    ('LogMiner reader: memory','Other',NULL,NULL,FALSE,NULL),
    ('LogMiner merger: redo slot','Other',NULL,NULL,FALSE,NULL),
    ('LogMiner: txn','Other',NULL,NULL,FALSE,NULL),
    ('LogMiner: queue','Other',NULL,NULL,FALSE,NULL),
    ('LogMiner: session audit list','Other',NULL,NULL,FALSE,NULL),
    ('LogMiner FSC: dictionary load completion','Other',NULL,NULL,FALSE,NULL),
    ('enq: MN - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZL - LogMiner foreign log metadata','Other',NULL,NULL,FALSE,NULL),
    ('enq: PL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: CP - Pluggable database resetlogs','Other',NULL,NULL,FALSE,NULL),
    ('enq: SB - logical standby metadata','Other',NULL,NULL,FALSE,NULL),
    ('enq: SB - table instantiation','Other',NULL,NULL,FALSE,NULL),
    ('Logical Standby Apply shutdown','Other',NULL,NULL,FALSE,NULL),
    ('Logical Standby pin transaction','Other',NULL,NULL,FALSE,NULL),
    ('Logical Standby dictionary build','Other',NULL,NULL,FALSE,NULL),
    ('Logical Standby Terminal Apply','Other',NULL,NULL,FALSE,NULL),
    ('Logical Standby Debug','Other',NULL,NULL,FALSE,NULL),
    ('Resolution of in-doubt txns','Other',NULL,NULL,FALSE,NULL),
    ('enq: XR - quiesce database','Other',NULL,NULL,FALSE,NULL),
    ('enq: XR - database force logging','Other',NULL,NULL,FALSE,NULL),
    ('ADG query scn advance','Other',NULL,NULL,FALSE,NULL),
    ('ADG instance recovery complete','Other',NULL,NULL,FALSE,NULL),
    ('latch: obj/range reuse redo processing','Other',NULL,NULL,FALSE,NULL),
    ('standby query scn advance','Other',NULL,NULL,FALSE,NULL),
    ('change tracking file synchronous read','Other',NULL,NULL,FALSE,NULL),
    ('change tracking file synchronous write','Other',NULL,NULL,FALSE,NULL),

    ('change tracking file parallel write','Other',NULL,NULL,FALSE,NULL),
    ('block change tracking buffer space','Other',NULL,NULL,FALSE,NULL),
    ('CTWR media recovery checkpoint request','Other',NULL,NULL,FALSE,NULL),
    ('enq: CT - global space management','Other',NULL,NULL,FALSE,NULL),
    ('enq: CT - local space management','Other',NULL,NULL,FALSE,NULL),
    ('enq: CT - change stream ownership','Other',NULL,NULL,FALSE,NULL),
    ('enq: CT - state','Other',NULL,NULL,FALSE,NULL),
    ('enq: CT - state change gate 1','Other',NULL,NULL,FALSE,NULL),
    ('enq: CT - state change gate 2','Other',NULL,NULL,FALSE,NULL),
    ('enq: CT - CTWR process start/stop','Other',NULL,NULL,FALSE,NULL),
    ('enq: CT - reading','Other',NULL,NULL,FALSE,NULL),
    ('recovery area: computing dropped files','Other',NULL,NULL,FALSE,NULL),
    ('recovery area: computing obsolete files','Other',NULL,NULL,FALSE,NULL),
    ('recovery area: computing backed up files','Other',NULL,NULL,FALSE,NULL),
    ('recovery area: computing applied logs','Other',NULL,NULL,FALSE,NULL),
    ('enq: RS - file delete','Other',NULL,NULL,FALSE,NULL),
    ('enq: RS - record reuse','Other',NULL,NULL,FALSE,NULL),
    ('enq: RS - prevent file delete','Other',NULL,NULL,FALSE,NULL),
    ('enq: RS - prevent aging list update','Other',NULL,NULL,FALSE,NULL),
    ('enq: RS - persist alert level','Other',NULL,NULL,FALSE,NULL),
    ('enq: RS - read alert level','Other',NULL,NULL,FALSE,NULL),
    ('enq: RS - write alert level','Other',NULL,NULL,FALSE,NULL),
    ('enq: FL - Flashback database log','Other',NULL,NULL,FALSE,NULL),
    ('enq: FL - Flashback db command','Other',NULL,NULL,FALSE,NULL),
    ('enq: FD - Marker generation','Other',NULL,NULL,FALSE,NULL),
    ('enq: FD - Tablespace flashback on/off','Other',NULL,NULL,FALSE,NULL),
    ('enq: FD - Flashback coordinator','Other',NULL,NULL,FALSE,NULL),
    ('enq: FD - Flashback on/off','Other',NULL,NULL,FALSE,NULL),
    ('enq: FD - Restore point create/drop','Other',NULL,NULL,FALSE,NULL),
    ('enq: FD - Flashback logical operations','Other',NULL,NULL,FALSE,NULL),
    ('flashback free VI log','Other',NULL,NULL,FALSE,NULL),
    ('flashback log switch','Other',NULL,NULL,FALSE,NULL),
    ('enq: FW - contention','Other',NULL,NULL,FALSE,NULL),
    ('RVWR wait for flashback copy','Other',NULL,NULL,FALSE,NULL),
    ('parallel recovery read buffer free','Other',NULL,NULL,FALSE,NULL),
    ('parallel recovery redo cache buffer free','Other',NULL,NULL,FALSE,NULL),
    ('parallel recovery change buffer free','Other',NULL,NULL,FALSE,NULL),
    ('parallel recovery push change','Other',NULL,NULL,FALSE,NULL),
    ('cell smart flash keep','Other',NULL,NULL,FALSE,NULL),
    ('cell smart flash unkeep','Other',NULL,NULL,FALSE,NULL),
    ('cell ram cache population','Other',NULL,NULL,FALSE,NULL),
    ('parallel recovery coord: all replies','Other',NULL,NULL,FALSE,NULL),
    ('datafile move cleanup during resize','Other',NULL,NULL,FALSE,NULL),
    ('Nologging Standby Unit Test','Other',NULL,NULL,FALSE,NULL),
    ('Nonlogged block fetch','Other',NULL,NULL,FALSE,NULL),
    ('recovery receive buffer free','Other',NULL,NULL,FALSE,NULL),
    ('recovery cancel','Other',NULL,NULL,FALSE,NULL),
    ('recovery remote file verification','Other',NULL,NULL,FALSE,NULL),
    ('recovery active instance mapping setup','Other',NULL,NULL,FALSE,NULL),
    ('recovery new thread enable','Other',NULL,NULL,FALSE,NULL),

    ('recovery file header update for checkpoint','Other',NULL,NULL,FALSE,NULL),
    ('recovery file header update for fuzziness','Other',NULL,NULL,FALSE,NULL),
    ('recovery coordinator apply pending','Other',NULL,NULL,FALSE,NULL),
    ('recovery coordinator marker apply','Other',NULL,NULL,FALSE,NULL),
    ('recovery coordinator message','Other',NULL,NULL,FALSE,NULL),
    ('recovery merge pending','Other',NULL,NULL,FALSE,NULL),
    ('recovery metadata latch','Other',NULL,NULL,FALSE,NULL),
    ('recovery checkpoint','Other',NULL,NULL,FALSE,NULL),
    ('recovery apply pending','Other',NULL,NULL,FALSE,NULL),
    ('recovery fuzzy update','Other',NULL,NULL,FALSE,NULL),
    ('recovery shutdown','Other',NULL,NULL,FALSE,NULL),
    ('recovery message','Other',NULL,NULL,FALSE,NULL),
    ('recovery slaves to be informed','Other',NULL,NULL,FALSE,NULL),
    ('recovery move influx buffers','Other',NULL,NULL,FALSE,NULL),
    ('recovery marker apply','Other',NULL,NULL,FALSE,NULL),
    ('recovery timestamp','Other',NULL,NULL,FALSE,NULL),
    ('recovery send buffer free','Other',NULL,NULL,FALSE,NULL),
    ('DBMS_ROLLING instruction completion','Other',NULL,NULL,FALSE,NULL),
    ('Shadow lost write','Other',NULL,NULL,FALSE,NULL),
    ('blocking txn id for DDL','Other',NULL,NULL,FALSE,NULL),
    ('transaction','Other',NULL,NULL,FALSE,NULL),
    ('inactive transaction branch','Other',NULL,NULL,FALSE,NULL),
    ('txn to complete','Other',NULL,NULL,FALSE,NULL),
    ('PMON to cleanup pseudo-branches at svc stop time','Other',NULL,NULL,FALSE,NULL),
    ('PMON to cleanup detached branches at shutdown','Other',NULL,NULL,FALSE,NULL),
    ('test long ops','Other',NULL,NULL,FALSE,NULL),
    ('latch: undo global data','Other',NULL,NULL,FALSE,NULL),
    ('undo segment recovery','Other',NULL,NULL,FALSE,NULL),
    ('unbound tx','Other',NULL,NULL,FALSE,NULL),
    ('wait for change','Other',NULL,NULL,FALSE,NULL),
    ('wait for another txn - undo rcv abort','Other',NULL,NULL,FALSE,NULL),
    ('wait for another txn - txn abort','Other',NULL,NULL,FALSE,NULL),
    ('wait for another txn - rollback to savepoint','Other',NULL,NULL,FALSE,NULL),
    ('undo_retention publish retry','Other',NULL,NULL,FALSE,NULL),
    ('txn cache read version','Other',NULL,NULL,FALSE,NULL),
    ('enq: TA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TX - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: US - contention','Other',NULL,NULL,FALSE,NULL),
    ('wait for stopper event to be increased','Other',NULL,NULL,FALSE,NULL),
    ('wait for a undo record','Other',NULL,NULL,FALSE,NULL),
    ('wait for a paralle reco to abort','Other',NULL,NULL,FALSE,NULL),
    ('enq: IM - contention for blr','Other',NULL,NULL,FALSE,NULL),
    ('enq: TD - KTF dump entries','Other',NULL,NULL,FALSE,NULL),
    ('enq: TE - KTF broadcast','Other',NULL,NULL,FALSE,NULL),
    ('enq: CN - race with txn','Other',NULL,NULL,FALSE,NULL),
    ('enq: CN - race with reg','Other',NULL,NULL,FALSE,NULL),
    ('enq: CN - race with init','Other',NULL,NULL,FALSE,NULL),
    ('latch: Change Notification Hash table latch','Other',NULL,NULL,FALSE,NULL),
    ('enq: CO - master slave det','Other',NULL,NULL,FALSE,NULL),
    ('enq: FE - contention','Other',NULL,NULL,FALSE,NULL),

    ('latch: change notification client cache latch','Other',NULL,NULL,FALSE,NULL),
    ('latch: SGA Logging Log Latch','Other',NULL,NULL,FALSE,NULL),
    ('latch: SGA Logging Bkt Latch','Other',NULL,NULL,FALSE,NULL),
    ('enq: MC - Securefile log','Other',NULL,NULL,FALSE,NULL),
    ('enq: MF - flush bkgnd periodic','Other',NULL,NULL,FALSE,NULL),
    ('enq: MF - creating swap in instance','Other',NULL,NULL,FALSE,NULL),
    ('enq: MF - flush space','Other',NULL,NULL,FALSE,NULL),
    ('enq: MF - flush client','Other',NULL,NULL,FALSE,NULL),
    ('enq: MF - flush prior error','Other',NULL,NULL,FALSE,NULL),
    ('enq: MF - flush destroy','Other',NULL,NULL,FALSE,NULL),
    ('latch: ILM activity tracking latch','Other',NULL,NULL,FALSE,NULL),
    ('latch: ILM access tracking extent','Other',NULL,NULL,FALSE,NULL),
    ('IM CU busy','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZQ - register','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZQ - quiesce','Other',NULL,NULL,FALSE,NULL),
    ('IM ADG space pressure','Other',NULL,NULL,FALSE,NULL),
    ('enq: TF - contention','Other',NULL,NULL,FALSE,NULL),
    ('latch: lob segment hash table latch','Other',NULL,NULL,FALSE,NULL),
    ('latch: lob segment query latch','Other',NULL,NULL,FALSE,NULL),
    ('latch: lob segment dispenser latch','Other',NULL,NULL,FALSE,NULL),
    ('Wait for shrink lock2','Other',NULL,NULL,FALSE,NULL),
    ('Wait for shrink lock','Other',NULL,NULL,FALSE,NULL),
    ('L1 validation','Other',NULL,NULL,FALSE,NULL),
    ('Wait for TT enqueue','Other',NULL,NULL,FALSE,NULL),
    ('kttm2d','Other',NULL,NULL,FALSE,NULL),
    ('ktsambl','Other',NULL,NULL,FALSE,NULL),
    ('ktfbtgex','Other',NULL,NULL,FALSE,NULL),
    ('enq: DT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: FB - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: SK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DW - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: SU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TT - contention','Other',NULL,NULL,FALSE,NULL),
    ('ktm: instance recovery','Other',NULL,NULL,FALSE,NULL),
    ('instance state change','Other',NULL,NULL,FALSE,NULL),
    ('enq: SM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: SJ - Slave Task Cancel','Other',NULL,NULL,FALSE,NULL),
    ('Space Manager: slave messages','Other',NULL,NULL,FALSE,NULL),
    ('enq: FH - contention','Other',NULL,NULL,FALSE,NULL),
    ('latch: IM area scb latch','Other',NULL,NULL,FALSE,NULL),
    ('latch: IM area sb latch','Other',NULL,NULL,FALSE,NULL),
    ('enq: TZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: IN - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZB - contention','Other',NULL,NULL,FALSE,NULL),
    ('latch: IM seg hdr latch','Other',NULL,NULL,FALSE,NULL),
    ('latch: IM emb latch','Other',NULL,NULL,FALSE,NULL),
    ('Analyze hash compare','Other',NULL,NULL,FALSE,NULL),
    ('index block split','Other',NULL,NULL,FALSE,NULL),
    ('internal test event (index split branch)','Other',NULL,NULL,FALSE,NULL),

    ('internal test event (index split leaf)','Other',NULL,NULL,FALSE,NULL),
    ('kdblil wait before retrying ORA-54','Other',NULL,NULL,FALSE,NULL),
    ('dupl. cluster key','Other',NULL,NULL,FALSE,NULL),
    ('internal test event (index merge)','Other',NULL,NULL,FALSE,NULL),
    ('enq: DL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: HQ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: HP - contention','Other',NULL,NULL,FALSE,NULL),
    ('Securefile Write Gather Cache Yield Process','Other',NULL,NULL,FALSE,NULL),
    ('enq: KL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: WG - delete fso','Other',NULL,NULL,FALSE,NULL),
    ('enq: SL - get lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: SL - escalate lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: SL - get lock for undo','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZH - compression analysis','Other',NULL,NULL,FALSE,NULL),
    ('Compression analysis','Other',NULL,NULL,FALSE,NULL),
    ('enq: SZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZC - FS Seg contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZD - FS CU mod','Other',NULL,NULL,FALSE,NULL),
    ('enq: SY - IM populate by other session','Other',NULL,NULL,FALSE,NULL),
    ('enq: JZ - Join group dictionary','Other',NULL,NULL,FALSE,NULL),
    ('IM populate completion','Other',NULL,NULL,FALSE,NULL),
    ('IMXT Populate - drop HT','Other',NULL,NULL,FALSE,NULL),
    ('IM FastStart deadlock retry','Other',NULL,NULL,FALSE,NULL),
    ('IM ADO scheduler retry','Other',NULL,NULL,FALSE,NULL),
    ('latch: IMFS defer write list','Other',NULL,NULL,FALSE,NULL),
    ('IMFS Flush defer writes','Other',NULL,NULL,FALSE,NULL),
    ('In-Memory populate: over pga limit','Other',NULL,NULL,FALSE,NULL),
    ('latch: Column stats entry latch','Other',NULL,NULL,FALSE,NULL),
    ('row cache cleanup','Other',NULL,NULL,FALSE,NULL),
    ('row cache process','Other',NULL,NULL,FALSE,NULL),
    ('enq: QA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QB - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QC - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QD - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QE - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QI - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QJ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QN - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QQ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QT - contention','Other',NULL,NULL,FALSE,NULL),

    ('enq: QU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QV - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QX - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QY - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: QZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DV - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: SO - contention','Other',NULL,NULL,FALSE,NULL),
    ('RAC: row cache lock nowait retry','Other',NULL,NULL,FALSE,NULL),
    ('enq: VA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VB - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VC - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VD - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VE - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VI - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VJ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VN - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VQ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VV - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VX - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VY - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: VZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EB - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EC - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ED - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EE - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EI - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EJ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EN - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EQ - contention','Other',NULL,NULL,FALSE,NULL),

    ('enq: ER - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ES - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ET - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EV - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EX - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EY - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: EZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LB - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LC - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LD - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LE - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LI - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LJ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LN - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LQ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LV - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LX - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LY - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: LZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YB - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YC - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YD - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YE - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YI - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YJ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YN - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YQ - contention','Other',NULL,NULL,FALSE,NULL),

    ('enq: YR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YV - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YX - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YY - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: YZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GB - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GC - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GD - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GE - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GI - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GJ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GN - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GQ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GV - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GX - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GY - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: GZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NB - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NC - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ND - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NE - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NI - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NJ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NM - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NN - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NQ - contention','Other',NULL,NULL,FALSE,NULL),

    ('enq: NR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NV - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NX - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NY - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: NZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: IV - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: RW - MV metadata contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: OC - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: OL - contention','Other',NULL,NULL,FALSE,NULL),
    ('kkdlgon','Other',NULL,NULL,FALSE,NULL),
    ('kkdlsipon','Other',NULL,NULL,FALSE,NULL),
    ('kkdlhpon','Other',NULL,NULL,FALSE,NULL),
    ('Remote Tool Request Reply','Other',NULL,NULL,FALSE,NULL),
    ('Remote Tool Request Free List','Other',NULL,NULL,FALSE,NULL),
    ('kgltwait','Other',NULL,NULL,FALSE,NULL),
    ('kksfbc research','Other',NULL,NULL,FALSE,NULL),
    ('kksscl hash split','Other',NULL,NULL,FALSE,NULL),
    ('kksfbc child completion','Other',NULL,NULL,FALSE,NULL),
    ('enq: CU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: AE - lock','Other',NULL,NULL,FALSE,NULL),
    ('Revoke: get object','Other',NULL,NULL,FALSE,NULL),
    ('enq: PF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: PZ - flush passwordfile metadata','Other',NULL,NULL,FALSE,NULL),
    ('enq: PZ - load passwordfile metadata','Other',NULL,NULL,FALSE,NULL),
    ('enq: IL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: CL - drop label','Other',NULL,NULL,FALSE,NULL),
    ('enq: CL - compare labels','Other',NULL,NULL,FALSE,NULL),
    ('enq: SG - OLS Add Group','Other',NULL,NULL,FALSE,NULL),
    ('enq: SG - OLS Create Group','Other',NULL,NULL,FALSE,NULL),
    ('enq: SG - OLS Drop Group','Other',NULL,NULL,FALSE,NULL),
    ('enq: SG - OLS Alter Group Parent','Other',NULL,NULL,FALSE,NULL),
    ('enq: OP - OLS Store user entries','Other',NULL,NULL,FALSE,NULL),
    ('enq: OP - OLS Cleanup unused profiles','Other',NULL,NULL,FALSE,NULL),
    ('move audit tablespace delay','Other',NULL,NULL,FALSE,NULL),
    ('enq: CC - decryption','Other',NULL,NULL,FALSE,NULL),
    ('enq: MK - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: OW - initialization','Other',NULL,NULL,FALSE,NULL),
    ('enq: OW - termination','Other',NULL,NULL,FALSE,NULL),
    ('enq: RK - set key','Other',NULL,NULL,FALSE,NULL),
    ('enq: RK - queue wallet and TS keys','Other',NULL,NULL,FALSE,NULL),
    ('enq: HC - HSM cache write','Other',NULL,NULL,FALSE,NULL),
    ('enq: HC - HSM cache read','Other',NULL,NULL,FALSE,NULL),
    ('enq: RL - RAC wallet lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: PJ - modify DV policy','Other',NULL,NULL,FALSE,NULL),
    ('enq: PJ - read DV policy','Other',NULL,NULL,FALSE,NULL),
    ('Row cache for Grant or Revoke','Other',NULL,NULL,FALSE,NULL),

    ('enq: ZZ - update hash tables','Other',NULL,NULL,FALSE,NULL),
    ('Failed Logon Delay','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZA - add std audit table partition','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZF - add fga audit table partition','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZS - excl access to spill audit file','Other',NULL,NULL,FALSE,NULL),
    ('enq: UT - transfer audit records','Other',NULL,NULL,FALSE,NULL),
    ('enq: PA - modify a privilege capture','Other',NULL,NULL,FALSE,NULL),
    ('enq: PA - read a privilege capture','Other',NULL,NULL,FALSE,NULL),
    ('enq: PC - update privilege capture info','Other',NULL,NULL,FALSE,NULL),
    ('enq: PC - read privilege capture info','Other',NULL,NULL,FALSE,NULL),
    ('enq: KZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DX - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DR - contention','Other',NULL,NULL,FALSE,NULL),
    ('pending global transaction(s)','Other',NULL,NULL,FALSE,NULL),
    ('free global transaction table entry','Other',NULL,NULL,FALSE,NULL),
    ('library cache revalidation','Other',NULL,NULL,FALSE,NULL),
    ('library cache shutdown','Other',NULL,NULL,FALSE,NULL),
    ('BFILE closure','Other',NULL,NULL,FALSE,NULL),
    ('BFILE check if exists','Other',NULL,NULL,FALSE,NULL),
    ('BFILE check if open','Other',NULL,NULL,FALSE,NULL),
    ('BFILE get length','Other',NULL,NULL,FALSE,NULL),
    ('BFILE get name object','Other',NULL,NULL,FALSE,NULL),
    ('BFILE get path object','Other',NULL,NULL,FALSE,NULL),
    ('BFILE open','Other',NULL,NULL,FALSE,NULL),
    ('BFILE internal seek','Other',NULL,NULL,FALSE,NULL),
    ('resmgr:internal state cleanup','Other',NULL,NULL,FALSE,NULL),
    ('xdb schema cache initialization','Other',NULL,NULL,FALSE,NULL),
    ('ASM cluster file access','Other',NULL,NULL,FALSE,NULL),
    ('CSS initialization','Other',NULL,NULL,FALSE,NULL),
    ('CSS group registration','Other',NULL,NULL,FALSE,NULL),
    ('CSS group membership query','Other',NULL,NULL,FALSE,NULL),
    ('CSS operation: data query','Other',NULL,NULL,FALSE,NULL),
    ('CSS operation: data update','Other',NULL,NULL,FALSE,NULL),
    ('CSS Xgrp shared operation','Other',NULL,NULL,FALSE,NULL),
    ('CSS operation: query','Other',NULL,NULL,FALSE,NULL),
    ('CSS operation: action','Other',NULL,NULL,FALSE,NULL),
    ('CSS operation: diagnostic','Other',NULL,NULL,FALSE,NULL),
    ('GIPC operation: dump','Other',NULL,NULL,FALSE,NULL),
    ('GPnP Initialization','Other',NULL,NULL,FALSE,NULL),
    ('GPnP Termination','Other',NULL,NULL,FALSE,NULL),
    ('GPnP Get Item','Other',NULL,NULL,FALSE,NULL),
    ('GPnP Set Item','Other',NULL,NULL,FALSE,NULL),
    ('GPnP Get Error','Other',NULL,NULL,FALSE,NULL),
    ('ADR file lock','Other',NULL,NULL,FALSE,NULL),
    ('ADR block file read','Other',NULL,NULL,FALSE,NULL),
    ('ADR block file write','Other',NULL,NULL,FALSE,NULL),
    ('CRS call completion','Other',NULL,NULL,FALSE,NULL),
    ('ASM: OFS Cluster membership update','Other',NULL,NULL,FALSE,NULL),
    ('dispatcher shutdown','Other',NULL,NULL,FALSE,NULL),
    ('latch: virtual circuit queues','Other',NULL,NULL,FALSE,NULL),

    ('listen endpoint status','Other',NULL,NULL,FALSE,NULL),
    ('listener registration dump','Other',NULL,NULL,FALSE,NULL),
    ('OJVM: Generic','Other',NULL,NULL,FALSE,NULL),
    ('select wait','Other',NULL,NULL,FALSE,NULL),
    ('jobq slave shutdown wait','Other',NULL,NULL,FALSE,NULL),
    ('jobq slave TJ process wait','Other',NULL,NULL,FALSE,NULL),
    ('job scheduler coordinator slave wait','Other',NULL,NULL,FALSE,NULL),
    ('enq: JD - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: JQ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: OD - Serializing DDLs','Other',NULL,NULL,FALSE,NULL),
    ('RAC referential constraint parent lock','Other',NULL,NULL,FALSE,NULL),
    ('RAC: constraint DDL lock','Other',NULL,NULL,FALSE,NULL),
    ('kkshgnc reloop','Other',NULL,NULL,FALSE,NULL),
    ('optimizer stats update retry','Other',NULL,NULL,FALSE,NULL),
    ('wait active processes','Other',NULL,NULL,FALSE,NULL),
    ('SUPLOG PL wait for inflight pragma-d PL/SQL','Other',NULL,NULL,FALSE,NULL),
    ('enq: MD - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: MS - contention','Other',NULL,NULL,FALSE,NULL),
    ('wait for kkpo ref-partitioning *TEST EVENT*','Other',NULL,NULL,FALSE,NULL),
    ('RAC reference partitioning descendants lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: AP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: RH - quarantine','Other',NULL,NULL,FALSE,NULL),
    ('PX slave connection','Other',NULL,NULL,FALSE,NULL),
    ('PX slave release','Other',NULL,NULL,FALSE,NULL),
    ('PX Send Wait','Other',NULL,NULL,FALSE,NULL),
    ('PX qref latch','Other',NULL,NULL,FALSE,NULL),
    ('PX server shutdown','Other',NULL,NULL,FALSE,NULL),
    ('PX create server','Other',NULL,NULL,FALSE,NULL),
    ('PX signal server','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Join ACK','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq Credit: free buffer','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Test for msg','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Test for credit','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Signal ACK RSG','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Signal ACK EXT','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: reap credit','Other',NULL,NULL,FALSE,NULL),
    ('PX Nsq: PQ descriptor query','Other',NULL,NULL,FALSE,NULL),
    ('PX Nsq: PQ load info query','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq Credit: Session Stats','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Slave Session Stats','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Slave Join Frag','Other',NULL,NULL,FALSE,NULL),
    ('enq: PI - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: PS - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DA - Slave Process Array','Other',NULL,NULL,FALSE,NULL),
    ('latch: parallel query alloc buffer','Other',NULL,NULL,FALSE,NULL),
    ('kxfxse','Other',NULL,NULL,FALSE,NULL),
    ('kxfxsp','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Table Q qref','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Table Q Get Keys','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: Table Q Close','Other',NULL,NULL,FALSE,NULL),

    ('GV$: slave acquisition retry wait time','Other',NULL,NULL,FALSE,NULL),
    ('PX hash elem being inserted','Other',NULL,NULL,FALSE,NULL),
    ('latch: PX hash array latch','Other',NULL,NULL,FALSE,NULL),
    ('enq: AY - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ZP - Private Temporary Table','Other',NULL,NULL,FALSE,NULL),
    ('IMCDT end of scans cleanup','Other',NULL,NULL,FALSE,NULL),
    ('enq: IT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: BF - allocation contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: BF - PMON Join Filter cleanup','Other',NULL,NULL,FALSE,NULL),
    ('enq: RD - RAC load','Other',NULL,NULL,FALSE,NULL),
    ('PX key vector flatten','Other',NULL,NULL,FALSE,NULL),
    ('PX hash key vector cell','Other',NULL,NULL,FALSE,NULL),
    ('PX hash key vector merge','Other',NULL,NULL,FALSE,NULL),
    ('PX key vector use load','Other',NULL,NULL,FALSE,NULL),
    ('PX key vector create dgk init','Other',NULL,NULL,FALSE,NULL),
    ('enq: MG - MGA allocation','Other',NULL,NULL,FALSE,NULL),
    ('enq: MG - client shared context allocation','Other',NULL,NULL,FALSE,NULL),
    ('kupp process wait','Other',NULL,NULL,FALSE,NULL),
    ('Kupp process shutdown','Other',NULL,NULL,FALSE,NULL),
    ('Data Pump slave startup','Other',NULL,NULL,FALSE,NULL),
    ('Data Pump slave init','Other',NULL,NULL,FALSE,NULL),
    ('enq: KP - contention','Other',NULL,NULL,FALSE,NULL),
    ('Replication Dequeue','Other',NULL,NULL,FALSE,NULL),
    ('knpc_acwm_AwaitChangedWaterMark','Other',NULL,NULL,FALSE,NULL),
    ('knpc_anq_AwaitNonemptyQueue','Other',NULL,NULL,FALSE,NULL),
    ('knpsmai','Other',NULL,NULL,FALSE,NULL),
    ('enq: SR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: RG - Apply coord start/stop','Other',NULL,NULL,FALSE,NULL),
    ('REPL Capture/Apply: database startup','Other',NULL,NULL,FALSE,NULL),
    ('REPL Capture/Apply: miscellaneous','Other',NULL,NULL,FALSE,NULL),
    ('enq: SI - contention','Other',NULL,NULL,FALSE,NULL),
    ('REPL Capture/Apply: RAC inter-instance ack','Other',NULL,NULL,FALSE,NULL),
    ('enq: IA - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: JI - contention','Other',NULL,NULL,FALSE,NULL),
    ('qerex_gdml','Other',NULL,NULL,FALSE,NULL),
    ('enq: AT - contention','Other',NULL,NULL,FALSE,NULL),
    ('Retry DB Audit Record Insertion Delay','Other',NULL,NULL,FALSE,NULL),
    ('opishd','Other',NULL,NULL,FALSE,NULL),
    ('secure protocol error delay','Other',NULL,NULL,FALSE,NULL),
    ('kpodplck wait before retrying ORA-54','Other',NULL,NULL,FALSE,NULL),
    ('enq: CQ - contention','Other',NULL,NULL,FALSE,NULL),
    ('wait for EMON to spawn','Other',NULL,NULL,FALSE,NULL),
    ('EMON termination','Other',NULL,NULL,FALSE,NULL),
    ('enq: AZ - AQ_SRVNTFN_Q Creation','Other',NULL,NULL,FALSE,NULL),
    ('Emon coordinator startup','Other',NULL,NULL,FALSE,NULL),
    ('enq: SE - contention','Other',NULL,NULL,FALSE,NULL),
    ('tsm with timeout','Other',NULL,NULL,FALSE,NULL),
    ('Streams AQ: waiting for busy instance for instance_name','Other',NULL,NULL,FALSE,NULL),
    ('Streams AQ: index block pin/row lock','Other',NULL,NULL,FALSE,NULL),

    ('enq: TQ - TM contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - DDL contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - INI contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - DDL-INI contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - INI sq contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - MC free sync at cross job start','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - MC free sync at cross job stop','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - MC free sync at cross job end','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - MC free sync at export subshard','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - create eviction table','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - TM Job cache initialization','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - TM Job cache use','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - sq TM contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TQ - LB drop volatile shard','Other',NULL,NULL,FALSE,NULL),
    ('AQ reload SO release','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - Enqueue commit uncached','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - Enqueue commit cached','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - Dequeue update scn','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - Parallel cross update scn','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - Cross update scn','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - Trucate subshard','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - Cross export subshard','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - Cross import subshard','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - Free shadow shard','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ indexed cached commit','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ uncached commit WM update','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ uncached dequeue','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Eq Ptn Mapping','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Dq Ptn Mapping','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Trnc mem free','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Trnc mem free remote','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Trnc mem free by LB','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Trnc mem free by CP','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Enq commit incarnation wrap','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Rule evaluation segment load','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Evict: block truncate','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Unevict PGA: setup subscriber','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Unevict PGA: Queue View','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Shid Gen','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Enq commit block truncate','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Cross update scn for delay','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ Cross Shard mem free','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ rollback retry count update','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ cached commit WM update','Other',NULL,NULL,FALSE,NULL),
    ('enq: RQ - AQ cached dequeue by condition','Other',NULL,NULL,FALSE,NULL),
    ('AQ propagation connection','Other',NULL,NULL,FALSE,NULL),
    ('enq: KR - Drop rule force','Other',NULL,NULL,FALSE,NULL),
    ('enq: KR - Add rule to ruleset','Other',NULL,NULL,FALSE,NULL),
    ('enq: KR - Remove rule from ruleset','Other',NULL,NULL,FALSE,NULL),
    ('enq: DP - contention','Other',NULL,NULL,FALSE,NULL),

    ('enq: MH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: ML - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: PH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: SF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: XH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: WA - contention','Other',NULL,NULL,FALSE,NULL),
    ('Streams AQ: QueueTable kgl locks','Other',NULL,NULL,FALSE,NULL),
    ('AQ spill debug idle','Other',NULL,NULL,FALSE,NULL),
    ('AQ master shutdown','Other',NULL,NULL,FALSE,NULL),
    ('AQPC: new master','Other',NULL,NULL,FALSE,NULL),
    ('AQ Background Master: slave start','Other',NULL,NULL,FALSE,NULL),
    ('enq: AQ - QPT fg map dqpt','Other',NULL,NULL,FALSE,NULL),
    ('enq: AQ - QPT fg map qpt','Other',NULL,NULL,FALSE,NULL),
    ('enq: PQ - QPT add qpt','Other',NULL,NULL,FALSE,NULL),
    ('enq: PQ - QPT drop qpt','Other',NULL,NULL,FALSE,NULL),
    ('enq: PQ - QPT add dqpt','Other',NULL,NULL,FALSE,NULL),
    ('enq: PQ - QPT drop dqpt','Other',NULL,NULL,FALSE,NULL),
    ('enq: PQ - QPT add qpt fg','Other',NULL,NULL,FALSE,NULL),
    ('enq: PQ - QPT add dqpt fg','Other',NULL,NULL,FALSE,NULL),
    ('enq: PQ - QPT Trunc','Other',NULL,NULL,FALSE,NULL),
    ('enq: PQ - QPT LB Trunc sync','Other',NULL,NULL,FALSE,NULL),
    ('enq: PQ - QPT XSTART Trunc sync','Other',NULL,NULL,FALSE,NULL),
    ('AQ master: time mgmt/task cleanup','Other',NULL,NULL,FALSE,NULL),
    ('AQ slave: time mgmt/task cleanup','Other',NULL,NULL,FALSE,NULL),
    ('enq: BA - SUBBMAP contention','Other',NULL,NULL,FALSE,NULL),
    ('AQ:non durable subscriber add or drop','Other',NULL,NULL,FALSE,NULL),
    ('AQ: RAC AQ Network','Other',NULL,NULL,FALSE,NULL),
    ('latch: AQ Sharded subscriber statistics latch','Other',NULL,NULL,FALSE,NULL),
    ('AQ OPT Operation Complete','Other',NULL,NULL,FALSE,NULL),
    ('latch: AQ OPT Background Master Latch','Other',NULL,NULL,FALSE,NULL),
    ('enq: CX - TEXT: Index Specific Lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: OT - TEXT: Generic Lock','Other',NULL,NULL,FALSE,NULL),
    ('XDB SGA initialization','Other',NULL,NULL,FALSE,NULL),
    ('enq: XC - XDB Configuration','Other',NULL,NULL,FALSE,NULL),
    ('NFS read delegation outstanding','Other',NULL,NULL,FALSE,NULL),
    ('Data Guard Broker Wait','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - synch: DG Broker metadata','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - atomicity','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - Broker Chief Lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - synchronization: aifo master','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - new AI','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - synchronization: critical ai','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - RF - Database Automatic Disable','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - FSFO Observer Heartbeat','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - DG Broker Current File ID','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - FSFO Primary Shutdown suspended','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - Broker State Lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - FSFO string buffer','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - Broker NSV Lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: RF - Broker LSBY FO Lock','Other',NULL,NULL,FALSE,NULL),

    ('PX Deq: OLAP Update Reply','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: OLAP Update Execute','Other',NULL,NULL,FALSE,NULL),
    ('PX Deq: OLAP Update Close','Other',NULL,NULL,FALSE,NULL),
    ('enq: AW - AW$ table lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: AW - AW state lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: AW - user access for AW','Other',NULL,NULL,FALSE,NULL),
    ('enq: AW - AW generation lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: AG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: AO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: OQ - xsoqhiAlloc','Other',NULL,NULL,FALSE,NULL),
    ('enq: OQ - xsoqhiFlush','Other',NULL,NULL,FALSE,NULL),
    ('enq: OQ - xsoq*histrecb','Other',NULL,NULL,FALSE,NULL),
    ('enq: OQ - xsoqhiClose','Other',NULL,NULL,FALSE,NULL),
    ('enq: OQ - xsoqhistrecb','Other',NULL,NULL,FALSE,NULL),
    ('enq: IZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - client registration','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - shutdown','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - rollback COD reservation','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - background COD reservation','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM cache freeze','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM ACD Relocation','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - group use','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - group block','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM File Destroy','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM User','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Password File Update','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Amdu Dump','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - disk offline','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM reserved','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - block repair','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM disk based alloc/dealloc','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM file descriptor','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM file relocation','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM SR relocation','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Grow ACD','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM DD update SrRloc','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM file chown','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - Register with IOServer','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM metadata replication','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - SR slice Clear/Mark','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - Enable Remote ASM','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - Disable Remote ASM','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - Credential creation','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - Credential deletion','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM file access req','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM client operation','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM client check','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM ATB COD creation','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - Create default DG key in OCR','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Audit file Delete','Other',NULL,NULL,FALSE,NULL),

    ('enq: AM - ASM Audit file Cleanup','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM VAT migration','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - Update SR nomark flag','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM VAL cache','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM SR Segment Reuse','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM SR Segment Reuse Lookup','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM SR Batch Allocation','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Sparse Disk IOCTL','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM VAM Active','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Split Mirror File Create','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Split Mirror File Delete','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Mirror Prepare','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Mirror Split','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Drop Mirror','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM PDB Mirror Split','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - DB Mirror Prepare','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - DB Drop Mirror Copy','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - DB Mirror Split','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - PDB Mirror Split','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - Create Prepare Child file group','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - Change file group redundancy','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Split Mirror ODM File Crt','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Split Mirror ODM File Del','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASMB Startup','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASMB Renew','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM: group unblock','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM file create','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM ATE conversion','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM resync from ATE','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Split Status Write','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Split Status Read','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Client Assisted Offline','Other',NULL,NULL,FALSE,NULL),
    ('enq: AM - ASM Client Assisted Offline Chk','Other',NULL,NULL,FALSE,NULL),
    ('ASM internal hang test','Other',NULL,NULL,FALSE,NULL),
    ('ASM Instance startup','Other',NULL,NULL,FALSE,NULL),
    ('buffer busy','Other',NULL,NULL,FALSE,NULL),
    ('buffer freelistbusy','Other',NULL,NULL,FALSE,NULL),
    ('buffer rememberlist busy','Other',NULL,NULL,FALSE,NULL),
    ('buffer writeList full','Other',NULL,NULL,FALSE,NULL),
    ('no free buffers','Other',NULL,NULL,FALSE,NULL),
    ('buffer write wait','Other',NULL,NULL,FALSE,NULL),
    ('buffer invalidation wait','Other',NULL,NULL,FALSE,NULL),
    ('buffer dirty disabled','Other',NULL,NULL,FALSE,NULL),
    ('ASM metadata cache frozen','Other',NULL,NULL,FALSE,NULL),
    ('enq: FZ - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: CM - gate','Other',NULL,NULL,FALSE,NULL),
    ('enq: CM - instance','Other',NULL,NULL,FALSE,NULL),
    ('enq: CM - diskgroup dismount','Other',NULL,NULL,FALSE,NULL),
    ('enq: XQ - recovery','Other',NULL,NULL,FALSE,NULL),
    ('enq: XQ - relocation','Other',NULL,NULL,FALSE,NULL),

    ('enq: XQ - purification','Other',NULL,NULL,FALSE,NULL),
    ('enq: AD - allocate AU','Other',NULL,NULL,FALSE,NULL),
    ('enq: AD - deallocate AU','Other',NULL,NULL,FALSE,NULL),
    ('enq: AD - relocate AU','Other',NULL,NULL,FALSE,NULL),
    ('enq: AD - flush writes to AU','Other',NULL,NULL,FALSE,NULL),
    ('enq: DO - disk online','Other',NULL,NULL,FALSE,NULL),
    ('enq: DO - disk online recovery','Other',NULL,NULL,FALSE,NULL),
    ('enq: DO - Staleness Registry create','Other',NULL,NULL,FALSE,NULL),
    ('enq: DO - startup of MARK process','Other',NULL,NULL,FALSE,NULL),
    ('extent map load/unlock','Other',NULL,NULL,FALSE,NULL),
    ('extent map locked','Other',NULL,NULL,FALSE,NULL),
    ('enq: XL - fault extent map','Other',NULL,NULL,FALSE,NULL),
    ('Sync ASM rebalance','Other',NULL,NULL,FALSE,NULL),
    ('Sync ASM discovery','Other',NULL,NULL,FALSE,NULL),
    ('File Directory Use','Other',NULL,NULL,FALSE,NULL),
    ('enq: DG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DD - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: HD - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: DQ - contention','Other',NULL,NULL,FALSE,NULL),
    ('ASM ioctl to dematerialize blocks','Other',NULL,NULL,FALSE,NULL),
    ('enq: DN - contention','Other',NULL,NULL,FALSE,NULL),
    ('Cluster stabilization wait','Other',NULL,NULL,FALSE,NULL),
    ('Cluster Suspension wait','Other',NULL,NULL,FALSE,NULL),
    ('ASMB cookie valid check','Other',NULL,NULL,FALSE,NULL),
    ('ASM background starting','Other',NULL,NULL,FALSE,NULL),
    ('CSS cookie check','Other',NULL,NULL,FALSE,NULL),
    ('ASM db client exists','Other',NULL,NULL,FALSE,NULL),
    ('ASM file metadata operation','Other',NULL,NULL,FALSE,NULL),
    ('ASM network foreground exits','Other',NULL,NULL,FALSE,NULL),
    ('ASM check disk slices','Other',NULL,NULL,FALSE,NULL),
    ('enq: XB - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: FA - access file','Other',NULL,NULL,FALSE,NULL),
    ('enq: RX - relocate extent','Other',NULL,NULL,FALSE,NULL),
    ('enq: RX - unlock extent','Other',NULL,NULL,FALSE,NULL),
    ('enq: AR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: AH - contention','Other',NULL,NULL,FALSE,NULL),
    ('log write(odd)','Other',NULL,NULL,FALSE,NULL),
    ('log write(even)','Other',NULL,NULL,FALSE,NULL),
    ('checkpoint advanced','Other',NULL,NULL,FALSE,NULL),
    ('enq: FR - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: FR - use the thread','Other',NULL,NULL,FALSE,NULL),
    ('enq: FR - recover the thread','Other',NULL,NULL,FALSE,NULL),
    ('enq: FG - serialize ACD relocate','Other',NULL,NULL,FALSE,NULL),
    ('enq: FG - FG redo generation enq race','Other',NULL,NULL,FALSE,NULL),
    ('enq: FG - LGWR redo generation enq race','Other',NULL,NULL,FALSE,NULL),
    ('enq: FT - allow LGWR writes','Other',NULL,NULL,FALSE,NULL),
    ('enq: FT - disable LGWR writes','Other',NULL,NULL,FALSE,NULL),
    ('enq: FC - open an ACD thread','Other',NULL,NULL,FALSE,NULL),
    ('enq: FC - recover an ACD thread','Other',NULL,NULL,FALSE,NULL),
    ('enq: FX - issue ACD Xtnt Relocation CIC','Other',NULL,NULL,FALSE,NULL),

    ('rollback operations block full','Other',NULL,NULL,FALSE,NULL),
    ('rollback operations active','Other',NULL,NULL,FALSE,NULL),
    ('enq: RB - contention','Other',NULL,NULL,FALSE,NULL),
    ('ASM: MARK subscribe to msg channel','Other',NULL,NULL,FALSE,NULL),
    ('ASM: Send msg to MARK','Other',NULL,NULL,FALSE,NULL),
    ('IOS client reconnect to dif IOS','Other',NULL,NULL,FALSE,NULL),
    ('enq: II - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: IK - contention','Other',NULL,NULL,FALSE,NULL),
    ('IOS worker process startup','Other',NULL,NULL,FALSE,NULL),
    ('IOS worker process exit','Other',NULL,NULL,FALSE,NULL),
    ('call','Other',NULL,NULL,FALSE,NULL),
    ('enq: IC - IOServer clientID','Other',NULL,NULL,FALSE,NULL),
    ('enq: IF - file open','Other',NULL,NULL,FALSE,NULL),
    ('enq: IF - file close','Other',NULL,NULL,FALSE,NULL),
    ('enq: PT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: PT - ASM Storage May Split','Other',NULL,NULL,FALSE,NULL),
    ('enq: PM - contention','Other',NULL,NULL,FALSE,NULL),
    ('ASM concurrent diskgroup dismount','Other',NULL,NULL,FALSE,NULL),
    ('ASM PST operation','Other',NULL,NULL,FALSE,NULL),
    ('global cache busy','Other',NULL,NULL,FALSE,NULL),
    ('lock release pending','Other',NULL,NULL,FALSE,NULL),
    ('dma prepare busy','Other',NULL,NULL,FALSE,NULL),
    ('GCS lock cancel','Other',NULL,NULL,FALSE,NULL),
    ('GCS lock open S','Other',NULL,NULL,FALSE,NULL),
    ('GCS lock open X','Other',NULL,NULL,FALSE,NULL),
    ('GCS lock open','Other',NULL,NULL,FALSE,NULL),
    ('GCS lock cvt S','Other',NULL,NULL,FALSE,NULL),
    ('GCS lock cvt X','Other',NULL,NULL,FALSE,NULL),
    ('GCS lock esc X','Other',NULL,NULL,FALSE,NULL),
    ('GCS lock esc','Other',NULL,NULL,FALSE,NULL),
    ('GCS recovery lock open','Other',NULL,NULL,FALSE,NULL),
    ('GCS recovery lock convert','Other',NULL,NULL,FALSE,NULL),
    ('kfcl: instance recovery','Other',NULL,NULL,FALSE,NULL),
    ('no free locks','Other',NULL,NULL,FALSE,NULL),
    ('lock close','Other',NULL,NULL,FALSE,NULL),
    ('enq: KE - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: KQ - access ASM attribute','Other',NULL,NULL,FALSE,NULL),
    ('ASM Volume Background','Other',NULL,NULL,FALSE,NULL),
    ('ASM volume directive send','Other',NULL,NULL,FALSE,NULL),
    ('ASM Volume Resource Action','Other',NULL,NULL,FALSE,NULL),
    ('enq: AV - persistent DG number','Other',NULL,NULL,FALSE,NULL),
    ('enq: AV - volume relocate','Other',NULL,NULL,FALSE,NULL),
    ('enq: AV - AVD client registration','Other',NULL,NULL,FALSE,NULL),
    ('enq: AV - add/enable first volume in DG','Other',NULL,NULL,FALSE,NULL),
    ('ASM Scrubbing I/O','Other',NULL,NULL,FALSE,NULL),
    ('ASM Async Scrub','Other',NULL,NULL,FALSE,NULL),
    ('ASM Scrub Stop','Other',NULL,NULL,FALSE,NULL),
    ('ASM Scrub Running','Other',NULL,NULL,FALSE,NULL),
    ('ASM: VAM activation','Other',NULL,NULL,FALSE,NULL),
    ('DB Split Delay','Other',NULL,NULL,FALSE,NULL),

    ('enq: WF - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: WT - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: WP - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: FU - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: UF - undo stat flush per PDB','Other',NULL,NULL,FALSE,NULL),
    ('enq: WI - AWR import','Other',NULL,NULL,FALSE,NULL),
    ('enq: WE - AWR auto-export','Other',NULL,NULL,FALSE,NULL),
    ('enq: WD - AWR mail package retrieval','Other',NULL,NULL,FALSE,NULL),
    ('AWR Flush','Other',NULL,NULL,FALSE,NULL),
    ('AWR Metric Capture','Other',NULL,NULL,FALSE,NULL),
    ('enq: TB - SQL Tuning Base Cache Update','Other',NULL,NULL,FALSE,NULL),
    ('enq: TB - SQL Tuning Base Cache Load','Other',NULL,NULL,FALSE,NULL),
    ('enq: SH - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: AF - task serialization','Other',NULL,NULL,FALSE,NULL),
    ('MMON slave messages','Other',NULL,NULL,FALSE,NULL),
    ('MMON (Lite) shutdown','Other',NULL,NULL,FALSE,NULL),
    ('enq: MO - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: MM - MMON Autotask scheduling','Other',NULL,NULL,FALSE,NULL),
    ('enq: TL - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TH - metric threshold evaluation','Other',NULL,NULL,FALSE,NULL),
    ('enq: TK - Auto Task Serialization','Other',NULL,NULL,FALSE,NULL),
    ('enq: TK - Auto Task Slave Lockout','Other',NULL,NULL,FALSE,NULL),
    ('enq: RR - contention','Other',NULL,NULL,FALSE,NULL),
    ('WCR: RAC message context busy','Other',NULL,NULL,FALSE,NULL),
    ('WCR: capture file IO write','Other',NULL,NULL,FALSE,NULL),
    ('WCR: Sync context busy','Other',NULL,NULL,FALSE,NULL),
    ('latch: WCR: sync','Other',NULL,NULL,FALSE,NULL),
    ('latch: WCR: processes HT','Other',NULL,NULL,FALSE,NULL),
    ('enq: RA - RT ADDM flood control','Other',NULL,NULL,FALSE,NULL),
    ('enq: MW - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: TU - UMF topology','Other',NULL,NULL,FALSE,NULL),
    ('SPA slave messages','Other',NULL,NULL,FALSE,NULL),
    ('enq: JS - job run lock - synchronize','Other',NULL,NULL,FALSE,NULL),
    ('enq: JS - job recov lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: JS - wdw op','Other',NULL,NULL,FALSE,NULL),
    ('enq: JS - evt notify','Other',NULL,NULL,FALSE,NULL),
    ('enq: JS - aq sync','Other',NULL,NULL,FALSE,NULL),
    ('enq: JG - queue lock','Other',NULL,NULL,FALSE,NULL),
    ('enq: JG - q mem clnup lck','Other',NULL,NULL,FALSE,NULL),
    ('enq: JG - contention','Other',NULL,NULL,FALSE,NULL),
    ('enq: JG - sch locl enqs','Other',NULL,NULL,FALSE,NULL),
    ('enq: JG - evt notify','Other',NULL,NULL,FALSE,NULL),
    ('enq: JG - evtsub add','Other',NULL,NULL,FALSE,NULL),
    ('enq: JG - evtsub drop','Other',NULL,NULL,FALSE,NULL),
    ('enq: AU - ADR Purge Operation','Other',NULL,NULL,FALSE,NULL),
    ('enq: XD - ASM disk drop/add','Other',NULL,NULL,FALSE,NULL),
    ('enq: XD - ASM disk ONLINE','Other',NULL,NULL,FALSE,NULL),
    ('enq: XD - ASM disk OFFLINE','Other',NULL,NULL,FALSE,NULL),
    ('cell worker online completion','Other',NULL,NULL,FALSE,NULL),
    ('cell worker retry','Other',NULL,NULL,FALSE,NULL),

    ('cell manager cancel work request','Other',NULL,NULL,FALSE,NULL),
    ('cell manager: CRS DG unmounted list','Other',NULL,NULL,FALSE,NULL),
    ('cell manager: CRS DG start','Other',NULL,NULL,FALSE,NULL),
    ('opening cell offload device','Other',NULL,NULL,FALSE,NULL),
    ('ioctl to cell offload device','Other',NULL,NULL,FALSE,NULL),
    ('reap block level offload operations','Other',NULL,NULL,FALSE,NULL),
    ('enq: SN - PDB SGA allocation','Other',NULL,NULL,FALSE,NULL),
    ('enq: SN - PDB SGA free','Other',NULL,NULL,FALSE,NULL),
    ('enq: SN - PDB SGA protection','Other',NULL,NULL,FALSE,NULL),
    ('CDB: Per Instance Query for PDB Info','Other',NULL,NULL,FALSE,NULL),
    ('PDB relocate completion','Other',NULL,NULL,FALSE,NULL),
    ('enq: PB - PDB Lock','Other',NULL,NULL,FALSE,NULL),
    ('chunk move metadata prefetch','Other',NULL,NULL,FALSE,NULL),
    ('secondary event','Other',NULL,NULL,FALSE,NULL),
    ('checkpoint completed','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('memoptimize write buffer get','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('SecureFile log buffer','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('nologging range consumption list','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('statement suspended wait error to be cleared','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('Global transaction acquire instance locks','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('flashback buf free by RVWR','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('wait for EMON to process ntfns','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('REPL Apply: commit','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('IM buffer busy SHR','Concurrency','buffer_busy','table_only',FALSE,'In-Memory buffer contention — concurrent access to an In-Memory Column Store (IMCS) buffer for a table. Root cause: high concurrent read/write on an In-Memory populated table. (1) Review IMCS population status and compression. (2) Check for concurrent DML invalidating IMCS buffers. (3) Review INMEMORY_MAX_POPULATE_SERVERS setting.'),
    ('library cache lock','Concurrency','none','none',TRUE,'Library cache object lock contention — DDL on a hot object or procedure recompilation. (1) Avoid DDL on hot procedures/packages during peak hours. (2) Check DBA_OBJECTS for INVALID objects auto-recompiling. (3) Review dependency chains — compilations cascade to dependents.'),
    ('library cache load lock','Concurrency','none','none',TRUE,'Library cache load contention — multiple sessions loading the same object simultaneously. (1) Pin critical packages with DBMS_SHARED_POOL.KEEP. (2) Pre-warm library cache after startup. (3) Reduce invalidation frequency.'),
    ('library cache: mutex X','Concurrency','none','none',TRUE,'Library cache mutex contention — high parse rate. (1) Enforce bind variable usage. (2) Review CURSOR_SHARING parameter. (3) Tune SESSION_CACHED_CURSORS and OPEN_CURSORS.'),
    ('library cache: dependency mutex X','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('latch: MGA shared context root latch','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('latch: MGA shared context latch','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('latch: MGA heap latch','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('latch: MGA pid alloc latch','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('latch: MGA asr alloc latch','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('latch: Undo Hint Latch','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('latch: In memory undo latch','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('latch: MQL Tracking Latch','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('log file sync: SCN ordering','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('logout restrictor','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('pipe put','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('resmgr:internal state change','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('resmgr:sessions to exit','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('result cache lock wait','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('db file sequential read','User I/O','io_read','index_only',TRUE,'Single-block I/O — index leaf/branch reads or ROWID table access after an index lookup. Root cause: deep B-tree (high BLEVEL), poor clustering factor, or buffer cache miss on hot index blocks. (1) Check BLEVEL of hot indexes — rebuild if BLEVEL > 4. (2) Check clustering_factor vs num_rows — if ratio > 0.5, consider reorganising the table. (3) Increase DB_CACHE_SIZE or assign hot indexes to the KEEP buffer pool.'),
    ('direct path read','User I/O','io_read','table_only',TRUE,'Multi-block read bypassing buffer cache — full table scan, parallel query, or large LOB read. Root cause: missing partition pruning, missing selective index, or intentional analytics scan. (1) Check for missing indexes on high-selectivity filter columns. (2) For analytics: validate partition pruning is active and parallel degree is appropriate. (3) For LOB reads: consider SecureFile LOB with CACHE option.'),
    ('db file scattered read','User I/O','io_read','table_only',TRUE,'Multi-block scattered read — full table or fast full index scan in non-parallel context. Root cause: missing indexes or large range scans. (1) Identify the full-scan SQL in Top SQL dashboard. (2) Set DB_FILE_MULTIBLOCK_READ_COUNT appropriately (128 for SSD). (3) Consider parallel query to shift reads to direct path for large analytics.'),
    ('cell smart table scan','User I/O','io_read','table_only',FALSE,'Exadata smart scan of a table — full segment scan offloaded to storage cell. Root cause: missing partition pruning or large analytics scan. (1) Enable storage index via partition pruning. (2) Check cell offload eligibility. (3) Review predicate pushdown to storage cells.'),
    ('cell smart index scan','User I/O','io_read','index_only',FALSE,'Exadata smart scan of an index — index read offloaded to storage cell. Root cause: deep B-tree or large index range scan. (1) Check BLEVEL of hot indexes. (2) Ensure cell offload is enabled for index scans. (3) Review index selectivity.'),
    ('cell single block physical read','User I/O','io_read','index_only',FALSE,'Exadata single-block physical read — equivalent to db file sequential read on Exadata. Root cause: index block read or ROWID lookup. (1) Check BLEVEL and clustering factor of hot indexes. (2) Review buffer cache hit ratio. (3) Assign hot indexes to the KEEP buffer pool.'),
    ('cell multiblock read request','User I/O','io_read','table_only',FALSE,'Exadata multiblock read request — storage cell multiblock read for table/LOB scans. (1) Review partition pruning. (2) Check cell offload eligibility. (3) Validate parallel degree for large scans.'),
    ('row cache lock','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),

    ('row cache mutex','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('row cache read','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('Shared IO Pool Memory','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('Unpin a recreatable chunk','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('LCK0 row cache object free','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('libcache interrupt action by LCK','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('db flash cache invalidate wait','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('enq: IV - cross instance invalidation','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('enq: CB - role operation','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('enq: RI - Reader Farm SQL Isolation','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('enq: TG - IMCDT global resource','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('enq: TI - IMCDT object HT','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('enq: KV - IMA key vector access','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('enq: BE - Critical Block Allocation','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('enq: HV - contention','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('enq: WG - lock fso','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('securefile chain update','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('Parameter File I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('SecureFile mutex','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('Cube Build Master Wait for Jobs','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('REPL Apply: dependency','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('Inmemory Populate: get loadscn','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('SQL*Net break/reset to dblink','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('External Procedure initial connection','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('External Procedure call','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('OLAP DML Sleep','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('REPL Apply: apply DDL','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('REPL Capture: filter callback ruleset','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('WCR: replay lock order','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('enq: UL - contention','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('enq: KO - fast object checkpoint','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('enq: PW - flush prewarm buffers','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('enq: RC - Result Cache: Contention','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('enq: RO - contention','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('enq: RO - fast object reuse','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('gc buffer busy acquire','Cluster','gc_cluster','all',TRUE,'RAC global cache block contention — hot blocks being transferred between instances. (1) Configure service affinity to route related transactions to the same instance. (2) Partition hot tables and pin partitions to specific instances. (3) Review interconnect bandwidth on SAR network dashboard.'),
    ('gc buffer busy release','Cluster','gc_cluster','all',TRUE,'RAC global cache block release wait. (1) Configure service affinity. (2) Review interconnect latency — target < 1ms. (3) Check for unindexed FK columns causing cross-instance TM lock shipping.'),
    ('gc cr request','Cluster','gc_cluster','all',TRUE,'RAC consistent-read block transfer — instance requesting a CR copy from another instance. (1) Configure read workload affinity per service. (2) Increase buffer cache size to reduce cross-instance reads. (3) Verify interconnect latency < 1ms on SAR dashboard.'),
    ('Standby redo I/O','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('Network file transfer','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('File Repopulation Write','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('PBR logfile IO','System I/O','none','none',FALSE,'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.'),
    ('library cache: mutex S','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('db file parallel write','System I/O','io_write','all',TRUE,'DBWR writing dirty buffers to datafiles. Root cause: data file device latency, insufficient DBWn processes, or checkpoint storms. (1) Check data file storage latency on SAR I/O dashboard. (2) Increase DB_WRITER_PROCESSES. (3) Enable async I/O (FILESYSTEMIO_OPTIONS=SETALL or use ASM).'),
    ('DBWR slave I/O','System I/O','io_write','all',FALSE,'DBWR slave process writing dirty buffers — same root cause as db file parallel write. (1) Check data file storage latency on SAR I/O dashboard. (2) Increase DB_WRITER_PROCESSES if this slave is bottlenecked. (3) Enable async I/O.'),
    ('control file sequential read','System I/O','none','none',TRUE,'Control file read by background process (ARCn, RMAN, CKPT). No user segment involved. (1) Ensure all control file copies are on fast storage. (2) Reduce log switch frequency by increasing redo log file size. (3) Review RMAN backup schedule — frequent backups update the control file repeatedly.'),
    ('control file parallel write','System I/O','none','none',TRUE,'Control file write by background process (log switches, checkpoints, RMAN). No user segment involved. (1) Ensure all control file copies are on fast storage (avoid NFS-mounted paths). (2) Reduce log switch frequency. (3) Review RMAN backup frequency during peak hours.'),
    ('gc current request','Cluster','gc_cluster','all',TRUE,'RAC current block transfer — requesting writable copy from another instance. (1) Route DML transactions to a single primary instance via services. (2) Hash partition high-DML tables with partition-wise service routing. (3) Check for unindexed FK columns.'),
    ('gc cr block 2-way','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr block 3-way','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),

    ('gc cr block congested','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr block remote read','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr failure','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr grant 2-way','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr grant 3-way','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr grant busy','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr grant congested','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr grant ka','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr block busy','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('log file sync','Commit','none','none',TRUE,'Session waiting for LGWR to flush redo on commit. No segment involved — this is redo I/O latency. (1) Move redo logs to dedicated fast storage (SSDs). (2) Batch application commits to reduce flush frequency. (3) Increase LOG_BUFFER to 256MB–1GB.'),
    ('remote log force - commit','Commit','none','none',FALSE,'Commit/redo synchronisation wait — no user segment involved. Root cause: redo I/O latency or distributed transaction coordination overhead. (1) Check redo log storage latency on SAR dashboard. (2) Review distributed transaction (dblink) commit frequency. (3) Batch commits where possible to reduce LGWR flush overhead.'),
    ('nologging standby txn commit','Commit','none','none',FALSE,'Commit/redo synchronisation wait — no user segment involved. Root cause: redo I/O latency or distributed transaction coordination overhead. (1) Check redo log storage latency on SAR dashboard. (2) Review distributed transaction (dblink) commit frequency. (3) Batch commits where possible to reduce LGWR flush overhead.'),
    ('Nologging standby progress','Commit','none','none',FALSE,'Commit/redo synchronisation wait — no user segment involved. Root cause: redo I/O latency or distributed transaction coordination overhead. (1) Check redo log storage latency on SAR dashboard. (2) Review distributed transaction (dblink) commit frequency. (3) Batch commits where possible to reduce LGWR flush overhead.'),
    ('enq: BB - 2PC across RAC instances','Commit','none','none',FALSE,'Commit/redo synchronisation wait — no user segment involved. Root cause: redo I/O latency or distributed transaction coordination overhead. (1) Check redo log storage latency on SAR dashboard. (2) Review distributed transaction (dblink) commit frequency. (3) Batch commits where possible to reduce LGWR flush overhead.'),
    ('free buffer waits','Configuration','buffer_busy','all',TRUE,'Server process cannot find a free buffer — DBWn not writing dirty buffers fast enough. (1) Check data file I/O latency on SAR dashboard. (2) Increase DB_WRITER_PROCESSES. (3) Increase DB_CACHE_SIZE if memory allows.'),
    ('write complete waits','Configuration','buffer_busy','all',FALSE,'Session waiting for a buffer write to complete before it can be modified. Root cause: slow storage causing write-side buffer contention. (1) Check data file storage latency. (2) Review DB_WRITER_PROCESSES count. (3) Enable async I/O if not already enabled.'),
    ('write complete waits: flash cache','Configuration','buffer_busy','all',FALSE,'Session waiting for a flash cache write to complete. Root cause: flash cache device latency or saturation. (1) Check flash cache device health and performance. (2) Review flash cache sizing (DB_FLASH_CACHE_SIZE). (3) Consider disabling flash cache if device is consistently bottlenecked.'),
    ('enq: TX - allocate ITL entry','Configuration','buffer_busy','all',FALSE,'Insufficient ITL (Interested Transaction List) entries in a block — concurrent transactions cannot fit their ITL entries. (1) Increase INITRANS on the hot table or index. (2) Increase PCTFREE to leave more space for ITL expansion. (3) Review concurrent DML patterns on the affected object.'),
    ('undo segment extension','Configuration','none','none',FALSE,'Undo segment needing to extend — undo tablespace space or extent allocation delay. No user data segment involved. (1) Increase undo tablespace size. (2) Increase UNDO_RETENTION to reduce premature undo reuse. (3) Enable RETENTION GUARANTEE on the undo tablespace.'),
    ('cell single block read request','User I/O','io_read','index_only',FALSE,'Exadata single-block read request — index or ROWID read submitted to storage cell. Root cause same as db file sequential read. (1) Check hot indexes for high BLEVEL. (2) Review buffer cache sizing. (3) Check storage cell response times.'),
    ('log buffer space','Configuration','none','none',TRUE,'Redo log buffer exhausted — sessions cannot write redo fast enough. (1) Increase LOG_BUFFER to 256MB–1GB. (2) Check LGWR latency (log file parallel write). (3) Reduce unnecessary redo — use NOLOGGING for bulk loads.'),
    ('enq: HW - contention','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('enq: ST - contention','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('sort segment request','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('enq: SQ - contention','Configuration','none','none',FALSE,'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.'),
    ('buffer busy waits','Concurrency','buffer_busy','all',TRUE,'Multiple sessions competing for the same buffer block. Root cause: hot segment blocks — frequently updated index leaf blocks or hot table rows. (1) Increase INITRANS on hot tables/indexes. (2) For index leaf contention: consider reverse-key index or hash partitioning. (3) For sequence inserts: use sequence cache to reduce monotonic clustering.'),
    ('enq: TX - index contention','Concurrency','buffer_busy','index_only',FALSE,'Index block split contention — a session is waiting for another to complete an index block split. Root cause: right-side index block splits on monotonically increasing keys (sequences, timestamps). (1) Consider reverse-key index for sequence-generated keys. (2) Use hash partitioning to distribute inserts. (3) Increase index INITRANS to reduce split frequency.'),
    ('IM buffer busy','Concurrency','buffer_busy','table_only',FALSE,'In-Memory buffer contention — concurrent access to an In-Memory Column Store (IMCS) buffer for a table. Root cause: high concurrent read/write on an In-Memory populated table. (1) Review IMCS population status and compression. (2) Check for concurrent DML invalidating IMCS buffers. (3) Review INMEMORY_MAX_POPULATE_SERVERS setting.'),
    ('IM buffer busy TXN','Concurrency','buffer_busy','table_only',FALSE,'In-Memory buffer contention — concurrent access to an In-Memory Column Store (IMCS) buffer for a table. Root cause: high concurrent read/write on an In-Memory populated table. (1) Review IMCS population status and compression. (2) Check for concurrent DML invalidating IMCS buffers. (3) Review INMEMORY_MAX_POPULATE_SERVERS setting.'),
    ('latch: cache buffers chains','Concurrency','none','none',TRUE,'Hot block contention at the latch level — a buffer block is accessed by so many concurrent sessions that the latch serialises access. (1) Identify the hot block using X$BH (addr, obj, tch columns). (2) For sequence inserts: enable sequence caching, consider reverse-key index. (3) Hash partition the hot segment to spread block access.'),
    ('latch: shared pool','Concurrency','none','none',TRUE,'Shared pool latch contention — heavy parse activity or fragmentation. (1) Enforce bind variable usage across all application SQL. (2) Increase SHARED_POOL_SIZE. (3) Pin critical packages with DBMS_SHARED_POOL.KEEP.'),
    ('latch: row cache objects','Concurrency','none','none',TRUE,'Data dictionary (row cache) latch contention. (1) Avoid DDL during peak hours. (2) Increase SHARED_POOL_SIZE. (3) Reduce metadata-intensive operations.'),
    ('cursor: pin S wait on X','Concurrency','none','none',TRUE,'Cursor pin contention — a session holds an exclusive cursor pin while others wait for shared. (1) Enforce bind variable usage to reduce hard parse rate. (2) Avoid DDL on hot objects during peak. (3) Review CURSOR_INVALIDATION parameter (12.2+).'),
    ('cursor: mutex X','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('cursor: mutex S','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('cursor: pin X','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('cursor: pin S','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('library cache pin','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('library cache: bucket mutex X','Concurrency','none','none',FALSE,'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.'),
    ('cell multiblock physical read','User I/O','io_read','table_only',FALSE,'Exadata multiblock physical read — full table or LOB scan on storage cells. (1) Review partition pruning on scanned tables. (2) Validate storage cell offload efficiency. (3) Check if parallel query is appropriate for the scan pattern.'),
    ('enq: TX - row lock contention','Application','row_lock','all',TRUE,'Row-level lock contention — sessions blocking each other on the same rows. (1) Identify blocking sessions from AWR Active Session History. (2) Ensure frequent commits in high-DML batch processes. (3) Review INITRANS on hot tables — increase to allow more concurrent row-level modifications.'),
    ('enq: TM - contention','Application','row_lock','all',TRUE,'Table-level lock contention — most commonly caused by DML on a parent table with an unindexed foreign key on the child. (1) Identify unindexed FK columns: query DBA_CONSTRAINTS joined to DBA_IND_COLUMNS. (2) Create indexes on all FK columns in child tables. (3) Avoid concurrent DDL on high-DML tables.'),
    ('Wait for Table Lock','Application','row_lock','table_only',FALSE,'Waiting for a table-level lock held by another session. Root cause: DDL-DML contention or explicit LOCK TABLE statement. (1) Identify the blocking session and its lock type from V$LOCK and V$SESSION. (2) Avoid DDL (ALTER, DROP, TRUNCATE) on tables with concurrent DML during peak hours. (3) Review application for unnecessary LOCK TABLE statements.'),
    ('SQL*Net break/reset to client','Application','none','none',FALSE,'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.'),
    ('gc cr block lost','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr grant read-mostly invalidation','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('cell list of blocks physical read','User I/O','io_read','all',FALSE,'Exadata list-of-blocks physical read — targeted block read from storage cells. Can involve any segment type. (1) Identify the SQL driving this read pattern. (2) Review execution plan for the targeted segment. (3) Check storage cell performance.'),
    ('cell list of blocks read request','User I/O','io_read','all',FALSE,'Exadata list-of-blocks read request — targeted block list read submitted to cells. Can involve any segment type. (1) Identify the SQL driving this. (2) Review execution plan. (3) Check storage cell response times.'),
    ('db file parallel read','User I/O','io_read','all',FALSE,'Parallel block read — used during parallel recovery or parallel prefetch. All segment types may be involved. (1) If during normal operations: check for parallel query prefetch activity. (2) If during recovery: normal and expected. (3) Review storage I/O throughput on SAR dashboard.'),
    ('local write wait','User I/O','io_write','all',FALSE,'Session waiting for a local write to complete — typically a dirty buffer being written before it can be reused. Root cause: slow storage or DBWn contention. (1) Check data file storage latency on SAR dashboard. (2) Review DB_WRITER_PROCESSES. (3) Enable async I/O.'),

    ('db file single write','User I/O','io_write','all',FALSE,'Single-block write — file header update or single block flush. Root cause: slow storage on file header device or checkpoint activity. (1) Check file header I/O latency. (2) Review checkpoint frequency. (3) Verify all datafile paths have adequate I/O performance.'),
    ('securefile direct-read completion','User I/O','io_read','table_only',FALSE,'SecureFile LOB direct read completion — reading LOB data outside the buffer cache. Root cause: LOB NOCACHE or large LOB access frequency. (1) Convert to SecureFile LOBs with CACHE option. (2) Consider LOB compression for large objects. (3) Review whether LOB data should be externalised for very large files.'),
    ('securefile direct-write completion','User I/O','io_write','table_only',FALSE,'SecureFile LOB direct write completion — writing LOB data directly to storage. Root cause: high-frequency LOB writes. (1) Review LOB write frequency in application. (2) Consider SecureFile with compression. (3) Ensure LOB tablespace is on fast storage.'),
    ('read by other session','User I/O','buffer_busy','all',TRUE,'Session waiting for another session to finish loading a block from disk. Root cause: buffer cache too small causing repeated cold reads of hot blocks. (1) Increase DB_CACHE_SIZE to retain hot blocks. (2) Assign critical lookup tables to KEEP buffer pool. (3) Reduce full scans that evict hot blocks from cache.'),
    ('buffer read retry','User I/O','buffer_busy','all',FALSE,'Block read retry — block being read was found to be invalid or in flux, requiring a retry. Root cause: hot block being concurrently modified. (1) Check for buffer busy waits on the same segments. (2) Increase INITRANS on hot tables/indexes. (3) Review concurrent DML patterns on hot objects.'),
    ('direct path write','User I/O','io_write','all',TRUE,'Direct path write — bulk load (CTAS, INSERT APPEND) bypassing buffer cache, or sort/hash spill to temp. (1) Check PGA usage — increase PGA_AGGREGATE_TARGET to reduce sort/hash spills. (2) For bulk loads: ensure NOLOGGING is used where applicable. (3) Validate temp tablespace I/O throughput on SAR dashboard.'),
    ('direct path read temp','User I/O','none','none',FALSE,'Temp tablespace read — sort/hash workarea spilling to temp. No user segment involved. (1) Increase PGA_AGGREGATE_TARGET. (2) Identify spilling SQL via V$SQL_WORKAREA_ACTIVE. (3) Ensure temp tablespace is on fast SSD storage.'),
    ('direct path write temp','User I/O','none','none',FALSE,'Temp tablespace write — sort/hash workarea spilling to temp. No user segment involved. (1) Increase PGA_AGGREGATE_TARGET. (2) Review execution plans for large sort/hash joins. (3) Add sort-elimination indexes where ORDER BY is frequent.'),
    ('Disk file I/O Calibration','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('Disk file Mirror Read','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('Disk file Mirror/Media Repair Write','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('Disk file operations I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('Data file init write','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('Log file init write','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('File Copy','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('Pluggable Database file copy','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('Shared IO Pool IO Completion','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('Datapump dump file I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('dbms_file_transfer I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('DG Broker configuration file I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('dbverify reads','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('BFILE read','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('utl_file I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('TEXT: File System I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('DNFS disp IO slave completion','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('external table read','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('external table write','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('external table open','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('external table seek','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('external table misc IO','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('ASM sync cache disk read','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('ASM IO for non-blocking poll','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('ASM Fixed Package I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('ASM Staleness File I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('ASM File Group Sync','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('Archive Manager file transfer I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('flashback log file sync','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('direct path sync','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('cell smart file creation','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('cell statistics gather','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('cell external table smart scan','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('cell physical read no I/O','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('db flash cache single block physical read','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('db flash cache multiblock physical read','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('db flash cache write','User I/O','none','none',FALSE,'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.'),
    ('control file single write','System I/O','none','none',FALSE,'Control file single-block write — usually a file header or checkpoint record update. No user segment involved. (1) Ensure control file copies are on fast storage. (2) This is typically low-frequency and benign unless it dominates wait time. (3) Correlate with log switch frequency if elevated.'),
    ('log file parallel write','System I/O','none','none',TRUE,'LGWR writing redo to redo log files — redo storage latency. No segment involved. (1) Move redo logs to dedicated SSD. (2) Enable write-back cache on the redo log storage device. (3) Verify redo log multiplexing does not include slow members.'),
    ('gc cr grant read-only instance invalidation','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr grant cluster flash cache read','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr cluster flash cache read','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),

    ('gc cr disk read','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr flash cache copy','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr multi block request','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr multi block mixed','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr multi block grant','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr cancel','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc cr disk request','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current block 2-way','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current block 3-way','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current block busy','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current block congested','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current block lost','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current retry','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current split','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current cancel','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current grant 2-way','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current grant 3-way','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current grant busy','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current grant congested','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current grant ka','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current grant cluster flash cache read','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current grant read-mostly invalidation','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current grant read-only instance invalidation','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current multi block request','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc current index split','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc block recovery request','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('DFS lock handle','Other','none','none',TRUE,'RAC global lock manager (DLM) contention. (1) Identify the specific resource from ASH (P1/P2 values). (2) Review object partitioning and service affinity to reduce DLM contention. (3) Check GCS/GES background process activity and interconnect latency.'),
    ('gc imc multi block request','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc imc multi block quiesce','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('gc index operation','Cluster','gc_cluster','all',FALSE,'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.'),
    ('ASM PST query : wait for [PM][grp][0] grant','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('lock remastering','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc transaction table','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc freelist','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc remaster','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc quiesce','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc recovery','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc flushed buffer','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc send complete','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc assume','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc domain validation','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc recovery free','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc recovery quiesce','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc claim','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('gc cancel retry','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('Service operation completion','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('service monitor: inst recovery completion','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('retry contact SCN lock master','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('pi renounce write complete','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('remote log force - buffer update','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),

    ('remote log force - buffer read','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('remote log force - SCN range','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('remote log force - session cleanout','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('remote log force - log switch/recovery','Cluster','none','none',FALSE,'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.'),
    ('SQL*Net message from client','Idle','none','none',TRUE,'Idle wait — session waiting for the next request from the client. Not a database bottleneck. (1) If this dominates DB time, focus on the non-idle waits. (2) Review connection pool min/max sizing. (3) Implement idle session timeout to release unused connections.'),
    ('SQL*Net more data to client','Network','none','none',TRUE,'Large resultset transfer to client — network or fetch bottleneck. (1) Implement result pagination (ROWNUM/ROW_NUMBER). (2) Avoid SELECT * on wide tables. (3) Increase SDU for batch/reporting connections.'),
    ('SQL*Net message from dblink','Network','none','none',FALSE,'Session waiting for a response from a remote database over a database link. No local segment involved. (1) Check network latency between local and remote DB. (2) Review the query using the dblink — avoid fetching large result sets row-by-row. (3) Consider materialising frequently-accessed remote data locally.'),
    ('remote db operation','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('ASM remote SQL','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('remote db file write','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('remote db file read','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('IPC group service call','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('Data Guard network buffer stall reap','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('ARCH wait for net re-connect','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('ARCH wait for netserver start','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('LNS wait on LGWR','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('LGWR wait on LNS','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('ARCH wait for netserver init 2','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('ARCH wait for flow-control','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('ARCH wait for netserver detach','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('TCP Socket (KGAS)','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('virtual circuit wait','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('dispatcher listen timer','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('dedicated server timer','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('connection broker handoff','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('SQL*Net message to client','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('SQL*Net message to dblink','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('SQL*Net more data to dblink','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('SQL*Net more data from client','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('SQL*Net more data from dblink','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('SQL*Net vector data to client','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('SQL*Net vector data from client','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('SQL*Net vector data to dblink','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('SQL*Net vector data from dblink','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('TEXT: URL_DATASTORE network wait','Network','none','none',FALSE,'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.'),
    ('resmgr:cpu quantum','Scheduler','none','none',TRUE,'Sessions throttled by Oracle Resource Manager — CPU quantum exhausted. (1) Review Resource Manager plan and consumer group CPU allocations. (2) Identify which sessions/users are being throttled. (3) Increase CPU allocation for critical consumer groups or adjust SWITCH_TIME thresholds.'),
    ('resmgr:become active','Scheduler','none','none',FALSE,'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.'),
    ('resmgr: I/O rate limit','Scheduler','none','none',FALSE,'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.'),
    ('resmgr:large I/O queued','Scheduler','none','none',FALSE,'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.'),
    ('resmgr:pq queued','Scheduler','none','none',FALSE,'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.'),
    ('resmgr: redo throttle','Scheduler','none','none',FALSE,'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.'),
    ('PX Queuing: statement queue','Scheduler','none','none',FALSE,'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.'),
    ('enq: JX - cleanup of queue','Scheduler','none','none',FALSE,'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.'),
    ('enq: JX - SQL statement queue','Scheduler','none','none',FALSE,'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.'),
    ('acknowledge over PGA limit','Scheduler','none','none',FALSE,'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.'),
    ('ASM COD rollback operation completion','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('ASM mount : wait for heartbeat','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('JS kgl get object wait','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('JS kill job wait','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('JS coord start wait','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),

    ('Backup: MML initialization','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML v1 open backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML v1 read backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML v1 write backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML v1 close backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML v1 query backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML v1 delete backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML create a backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML commit backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML command to channel','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML shutdown','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML obtain textual error','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML query backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML extended initialization','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML read backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML delete backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML restore backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML write backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML proxy initialize backup','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML proxy cancel','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML proxy commit backup piece','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML proxy session end','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML datafile proxy backup?','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML datafile proxy restore?','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML proxy initialize restore','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML proxy start data movement','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML data movement done?','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML proxy prepare to start','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML obtain a direct buffer','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML release a direct buffer','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML get base address','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('Backup: MML query for direct buffers','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('OFS operation completion','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('BA: Performance API','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('control file backup creation','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('multiple dbwriter suspend/resume for file offline','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('db flash cache dynamic disabling wait','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('switch logfile command','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('enq: MV - datafile move','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('datafile pre-create','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('wait for possible quiesce finish','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('concurrent I/O completion','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('datafile copy range completion','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('switch undo - offline','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('alter rbs offline','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('enq: TW - contention','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('index (re)build online start','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('index (re)build online cleanup','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('index (re)build online merge','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('index (re)build lock or pin object','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),

    ('alter system set dispatcher','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('connection pool wait','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('enq: DB - contention','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('enq: ZG - contention','Administrative','none','none',FALSE,'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.'),
    ('LogMiner builder: DDL','Queueing','none','none',FALSE,'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.'),
    ('LogMiner builder: memory','Queueing','none','none',FALSE,'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.'),
    ('LogMiner preparer: memory','Queueing','none','none',FALSE,'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.'),
    ('LogMiner reader: buffer','Queueing','none','none',FALSE,'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.'),
    ('REPL Capture/Apply: flow control','Queueing','none','none',FALSE,'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.'),
    ('REPL Capture/Apply: memory','Queueing','none','none',FALSE,'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.'),
    ('REPL Capture: subscribers to catch up','Queueing','none','none',FALSE,'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.'),
    ('Streams AQ: enqueue blocked due to flow control','Queueing','none','none',FALSE,'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.'),
    ('Streams AQ: enqueue blocked on low memory','Queueing','none','none',FALSE,'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.'),
    ('latch free','Other','none','none',TRUE,'Generic latch wait — a session is waiting for an unspecified latch. (1) Identify the specific latch from AWR Latch Activity section. (2) Correlate with other concurrent wait events for the primary driver. (3) Use the specific latch rule in the Recommendations panel if available.'),
    ('reliable message','Other','none','none',TRUE,'Background inter-process messaging wait. (1) Investigate only if this dominates alongside other symptoms. (2) Correlate with specific background process (AQ, XStream, Replication). (3) Check alert log for related background process errors.'),
    ('rdbms ipc reply','Other','none','none',TRUE,'Foreground session waiting for a background process to complete an operation. (1) Identify the background process from ASH (PROGRAM column). (2) If SMON: check for heavy coalescing or undo management. (3) If ARCn: check archivelog I/O and destination space.'),
    ('PX Deq Credit: send blkd','Idle','none','none',TRUE,'PX producer slave blocked — consumer slaves cannot process rows fast enough. (1) Identify the bottleneck operation in the parallel plan. (2) Review join methods — hash joins consume faster than nested loops. (3) Reduce DOP if consumer is overloaded.'),
    ('PX Deq: Execute Reply','Idle','none','none',TRUE,'Parallel query coordinator waiting for slave replies. (1) Check for data distribution imbalance across partitions. (2) Review PARALLEL_MAX_SERVERS and available PX server pool. (3) Consider reducing degree of parallelism if server pool is saturated.')
ON CONFLICT (event) DO UPDATE SET
    wait_class        = EXCLUDED.wait_class,
    corr_type         = EXCLUDED.corr_type,
    seg_filter        = EXCLUDED.seg_filter,
    has_specific_rule = EXCLUDED.has_specific_rule,
    guidance_text     = EXCLUDED.guidance_text;

\echo '  awr_wait_event_master: done (1918 rows)'

-- ============================================================
-- GRANT OBJECT PERMISSIONS TO SCHEMA OWNER
-- ============================================================
-- Grants SELECT/INSERT/UPDATE/DELETE on all tables, USAGE on
-- sequences, and SELECT on MVs to the DAR_PORTAL_USER role.
-- Update config/settings.yaml database.user = DAR_PORTAL_USER to
-- connect as the owner role instead of postgres.

\echo 'Granting permissions to DAR_PORTAL_USER...'

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE public.%I TO DAR_PORTAL_USER', r.tablename);
    END LOOP;
    FOR r IN SELECT sequencename FROM pg_sequences WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT USAGE,SELECT ON SEQUENCE public.%I TO DAR_PORTAL_USER', r.sequencename);
    END LOOP;
    FOR r IN SELECT matviewname FROM pg_matviews WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT SELECT ON TABLE public.%I TO DAR_PORTAL_USER', r.matviewname);
    END LOOP;
    RAISE NOTICE 'Permissions granted to DAR_PORTAL_USER';
END $$;

\echo '  Permissions: done'

-- ============================================================
-- VERIFY INSTALLATION
-- Run this SELECT to confirm object counts are correct.
-- ============================================================

\echo ''
\echo '============================================================'
\echo ' INSTALLATION COMPLETE — Verification'
\echo '============================================================'

SELECT object_type, count FROM (
    SELECT 'Tables'             AS object_type, COUNT(*)::TEXT AS count FROM information_schema.tables       WHERE table_schema='public' AND table_type='BASE TABLE'
    UNION ALL
    SELECT 'Materialized Views',                COUNT(*)::TEXT FROM pg_matviews                              WHERE schemaname='public'
    UNION ALL
    SELECT 'Views',                             COUNT(*)::TEXT FROM information_schema.views                  WHERE table_schema='public'
    UNION ALL
    SELECT 'Indexes',                           COUNT(*)::TEXT FROM pg_indexes                               WHERE schemaname='public'
    UNION ALL
    SELECT 'portal_config rows',                COUNT(*)::TEXT FROM portal_config
    UNION ALL
    SELECT 'portal_users rows',                 COUNT(*)::TEXT FROM portal_users
    UNION ALL
    SELECT 'wait_event_master rows',            COUNT(*)::TEXT FROM awr_wait_event_master
) v ORDER BY object_type;

\echo ''
\echo 'Expected results:'
\echo '  Tables               : 80'
\echo '  Materialized Views   : 11'
\echo '  Views                : 2'
\echo '  Indexes              : 90+'
\echo '  portal_config rows   : 46'
\echo '  portal_users rows    : 1'
\echo '  wait_event_master    : 1918'
\echo ''
\echo 'NEXT STEPS:'
\echo '  1. py -m pip install -r requirements.txt'
\echo '  2. py -m pip install oracledb paramiko'
\echo '  3. Edit config\settings.yaml  (DB password, portal/grafana URLs)'
\echo '  4. install_services.bat       (register Windows services)'
\echo '  5. py bulk_import.py          (import Grafana dashboards)'
\echo '  6. Open http://localhost:8000  login: admin / Admin@123'
\echo '  7. Settings → Access Control  update portal_url and grafana_url'
\echo '  8. Settings → License         enter your license key'
\echo '  9. CHANGE THE ADMIN PASSWORD  Settings → Users → Change Password'
\echo '============================================================'
