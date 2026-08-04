-- ============================================================
-- DAR Portal v3 — Database Analysis and Recommendations
-- Complete Schema DDL
-- Generated: 2026-08-04 11:30:16
-- Tool: extract_ddl.py
-- ============================================================
-- Run as:
--   psql -U postgres -d postgres -f awr_portal_full_schema_extracted_from_database.sql
-- ============================================================

SET client_min_messages = WARNING;
SET search_path = public;



-- ============================================================
-- TABLESPACES
-- ============================================================

-- Edit LOCATION paths before running on a new server.
-- Directories must exist first (mkdir).

-- CREATE TABLESPACE awrparser
--     LOCATION '/path/to/tablespaces/awrparser';
-- (Uncomment and edit the path above)

-- CREATE TABLESPACE awrparser_idx
--     LOCATION '/path/to/tablespaces/awrparser_idx';
-- (Uncomment and edit the path above)

-- CREATE TABLESPACE ganesh
--     LOCATION '/path/to/tablespaces/ganesh';
-- (Uncomment and edit the path above)

-- CREATE TABLESPACE test1
--     LOCATION '/path/to/tablespaces/test1';
-- (Uncomment and edit the path above)

-- CREATE TABLESPACE test2
--     LOCATION '/path/to/tablespaces/test2';
-- (Uncomment and edit the path above)

-- CREATE TABLESPACE test3
--     LOCATION '/path/to/tablespaces/test3';
-- (Uncomment and edit the path above)


-- ============================================================
-- CUSTOM TYPES / ENUMS
-- ============================================================


-- ============================================================
-- TABLES (80 portal tables)
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
    CONSTRAINT uq_awr_adv_pga UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_adv_sga UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
) TABLESPACE awrparser;

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
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_anomaly UNIQUE (dbname, instance, begin_snap, metric_source, metric_name, object_name)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_bg_wait_events UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_buf_waits UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_tag UNIQUE (dbname, tag_name, tag_type)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_db_info UNIQUE (db_name, instance, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_db_master_db_inst UNIQUE (db_name, inst_no)
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
    CONSTRAINT uq_awr_enqueue_stats UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_exec_plan UNIQUE (dbname, sql_id, plan_hash_value, step_id)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_file_io UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_fg_wait_class UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_fg_wait_events UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_inst_activity UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_instance_eff UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_io_profile UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_iostat_filetype UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_iostat_func_filetype UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_iostat_function UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

-- Table: awr_license_audit
CREATE TABLE IF NOT EXISTS awr_license_audit (
    id                             SERIAL,
    event_type                     TEXT NOT NULL,
    message                        TEXT,
    db_count                       INTEGER,
    sar_count                      INTEGER,
    event_time                     TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT awr_license_audit_pkey PRIMARY KEY (id)
) TABLESPACE awrparser;

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
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_load_profile UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_object UNIQUE (dbname, owner, object_name, object_type)
) TABLESPACE awrparser;

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
) TABLESPACE awrparser;
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
    CONSTRAINT uq_failed_snap UNIQUE (conn_id, begin_snap, end_snap),
    CONSTRAINT awr_oracle_failed_snaps_conn_id_fkey FOREIGN KEY (conn_id)
        REFERENCES awr_oracle_connections (id) ON DELETE CASCADE
) TABLESPACE awrparser;
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
    CONSTRAINT uq_awr_os_stats UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

-- Table: awr_recommendation_rules
CREATE TABLE IF NOT EXISTS awr_recommendation_rules (
    category                       TEXT NOT NULL,
    rule_key                       TEXT NOT NULL,
    rule_text                      TEXT NOT NULL,
    CONSTRAINT awr_recommendation_rules_pkey PRIMARY KEY (category, rule_key)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_rec UNIQUE (dbname, begin_snap, end_snap, rule_id)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_repo_scan UNIQUE (repo_path, db_name, filename, file_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_seg_buff_busy_waits UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_cr_blk_rec UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_cur_blk_rec UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_db_blk_chg UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_direct_phy_reads UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_direct_phy_writes UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_gbl_cache_buff_busy UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_itl_waits UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_seg_logical_reads UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_opt_reads UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_phy_read_req UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_phy_reads UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_phy_write_req UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_phy_writes UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_row_lck_waits UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_table_scan UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_seg_unopt_reads UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_cluster_wait_time UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sql_cpu_time UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sql_elapsed_time UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_executions UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sql_gets UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_parsed_calls UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_phy_reads_unopt UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sql_reads UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sql_text UNIQUE (dbname, sql_id, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sql_user_io_time UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_tblspc_io UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_time_model UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_awr_undo_stats UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;

-- Table: awr_wait_event_master
CREATE TABLE IF NOT EXISTS awr_wait_event_master (
    event                          TEXT NOT NULL,
    wait_class                     TEXT,
    corr_type                      TEXT,
    seg_filter                     TEXT,
    has_specific_rule              BOOLEAN DEFAULT false,
    guidance_text                  TEXT,
    CONSTRAINT awr_wait_event_master_pkey PRIMARY KEY (event)
) TABLESPACE awrparser;

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
) TABLESPACE awrparser;

-- Table: portal_config
CREATE TABLE IF NOT EXISTS portal_config (
    key                            VARCHAR(100) NOT NULL,
    value                          TEXT,
    description                    VARCHAR(300),
    section                        VARCHAR(50),
    updated_by                     VARCHAR(50),
    updated_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    CONSTRAINT portal_config_pkey PRIMARY KEY (key)
) TABLESPACE awrparser;

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
) TABLESPACE awrparser;

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
) TABLESPACE awrparser;

-- Table: sar_anomalies
CREATE TABLE IF NOT EXISTS sar_anomalies (
    id                             SERIAL,
    hostname                       TEXT NOT NULL,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    metric_source                  TEXT NOT NULL,
    metric_name                    TEXT NOT NULL,
    object_name                    TEXT,
    metric_value                   NUMERIC,
    baseline_mean                  NUMERIC,
    baseline_stddev                NUMERIC,
    z_score                        NUMERIC,
    severity                       TEXT,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sar_anomalies_pkey PRIMARY KEY (id),
    CONSTRAINT uq_sar_anomaly UNIQUE (hostname, snap_time, metric_source, metric_name, object_name)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sar_cpu UNIQUE (hostname, snap_time, cpu, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sar_ctxswitch UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sar_disk UNIQUE (hostname, snap_time, device, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sar_hugepage UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sar_loadavg UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sar_mem UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sar_network UNIQUE (hostname, snap_time, iface, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sar_paging UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;

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
    CONSTRAINT uq_sar_socket UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;

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
) TABLESPACE awrparser;
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
    CONSTRAINT uq_sar_swap UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;

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
-- INDEXES (61 indexes)
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_ai_rec_dbname ON public.awr_ai_recommendations USING btree (dbname, begin_snap);
CREATE INDEX IF NOT EXISTS idx_ai_rec_status ON public.awr_ai_recommendations USING btree (status);
CREATE INDEX IF NOT EXISTS idx_ai_rec_trigger ON public.awr_ai_recommendations USING btree (trigger_type, trigger_value);

CREATE INDEX IF NOT EXISTS idx_awr_anomaly_db_snap ON public.awr_anomalies USING btree (dbname, instance, begin_snap, severity);
CREATE INDEX IF NOT EXISTS idx_awr_anomaly_time ON public.awr_anomalies USING btree (snap_time DESC);

CREATE INDEX IF NOT EXISTS idx_change_log_db_time ON public.awr_change_log USING btree (dbname, event_time);

CREATE INDEX IF NOT EXISTS idx_db_master_db_name ON public.awr_db_master USING btree (db_name, active);

CREATE INDEX IF NOT EXISTS idx_exec_plan_fts ON public.awr_execution_plans USING gin (to_tsvector('english'::regconfig, ((COALESCE(object_name, ''::text) || ' '::text) || COALESCE(operation, ''::text))));
CREATE INDEX IF NOT EXISTS idx_exec_plan_obj ON public.awr_execution_plans USING btree (object_owner, object_name);
CREATE INDEX IF NOT EXISTS idx_exec_plan_snap ON public.awr_execution_plans USING btree (dbname, begin_snap);
CREATE INDEX IF NOT EXISTS idx_exec_plan_sql ON public.awr_execution_plans USING btree (dbname, sql_id);

CREATE INDEX IF NOT EXISTS idx_awrfw_pdb ON public.awr_foreground_wait_events USING btree (dbname, pdb_name, snap_time);

CREATE INDEX IF NOT EXISTS idx_lic_audit_time ON public.awr_license_audit USING btree (event_time DESC);

CREATE INDEX IF NOT EXISTS idx_obj_meta_db ON public.awr_object_metadata USING btree (dbname);
CREATE INDEX IF NOT EXISTS idx_obj_meta_owner ON public.awr_object_metadata USING btree (owner, object_name);
CREATE INDEX IF NOT EXISTS idx_obj_meta_type ON public.awr_object_metadata USING btree (object_type);

CREATE INDEX IF NOT EXISTS idx_oracle_conn_enabled ON public.awr_oracle_connections USING btree (enabled, db_name);

CREATE INDEX IF NOT EXISTS idx_failed_snaps_pending ON public.awr_oracle_failed_snaps USING btree (conn_id, resolved, retry_count) WHERE (resolved = false);

CREATE INDEX IF NOT EXISTS idx_awr_rec_category ON public.awr_recommendations USING btree (category, severity);
CREATE INDEX IF NOT EXISTS idx_awr_rec_db_snap ON public.awr_recommendations USING btree (dbname, begin_snap, end_snap);
CREATE INDEX IF NOT EXISTS idx_awr_rec_severity ON public.awr_recommendations USING btree (severity, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_repo_scan_db ON public.awr_repo_scan_log USING btree (db_name, status);
CREATE INDEX IF NOT EXISTS idx_repo_scan_status ON public.awr_repo_scan_log USING btree (status, scanned_at);

CREATE INDEX IF NOT EXISTS idx_awrseg_pdb ON public.awr_seg_logical_reads USING btree (dbname, pdb_name, snap_time);

CREATE INDEX IF NOT EXISTS idx_cluster ON public.awr_sql_cluster_wait_time USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_cpu ON public.awr_sql_cpu_time USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_awrsql_pdb ON public.awr_sql_elapsed_time USING btree (dbname, pdb_name, snap_time);
CREATE INDEX IF NOT EXISTS idx_elapsed ON public.awr_sql_elapsed_time USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_gets ON public.awr_sql_gets USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_parse ON public.awr_sql_parsed_calls USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_phy ON public.awr_sql_phy_reads_unopt USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_reads ON public.awr_sql_reads USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_sql_text_trgm ON public.awr_sql_text USING gin (sql_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS ix_sql_text_snap ON public.awr_sql_text USING btree (dbname, instance, begin_snap);

CREATE INDEX IF NOT EXISTS idx_uio ON public.awr_sql_user_io_time USING btree (dbname, instance, sql_id, begin_snap);

CREATE INDEX IF NOT EXISTS idx_plan_hdr_created ON public.exec_plan_headers USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_plan_hdr_dbname ON public.exec_plan_headers USING btree (dbname);
CREATE INDEX IF NOT EXISTS idx_plan_hdr_sql ON public.exec_plan_headers USING btree (sql_id);

CREATE INDEX IF NOT EXISTS idx_fetch_log_src ON public.remote_fetch_log USING btree (source_type, source_id, fetched_at DESC);

CREATE INDEX IF NOT EXISTS idx_sar_anomaly_host_time ON public.sar_anomalies USING btree (hostname, snap_time DESC, severity);
CREATE INDEX IF NOT EXISTS idx_sar_anomaly_severity ON public.sar_anomalies USING btree (severity, snap_time DESC);

CREATE INDEX IF NOT EXISTS idx_sar_cpu_host_time ON public.sar_cpu_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_cpu_iowait ON public.sar_cpu_stats USING btree (hostname, iowait_pct DESC);

CREATE INDEX IF NOT EXISTS idx_sar_ctxswitch_cswch ON public.sar_ctxswitch_stats USING btree (hostname, cswch_per_sec DESC);
CREATE INDEX IF NOT EXISTS idx_sar_ctxswitch_host_time ON public.sar_ctxswitch_stats USING btree (hostname, snap_time);

CREATE INDEX IF NOT EXISTS idx_sar_disk_host_time ON public.sar_disk_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_disk_util ON public.sar_disk_stats USING btree (hostname, util_pct DESC);

CREATE INDEX IF NOT EXISTS idx_sar_hugepage_host_time ON public.sar_hugepage_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_hugepage_pct ON public.sar_hugepage_stats USING btree (hostname, hugused_pct DESC);

CREATE INDEX IF NOT EXISTS idx_sar_loadavg_blocked ON public.sar_loadavg_stats USING btree (hostname, blocked DESC);
CREATE INDEX IF NOT EXISTS idx_sar_loadavg_host_time ON public.sar_loadavg_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_loadavg_runq ON public.sar_loadavg_stats USING btree (hostname, runq_sz DESC);

CREATE INDEX IF NOT EXISTS idx_sar_mem_host_time ON public.sar_memory_stats USING btree (hostname, snap_time);

CREATE INDEX IF NOT EXISTS idx_sar_network_host_time ON public.sar_network_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_network_iface ON public.sar_network_stats USING btree (iface);

CREATE INDEX IF NOT EXISTS idx_sar_paging_host_time ON public.sar_paging_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_paging_majflt ON public.sar_paging_stats USING btree (hostname, majflt_per_sec DESC);

CREATE INDEX IF NOT EXISTS idx_sar_socket_host_time ON public.sar_socket_stats USING btree (hostname, snap_time);
CREATE INDEX IF NOT EXISTS idx_sar_socket_tcptw ON public.sar_socket_stats USING btree (hostname, tcp_tw DESC);

CREATE INDEX IF NOT EXISTS idx_sar_ssh_enabled ON public.sar_ssh_connections USING btree (enabled, hostname);

CREATE INDEX IF NOT EXISTS idx_sar_swap_host_time ON public.sar_swap_stats USING btree (hostname, snap_time);


-- ============================================================
-- VIEWS (2 portal views)
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
-- MATERIALIZED VIEWS (12 portal MVs)
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

-- Materialized View: awr_bg_wait_event_summary_mv1
CREATE MATERIALIZED VIEW IF NOT EXISTS awr_bg_wait_event_summary_mv1 AS
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

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_bg_wait_event_summary_mv_id ON public.awr_bg_wait_event_summary_mv USING btree (mv_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_bg_wait_summary_mv_id ON public.awr_bg_wait_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_bg_wait_summary_dbinstsnap ON public.awr_bg_wait_summary_mv USING btree (dbname, instance, begin_snap);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_fg_wait_event_summary_mv_id ON public.awr_fg_wait_event_summary_mv USING btree (mv_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_fg_wait_summary_mv_id ON public.awr_fg_wait_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_fg_wait_summary_dbinstsnap ON public.awr_fg_wait_summary_mv USING btree (dbname, instance, begin_snap);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_seg_summary_mv_id ON public.awr_seg_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_seg_summary_dbinstsnap ON public.awr_seg_summary_mv USING btree (dbname, instance, begin_snap);
CREATE INDEX IF NOT EXISTS idx_seg_summary_score ON public.awr_seg_summary_mv USING btree (severity_score DESC);

CREATE INDEX IF NOT EXISTS idx_seg_summary_mv_dbname_snap ON public.awr_segment_summary_mv USING btree (dbname, instance, begin_snap);
CREATE INDEX IF NOT EXISTS idx_seg_summary_mv_owner_object ON public.awr_segment_summary_mv USING btree (dbname, owner, object_name);
CREATE INDEX IF NOT EXISTS idx_seg_summary_mv_severity ON public.awr_segment_summary_mv USING btree (dbname, instance, begin_snap, severity_score DESC);
CREATE INDEX IF NOT EXISTS ix_seg_mv_snap ON public.awr_segment_summary_mv USING btree (dbname, instance, begin_snap);
CREATE UNIQUE INDEX IF NOT EXISTS uq_seg_mv_id ON public.awr_segment_summary_mv USING btree (mv_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_sql_object_map_mv_id ON public.awr_sql_object_map_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_awr_sql_object_map_obj ON public.awr_sql_object_map_mv USING btree (object);
CREATE INDEX IF NOT EXISTS idx_awr_sql_object_map_sql ON public.awr_sql_object_map_mv USING btree (sql_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_sql_summary_mv_id ON public.awr_sql_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS ix_sql_summary_snap ON public.awr_sql_summary_mv USING btree (dbname, instance, begin_snap);

CREATE INDEX IF NOT EXISTS idx_awr_sql_text_norm_id ON public.awr_sql_text_norm USING btree (sql_id);
CREATE INDEX IF NOT EXISTS idx_awr_sql_text_norm_mv_sql_id ON public.awr_sql_text_norm USING btree (sql_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_sql_text_norm_mv_id ON public.awr_sql_text_norm_mv USING btree (mv_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_awr_wait_summary_mv_id ON public.awr_wait_summary_mv USING btree (mv_id);
CREATE INDEX IF NOT EXISTS idx_wait_summary_dbinstsnap ON public.awr_wait_summary_mv USING btree (dbname, instance, begin_snap, wait_scope, wait_class);
CREATE INDEX IF NOT EXISTS ix_wait_mv_snap ON public.awr_wait_summary_mv USING btree (dbname, instance, begin_snap);


-- ============================================================
-- REFRESH MATERIALIZED VIEWS
-- ============================================================

-- Run after initial data load to populate all MVs:
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_bg_wait_event_summary_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_bg_wait_event_summary_mv1;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_bg_wait_summary_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_fg_wait_event_summary_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_fg_wait_summary_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_seg_summary_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_segment_summary_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_sql_object_map_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_sql_summary_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_sql_text_norm;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_sql_text_norm_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY awr_wait_summary_mv;


-- ============================================================
-- FUNCTIONS & PROCEDURES (248 total)
-- ============================================================

-- Function: check_stmt_all_setting
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.check_stmt_all_setting(sserver_id integer, start_id integer, end_id integer)
 RETURNS integer
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT count(1)::integer
    FROM v_sample_settings
    WHERE server_id = sserver_id AND name = 'pg_stat_statements.track'
        AND setting = 'all' AND sample_id BETWEEN start_id + 1 AND end_id;
$function$;

-- Function: check_stmt_cnt
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.check_stmt_cnt(sserver_id integer, start_id integer DEFAULT 0, end_id integer DEFAULT 0)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    tab_tpl CONSTANT text :=
      '<table {stattbl}>'
        '<tr>'
          '<th>Sample ID</th>'
          '<th>Sample Time</th>'
          '<th>Stmts Captured</th>'
          '<th>pg_stat_statements.max</th>'
        '</tr>'
        '{rows}'
      '</table>';
    row_tpl CONSTANT text :=
      '<tr>'
        '<td>%s</td>'
        '<td>%s</td>'
        '<td>%s</td>'
        '<td>%s</td>'
      '</tr>';

    report text := '';

    c_stmt_all_stats CURSOR FOR
    SELECT sample_id,sample_time,stmt_cnt,prm.setting AS max_cnt
    FROM samples
        JOIN (
            SELECT sample_id,sum(statements) stmt_cnt
            FROM sample_statements_total
            WHERE server_id = sserver_id
            GROUP BY sample_id
        ) sample_stmt_cnt USING(sample_id)
        JOIN v_sample_settings prm USING (server_id, sample_id)
    WHERE server_id = sserver_id AND prm.name='pg_stat_statements.max' AND stmt_cnt >= 0.9*cast(prm.setting AS integer)
    ORDER BY sample_id ASC;

    c_stmt_stats CURSOR (s_id integer, e_id integer) FOR
    SELECT sample_id,sample_time,stmt_cnt,prm.setting AS max_cnt
    FROM samples
        JOIN (
            SELECT sample_id,sum(statements) stmt_cnt
            FROM sample_statements_total
            WHERE server_id = sserver_id AND sample_id BETWEEN s_id + 1 AND e_id
            GROUP BY sample_id
        ) sample_stmt_cnt USING(sample_id)
        JOIN v_sample_settings prm USING (server_id,sample_id)
    WHERE server_id = sserver_id AND prm.name='pg_stat_statements.max' AND stmt_cnt >= 0.9*cast(prm.setting AS integer)
    ORDER BY sample_id ASC;

    r_result RECORD;
BEGIN
    IF start_id = 0 THEN
        FOR r_result IN c_stmt_all_stats LOOP
            report := report||format(
                row_tpl,
                r_result.sample_id,
                r_result.sample_time,
                r_result.stmt_cnt,
                r_result.max_cnt
            );
        END LOOP;
    ELSE
        FOR r_result IN c_stmt_stats(start_id,end_id) LOOP
            report := report||format(
                row_tpl,
                r_result.sample_id,
                r_result.sample_time,
                r_result.stmt_cnt,
                r_result.max_cnt
            );
        END LOOP;
    END IF;

    IF report != '' THEN
        report := replace(tab_tpl,'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: cluster_stats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.cluster_stats(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, checkpoints_timed bigint, checkpoints_req bigint, checkpoint_write_time double precision, checkpoint_sync_time double precision, buffers_checkpoint bigint, buffers_clean bigint, buffers_backend bigint, buffers_backend_fsync bigint, maxwritten_clean bigint, buffers_alloc bigint, wal_size bigint, archived_count bigint, failed_count bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        st.server_id as server_id,
        sum(checkpoints_timed)::bigint as checkpoints_timed,
        sum(checkpoints_req)::bigint as checkpoints_req,
        sum(checkpoint_write_time)::double precision as checkpoint_write_time,
        sum(checkpoint_sync_time)::double precision as checkpoint_sync_time,
        sum(buffers_checkpoint)::bigint as buffers_checkpoint,
        sum(buffers_clean)::bigint as buffers_clean,
        sum(buffers_backend)::bigint as buffers_backend,
        sum(buffers_backend_fsync)::bigint as buffers_backend_fsync,
        sum(maxwritten_clean)::bigint as maxwritten_clean,
        sum(buffers_alloc)::bigint as buffers_alloc,
        sum(wal_size)::bigint as wal_size,
        sum(archived_count)::bigint as archived_count,
        sum(failed_count)::bigint as failed_count
    FROM sample_stat_cluster st
        LEFT OUTER JOIN sample_stat_archiver sa USING (server_id, sample_id)
    WHERE st.server_id = sserver_id AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id
$function$;

-- Function: cluster_stats_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.cluster_stats_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        NULLIF(stat1.checkpoints_timed, 0) as checkpoints_timed1,
        NULLIF(stat1.checkpoints_req, 0) as checkpoints_req1,
        NULLIF(stat1.checkpoint_write_time, 0.0) as checkpoint_write_time1,
        NULLIF(stat1.checkpoint_sync_time, 0.0) as checkpoint_sync_time1,
        NULLIF(stat1.buffers_checkpoint, 0) as buffers_checkpoint1,
        NULLIF(stat1.buffers_clean, 0) as buffers_clean1,
        NULLIF(stat1.buffers_backend, 0) as buffers_backend1,
        NULLIF(stat1.buffers_backend_fsync, 0) as buffers_backend_fsync1,
        NULLIF(stat1.maxwritten_clean, 0) as maxwritten_clean1,
        NULLIF(stat1.buffers_alloc, 0) as buffers_alloc1,
        pg_size_pretty(NULLIF(stat1.wal_size, 0)) as wal_size1,
        NULLIF(stat1.archived_count, 0) as archived_count1,
        NULLIF(stat1.failed_count, 0) as failed_count1,
        NULLIF(stat2.checkpoints_timed, 0) as checkpoints_timed2,
        NULLIF(stat2.checkpoints_req, 0) as checkpoints_req2,
        NULLIF(stat2.checkpoint_write_time, 0.0) as checkpoint_write_time2,
        NULLIF(stat2.checkpoint_sync_time, 0.0) as checkpoint_sync_time2,
        NULLIF(stat2.buffers_checkpoint, 0) as buffers_checkpoint2,
        NULLIF(stat2.buffers_clean, 0) as buffers_clean2,
        NULLIF(stat2.buffers_backend, 0) as buffers_backend2,
        NULLIF(stat2.buffers_backend_fsync, 0) as buffers_backend_fsync2,
        NULLIF(stat2.maxwritten_clean, 0) as maxwritten_clean2,
        NULLIF(stat2.buffers_alloc, 0) as buffers_alloc2,
        pg_size_pretty(NULLIF(stat2.wal_size, 0)) as wal_size2,
        NULLIF(stat2.archived_count, 0) as archived_count2,
        NULLIF(stat2.failed_count, 0) as failed_count2
    FROM cluster_stats(sserver_id,start1_id,end1_id) stat1
        FULL OUTER JOIN cluster_stats(sserver_id,start2_id,end2_id) stat2 USING (server_id);

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Metric</th>'
            '<th {title1}>Value (1)</th>'
            '<th {title2}>Value (2)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'val_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {interval1}><div {value}>%s</div></td>'
          '<td {interval2}><div {value}>%s</div></td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting summary bgwriter stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Scheduled checkpoints',r_result.checkpoints_timed1,r_result.checkpoints_timed2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Requested checkpoints',r_result.checkpoints_req1,r_result.checkpoints_req2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Checkpoint write time (s)',
            round(cast(r_result.checkpoint_write_time1/1000 as numeric),2),
            round(cast(r_result.checkpoint_write_time2/1000 as numeric),2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Checkpoint sync time (s)',
            round(cast(r_result.checkpoint_sync_time1/1000 as numeric),2),
            round(cast(r_result.checkpoint_sync_time2/1000 as numeric),2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Checkpoints buffers written',r_result.buffers_checkpoint1,r_result.buffers_checkpoint2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Background buffers written',r_result.buffers_clean1,r_result.buffers_clean2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Backend buffers written',r_result.buffers_backend1,r_result.buffers_backend2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Backend fsync count',r_result.buffers_backend_fsync1,r_result.buffers_backend_fsync2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Bgwriter interrupts (too many buffers)',r_result.maxwritten_clean1,r_result.maxwritten_clean2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Number of buffers allocated',r_result.buffers_alloc1,r_result.buffers_alloc2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'WAL generated',r_result.wal_size1,r_result.wal_size2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'WAL segments archived',r_result.archived_count1,r_result.archived_count2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'WAL segments archive failed',r_result.failed_count1,r_result.failed_count2);
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: cluster_stats_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.cluster_stats_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        NULLIF(checkpoints_timed, 0) as checkpoints_timed,
        NULLIF(checkpoints_req, 0) as checkpoints_req,
        NULLIF(checkpoint_write_time, 0.0) as checkpoint_write_time,
        NULLIF(checkpoint_sync_time, 0.0) as checkpoint_sync_time,
        NULLIF(buffers_checkpoint, 0) as buffers_checkpoint,
        NULLIF(buffers_clean, 0) as buffers_clean,
        NULLIF(buffers_backend, 0) as buffers_backend,
        NULLIF(buffers_backend_fsync, 0) as buffers_backend_fsync,
        NULLIF(maxwritten_clean, 0) as maxwritten_clean,
        NULLIF(buffers_alloc, 0) as buffers_alloc,
        pg_size_pretty(NULLIF(wal_size, 0)) as wal_size,
        NULLIF(archived_count, 0) as archived_count,
        NULLIF(failed_count, 0) as failed_count
    FROM cluster_stats(sserver_id,start_id,end_id);

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Metric</th>'
            '<th>Value</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'val_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting summary bgwriter stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Scheduled checkpoints',r_result.checkpoints_timed);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Requested checkpoints',r_result.checkpoints_req);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Checkpoint write time (s)',round(cast(r_result.checkpoint_write_time/1000 as numeric),2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Checkpoint sync time (s)',round(cast(r_result.checkpoint_sync_time/1000 as numeric),2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Checkpoints buffers written',r_result.buffers_checkpoint);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Background buffers written',r_result.buffers_clean);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Backend buffers written',r_result.buffers_backend);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Backend fsync count',r_result.buffers_backend_fsync);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Bgwriter interrupts (too many buffers)',r_result.maxwritten_clean);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'Number of buffers allocated',r_result.buffers_alloc);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'WAL generated',r_result.wal_size);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'WAL segments archived',r_result.archived_count);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],'WAL segments archive failed',r_result.failed_count);
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: cluster_stats_reset
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.cluster_stats_reset(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(sample_id integer, bgwriter_stats_reset timestamp with time zone, archiver_stats_reset timestamp with time zone)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT
      bgwr1.sample_id as sample_id,
      nullif(bgwr1.stats_reset,bgwr0.stats_reset),
      nullif(sta1.stats_reset,sta0.stats_reset)
  FROM sample_stat_cluster bgwr1
      LEFT OUTER JOIN sample_stat_archiver sta1 USING (server_id,sample_id)
      JOIN sample_stat_cluster bgwr0 ON (bgwr1.server_id = bgwr0.server_id AND bgwr1.sample_id = bgwr0.sample_id + 1)
      LEFT OUTER JOIN sample_stat_archiver sta0 ON (sta1.server_id = sta0.server_id AND sta1.sample_id = sta0.sample_id + 1)
  WHERE bgwr1.server_id = sserver_id AND bgwr1.sample_id BETWEEN start_id + 1 AND end_id
    AND
      COALESCE(
        nullif(bgwr1.stats_reset,bgwr0.stats_reset),
        nullif(sta1.stats_reset,sta0.stats_reset)
      ) IS NOT NULL
  ORDER BY bgwr1.sample_id ASC
$function$;

-- Function: cluster_stats_reset_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.cluster_stats_reset_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        interval_num,
        sample_id,
        bgwriter_stats_reset,
        archiver_stats_reset
    FROM
      (SELECT 1 AS interval_num, sample_id, bgwriter_stats_reset, archiver_stats_reset
        FROM cluster_stats_reset(sserver_id,start1_id,end1_id)
      UNION ALL
      SELECT 2 AS interval_num, sample_id, bgwriter_stats_reset, archiver_stats_reset
        FROM cluster_stats_reset(sserver_id,start2_id,end2_id)) AS samples
    ORDER BY interval_num, COALESCE(bgwriter_stats_reset, archiver_stats_reset) ASC;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>I</th>'
            '<th>Sample</th>'
            '<th>BGWriter reset time</th>'
            '<th>Archiver reset time</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'sample_tpl1',
        '<tr {interval1}>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'sample_tpl2',
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
      CASE r_result.interval_num
        WHEN 1 THEN
          report := report||format(
              jtab_tpl #>> ARRAY['sample_tpl1'],
              r_result.sample_id,
              r_result.bgwriter_stats_reset,
              r_result.archiver_stats_reset
          );
        WHEN 2 THEN
          report := report||format(
              jtab_tpl #>> ARRAY['sample_tpl2'],
              r_result.sample_id,
              r_result.bgwriter_stats_reset,
              r_result.archiver_stats_reset
          );
        END CASE;
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: cluster_stats_reset_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.cluster_stats_reset_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        sample_id,
        bgwriter_stats_reset,
        archiver_stats_reset
    FROM cluster_stats_reset(sserver_id,start_id,end_id)
    ORDER BY COALESCE(bgwriter_stats_reset,archiver_stats_reset) ASC;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Sample</th>'
            '<th>BGWriter reset time</th>'
            '<th>Archiver reset time</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'sample_tpl',
        '<tr>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['sample_tpl'],
            r_result.sample_id,
            r_result.bgwriter_stats_reset,
            r_result.archiver_stats_reset
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: collect_obj_stats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.collect_obj_stats(properties jsonb, sserver_id integer, s_id integer, connstr text, skip_sizes boolean, limited_sizes_allowed boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    --Cursor for db stats
    c_dblist CURSOR FOR
    SELECT datid,datname,tablespaceid FROM dblink('server_connection',
    'select dbs.oid,dbs.datname,dbs.dattablespace from pg_catalog.pg_database dbs '
    'where not dbs.datistemplate and dbs.datallowconn') AS dbl (
        datid oid,
        datname name,
        tablespaceid oid
    ) JOIN servers n ON (n.server_id = sserver_id AND array_position(n.db_exclude,dbl.datname) IS NULL);

    qres        record;
    db_connstr  text;
    t_query     text;
    result      jsonb;
BEGIN
    -- Adding dblink extension schema to search_path if it does not already there
    IF (SELECT count(*) = 0 FROM pg_catalog.pg_extension WHERE extname = 'dblink') THEN
      RAISE 'dblink extension must be installed';
    END IF;
    SELECT extnamespace::regnamespace AS dblink_schema INTO STRICT qres FROM pg_catalog.pg_extension WHERE extname = 'dblink';
    IF NOT string_to_array(current_setting('search_path'),',') @> ARRAY[qres.dblink_schema::text] THEN
      EXECUTE 'SET LOCAL search_path TO ' || current_setting('search_path')||','|| qres.dblink_schema;
    END IF;

    -- Disconnecting existing connection
    IF dblink_get_connections() @> ARRAY['server_db_connection'] THEN
        PERFORM dblink_disconnect('server_db_connection');
    END IF;

    result := properties;

    -- Load new data from statistic views of all cluster databases
    FOR qres IN c_dblist LOOP
      db_connstr := concat_ws(' ',connstr,
        format($o$dbname='%s'$o$,replace(qres.datname,$o$'$o$,$o$\'$o$))
      );
      PERFORM dblink_connect('server_db_connection',db_connstr);
      -- Setting lock_timout prevents hanging of take_sample() call due to DDL in long transaction
      PERFORM dblink('server_db_connection','SET lock_timeout=3000');
      -- Reset search_path for security reasons
      PERFORM dblink('server_connection','SET search_path=''''');

      IF (properties #>> '{collect_timings}')::boolean THEN
        result := jsonb_set(result,ARRAY['timings',format('db:%s collect tables stats',qres.datname)],jsonb_build_object('start',clock_timestamp()));
      END IF;

      -- Generate Table stats query
      CASE
        WHEN (
          SELECT count(*) = 1 FROM jsonb_to_recordset(properties #> '{settings}')
            AS x(name text, reset_val text)
          WHERE name = 'server_version_num'
            AND reset_val::integer < 130000
        )
        THEN
          t_query := 'SELECT '
            'st.relid,'
            'st.schemaname,'
            'st.relname,'
            'st.seq_scan,'
            'st.seq_tup_read,'
            'st.idx_scan,'
            'st.idx_tup_fetch,'
            'st.n_tup_ins,'
            'st.n_tup_upd,'
            'st.n_tup_del,'
            'st.n_tup_hot_upd,'
            'st.n_live_tup,'
            'st.n_dead_tup,'
            'st.n_mod_since_analyze,'
            'NULL as n_ins_since_vacuum,'
            'st.last_vacuum,'
            'st.last_autovacuum,'
            'st.last_analyze,'
            'st.last_autoanalyze,'
            'st.vacuum_count,'
            'st.autovacuum_count,'
            'st.analyze_count,'
            'st.autoanalyze_count,'
            'stio.heap_blks_read,'
            'stio.heap_blks_hit,'
            'stio.idx_blks_read,'
            'stio.idx_blks_hit,'
            'stio.toast_blks_read,'
            'stio.toast_blks_hit,'
            'stio.tidx_blks_read,'
            'stio.tidx_blks_hit,'
            -- Size of all forks without TOAST
            '{relation_size} relsize,'
            '0 relsize_diff,'
            'class.reltablespace AS tablespaceid,'
            'class.reltoastrelid,'
            'class.relkind '
          'FROM pg_catalog.pg_stat_all_tables st '
          'JOIN pg_catalog.pg_statio_all_tables stio USING (relid, schemaname, relname) '
          'JOIN pg_catalog.pg_class class ON (st.relid = class.oid) '
          -- is relation or its dependant is locked
          '{lock_join}'
          ;

        WHEN (
          SELECT count(*) = 1 FROM jsonb_to_recordset(properties #> '{settings}')
            AS x(name text, reset_val text)
          WHERE name = 'server_version_num'
            AND reset_val::integer >= 130000
        )
        THEN
          t_query := 'SELECT '
            'st.relid,'
            'st.schemaname,'
            'st.relname,'
            'st.seq_scan,'
            'st.seq_tup_read,'
            'st.idx_scan,'
            'st.idx_tup_fetch,'
            'st.n_tup_ins,'
            'st.n_tup_upd,'
            'st.n_tup_del,'
            'st.n_tup_hot_upd,'
            'st.n_live_tup,'
            'st.n_dead_tup,'
            'st.n_mod_since_analyze,'
            'st.n_ins_since_vacuum,'
            'st.last_vacuum,'
            'st.last_autovacuum,'
            'st.last_analyze,'
            'st.last_autoanalyze,'
            'st.vacuum_count,'
            'st.autovacuum_count,'
            'st.analyze_count,'
            'st.autoanalyze_count,'
            'stio.heap_blks_read,'
            'stio.heap_blks_hit,'
            'stio.idx_blks_read,'
            'stio.idx_blks_hit,'
            'stio.toast_blks_read,'
            'stio.toast_blks_hit,'
            'stio.tidx_blks_read,'
            'stio.tidx_blks_hit,'
            -- Size of all forks without TOAST
            '{relation_size} relsize,'
            '0 relsize_diff,'
            'class.reltablespace AS tablespaceid,'
            'class.reltoastrelid,'
            'class.relkind '
          'FROM pg_catalog.pg_stat_all_tables st '
          'JOIN pg_catalog.pg_statio_all_tables stio USING (relid, schemaname, relname) '
          'JOIN pg_catalog.pg_class class ON (st.relid = class.oid) '
          -- is relation or its dependant is locked
          '{lock_join}'
          ;
        ELSE
          RAISE 'Unsupported server version.';
      END CASE;

      IF skip_sizes THEN
        t_query := replace(t_query,'{relation_size}','NULL');
        t_query := replace(t_query,'{lock_join}','');
      ELSE
        t_query := replace(t_query,'{relation_size}','CASE locked.objid WHEN st.relid THEN NULL ELSE '
          'pg_catalog.pg_table_size(st.relid) - '
          'coalesce(pg_catalog.pg_relation_size(class.reltoastrelid),0) END');
        t_query := replace(t_query,'{lock_join}',
          'LEFT OUTER JOIN LATERAL '
            '(WITH RECURSIVE deps (objid) AS ('
              'SELECT relation FROM pg_catalog.pg_locks WHERE granted AND locktype = ''relation'' AND mode=''AccessExclusiveLock'' '
              'UNION '
              'SELECT refobjid FROM pg_catalog.pg_depend d JOIN deps dd ON (d.objid = dd.objid)'
            ') '
            'SELECT objid FROM deps) AS locked ON (st.relid = locked.objid)');
      END IF;

      INSERT INTO last_stat_tables(
        server_id,
        sample_id,
        datid,
        relid,
        schemaname,
        relname,
        seq_scan,
        seq_tup_read,
        idx_scan,
        idx_tup_fetch,
        n_tup_ins,
        n_tup_upd,
        n_tup_del,
        n_tup_hot_upd,
        n_live_tup,
        n_dead_tup,
        n_mod_since_analyze,
        n_ins_since_vacuum,
        last_vacuum,
        last_autovacuum,
        last_analyze,
        last_autoanalyze,
        vacuum_count,
        autovacuum_count,
        analyze_count,
        autoanalyze_count,
        heap_blks_read,
        heap_blks_hit,
        idx_blks_read,
        idx_blks_hit,
        toast_blks_read,
        toast_blks_hit,
        tidx_blks_read,
        tidx_blks_hit,
        relsize,
        relsize_diff,
        tablespaceid,
        reltoastrelid,
        relkind
      )
      SELECT
        sserver_id,
        s_id,
        qres.datid,
        dbl.relid,
        dbl.schemaname,
        dbl.relname,
        dbl.seq_scan AS seq_scan,
        dbl.seq_tup_read AS seq_tup_read,
        dbl.idx_scan AS idx_scan,
        dbl.idx_tup_fetch AS idx_tup_fetch,
        dbl.n_tup_ins AS n_tup_ins,
        dbl.n_tup_upd AS n_tup_upd,
        dbl.n_tup_del AS n_tup_del,
        dbl.n_tup_hot_upd AS n_tup_hot_upd,
        dbl.n_live_tup AS n_live_tup,
        dbl.n_dead_tup AS n_dead_tup,
        dbl.n_mod_since_analyze AS n_mod_since_analyze,
        dbl.n_ins_since_vacuum AS n_ins_since_vacuum,
        dbl.last_vacuum,
        dbl.last_autovacuum,
        dbl.last_analyze,
        dbl.last_autoanalyze,
        dbl.vacuum_count AS vacuum_count,
        dbl.autovacuum_count AS autovacuum_count,
        dbl.analyze_count AS analyze_count,
        dbl.autoanalyze_count AS autoanalyze_count,
        dbl.heap_blks_read AS heap_blks_read,
        dbl.heap_blks_hit AS heap_blks_hit,
        dbl.idx_blks_read AS idx_blks_read,
        dbl.idx_blks_hit AS idx_blks_hit,
        dbl.toast_blks_read AS toast_blks_read,
        dbl.toast_blks_hit AS toast_blks_hit,
        dbl.tidx_blks_read AS tidx_blks_read,
        dbl.tidx_blks_hit AS tidx_blks_hit,
        dbl.relsize AS relsize,
        dbl.relsize_diff AS relsize_diff,
        CASE WHEN dbl.tablespaceid=0 THEN qres.tablespaceid ELSE dbl.tablespaceid END AS tablespaceid,
        dbl.reltoastrelid,
        dbl.relkind
      FROM dblink('server_db_connection', t_query)
      AS dbl (
          relid                 oid,
          schemaname            name,
          relname               name,
          seq_scan              bigint,
          seq_tup_read          bigint,
          idx_scan              bigint,
          idx_tup_fetch         bigint,
          n_tup_ins             bigint,
          n_tup_upd             bigint,
          n_tup_del             bigint,
          n_tup_hot_upd         bigint,
          n_live_tup            bigint,
          n_dead_tup            bigint,
          n_mod_since_analyze   bigint,
          n_ins_since_vacuum    bigint,
          last_vacuum           timestamp with time zone,
          last_autovacuum       timestamp with time zone,
          last_analyze          timestamp with time zone,
          last_autoanalyze      timestamp with time zone,
          vacuum_count          bigint,
          autovacuum_count      bigint,
          analyze_count         bigint,
          autoanalyze_count     bigint,
          heap_blks_read        bigint,
          heap_blks_hit         bigint,
          idx_blks_read         bigint,
          idx_blks_hit          bigint,
          toast_blks_read       bigint,
          toast_blks_hit        bigint,
          tidx_blks_read        bigint,
          tidx_blks_hit         bigint,
          relsize               bigint,
          relsize_diff          bigint,
          tablespaceid          oid,
          reltoastrelid         oid,
          relkind               char
      );

      ANALYZE last_stat_tables;

      IF skip_sizes AND limited_sizes_allowed THEN
      /* Limited tables sizes collection
        * We will collect table sizes even if size collection is disabled
        * for vacuumed or seq-scanned tables. This data is needed for
        * index vacuum I/O estimation and for seq-scanned load and I'am
        * not expecting much overhead here.
        */
        IF (result #>> '{collect_timings}')::boolean THEN
          result := jsonb_set(result,ARRAY['timings',format('db:%s collect limited table sizes'
          ,qres.datname)],jsonb_build_object('start',clock_timestamp()));
        END IF;
        t_query := NULL;

        SELECT
          'SELECT rel.oid AS relid, pg_relation_size(rel.oid) AS relsize '
          'FROM pg_catalog.pg_class rel '
          'WHERE rel.oid IN ('||
            string_agg(cur.relid::text,',')||
          ')' INTO t_query
        FROM
          last_stat_tables lst JOIN sample_stat_database dbcur USING (server_id, sample_id, datid)
          LEFT OUTER JOIN sample_stat_database dblst ON
            (dbcur.server_id, dbcur.datid, dbcur.sample_id - 1, dbcur.stats_reset) =
            (dblst.server_id, dblst.datid, dblst.sample_id, dblst.stats_reset)
          LEFT OUTER JOIN last_stat_tables cur ON (lst.server_id, lst.sample_id, lst.datid, lst.relid) =
            (cur.server_id, cur.sample_id - 1, cur.datid, cur.relid)
        WHERE
          (cur.server_id, cur.sample_id, cur.datid) =
          (sserver_id, s_id, qres.datid)
          AND (
            ((dblst.server_id IS NULL OR lst.server_id IS NULL)
              AND (cur.vacuum_count + cur.autovacuum_count + cur.seq_scan > 0))
            OR
            (dblst.server_id IS NOT NULL AND
            (cur.vacuum_count, cur.autovacuum_count, cur.seq_scan) !=
            (lst.vacuum_count, lst.autovacuum_count, lst.seq_scan))
          );

        IF t_query IS NOT NULL THEN
          UPDATE last_stat_tables lst
          SET
            relsize = dbl.relsize
          FROM dblink('server_db_connection', t_query) AS
            dbl(relid oid, relsize bigint)
          WHERE (lst.server_id, lst.sample_id, lst.datid, lst.relid) =
            (sserver_id, s_id, qres.datid, dbl.relid);
        END IF;

        IF (result #>> '{collect_timings}')::boolean THEN
          result := jsonb_set(result,ARRAY['timings',format('db:%s collect limited table sizes'
          ,qres.datname),'end'],to_jsonb(clock_timestamp()));
        END IF;
      END IF;


      IF (result #>> '{collect_timings}')::boolean THEN
        result := jsonb_set(result,ARRAY['timings',format('db:%s collect tables stats',qres.datname),'end'],to_jsonb(clock_timestamp()));
        result := jsonb_set(result,ARRAY['timings',format('db:%s collect indexes stats',qres.datname)],jsonb_build_object('start',clock_timestamp()));
      END IF;

      -- Generate index stats query
      t_query := 'SELECT st.*,'
        'stio.idx_blks_read,'
        'stio.idx_blks_hit,'
        '{relation_size} relsize,'
        '0,'
        'pg_class.reltablespace as tablespaceid,'
        '(ix.indisunique OR con.conindid IS NOT NULL) AS indisunique '
      'FROM pg_catalog.pg_stat_all_indexes st '
        'JOIN pg_catalog.pg_statio_all_indexes stio USING (relid, indexrelid, schemaname, relname, indexrelname) '
        'JOIN pg_catalog.pg_index ix ON (ix.indexrelid = st.indexrelid) '
        'JOIN pg_catalog.pg_class ON (pg_class.oid = st.indexrelid) '
        'LEFT OUTER JOIN pg_catalog.pg_constraint con ON (con.conindid = ix.indexrelid AND con.contype in (''p'',''u'')) '
        '{lock_join}'
        ;

      IF skip_sizes THEN
        t_query := replace(t_query,'{relation_size}','NULL');
        t_query := replace(t_query,'{lock_join}','');
      ELSE
        t_query := replace(t_query,'{relation_size}',
          'CASE l.relation WHEN st.indexrelid THEN NULL ELSE pg_relation_size(st.indexrelid) END');
        t_query := replace(t_query,'{lock_join}',
          'LEFT OUTER JOIN LATERAL ('
            'SELECT relation '
            'FROM pg_catalog.pg_locks '
            'WHERE '
            '(relation = st.indexrelid AND granted AND locktype = ''relation'' AND mode=''AccessExclusiveLock'')'
          ') l ON (l.relation = st.indexrelid)');
      END IF;

      INSERT INTO last_stat_indexes(
        server_id,
        sample_id,
        datid,
        relid,
        indexrelid,
        schemaname,
        relname,
        indexrelname,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch,
        idx_blks_read,
        idx_blks_hit,
        relsize,
        relsize_diff,
        tablespaceid,
        indisunique
      )
      SELECT
        sserver_id,
        s_id,
        qres.datid,
        relid,
        indexrelid,
        schemaname,
        relname,
        indexrelname,
        dbl.idx_scan AS idx_scan,
        dbl.idx_tup_read AS idx_tup_read,
        dbl.idx_tup_fetch AS idx_tup_fetch,
        dbl.idx_blks_read AS idx_blks_read,
        dbl.idx_blks_hit AS idx_blks_hit,
        dbl.relsize AS relsize,
        dbl.relsize_diff AS relsize_diff,
        CASE WHEN tablespaceid=0 THEN qres.tablespaceid ELSE tablespaceid END tablespaceid,
        indisunique
      FROM dblink('server_db_connection', t_query)
      AS dbl (
         relid          oid,
         indexrelid     oid,
         schemaname     name,
         relname        name,
         indexrelname   name,
         idx_scan       bigint,
         idx_tup_read   bigint,
         idx_tup_fetch  bigint,
         idx_blks_read  bigint,
         idx_blks_hit   bigint,
         relsize        bigint,
         relsize_diff   bigint,
         tablespaceid   oid,
         indisunique    bool
      );

      ANALYZE last_stat_indexes;

      IF skip_sizes AND limited_sizes_allowed THEN
      /* Limited indexes sizes collection
        * We will collect index sizes even if size collection is disabled
        * for vacuumed indexes. This data is needed for index vacuum I/O
        * estimation and I'am not expecting much overhead here.
        */
        IF (result #>> '{collect_timings}')::boolean THEN
          result := jsonb_set(result,ARRAY['timings',format('db:%s collect limited index sizes'
          ,qres.datname)],jsonb_build_object('start',clock_timestamp()));
        END IF;
        t_query := NULL;

        SELECT
          'SELECT ix.indexrelid AS indexrelid, pg_relation_size(ix.indexrelid) AS relsize '
          'FROM pg_catalog.pg_index ix '
          'WHERE ix.indrelid IN ('||
            string_agg(cur.relid::text,',')||
          ')' INTO t_query
        FROM
          last_stat_tables lst JOIN sample_stat_database dbcur USING (server_id, sample_id, datid)
          LEFT OUTER JOIN sample_stat_database dblst ON
            (dbcur.server_id, dbcur.datid, dbcur.sample_id - 1, dbcur.stats_reset) =
            (dblst.server_id, dblst.datid, dblst.sample_id, dblst.stats_reset)
          LEFT OUTER JOIN last_stat_tables cur ON (lst.server_id, lst.sample_id, lst.datid, lst.relid) =
            (cur.server_id, cur.sample_id - 1, cur.datid, cur.relid)
        WHERE
          (cur.server_id, cur.sample_id, cur.datid) =
          (sserver_id, s_id, qres.datid)
          AND (
            ((dblst.server_id IS NULL OR lst.server_id IS NULL)
              AND (cur.vacuum_count + cur.autovacuum_count > 0))
            OR
            (dblst.server_id IS NOT NULL AND
            (cur.vacuum_count, cur.autovacuum_count) !=
            (lst.vacuum_count, lst.autovacuum_count))
          );

        IF t_query IS NOT NULL THEN
          UPDATE last_stat_indexes lsi
          SET relsize = dbl.relsize
          FROM dblink('server_db_connection', t_query) AS
            dbl(indexrelid oid, relsize bigint)
          WHERE (lsi.server_id, lsi.sample_id, lsi.datid, lsi.indexrelid) =
            (sserver_id, s_id, qres.datid, dbl.indexrelid);
        END IF;

        IF (result #>> '{collect_timings}')::boolean THEN
          result := jsonb_set(result,ARRAY['timings',format('db:%s collect limited index sizes'
          ,qres.datname),'end'],to_jsonb(clock_timestamp()));
        END IF;
      END IF;

      IF (result #>> '{collect_timings}')::boolean THEN
        result := jsonb_set(result,ARRAY['timings',format('db:%s collect indexes stats',qres.datname),'end'],to_jsonb(clock_timestamp()));
        result := jsonb_set(result,ARRAY['timings',format('db:%s collect functions stats',qres.datname)],jsonb_build_object('start',clock_timestamp()));
      END IF;

      -- Generate Function stats query
      t_query := 'SELECT f.funcid,'
        'f.schemaname,'
        'f.funcname,'
        'pg_get_function_arguments(f.funcid) AS funcargs,'
        'f.calls,'
        'f.total_time,'
        'f.self_time,'
        'p.prorettype::regtype::text =''trigger'' AS trg_fn '
      'FROM pg_catalog.pg_stat_user_functions f '
        'JOIN pg_catalog.pg_proc p ON (f.funcid = p.oid)';

      INSERT INTO last_stat_user_functions(
        server_id,
        sample_id,
        datid,
        funcid,
        schemaname,
        funcname,
        funcargs,
        calls,
        total_time,
        self_time,
        trg_fn
      )
      SELECT
        sserver_id,
        s_id,
        qres.datid,
        funcid,
        schemaname,
        funcname,
        funcargs,
        dbl.calls AS calls,
        dbl.total_time AS total_time,
        dbl.self_time AS self_time,
        dbl.trg_fn
      FROM dblink('server_db_connection', t_query)
      AS dbl (
         funcid       oid,
         schemaname   name,
         funcname     name,
         funcargs     text,
         calls        bigint,
         total_time   double precision,
         self_time    double precision,
         trg_fn       boolean
      );

      ANALYZE last_stat_user_functions;

      PERFORM dblink_disconnect('server_db_connection');
      IF (result #>> '{collect_timings}')::boolean THEN
        result := jsonb_set(result,ARRAY['timings',format('db:%s collect functions stats',qres.datname),'end'],to_jsonb(clock_timestamp()));
      END IF;
    END LOOP;
   RETURN result;
END;
$function$;

-- Function: collect_pg_stat_statements_stats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.collect_pg_stat_statements_stats(properties jsonb, sserver_id integer, s_id integer, topn integer)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  qres              record;
  st_query          text;
BEGIN
    -- Adding dblink extension schema to search_path if it does not already there
    SELECT extnamespace::regnamespace AS dblink_schema INTO STRICT qres FROM pg_catalog.pg_extension WHERE extname = 'dblink';
    IF NOT string_to_array(current_setting('search_path'),',') @> ARRAY[qres.dblink_schema::text] THEN
      EXECUTE 'SET LOCAL search_path TO ' || current_setting('search_path')||','|| qres.dblink_schema;
    END IF;

    -- Check if mandatory extensions exists
    IF NOT
      (
        SELECT count(*) = 1
        FROM jsonb_to_recordset(properties #> '{extensions}') AS ext(extname text)
        WHERE extname = 'pg_stat_statements'
      )
    THEN
      RETURN;
    END IF;

    -- Dynamic statements query
    st_query := format(
      'SELECT '
        'st.userid,'
        'st.dbid,'
        'st.queryid,'
        'md5(st.query) AS queryid_md5,'
        '{statements_fields}'
        '{kcache_fields}'
      ' FROM '
      '{statements_view} st '
      '{kcache_stats} '
      'JOIN pg_catalog.pg_database db ON (db.oid=st.dbid) '
      'JOIN pg_catalog.pg_roles r ON (r.oid=st.userid) '
      'JOIN '
      '(SELECT '
        'userid,'
        'dbid,'
        'queryid,'
        '{statements_rank_calc}'
        '{kcache_rank_calc}'
      'FROM {statements_view} s '
        '{kcache_rank_join} '
      ') rank_st '
      'USING (userid, dbid, queryid)'
      ' WHERE '
        'st.queryid IS NOT NULL '
        'AND '
        'least('
          '{statements_rank_fields}'
          '{kcache_rank_fields}'
          ') <= %1$s',
      topn);

    -- pg_stat_statements versions
    CASE (
        SELECT extversion
        FROM jsonb_to_recordset(properties #> '{extensions}')
          AS ext(extname text, extversion text)
        WHERE extname = 'pg_stat_statements'
      )
      WHEN '1.3','1.4','1.5','1.6','1.7' THEN
        st_query := replace(st_query, '{statements_fields}',
          'NULL as toplevel,'
          'NULL as plans,'
          'NULL as total_plan_time,'
          'NULL as min_plan_time,'
          'NULL as max_plan_time,'
          'NULL as mean_plan_time,'
          'NULL as stddev_plan_time,'
          'st.calls,'
          'st.total_time as total_exec_time,'
          'st.min_time as min_exec_time,'
          'st.max_time as max_exec_time,'
          'st.mean_time as mean_exec_time,'
          'st.stddev_time as stddev_exec_time,'
          'st.rows,'
          'st.shared_blks_hit,'
          'st.shared_blks_read,'
          'st.shared_blks_dirtied,'
          'st.shared_blks_written,'
          'st.local_blks_hit,'
          'st.local_blks_read,'
          'st.local_blks_dirtied,'
          'st.local_blks_written,'
          'st.temp_blks_read,'
          'st.temp_blks_written,'
          'st.blk_read_time,'
          'st.blk_write_time,'
          'NULL as wal_records,'
          'NULL as wal_fpi,'
          'NULL as wal_bytes,'||
          $o$regexp_replace(st.query,$i$\s+$i$,$i$ $i$,$i$g$i$) AS query$o$
        );
        st_query := replace(st_query, '{statements_rank_calc}',
            'row_number() over (ORDER BY total_time DESC) AS exec_time_rank,'
            'row_number() over (ORDER BY calls DESC) AS calls_rank,'
            'row_number() over (ORDER BY blk_read_time + blk_write_time DESC) AS io_time_rank,'
            'row_number() over (ORDER BY shared_blks_hit + shared_blks_read DESC) AS gets_rank,'
            'row_number() over (ORDER BY shared_blks_read DESC) AS read_rank,'
            'row_number() over (ORDER BY shared_blks_dirtied DESC) AS dirtied_rank,'
            'row_number() over (ORDER BY shared_blks_written DESC) AS written_rank,'
            'row_number() over (ORDER BY temp_blks_written + local_blks_written DESC) AS tempw_rank,'
            'row_number() over (ORDER BY temp_blks_read + local_blks_read DESC) AS tempr_rank '
        );
        st_query := replace(st_query, '{statements_rank_fields}',
          'exec_time_rank,'
          'calls_rank,'
          'io_time_rank,'
          'gets_rank,'
          'read_rank,'
          'tempw_rank,'
          'tempr_rank,'
          'dirtied_rank,'
          'written_rank'
        );
        st_query := replace(st_query, '{statements_view}',
          format('%1$I.pg_stat_statements',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_statements'
            )
          )
        );
      WHEN '1.8' THEN
        st_query := replace(st_query, '{statements_fields}',
          'NULL as toplevel,'
          'st.plans,'
          'st.total_plan_time,'
          'st.min_plan_time,'
          'st.max_plan_time,'
          'st.mean_plan_time,'
          'st.stddev_plan_time,'
          'st.calls,'
          'st.total_exec_time,'
          'st.min_exec_time,'
          'st.max_exec_time,'
          'st.mean_exec_time,'
          'st.stddev_exec_time,'
          'st.rows,'
          'st.shared_blks_hit,'
          'st.shared_blks_read,'
          'st.shared_blks_dirtied,'
          'st.shared_blks_written,'
          'st.local_blks_hit,'
          'st.local_blks_read,'
          'st.local_blks_dirtied,'
          'st.local_blks_written,'
          'st.temp_blks_read,'
          'st.temp_blks_written,'
          'st.blk_read_time,'
          'st.blk_write_time,'
          'st.wal_records,'
          'st.wal_fpi,'
          'st.wal_bytes,'||
          $o$regexp_replace(st.query,$i$\s+$i$,$i$ $i$,$i$g$i$) AS query$o$
        );
        st_query := replace(st_query, '{statements_rank_calc}',
            'row_number() over (ORDER BY total_plan_time + total_exec_time DESC) AS time_rank,'
            'row_number() over (ORDER BY total_plan_time DESC) AS plan_time_rank,'
            'row_number() over (ORDER BY total_exec_time DESC) AS exec_time_rank,'
            'row_number() over (ORDER BY calls DESC) AS calls_rank,'
            'row_number() over (ORDER BY blk_read_time + blk_write_time DESC) AS io_time_rank,'
            'row_number() over (ORDER BY shared_blks_hit + shared_blks_read DESC) AS gets_rank,'
            'row_number() over (ORDER BY shared_blks_read DESC) AS read_rank,'
            'row_number() over (ORDER BY shared_blks_dirtied DESC) AS dirtied_rank,'
            'row_number() over (ORDER BY shared_blks_written DESC) AS written_rank,'
            'row_number() over (ORDER BY temp_blks_written + local_blks_written DESC) AS tempw_rank,'
            'row_number() over (ORDER BY temp_blks_read + local_blks_read DESC) AS tempr_rank,'
            'row_number() over (ORDER BY wal_bytes DESC) AS wal_rank '
        );
        st_query := replace(st_query, '{statements_rank_fields}',
          'time_rank,'
          'plan_time_rank,'
          'exec_time_rank,'
          'calls_rank,'
          'io_time_rank,'
          'gets_rank,'
          'read_rank,'
          'dirtied_rank,'
          'written_rank,'
          'tempw_rank,'
          'tempr_rank,'
          'wal_rank'
        );
        st_query := replace(st_query, '{statements_view}',
          format('%1$I.pg_stat_statements',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_statements'
            )
          )
        );
      WHEN '1.9' THEN
        st_query := replace(st_query, '{statements_fields}',
          'st.toplevel,'
          'st.plans,'
          'st.total_plan_time,'
          'st.min_plan_time,'
          'st.max_plan_time,'
          'st.mean_plan_time,'
          'st.stddev_plan_time,'
          'st.calls,'
          'st.total_exec_time,'
          'st.min_exec_time,'
          'st.max_exec_time,'
          'st.mean_exec_time,'
          'st.stddev_exec_time,'
          'st.rows,'
          'st.shared_blks_hit,'
          'st.shared_blks_read,'
          'st.shared_blks_dirtied,'
          'st.shared_blks_written,'
          'st.local_blks_hit,'
          'st.local_blks_read,'
          'st.local_blks_dirtied,'
          'st.local_blks_written,'
          'st.temp_blks_read,'
          'st.temp_blks_written,'
          'st.blk_read_time,'
          'st.blk_write_time,'
          'st.wal_records,'
          'st.wal_fpi,'
          'st.wal_bytes,'||
          $o$regexp_replace(st.query,$i$\s+$i$,$i$ $i$,$i$g$i$) AS query$o$
        );
        st_query := replace(st_query, '{statements_rank_calc}',
            'row_number() over (ORDER BY total_plan_time + total_exec_time DESC) AS time_rank,'
            'row_number() over (ORDER BY total_plan_time DESC) AS plan_time_rank,'
            'row_number() over (ORDER BY total_exec_time DESC) AS exec_time_rank,'
            'row_number() over (ORDER BY calls DESC) AS calls_rank,'
            'row_number() over (ORDER BY blk_read_time + blk_write_time DESC) AS io_time_rank,'
            'row_number() over (ORDER BY shared_blks_hit + shared_blks_read DESC) AS gets_rank,'
            'row_number() over (ORDER BY shared_blks_read DESC) AS read_rank,'
            'row_number() over (ORDER BY shared_blks_dirtied DESC) AS dirtied_rank,'
            'row_number() over (ORDER BY shared_blks_written DESC) AS written_rank,'
            'row_number() over (ORDER BY temp_blks_written + local_blks_written DESC) AS tempw_rank,'
            'row_number() over (ORDER BY temp_blks_read + local_blks_read DESC) AS tempr_rank,'
            'row_number() over (ORDER BY wal_bytes DESC) AS wal_rank '
        );
        st_query := replace(st_query, '{statements_rank_fields}',
          'time_rank,'
          'plan_time_rank,'
          'exec_time_rank,'
          'calls_rank,'
          'io_time_rank,'
          'gets_rank,'
          'read_rank,'
          'dirtied_rank,'
          'written_rank,'
          'tempw_rank,'
          'tempr_rank,'
          'wal_rank'
        );
        st_query := replace(st_query, '{statements_view}',
          format('%1$I.pg_stat_statements',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_statements'
            )
          )
        );
      ELSE
        RAISE 'Unsupported pg_stat_statements extension version.';
    END CASE; -- pg_stat_statememts versions

    CASE -- pg_stat_kcache versions
      (
        SELECT extversion
        FROM jsonb_to_recordset(properties #> '{extensions}')
          AS x(extname text, extversion text)
        WHERE extname = 'pg_stat_kcache'
      )
      -- pg_stat_kcache v.2.1.0 - 2.1.3
      WHEN '2.1.0','2.1.1','2.1.2','2.1.3' THEN
        st_query := replace(st_query, '{kcache_fields}',
          ',true as kcache_avail,'
          'NULL as plan_user_time,'
          'NULL as plan_system_time,'
          'NULL as plan_minflts,'
          'NULL as plan_majflts,'
          'NULL as plan_nswaps,'
          'NULL as plan_reads,'
          'NULL as plan_writes,'
          'NULL as plan_msgsnds,'
          'NULL as plan_msgrcvs,'
          'NULL as plan_nsignals,'
          'NULL as plan_nvcsws,'
          'NULL as plan_nivcsws,'
          'kc.user_time as exec_user_time,'
          'kc.system_time as exec_system_time,'
          'kc.minflts as exec_minflts,'
          'kc.majflts as exec_majflts,'
          'kc.nswaps as exec_nswaps,'
          'kc.reads as exec_reads,'
          'kc.writes  as exec_writes,'
          'kc.msgsnds as exec_msgsnds,'
          'kc.msgrcvs as exec_msgrcvs,'
          'kc.nsignals as exec_nsignals,'
          'kc.nvcsws as exec_nvcsws,'
          'kc.nivcsws as exec_nivcsws'
        );
        st_query := replace(st_query, '{kcache_stats}',format(
          'LEFT OUTER JOIN %1$I.pg_stat_kcache() kc USING (queryid, userid, dbid) ',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_kcache'
            )
          ));
        st_query := replace(st_query, '{kcache_rank_calc}',
          ', row_number() over (ORDER BY coalesce(user_time, 0.0)+coalesce(system_time, 0.0) DESC) AS cpu_time_rank,'
          'row_number() over (ORDER BY coalesce(reads, 0)+coalesce(writes, 0) DESC) AS io_rank '
        );
        st_query := replace(st_query, '{kcache_rank_join}',format(
          'LEFT OUTER JOIN %1$I.pg_stat_kcache() k USING (queryid, userid, dbid) ',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_kcache'
            )
          ));
        st_query := replace(st_query, '{kcache_rank_fields}',
          ',cpu_time_rank,'
          'io_rank'
        );
      -- pg_stat_kcache v.2.2.0
      WHEN '2.2.0' THEN
        st_query := replace(st_query, '{kcache_fields}',
          ',true as kcache_avail,'
          'kc.plan_user_time as plan_user_time,'
          'kc.plan_system_time as plan_system_time,'
          'kc.plan_minflts as plan_minflts,'
          'kc.plan_majflts as plan_majflts,'
          'kc.plan_nswaps as plan_nswaps,'
          'kc.plan_reads as plan_reads,'
          'kc.plan_writes as plan_writes,'
          'kc.plan_msgsnds as plan_msgsnds,'
          'kc.plan_msgrcvs as plan_msgrcvs,'
          'kc.plan_nsignals as plan_nsignals,'
          'kc.plan_nvcsws as plan_nvcsws,'
          'kc.plan_nivcsws as plan_nivcsws,'
          'kc.exec_user_time as exec_user_time,'
          'kc.exec_system_time as exec_system_time,'
          'kc.exec_minflts as exec_minflts,'
          'kc.exec_majflts as exec_majflts,'
          'kc.exec_nswaps as exec_nswaps,'
          'kc.exec_reads as exec_reads,'
          'kc.exec_writes as exec_writes,'
          'kc.exec_msgsnds as exec_msgsnds,'
          'kc.exec_msgrcvs as exec_msgrcvs,'
          'kc.exec_nsignals as exec_nsignals,'
          'kc.exec_nvcsws as exec_nvcsws,'
          'kc.exec_nivcsws as exec_nivcsws'
        );
        st_query := replace(st_query, '{kcache_stats}',format(
          'LEFT OUTER JOIN %1$I.pg_stat_kcache() kc USING (queryid, userid, dbid) ',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_kcache'
            )
          ));
        st_query := replace(st_query, '{kcache_rank_calc}',
          ', row_number() OVER (ORDER BY '
            'COALESCE(plan_user_time, 0.0) +'
            'COALESCE(plan_system_time, 0.0) '
            'DESC) AS plan_cpu_time_rank '
          ', row_number() OVER (ORDER BY '
            'COALESCE(exec_user_time, 0.0) +'
            'COALESCE(exec_system_time, 0.0) '
            'DESC) AS exec_cpu_time_rank '
          ', row_number() OVER (ORDER BY '
            'COALESCE(plan_reads, 0) + '
            'COALESCE(plan_writes, 0) '
            'DESC) AS plan_io_rank '
          ', row_number() OVER (ORDER BY '
            'COALESCE(exec_reads, 0) + '
            'COALESCE(exec_writes, 0) '
            'DESC) AS exec_io_rank '
        );
        st_query := replace(st_query, '{kcache_rank_join}',format(
          'LEFT OUTER JOIN %1$I.pg_stat_kcache() k USING (queryid, userid, dbid) ',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_kcache'
            )
          ));
        st_query := replace(st_query, '{kcache_rank_fields}',
          ',plan_cpu_time_rank,'
          'exec_cpu_time_rank,'
          'plan_io_rank,'
          'exec_io_rank'
        );
      ELSE -- suitable pg_stat_kcache version not found
        st_query := replace(st_query, '{kcache_stats}','');
        st_query := replace(st_query, '{kcache_rank_calc}','');
        st_query := replace(st_query, '{kcache_rank_join}','');
        st_query := replace(st_query, '{kcache_rank_fields}','');
        st_query := replace(st_query, '{kcache_fields}',
          ',false as kcache_avail,'
          'NULL as plan_user_time,'
          'NULL as plan_system_time,'
          'NULL as plan_minflts,'
          'NULL as plan_majflts,'
          'NULL as plan_nswaps,'
          'NULL as plan_reads,'
          'NULL as plan_writes,'
          'NULL as plan_msgsnds,'
          'NULL as plan_msgrcvs,'
          'NULL as plan_nsignals,'
          'NULL as plan_nvcsws,'
          'NULL as plan_nivcsws,'
          'NULL as exec_user_time,'
          'NULL as exec_system_time,'
          'NULL as exec_minflts,'
          'NULL as exec_majflts,'
          'NULL as exec_nswaps,'
          'NULL as exec_reads,'
          'NULL as exec_writes,'
          'NULL as exec_msgsnds,'
          'NULL as exec_msgrcvs,'
          'NULL as exec_nsignals,'
          'NULL as exec_nvcsws,'
          'NULL as exec_nivcsws');
    END CASE; --pg_stat_kcache versions

    -- RAISE LOG 'stmts query: %',st_query; -- statements query debug
    -- Sample data from pg_stat_statements and pg_stat_kcache top whole cluster statements
    FOR qres IN
        SELECT
          -- pg_stat_statements fields
          sserver_id,
          s_id AS sample_id,
          dbl.userid AS userid,
          dbl.datid AS datid,
          dbl.queryid AS queryid,
          dbl.queryid_md5 AS queryid_md5,
          dbl.toplevel AS toplevel,
          dbl.plans AS plans,
          dbl.total_plan_time AS total_plan_time,
          dbl.min_plan_time AS min_plan_time,
          dbl.max_plan_time AS max_plan_time,
          dbl.mean_plan_time AS mean_plan_time,
          dbl.stddev_plan_time AS stddev_plan_time,
          dbl.calls  AS calls,
          dbl.total_exec_time  AS total_exec_time,
          dbl.min_exec_time  AS min_exec_time,
          dbl.max_exec_time  AS max_exec_time,
          dbl.mean_exec_time  AS mean_exec_time,
          dbl.stddev_exec_time  AS stddev_exec_time,
          dbl.rows  AS rows,
          dbl.shared_blks_hit  AS shared_blks_hit,
          dbl.shared_blks_read  AS shared_blks_read,
          dbl.shared_blks_dirtied  AS shared_blks_dirtied,
          dbl.shared_blks_written  AS shared_blks_written,
          dbl.local_blks_hit  AS local_blks_hit,
          dbl.local_blks_read  AS local_blks_read,
          dbl.local_blks_dirtied  AS local_blks_dirtied,
          dbl.local_blks_written  AS local_blks_written,
          dbl.temp_blks_read  AS temp_blks_read,
          dbl.temp_blks_written  AS temp_blks_written,
          dbl.blk_read_time  AS blk_read_time,
          dbl.blk_write_time  AS blk_write_time,
          dbl.wal_records AS wal_records,
          dbl.wal_fpi AS wal_fpi,
          dbl.wal_bytes AS wal_bytes,
          dbl.query AS query,
          -- pg_stat_kcache fields
          dbl.kcache_avail AS kcache_avail,
          dbl.plan_user_time  AS plan_user_time,
          dbl.plan_system_time  AS plan_system_time,
          dbl.plan_minflts  AS plan_minflts,
          dbl.plan_majflts  AS plan_majflts,
          dbl.plan_nswaps  AS plan_nswaps,
          dbl.plan_reads  AS plan_reads,
          dbl.plan_writes  AS plan_writes,
          dbl.plan_msgsnds  AS plan_msgsnds,
          dbl.plan_msgrcvs  AS plan_msgrcvs,
          dbl.plan_nsignals  AS plan_nsignals,
          dbl.plan_nvcsws  AS plan_nvcsws,
          dbl.plan_nivcsws  AS plan_nivcsws,
          dbl.exec_user_time  AS exec_user_time,
          dbl.exec_system_time  AS exec_system_time,
          dbl.exec_minflts  AS exec_minflts,
          dbl.exec_majflts  AS exec_majflts,
          dbl.exec_nswaps  AS exec_nswaps,
          dbl.exec_reads  AS exec_reads,
          dbl.exec_writes  AS exec_writes,
          dbl.exec_msgsnds  AS exec_msgsnds,
          dbl.exec_msgrcvs  AS exec_msgrcvs,
          dbl.exec_nsignals  AS exec_nsignals,
          dbl.exec_nvcsws  AS exec_nvcsws,
          dbl.exec_nivcsws  AS exec_nivcsws
        FROM dblink('server_connection',st_query)
        AS dbl (
          -- pg_stat_statements fields
            userid              oid,
            datid               oid,
            queryid             bigint,
            queryid_md5         char(32),
            toplevel            boolean,
            plans               bigint,
            total_plan_time     double precision,
            min_plan_time       double precision,
            max_plan_time       double precision,
            mean_plan_time      double precision,
            stddev_plan_time    double precision,
            calls               bigint,
            total_exec_time     double precision,
            min_exec_time       double precision,
            max_exec_time       double precision,
            mean_exec_time      double precision,
            stddev_exec_time    double precision,
            rows                bigint,
            shared_blks_hit     bigint,
            shared_blks_read    bigint,
            shared_blks_dirtied bigint,
            shared_blks_written bigint,
            local_blks_hit      bigint,
            local_blks_read     bigint,
            local_blks_dirtied  bigint,
            local_blks_written  bigint,
            temp_blks_read      bigint,
            temp_blks_written   bigint,
            blk_read_time       double precision,
            blk_write_time      double precision,
            wal_records         bigint,
            wal_fpi             bigint,
            wal_bytes           numeric,
            query               text,
          -- pg_stat_kcache fields
            kcache_avail        boolean,
            plan_user_time      double precision, --  User CPU time used
            plan_system_time    double precision, --  System CPU time used
            plan_minflts         bigint, -- Number of page reclaims (soft page faults)
            plan_majflts         bigint, -- Number of page faults (hard page faults)
            plan_nswaps         bigint, -- Number of swaps
            plan_reads          bigint, -- Number of bytes read by the filesystem layer
            --reads_blks          bigint, -- Number of 8K blocks read by the filesystem layer
            plan_writes         bigint, -- Number of bytes written by the filesystem layer
            --plan_writes_blks         bigint, -- Number of 8K blocks written by the filesystem layer
            plan_msgsnds        bigint, -- Number of IPC messages sent
            plan_msgrcvs        bigint, -- Number of IPC messages received
            plan_nsignals       bigint, -- Number of signals received
            plan_nvcsws         bigint, -- Number of voluntary context switches
            plan_nivcsws        bigint,
            exec_user_time      double precision, --  User CPU time used
            exec_system_time    double precision, --  System CPU time used
            exec_minflts         bigint, -- Number of page reclaims (soft page faults)
            exec_majflts         bigint, -- Number of page faults (hard page faults)
            exec_nswaps         bigint, -- Number of swaps
            exec_reads          bigint, -- Number of bytes read by the filesystem layer
            --reads_blks          bigint, -- Number of 8K blocks read by the filesystem layer
            exec_writes         bigint, -- Number of bytes written by the filesystem layer
            --exec_writes_blks         bigint, -- Number of 8K blocks written by the filesystem layer
            exec_msgsnds        bigint, -- Number of IPC messages sent
            exec_msgrcvs        bigint, -- Number of IPC messages received
            exec_nsignals       bigint, -- Number of signals received
            exec_nvcsws         bigint, -- Number of voluntary context switches
            exec_nivcsws        bigint
        ) JOIN sample_stat_database sd ON (dbl.datid = sd.datid AND sd.sample_id = s_id AND sd.server_id = sserver_id)
    LOOP
        INSERT INTO stmt_list(
          server_id,
          queryid_md5,
          query
        )
        VALUES (sserver_id,qres.queryid_md5,qres.query) ON CONFLICT DO NOTHING;

        INSERT INTO sample_statements(
          server_id,
          sample_id,
          userid,
          datid,
          toplevel,
          queryid,
          queryid_md5,
          plans,
          total_plan_time,
          min_plan_time,
          max_plan_time,
          mean_plan_time,
          stddev_plan_time,
          calls,
          total_exec_time,
          min_exec_time,
          max_exec_time,
          mean_exec_time,
          stddev_exec_time,
          rows,
          shared_blks_hit,
          shared_blks_read,
          shared_blks_dirtied,
          shared_blks_written,
          local_blks_hit,
          local_blks_read,
          local_blks_dirtied,
          local_blks_written,
          temp_blks_read,
          temp_blks_written,
          blk_read_time,
          blk_write_time,
          wal_records,
          wal_fpi,
          wal_bytes
        )
        VALUES (
            qres.sserver_id,
            qres.sample_id,
            qres.userid,
            qres.datid,
            qres.toplevel,
            qres.queryid,
            qres.queryid_md5,
            qres.plans,
            qres.total_plan_time,
            qres.min_plan_time,
            qres.max_plan_time,
            qres.mean_plan_time,
            qres.stddev_plan_time,
            qres.calls,
            qres.total_exec_time,
            qres.min_exec_time,
            qres.max_exec_time,
            qres.mean_exec_time,
            qres.stddev_exec_time,
            qres.rows,
            qres.shared_blks_hit,
            qres.shared_blks_read,
            qres.shared_blks_dirtied,
            qres.shared_blks_written,
            qres.local_blks_hit,
            qres.local_blks_read,
            qres.local_blks_dirtied,
            qres.local_blks_written,
            qres.temp_blks_read,
            qres.temp_blks_written,
            qres.blk_read_time,
            qres.blk_write_time,
            qres.wal_records,
            qres.wal_fpi,
            qres.wal_bytes
        );
        IF qres.kcache_avail THEN
          INSERT INTO sample_kcache(
            server_id,
            sample_id,
            userid,
            datid,
            queryid,
            queryid_md5,
            plan_user_time,
            plan_system_time,
            plan_minflts,
            plan_majflts,
            plan_nswaps,
            plan_reads,
            plan_writes,
            plan_msgsnds,
            plan_msgrcvs,
            plan_nsignals,
            plan_nvcsws,
            plan_nivcsws,
            exec_user_time,
            exec_system_time,
            exec_minflts,
            exec_majflts,
            exec_nswaps,
            exec_reads,
            exec_writes,
            exec_msgsnds,
            exec_msgrcvs,
            exec_nsignals,
            exec_nvcsws,
            exec_nivcsws
          )
          VALUES (
            qres.sserver_id,
            qres.sample_id,
            qres.userid,
            qres.datid,
            qres.queryid,
            qres.queryid_md5,
            qres.plan_user_time,
            qres.plan_system_time,
            qres.plan_minflts,
            qres.plan_majflts,
            qres.plan_nswaps,
            qres.plan_reads,
            qres.plan_writes,
            qres.plan_msgsnds,
            qres.plan_msgrcvs,
            qres.plan_nsignals,
            qres.plan_nvcsws,
            qres.plan_nivcsws,
            qres.exec_user_time,
            qres.exec_system_time,
            qres.exec_minflts,
            qres.exec_majflts,
            qres.exec_nswaps,
            qres.exec_reads,
            qres.exec_writes,
            qres.exec_msgsnds,
            qres.exec_msgrcvs,
            qres.exec_nsignals,
            qres.exec_nvcsws,
            qres.exec_nivcsws
          );
        END IF;
    END LOOP;

    -- Agregated pg_stat_kcache data
    CASE (
        SELECT extversion FROM jsonb_to_recordset(properties #> '{extensions}')
          AS x(extname text, extversion text)
        WHERE extname = 'pg_stat_kcache'
    )
      WHEN '2.1.0','2.1.1','2.1.2','2.1.3' THEN
        INSERT INTO sample_kcache_total(
          server_id,
          sample_id,
          datid,
          exec_user_time,
          exec_system_time,
          exec_minflts,
          exec_majflts,
          exec_nswaps,
          exec_reads,
          exec_writes,
          exec_msgsnds,
          exec_msgrcvs,
          exec_nsignals,
          exec_nvcsws,
          exec_nivcsws,
          statements
        )
        SELECT sd.server_id,sd.sample_id,dbl.*
        FROM
          dblink('server_connection',
            format('SELECT
                dbid as datid,
                sum(user_time),
                sum(system_time),
                sum(minflts),
                sum(majflts),
                sum(nswaps),
                sum(reads),
                sum(writes),
                sum(msgsnds),
                sum(msgrcvs),
                sum(nsignals),
                sum(nvcsws),
                sum(nivcsws),
                count(*)
              FROM %1$I.pg_stat_kcache()
              GROUP BY dbid',
                (
                  SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                    AS x(extname text, extnamespace text)
                  WHERE extname = 'pg_stat_kcache'
                )
            )
          ) AS dbl (
            datid               oid,
            exec_user_time           double precision,
            exec_system_time         double precision,
            exec_minflts             bigint,
            exec_majflts             bigint, -- Number of page faults (hard page faults)
            exec_nswaps              bigint, -- Number of swaps
            exec_reads               bigint, -- Number of bytes read by the filesystem layer
            exec_writes              bigint, -- Number of bytes written by the filesystem layer
            exec_msgsnds             bigint, -- Number of IPC messages sent
            exec_msgrcvs             bigint, -- Number of IPC messages received
            exec_nsignals            bigint, -- Number of signals received
            exec_nvcsws              bigint, -- Number of voluntary context switches
            exec_nivcsws             bigint,
            stmts               integer
        ) JOIN sample_stat_database sd USING (datid)
        WHERE sd.sample_id = s_id AND sd.server_id = sserver_id;

        -- Flushing pg_stat_kcache
        SELECT * INTO qres FROM dblink('server_connection',
          format('SELECT %1$I.pg_stat_kcache_reset()',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_kcache'
            )
          )
        ) AS t(res char(1));
      WHEN '2.2.0' THEN
        INSERT INTO sample_kcache_total(
          server_id,
          sample_id,
          datid,
          plan_user_time,
          plan_system_time,
          plan_minflts,
          plan_majflts,
          plan_nswaps,
          plan_reads,
          plan_writes,
          plan_msgsnds,
          plan_msgrcvs,
          plan_nsignals,
          plan_nvcsws,
          plan_nivcsws,
          exec_user_time,
          exec_system_time,
          exec_minflts,
          exec_majflts,
          exec_nswaps,
          exec_reads,
          exec_writes,
          exec_msgsnds,
          exec_msgrcvs,
          exec_nsignals,
          exec_nvcsws,
          exec_nivcsws,
          statements
        )
        SELECT sd.server_id,sd.sample_id,dbl.*
        FROM
          dblink('server_connection',
            format('SELECT '
                'dbid as datid, '
                'sum(plan_user_time), '
                'sum(plan_system_time), '
                'sum(plan_minflts), '
                'sum(plan_majflts), '
                'sum(plan_nswaps), '
                'sum(plan_reads), '
                'sum(plan_writes), '
                'sum(plan_msgsnds), '
                'sum(plan_msgrcvs), '
                'sum(plan_nsignals), '
                'sum(plan_nvcsws), '
                'sum(plan_nivcsws), '
                'sum(exec_user_time), '
                'sum(exec_system_time), '
                'sum(exec_minflts), '
                'sum(exec_majflts), '
                'sum(exec_nswaps), '
                'sum(exec_reads), '
                'sum(exec_writes), '
                'sum(exec_msgsnds), '
                'sum(exec_msgrcvs), '
                'sum(exec_nsignals), '
                'sum(exec_nvcsws), '
                'sum(exec_nivcsws), '
                'count(*) '
              'FROM %1$I.pg_stat_kcache() '
              'WHERE top '
              'GROUP BY dbid',
                (
                  SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                    AS x(extname text, extnamespace text)
                  WHERE extname = 'pg_stat_kcache'
                )
            )
          ) AS dbl (
            datid               oid,
            plan_user_time      double precision,
            plan_system_time    double precision,
            plan_minflts         bigint,
            plan_majflts         bigint, -- Number of page faults (hard page faults)
            plan_nswaps         bigint, -- Number of swaps
            plan_reads          bigint, -- Number of bytes read by the filesystem layer
            plan_writes         bigint, -- Number of bytes written by the filesystem layer
            plan_msgsnds        bigint, -- Number of IPC messages sent
            plan_msgrcvs        bigint, -- Number of IPC messages received
            plan_nsignals       bigint, -- Number of signals received
            plan_nvcsws         bigint, -- Number of voluntary context switches
            plan_nivcsws        bigint,
            exec_user_time      double precision,
            exec_system_time    double precision,
            exec_minflts         bigint,
            exec_majflts         bigint, -- Number of page faults (hard page faults)
            exec_nswaps         bigint, -- Number of swaps
            exec_reads          bigint, -- Number of bytes read by the filesystem layer
            exec_writes         bigint, -- Number of bytes written by the filesystem layer
            exec_msgsnds        bigint, -- Number of IPC messages sent
            exec_msgrcvs        bigint, -- Number of IPC messages received
            exec_nsignals       bigint, -- Number of signals received
            exec_nvcsws         bigint, -- Number of voluntary context switches
            exec_nivcsws        bigint,
            stmts               integer
        ) JOIN sample_stat_database sd USING (datid)
        WHERE sd.sample_id = s_id AND sd.server_id = sserver_id;

        -- Flushing pg_stat_kcache
        SELECT * INTO qres FROM dblink('server_connection',
          format('SELECT %1$I.pg_stat_kcache_reset()',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_kcache'
            )
          )
        ) AS t(res char(1));
      ELSE
        NULL;
    END CASE;

    -- Agregated statements data
    CASE (
        SELECT extversion
        FROM jsonb_to_recordset(properties #> '{extensions}')
          AS ext(extname text, extversion text)
        WHERE extname = 'pg_stat_statements'
      )
      -- pg_stat_statements v 1.3-1.7
      WHEN '1.3','1.4','1.5','1.6','1.7' THEN
        st_query := format('SELECT '
            'dbid as datid,'
            'NULL,' -- plans
            'NULL,' -- total_plan_time
            'sum(calls),'
            'sum(total_time),'
            'sum(rows),'
            'sum(shared_blks_hit),'
            'sum(shared_blks_read),'
            'sum(shared_blks_dirtied),'
            'sum(shared_blks_written),'
            'sum(local_blks_hit),'
            'sum(local_blks_read),'
            'sum(local_blks_dirtied),'
            'sum(local_blks_written),'
            'sum(temp_blks_read),'
            'sum(temp_blks_written),'
            'sum(blk_read_time),'
            'sum(blk_write_time),'
            'NULL,' -- wal_records
            'NULL,' -- wal_fpi
            'NULL,' -- wal_bytes
            'count(*) '
        'FROM %1$I.pg_stat_statements '
        'GROUP BY dbid',
          (
            SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
              AS x(extname text, extnamespace text)
            WHERE extname = 'pg_stat_statements'
          )
        );
      -- pg_stat_statements v 1.8
      WHEN '1.8' THEN
        st_query := format('SELECT '
            'dbid as datid,'
            'sum(plans),'
            'sum(total_plan_time),'
            'sum(calls),'
            'sum(total_exec_time),'
            'sum(rows),'
            'sum(shared_blks_hit),'
            'sum(shared_blks_read),'
            'sum(shared_blks_dirtied),'
            'sum(shared_blks_written),'
            'sum(local_blks_hit),'
            'sum(local_blks_read),'
            'sum(local_blks_dirtied),'
            'sum(local_blks_written),'
            'sum(temp_blks_read),'
            'sum(temp_blks_written),'
            'sum(blk_read_time),'
            'sum(blk_write_time),'
            'sum(wal_records),'
            'sum(wal_fpi),'
            'sum(wal_bytes),'
            'count(*) '
        'FROM %1$I.pg_stat_statements '
        'GROUP BY dbid',
          (
            SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
              AS x(extname text, extnamespace text)
            WHERE extname = 'pg_stat_statements'
          )
        );
      -- pg_stat_statements v 1.9
      WHEN '1.9' THEN
        st_query := format('SELECT '
            'dbid as datid,'
            'sum(plans),'
            'sum(total_plan_time),'
            'sum(calls),'
            'sum(total_exec_time),'
            'sum(rows),'
            'sum(shared_blks_hit),'
            'sum(shared_blks_read),'
            'sum(shared_blks_dirtied),'
            'sum(shared_blks_written),'
            'sum(local_blks_hit),'
            'sum(local_blks_read),'
            'sum(local_blks_dirtied),'
            'sum(local_blks_written),'
            'sum(temp_blks_read),'
            'sum(temp_blks_written),'
            'sum(blk_read_time),'
            'sum(blk_write_time),'
            'sum(wal_records),'
            'sum(wal_fpi),'
            'sum(wal_bytes),'
            'count(*) '
        'FROM %1$I.pg_stat_statements WHERE toplevel '
        'GROUP BY dbid',
          (
            SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
              AS x(extname text, extnamespace text)
            WHERE extname = 'pg_stat_statements'
          )
        );
      ELSE
        RAISE 'Unsupported pg_stat_statements version.';
    END CASE;

    INSERT INTO sample_statements_total(
      server_id,
      sample_id,
      datid,
      plans,
      total_plan_time,
      calls,
      total_exec_time,
      rows,
      shared_blks_hit,
      shared_blks_read,
      shared_blks_dirtied,
      shared_blks_written,
      local_blks_hit,
      local_blks_read,
      local_blks_dirtied,
      local_blks_written,
      temp_blks_read,
      temp_blks_written,
      blk_read_time,
      blk_write_time,
      wal_records,
      wal_fpi,
      wal_bytes,
      statements
    )
    SELECT sd.server_id,sd.sample_id,dbl.*
    FROM
    dblink('server_connection',st_query
    ) AS dbl (
        datid               oid,
        plans               bigint,
        total_plan_time     double precision,
        calls               bigint,
        total_exec_time     double precision,
        rows                bigint,
        shared_blks_hit     bigint,
        shared_blks_read    bigint,
        shared_blks_dirtied bigint,
        shared_blks_written bigint,
        local_blks_hit      bigint,
        local_blks_read     bigint,
        local_blks_dirtied  bigint,
        local_blks_written  bigint,
        temp_blks_read      bigint,
        temp_blks_written   bigint,
        blk_read_time       double precision,
        blk_write_time      double precision,
        wal_records         bigint,
        wal_fpi             bigint,
        wal_bytes           numeric,
        stmts               integer
    ) JOIN sample_stat_database sd USING (datid)
    WHERE sd.sample_id = s_id AND sd.server_id = sserver_id;

    -- Flushing statements
    CASE (
        SELECT extversion
        FROM jsonb_to_recordset(properties #> '{extensions}')
          AS ext(extname text, extversion text)
        WHERE extname = 'pg_stat_statements'
      )
      -- pg_stat_statements v 1.3-1.8
      WHEN '1.3','1.4','1.5','1.6','1.7','1.8','1.9' THEN
        SELECT * INTO qres FROM dblink('server_connection',
          format('SELECT %1$I.pg_stat_statements_reset()',
            (
              SELECT extnamespace FROM jsonb_to_recordset(properties #> '{extensions}')
                AS x(extname text, extnamespace text)
              WHERE extname = 'pg_stat_statements'
            )
          )
        ) AS t(res char(1));
      ELSE
        RAISE 'Unsupported pg_stat_statements version.';
    END CASE;
END;
$function$;

-- Function: collect_queries
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.collect_queries(userid oid, datid oid, queryid bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    INSERT INTO queries_list(
      userid,
      datid,
      queryid
    )
    VALUES (
      collect_queries.userid,
      collect_queries.datid,
      collect_queries.queryid
    )
    ON CONFLICT DO NOTHING;

    RETURN 0;
END;
$function$;

-- Function: create_baseline
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.create_baseline(baseline character varying, time_range tstzrange, days integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN create_baseline('local',baseline,time_range,days);
END;
$function$;

-- Function: create_baseline
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.create_baseline(baseline character varying, start_id integer, end_id integer, days integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN create_baseline('local',baseline,start_id,end_id,days);
END;
$function$;

-- Function: create_baseline
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.create_baseline(server name, baseline character varying, start_id integer, end_id integer, days integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    baseline_id integer;
    sserver_id     integer;
BEGIN
    SELECT server_id INTO sserver_id FROM servers WHERE server_name=server;
    IF sserver_id IS NULL THEN
        RAISE 'Server not found';
    END IF;

    INSERT INTO baselines(server_id,bl_name,keep_until)
    VALUES (sserver_id,baseline,now() + (days || ' days')::interval)
    RETURNING bl_id INTO baseline_id;

    INSERT INTO bl_samples (server_id,sample_id,bl_id)
    SELECT server_id,sample_id,baseline_id
    FROM samples s JOIN servers n USING (server_id)
    WHERE server_id=sserver_id AND sample_id BETWEEN start_id AND end_id;

    RETURN baseline_id;
END;
$function$;

-- Function: create_baseline
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.create_baseline(server name, baseline character varying, time_range tstzrange, days integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  range_ids record;
BEGIN
  SELECT * INTO STRICT range_ids
  FROM get_sampleids_by_timerange(get_server_by_name(server), time_range);

  RETURN create_baseline(server,baseline,range_ids.start_id,range_ids.end_id,days);
END;
$function$;

-- Function: create_server
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.create_server(server name, server_connstr text, server_enabled boolean DEFAULT true, max_sample_age integer DEFAULT NULL::integer, description text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    server_exists     integer;
    sserver_id        integer;
BEGIN

    SELECT count(*) INTO server_exists FROM servers WHERE server_name=server;
    IF server_exists > 0 THEN
        RAISE 'Server already exists.';
    END IF;

    INSERT INTO servers(server_name,server_description,connstr,enabled,max_sample_age)
    VALUES (server,description,server_connstr,server_enabled,max_sample_age)
    RETURNING server_id INTO sserver_id;

    RETURN sserver_id;
END;
$function$;

-- Function: dblink
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink(text, text, boolean)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_record$function$;

-- Function: dblink
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink(text, boolean)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_record$function$;

-- Function: dblink
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink(text)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_record$function$;

-- Function: dblink
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink(text, text)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_record$function$;

-- Function: dblink_build_sql_delete
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_build_sql_delete(text, int2vector, integer, text[])
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_build_sql_delete$function$;

-- Function: dblink_build_sql_insert
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_build_sql_insert(text, int2vector, integer, text[], text[])
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_build_sql_insert$function$;

-- Function: dblink_build_sql_update
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_build_sql_update(text, int2vector, integer, text[], text[])
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_build_sql_update$function$;

-- Function: dblink_cancel_query
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_cancel_query(text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_cancel_query$function$;

-- Function: dblink_close
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_close(text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_close$function$;

-- Function: dblink_close
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_close(text, text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_close$function$;

-- Function: dblink_close
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_close(text, text, boolean)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_close$function$;

-- Function: dblink_close
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_close(text, boolean)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_close$function$;

-- Function: dblink_connect
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_connect(text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_connect$function$;

-- Function: dblink_connect
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_connect(text, text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_connect$function$;

-- Function: dblink_connect_u
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_connect_u(text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT SECURITY DEFINER
AS '$libdir/dblink', $function$dblink_connect$function$;

-- Function: dblink_connect_u
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_connect_u(text, text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT SECURITY DEFINER
AS '$libdir/dblink', $function$dblink_connect$function$;

-- Function: dblink_current_query
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_current_query()
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED
AS '$libdir/dblink', $function$dblink_current_query$function$;

-- Function: dblink_disconnect
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_disconnect(text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_disconnect$function$;

-- Function: dblink_disconnect
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_disconnect()
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_disconnect$function$;

-- Function: dblink_error_message
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_error_message(text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_error_message$function$;

-- Function: dblink_exec
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_exec(text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_exec$function$;

-- Function: dblink_exec
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_exec(text, text, boolean)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_exec$function$;

-- Function: dblink_exec
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_exec(text, text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_exec$function$;

-- Function: dblink_exec
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_exec(text, boolean)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_exec$function$;

-- Function: dblink_fdw_validator
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_fdw_validator(options text[], catalog oid)
 RETURNS void
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/dblink', $function$dblink_fdw_validator$function$;

-- Function: dblink_fetch
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_fetch(text, text, integer, boolean)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_fetch$function$;

-- Function: dblink_fetch
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_fetch(text, integer)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_fetch$function$;

-- Function: dblink_fetch
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_fetch(text, integer, boolean)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_fetch$function$;

-- Function: dblink_fetch
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_fetch(text, text, integer)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_fetch$function$;

-- Function: dblink_get_connections
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_get_connections()
 RETURNS text[]
 LANGUAGE c
 PARALLEL RESTRICTED
AS '$libdir/dblink', $function$dblink_get_connections$function$;

-- Function: dblink_get_notify
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_get_notify(OUT notify_name text, OUT be_pid integer, OUT extra text)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_get_notify$function$;

-- Function: dblink_get_notify
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_get_notify(conname text, OUT notify_name text, OUT be_pid integer, OUT extra text)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_get_notify$function$;

-- Function: dblink_get_pkey
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_get_pkey(text)
 RETURNS SETOF dblink_pkey_results
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_get_pkey$function$;

-- Function: dblink_get_result
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_get_result(text, boolean)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_get_result$function$;

-- Function: dblink_get_result
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_get_result(text)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_get_result$function$;

-- Function: dblink_is_busy
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_is_busy(text)
 RETURNS integer
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_is_busy$function$;

-- Function: dblink_open
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_open(text, text, text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_open$function$;

-- Function: dblink_open
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_open(text, text)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_open$function$;

-- Function: dblink_open
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_open(text, text, text, boolean)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_open$function$;

-- Function: dblink_open
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_open(text, text, boolean)
 RETURNS text
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_open$function$;

-- Function: dblink_send_query
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dblink_send_query(text, text)
 RETURNS integer
 LANGUAGE c
 PARALLEL RESTRICTED STRICT
AS '$libdir/dblink', $function$dblink_send_query$function$;

-- Function: dbstats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dbstats(sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS TABLE(server_id integer, datid oid, dbname name, xact_commit bigint, xact_rollback bigint, blks_read bigint, blks_hit bigint, tup_returned bigint, tup_fetched bigint, tup_inserted bigint, tup_updated bigint, tup_deleted bigint, temp_files bigint, temp_bytes bigint, datsize_delta bigint, deadlocks bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        st.server_id AS server_id,
        st.datid AS datid,
        st.datname AS dbname,
        sum(xact_commit)::bigint AS xact_commit,
        sum(xact_rollback)::bigint AS xact_rollback,
        sum(blks_read)::bigint AS blks_read,
        sum(blks_hit)::bigint AS blks_hit,
        sum(tup_returned)::bigint AS tup_returned,
        sum(tup_fetched)::bigint AS tup_fetched,
        sum(tup_inserted)::bigint AS tup_inserted,
        sum(tup_updated)::bigint AS tup_updated,
        sum(tup_deleted)::bigint AS tup_deleted,
        sum(temp_files)::bigint AS temp_files,
        sum(temp_bytes)::bigint AS temp_bytes,
        sum(datsize_delta)::bigint AS datsize_delta,
        sum(deadlocks)::bigint AS deadlocks
    FROM sample_stat_database st
    WHERE st.server_id = sserver_id AND NOT datistemplate AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id, st.datid, st.datname
$function$;

-- Function: dbstats_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dbstats_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        COALESCE(COALESCE(dbs1.dbname,dbs2.dbname),'Total') AS dbname,
        NULLIF(sum(dbs1.xact_commit), 0) AS xact_commit1,
        NULLIF(sum(dbs1.xact_rollback), 0) AS xact_rollback1,
        NULLIF(sum(dbs1.blks_read), 0) AS blks_read1,
        NULLIF(sum(dbs1.blks_hit), 0) AS blks_hit1,
        NULLIF(sum(dbs1.tup_returned), 0) AS tup_returned1,
        NULLIF(sum(dbs1.tup_fetched), 0) AS tup_fetched1,
        NULLIF(sum(dbs1.tup_inserted), 0) AS tup_inserted1,
        NULLIF(sum(dbs1.tup_updated), 0) AS tup_updated1,
        NULLIF(sum(dbs1.tup_deleted), 0) AS tup_deleted1,
        NULLIF(sum(dbs1.temp_files), 0) AS temp_files1,
        pg_size_pretty(NULLIF(sum(dbs1.temp_bytes), 0)) AS temp_bytes1,
        pg_size_pretty(NULLIF(sum(st_last1.datsize), 0)) AS datsize1,
        pg_size_pretty(NULLIF(sum(dbs1.datsize_delta), 0)) AS datsize_delta1,
        NULLIF(sum(dbs1.deadlocks), 0) AS deadlocks1,
        (sum(dbs1.blks_hit)*100/NULLIF(sum(dbs1.blks_hit)+sum(dbs1.blks_read),0))::double precision AS blks_hit_pct1,
        NULLIF(sum(dbs2.xact_commit), 0) AS xact_commit2,
        NULLIF(sum(dbs2.xact_rollback), 0) AS xact_rollback2,
        NULLIF(sum(dbs2.blks_read), 0) AS blks_read2,
        NULLIF(sum(dbs2.blks_hit), 0) AS blks_hit2,
        NULLIF(sum(dbs2.tup_returned), 0) AS tup_returned2,
        NULLIF(sum(dbs2.tup_fetched), 0) AS tup_fetched2,
        NULLIF(sum(dbs2.tup_inserted), 0) AS tup_inserted2,
        NULLIF(sum(dbs2.tup_updated), 0) AS tup_updated2,
        NULLIF(sum(dbs2.tup_deleted), 0) AS tup_deleted2,
        NULLIF(sum(dbs2.temp_files), 0) AS temp_files2,
        pg_size_pretty(NULLIF(sum(dbs2.temp_bytes), 0)) AS temp_bytes2,
        pg_size_pretty(NULLIF(sum(st_last2.datsize), 0)) AS datsize2,
        pg_size_pretty(NULLIF(sum(dbs2.datsize_delta), 0)) AS datsize_delta2,
        NULLIF(sum(dbs2.deadlocks), 0) AS deadlocks2,
        (sum(dbs2.blks_hit)*100/NULLIF(sum(dbs2.blks_hit)+sum(dbs2.blks_read),0))::double precision AS blks_hit_pct2
    FROM dbstats(sserver_id,start1_id,end1_id,topn) dbs1 FULL OUTER JOIN dbstats(sserver_id,start2_id,end2_id,topn) dbs2
        USING (server_id, datid)
      LEFT OUTER JOIN sample_stat_database st_last1 ON
        (st_last1.server_id = dbs1.server_id AND st_last1.datid = dbs1.datid AND st_last1.sample_id = end1_id)
      LEFT OUTER JOIN sample_stat_database st_last2 ON
        (st_last2.server_id = dbs2.server_id AND st_last2.datid = dbs2.datid AND st_last2.sample_id = end2_id)
    GROUP BY ROLLUP(COALESCE(dbs1.dbname,dbs2.dbname))
    ORDER BY COALESCE(dbs1.dbname,dbs2.dbname) NULLS LAST;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">I</th>'
            '<th colspan="3">Transactions</th>'
            '<th colspan="3">Block statistics</th>'
            '<th colspan="5">Tuples</th>'
            '<th colspan="2">Temp files</th>'
            '<th rowspan="2" title="Database size as is was at the moment of last sample in report interval">Size</th>'
            '<th rowspan="2" title="Database size increment during report interval">Growth</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of transactions in this database that have been committed">Commits</th>'
            '<th title="Number of transactions in this database that have been rolled back">Rollbacks</th>'
            '<th title="Number of deadlocks detected in this database">Deadlocks</th>'
            '<th title="Buffer cache hit ratio">Hit(%)</th>'
            '<th title="Number of disk blocks read in this database">Read</th>'
            '<th title="Number of times disk blocks were found already in the buffer cache">Hit</th>'
            '<th title="Number of rows returned by queries in this database">Ret</th>'
            '<th title="Number of rows fetched by queries in this database">Fet</th>'
            '<th title="Number of rows inserted by queries in this database">Ins</th>'
            '<th title="Number of rows updated by queries in this database">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Total amount of data written to temporary files by queries in this database">Size</th>'
            '<th title="Number of temporary files created by queries in this database">Files</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'db_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates

    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['db_tpl'],
            r_result.dbname,
            r_result.xact_commit1,
            r_result.xact_rollback1,
            r_result.deadlocks1,
            round(CAST(r_result.blks_hit_pct1 AS numeric),2),
            r_result.blks_read1,
            r_result.blks_hit1,
            r_result.tup_returned1,
            r_result.tup_fetched1,
            r_result.tup_inserted1,
            r_result.tup_updated1,
            r_result.tup_deleted1,
            r_result.temp_bytes1,
            r_result.temp_files1,
            r_result.datsize1,
            r_result.datsize_delta1,
            r_result.xact_commit2,
            r_result.xact_rollback2,
            r_result.deadlocks2,
            round(CAST(r_result.blks_hit_pct2 AS numeric),2),
            r_result.blks_read2,
            r_result.blks_hit2,
            r_result.tup_returned2,
            r_result.tup_fetched2,
            r_result.tup_inserted2,
            r_result.tup_updated2,
            r_result.tup_deleted2,
            r_result.temp_bytes2,
            r_result.temp_files2,
            r_result.datsize2,
            r_result.datsize_delta2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: dbstats_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dbstats_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        COALESCE(st.dbname,'Total') as dbname,
        NULLIF(sum(st.xact_commit), 0) as xact_commit,
        NULLIF(sum(st.xact_rollback), 0) as xact_rollback,
        NULLIF(sum(st.blks_read), 0) as blks_read,
        NULLIF(sum(st.blks_hit), 0) as blks_hit,
        NULLIF(sum(st.tup_returned), 0) as tup_returned,
        NULLIF(sum(st.tup_fetched), 0) as tup_fetched,
        NULLIF(sum(st.tup_inserted), 0) as tup_inserted,
        NULLIF(sum(st.tup_updated), 0) as tup_updated,
        NULLIF(sum(st.tup_deleted), 0) as tup_deleted,
        NULLIF(sum(st.temp_files), 0) as temp_files,
        pg_size_pretty(NULLIF(sum(st.temp_bytes), 0)) AS temp_bytes,
        pg_size_pretty(NULLIF(sum(st_last.datsize), 0)) AS datsize,
        pg_size_pretty(NULLIF(sum(st.datsize_delta), 0)) AS datsize_delta,
        NULLIF(sum(st.deadlocks), 0) as deadlocks,
        (sum(st.blks_hit)*100/NULLIF(sum(st.blks_hit)+sum(st.blks_read),0))::double precision AS blks_hit_pct
    FROM dbstats(sserver_id,start_id,end_id,topn) st
      LEFT OUTER JOIN sample_stat_database st_last ON
        (st_last.server_id = st.server_id AND st_last.datid = st.datid AND st_last.sample_id = end_id)
    GROUP BY ROLLUP(st.dbname)
    ORDER BY st.dbname NULLS LAST;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Database</th>'
            '<th colspan="3">Transactions</th>'
            '<th colspan="3">Block statistics</th>'
            '<th colspan="5">Tuples</th>'
            '<th colspan="2">Temp files</th>'
            '<th rowspan="2" title="Database size as is was at the moment of last sample in report interval">Size</th>'
            '<th rowspan="2" title="Database size increment during report interval">Growth</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of transactions in this database that have been committed">Commits</th>'
            '<th title="Number of transactions in this database that have been rolled back">Rollbacks</th>'
            '<th title="Number of deadlocks detected in this database">Deadlocks</th>'
            '<th title="Buffer cache hit ratio">Hit(%)</th>'
            '<th title="Number of disk blocks read in this database">Read</th>'
            '<th title="Number of times disk blocks were found already in the buffer cache">Hit</th>'
            '<th title="Number of rows returned by queries in this database">Ret</th>'
            '<th title="Number of rows fetched by queries in this database">Fet</th>'
            '<th title="Number of rows inserted by queries in this database">Ins</th>'
            '<th title="Number of rows updated by queries in this database">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Total amount of data written to temporary files by queries in this database">Size</th>'
            '<th title="Number of temporary files created by queries in this database">Files</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'db_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
          -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['db_tpl'],
            r_result.dbname,
            r_result.xact_commit,
            r_result.xact_rollback,
            r_result.deadlocks,
            round(CAST(r_result.blks_hit_pct AS numeric),2),
            r_result.blks_read,
            r_result.blks_hit,
            r_result.tup_returned,
            r_result.tup_fetched,
            r_result.tup_inserted,
            r_result.tup_updated,
            r_result.tup_deleted,
            r_result.temp_bytes,
            r_result.temp_files,
            r_result.datsize,
            r_result.datsize_delta
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: dbstats_reset
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dbstats_reset(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(datname name, stats_reset timestamp with time zone, sample_id integer)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        st1.datname,
        st1.stats_reset,
        st1.sample_id
    FROM sample_stat_database st1
        LEFT JOIN sample_stat_database st0 ON
          (st0.server_id = st1.server_id AND st0.sample_id = st1.sample_id - 1 AND st0.datid = st1.datid)
    WHERE st1.server_id = sserver_id AND NOT st1.datistemplate AND st1.sample_id BETWEEN start_id + 1 AND end_id
      AND nullif(st1.stats_reset,st0.stats_reset) IS NOT NULL
    ORDER BY sample_id ASC
$function$;

-- Function: dbstats_reset_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dbstats_reset_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        interval_num,
        datname,
        sample_id,
        stats_reset
    FROM
      (SELECT 1 AS interval_num, datname, sample_id, stats_reset
        FROM dbstats_reset(sserver_id,start1_id,end1_id)
      UNION ALL
      SELECT 2 AS interval_num, datname, sample_id, stats_reset
        FROM dbstats_reset(sserver_id,start2_id,end2_id)) AS samples
    ORDER BY interval_num, stats_reset ASC;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>I</th>'
            '<th>Database</th>'
            '<th>Sample</th>'
            '<th>Reset time</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'sample_tpl1',
        '<tr {interval1}>'
          '<td {label} {title1}>1</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'sample_tpl2',
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
      CASE r_result.interval_num
        WHEN 1 THEN
          report := report||format(
              jtab_tpl #>> ARRAY['sample_tpl1'],
              r_result.datname,
              r_result.sample_id,
              r_result.stats_reset
          );
        WHEN 2 THEN
          report := report||format(
              jtab_tpl #>> ARRAY['sample_tpl2'],
              r_result.datname,
              r_result.sample_id,
              r_result.stats_reset
          );
        END CASE;
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: dbstats_reset_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dbstats_reset_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        datname,
        sample_id,
        stats_reset
    FROM dbstats_reset(sserver_id,start_id,end_id)
      ORDER BY stats_reset ASC;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Database</th>'
            '<th>Sample</th>'
            '<th>Reset time</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'sample_tpl',
      '<tr>'
        '<td>%s</td>'
        '<td {value}>%s</td>'
        '<td {value}>%s</td>'
      '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['sample_tpl'],
            r_result.datname,
            r_result.sample_id,
            r_result.stats_reset
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: dbstats_sessions
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dbstats_sessions(sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS TABLE(server_id integer, datid oid, dbname name, session_time double precision, active_time double precision, idle_in_transaction_time double precision, sessions bigint, sessions_abandoned bigint, sessions_fatal bigint, sessions_killed bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        st.server_id AS server_id,
        st.datid AS datid,
        st.datname AS dbname,
        sum(session_time)::double precision AS xact_commit,
        sum(active_time)::double precision AS xact_rollback,
        sum(idle_in_transaction_time)::double precision AS blks_read,
        sum(sessions)::bigint AS blks_hit,
        sum(sessions_abandoned)::bigint AS tup_returned,
        sum(sessions_fatal)::bigint AS tup_fetched,
        sum(sessions_killed)::bigint AS tup_inserted
    FROM sample_stat_database st
    WHERE st.server_id = sserver_id AND NOT datistemplate AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id, st.datid, st.datname
$function$;

-- Function: dbstats_sessions_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dbstats_sessions_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        COALESCE(COALESCE(dbs1.dbname,dbs2.dbname),'Total') AS dbname,
        NULLIF(sum(dbs1.session_time), 0) as session_time1,
        NULLIF(sum(dbs1.active_time), 0) as active_time1,
        NULLIF(sum(dbs1.idle_in_transaction_time), 0) as idle_in_transaction_time1,
        NULLIF(sum(dbs1.sessions), 0) as sessions1,
        NULLIF(sum(dbs1.sessions_abandoned), 0) as sessions_abandoned1,
        NULLIF(sum(dbs1.sessions_fatal), 0) as sessions_fatal1,
        NULLIF(sum(dbs1.sessions_killed), 0) as sessions_killed1,
        NULLIF(sum(dbs2.session_time), 0) as session_time2,
        NULLIF(sum(dbs2.active_time), 0) as active_time2,
        NULLIF(sum(dbs2.idle_in_transaction_time), 0) as idle_in_transaction_time2,
        NULLIF(sum(dbs2.sessions), 0) as sessions2,
        NULLIF(sum(dbs2.sessions_abandoned), 0) as sessions_abandoned2,
        NULLIF(sum(dbs2.sessions_fatal), 0) as sessions_fatal2,
        NULLIF(sum(dbs2.sessions_killed), 0) as sessions_killed2
    FROM dbstats_sessions(sserver_id,start1_id,end1_id,topn) dbs1
      FULL OUTER JOIN dbstats_sessions(sserver_id,start2_id,end2_id,topn) dbs2
        USING (server_id, datid)
      LEFT OUTER JOIN sample_stat_database st_last1 ON
        (st_last1.server_id = dbs1.server_id AND st_last1.datid = dbs1.datid AND st_last1.sample_id = end1_id)
      LEFT OUTER JOIN sample_stat_database st_last2 ON
        (st_last2.server_id = dbs2.server_id AND st_last2.datid = dbs2.datid AND st_last2.sample_id = end2_id)
    GROUP BY ROLLUP(COALESCE(dbs1.dbname,dbs2.dbname))
    ORDER BY COALESCE(dbs1.dbname,dbs2.dbname) NULLS LAST;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">I</th>'
            '<th colspan="3" title="Session timings for databases">Timings (s)</th>'
            '<th colspan="4" title="Session counts for databases">Sessions</th>'
          '</tr>'
          '<tr>'
            '<th title="Time spent by database sessions in this database (note that statistics are only updated when the state of a session changes, so if sessions have been idle for a long time, this idle time won''t be included)">Total</th>'
            '<th title="Time spent executing SQL statements in this database (this corresponds to the states active and fastpath function call in pg_stat_activity)">Active</th>'
            '<th title="Time spent idling while in a transaction in this database (this corresponds to the states idle in transaction and idle in transaction (aborted) in pg_stat_activity)">Idle(T)</th>'
            '<th title="Total number of sessions established to this database">Established</th>'
            '<th title="Number of database sessions to this database that were terminated because connection to the client was lost">Abondoned</th>'
            '<th title="Number of database sessions to this database that were terminated by fatal errors">Fatal</th>'
            '<th title="Number of database sessions to this database that were terminated by operator intervention">Killed</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'db_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates

    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['db_tpl'],
            r_result.dbname,
            round(CAST(r_result.session_time1 / 1000 AS numeric),2),
            round(CAST(r_result.active_time1 / 1000 AS numeric),2),
            round(CAST(r_result.idle_in_transaction_time1 / 1000 AS numeric),2),
            r_result.sessions1,
            r_result.sessions_abandoned1,
            r_result.sessions_fatal1,
            r_result.sessions_killed1,
            round(CAST(r_result.session_time2 / 1000 AS numeric),2),
            round(CAST(r_result.active_time2 / 1000 AS numeric),2),
            round(CAST(r_result.idle_in_transaction_time2 / 1000 AS numeric),2),
            r_result.sessions2,
            r_result.sessions_abandoned2,
            r_result.sessions_fatal2,
            r_result.sessions_killed2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: dbstats_sessions_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.dbstats_sessions_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        COALESCE(st.dbname,'Total') as dbname,
        NULLIF(sum(st.session_time), 0) as session_time,
        NULLIF(sum(st.active_time), 0) as active_time,
        NULLIF(sum(st.idle_in_transaction_time), 0) as idle_in_transaction_time,
        NULLIF(sum(st.sessions), 0) as sessions,
        NULLIF(sum(st.sessions_abandoned), 0) as sessions_abandoned,
        NULLIF(sum(st.sessions_fatal), 0) as sessions_fatal,
        NULLIF(sum(st.sessions_killed), 0) as sessions_killed
    FROM dbstats_sessions(sserver_id,start_id,end_id,topn) st
      LEFT OUTER JOIN sample_stat_database st_last ON
        (st_last.server_id = st.server_id AND st_last.datid = st.datid AND st_last.sample_id = end_id)
    GROUP BY ROLLUP(st.dbname)
    ORDER BY st.dbname NULLS LAST;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Database</th>'
            '<th colspan="3" title="Session timings for databases">Timings (s)</th>'
            '<th colspan="4" title="Session counts for databases">Sessions</th>'
          '</tr>'
          '<tr>'
            '<th title="Time spent by database sessions in this database (note that statistics are only updated when the state of a session changes, so if sessions have been idle for a long time, this idle time won''t be included)">Total</th>'
            '<th title="Time spent executing SQL statements in this database (this corresponds to the states active and fastpath function call in pg_stat_activity)">Active</th>'
            '<th title="Time spent idling while in a transaction in this database (this corresponds to the states idle in transaction and idle in transaction (aborted) in pg_stat_activity)">Idle(T)</th>'
            '<th title="Total number of sessions established to this database">Established</th>'
            '<th title="Number of database sessions to this database that were terminated because connection to the client was lost">Abondoned</th>'
            '<th title="Number of database sessions to this database that were terminated by fatal errors">Fatal</th>'
            '<th title="Number of database sessions to this database that were terminated by operator intervention">Killed</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'db_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
          -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['db_tpl'],
            r_result.dbname,
            round(CAST(r_result.session_time / 1000 AS numeric),2),
            round(CAST(r_result.active_time / 1000 AS numeric),2),
            round(CAST(r_result.idle_in_transaction_time / 1000 AS numeric),2),
            r_result.sessions,
            r_result.sessions_abandoned,
            r_result.sessions_fatal,
            r_result.sessions_killed
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: disable_server
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.disable_server(server name)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET enabled = FALSE WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$function$;

-- Function: drop_baseline
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.drop_baseline(server name, baseline character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    del_rows integer;
BEGIN
    DELETE FROM baselines WHERE bl_name = baseline AND server_id IN (SELECT server_id FROM servers WHERE server_name = server);
    GET DIAGNOSTICS del_rows = ROW_COUNT;
    RETURN del_rows;
END;
$function$;

-- Function: drop_baseline
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.drop_baseline(baseline character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN drop_baseline('local',baseline);
END;
$function$;

-- Function: drop_server
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.drop_server(server name)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    del_rows    integer;
    dserver_id  integer;
BEGIN
    SELECT server_id INTO STRICT dserver_id FROM servers WHERE server_name = server;
    DELETE FROM bl_samples WHERE server_id = dserver_id;
    DELETE FROM last_stat_cluster WHERE server_id = dserver_id;
    DELETE FROM last_stat_wal WHERE server_id = dserver_id;
    DELETE FROM last_stat_tables WHERE server_id = dserver_id;
    DELETE FROM last_stat_indexes WHERE server_id = dserver_id;
    DELETE FROM last_stat_user_functions WHERE server_id = dserver_id;
    DELETE FROM last_stat_database WHERE server_id = dserver_id;
    DELETE FROM last_stat_tablespaces WHERE server_id = dserver_id;
    DELETE FROM last_stat_archiver WHERE server_id = dserver_id;
    DELETE FROM sample_stat_tablespaces WHERE server_id = dserver_id;
    DELETE FROM tablespaces_list WHERE server_id = dserver_id;
    DELETE FROM indexes_list WHERE server_id = dserver_id;
    DELETE FROM tables_list WHERE server_id = dserver_id;
    DELETE FROM sample_stat_user_functions WHERE server_id = dserver_id;
    DELETE FROM funcs_list WHERE server_id = dserver_id;
    DELETE FROM sample_statements WHERE server_id = dserver_id;
    DELETE FROM stmt_list WHERE server_id = dserver_id;
    DELETE FROM servers WHERE server_name = server;
    GET DIAGNOSTICS del_rows = ROW_COUNT;
    RETURN del_rows;
END;
$function$;

-- Function: enable_server
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.enable_server(server name)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET enabled = TRUE WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$function$;

-- Function: export_data
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.export_data(server_name name DEFAULT NULL::name, min_sample_id integer DEFAULT NULL::integer, max_sample_id integer DEFAULT NULL::integer, obfuscate_queries boolean DEFAULT false)
 RETURNS TABLE(section_id bigint, row_data json)
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  section_counter   bigint = 0;
  ext_version       text = NULL;
  tables_list       json = NULL;
  sserver_id        integer = NULL;
  r_result          RECORD;
BEGIN
  /*
    Exported table will contain rows of extension tables, packed in JSON
    Each row will have a section ID, defining a table in most cases
    First sections contains metadata - extension name and version, tables list
  */
  -- Extension info
  IF (SELECT count(*) = 1 FROM pg_catalog.pg_extension WHERE extname = 'pg_profile') THEN
    SELECT extversion INTO STRICT r_result FROM pg_catalog.pg_extension WHERE extname = 'pg_profile';
    ext_version := r_result.extversion;
  ELSE
    ext_version := '0.3.4';
  END IF;
  RETURN QUERY EXECUTE $q$SELECT $3, row_to_json(s)
    FROM (SELECT $1 AS extension,
              $2 AS version,
              $3 + 1 AS tab_list_section
    ) s$q$
    USING 'pg_profile', ext_version, section_counter;
  section_counter := section_counter + 1;
  -- tables list
  EXECUTE $q$
    WITH RECURSIVE exp_tables (reloid, relname, inc_rels) AS (
      -- start with all independent tables
        SELECT rel.oid, rel.relname, array_agg(rel.oid) OVER()
          FROM pg_depend dep
            JOIN pg_extension ext ON (dep.refobjid = ext.oid)
            JOIN pg_class rel ON (rel.oid = dep.objid AND rel.relkind= 'r')
            LEFT OUTER JOIN fkdeps con ON (con.reloid = dep.objid)
          WHERE ext.extname = $1 AND rel.relname NOT LIKE ('import%') AND con.reloid IS NULL
      UNION
      -- and add all tables that have resolved dependencies by previously added tables
          SELECT con.reloid as reloid, con.relname, recurse.inc_rels||array_agg(con.reloid) OVER()
          FROM
            fkdeps con JOIN
            exp_tables recurse ON
              (array_append(recurse.inc_rels,con.reloid) @> con.reldeps AND
              NOT ARRAY[con.reloid] <@ recurse.inc_rels)
    ),
    fkdeps (reloid, relname, reldeps) AS (
      -- tables with their foreign key dependencies
      SELECT rel.oid as reloid, rel.relname, array_agg(con.confrelid), array_agg(rel.oid) OVER()
      FROM pg_depend dep
        JOIN pg_extension ext ON (dep.refobjid = ext.oid)
        JOIN pg_class rel ON (rel.oid = dep.objid AND rel.relkind= 'r')
        JOIN pg_constraint con ON (con.conrelid = dep.objid AND con.contype = 'f')
      WHERE ext.extname = $1 AND rel.relname NOT LIKE ('import%')
      GROUP BY rel.oid, rel.relname
    )
    SELECT json_agg(row_to_json(tl)) FROM
    (SELECT row_number() OVER() + $2 AS section_id, relname FROM exp_tables) tl ;
  $q$ INTO tables_list
  USING 'pg_profile', section_counter;
  section_id := section_counter;
  row_data := tables_list;
  RETURN NEXT;
  section_counter := section_counter + 1;
  -- Server selection
  IF export_data.server_name IS NOT NULL THEN
    sserver_id := get_server_by_name(export_data.server_name);
  END IF;
  -- Tables data
  FOR r_result IN
    SELECT json_array_elements(tables_list)->>'relname' as relname
  LOOP
    -- Tables select conditions
    CASE
      WHEN r_result.relname != 'sample_settings'
        AND (r_result.relname LIKE 'sample%' OR r_result.relname LIKE 'last%') THEN
        RETURN QUERY EXECUTE format(
            $q$SELECT $1,row_to_json(dt) FROM
              (SELECT * FROM %I WHERE ($2 IS NULL OR $2 = server_id) AND
                ($3 IS NULL OR sample_id >= $3) AND
                ($4 IS NULL OR sample_id <= $4)) dt$q$,
            r_result.relname
          )
        USING
          section_counter,
          sserver_id,
          min_sample_id,
          max_sample_id;
      WHEN r_result.relname = 'bl_samples' THEN
        RETURN QUERY EXECUTE format(
            $q$
            SELECT $1,row_to_json(dt) FROM (
              SELECT *
              FROM %I b
                JOIN (
                  SELECT bl_id
                  FROM bl_samples
                    WHERE ($2 IS NULL OR $2 = server_id)
                  GROUP BY bl_id
                  HAVING
                    ($3 IS NULL OR min(sample_id) >= $3) AND
                    ($4 IS NULL OR max(sample_id) <= $4)
                ) bl_smp USING (bl_id)
              WHERE ($2 IS NULL OR $2 = server_id)
              ) dt$q$,
            r_result.relname
          )
        USING
          section_counter,
          sserver_id,
          min_sample_id,
          max_sample_id;
      WHEN r_result.relname = 'baselines' THEN
        RETURN QUERY EXECUTE format(
            $q$
            SELECT $1,row_to_json(dt) FROM (
              SELECT b.*
              FROM %I b
              JOIN bl_samples bs USING(server_id, bl_id)
                WHERE ($2 IS NULL OR $2 = server_id)
              GROUP BY b.server_id, b.bl_id, b.bl_name, b.keep_until
              HAVING
                ($3 IS NULL OR min(sample_id) >= $3) AND
                ($4 IS NULL OR max(sample_id) <= $4)
              ) dt$q$,
            r_result.relname
          )
        USING
          section_counter,
          sserver_id,
          min_sample_id,
          max_sample_id;
      WHEN r_result.relname = 'stmt_list' THEN
        RETURN QUERY EXECUTE format(
            $sql$SELECT $1,row_to_json(dt) FROM
              (SELECT rows.server_id, rows.queryid_md5,
                CASE $5
                  WHEN TRUE THEN pg_catalog.md5(rows.query)
                  ELSE rows.query
                END AS query
               FROM %I AS rows WHERE (server_id,queryid_md5) IN
                (SELECT server_id, queryid_md5 FROM sample_statements WHERE
                  ($2 IS NULL OR $2 = server_id) AND
                ($3 IS NULL OR sample_id >= $3) AND
                ($4 IS NULL OR sample_id <= $4))) dt$sql$,
            r_result.relname
          )
        USING
          section_counter,
          sserver_id,
          min_sample_id,
          max_sample_id,
          obfuscate_queries;
      ELSE
        RETURN QUERY EXECUTE format(
            $q$SELECT $1,row_to_json(dt) FROM (SELECT * FROM %I WHERE $2 IS NULL OR $2 = server_id) dt$q$,
            r_result.relname
          )
        USING section_counter, sserver_id;
    END CASE;
    section_counter := section_counter + 1;
  END LOOP;
  RETURN;
END;
$function$;

-- Function: func_top_calls_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.func_top_calls_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_fun_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(f1.dbname,f2.dbname) as dbname,
        COALESCE(f1.schemaname,f2.schemaname) as schemaname,
        COALESCE(f1.funcname,f2.funcname) as funcname,
        COALESCE(f1.funcargs,f2.funcargs) as funcargs,
        NULLIF(f1.calls, 0) as calls1,
        NULLIF(f1.total_time, 0.0) as total_time1,
        NULLIF(f1.self_time, 0.0) as self_time1,
        NULLIF(f1.m_time, 0.0) as m_time1,
        NULLIF(f1.m_stime, 0.0) as m_stime1,
        NULLIF(f2.calls, 0) as calls2,
        NULLIF(f2.total_time, 0.0) as total_time2,
        NULLIF(f2.self_time, 0.0) as self_time2,
        NULLIF(f2.m_time, 0.0) as m_time2,
        NULLIF(f2.m_stime, 0.0) as m_stime2,
        row_number() OVER (ORDER BY f1.calls DESC NULLS LAST) as rn_calls1,
        row_number() OVER (ORDER BY f2.calls DESC NULLS LAST) as rn_calls2
    FROM top_functions1 f1
        FULL OUTER JOIN top_functions2 f2 USING (server_id, datid, funcid)
    ORDER BY
      COALESCE(f1.calls, 0) + COALESCE(f2.calls, 0) DESC,
      COALESCE(f1.datid,f2.datid) ASC,
      COALESCE(f1.funcid,f2.funcid) ASC
    ) t1
    WHERE COALESCE(calls1, 0) + COALESCE(calls2, 0) > 0
      AND least(
        rn_calls1,
        rn_calls2
      ) <= topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Function</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Number of times this function has been called">Executions</th>'
            '<th colspan="4" title="Function execution timing statistics">Time (s)</th>'
          '</tr>'
          '<tr>'
            '<th title="Total time spent in this function and all other functions called by it">Total</th>'
            '<th title="Total time spent in this function itself, not including other functions called by it">Self</th>'
            '<th title="Mean total time per execution">Mean</th>'
            '<th title="Mean self time per execution">Mean self</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr} title="%s">%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    FOR r_result IN c_fun_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.schemaname,
            r_result.funcargs,
            r_result.funcname,
            r_result.calls1,
            round(CAST(r_result.total_time1 AS numeric),2),
            round(CAST(r_result.self_time1 AS numeric),2),
            round(CAST(r_result.m_time1 AS numeric),3),
            round(CAST(r_result.m_stime1 AS numeric),3),
            r_result.calls2,
            round(CAST(r_result.total_time2 AS numeric),2),
            round(CAST(r_result.self_time2 AS numeric),2),
            round(CAST(r_result.m_time2 AS numeric),3),
            round(CAST(r_result.m_stime2 AS numeric),3)
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: func_top_calls_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.func_top_calls_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_fun_stats CURSOR FOR
    SELECT
        dbname,
        schemaname,
        funcname,
        funcargs,
        NULLIF(calls, 0) as calls,
        NULLIF(total_time, 0.0) as total_time,
        NULLIF(self_time, 0.0) as self_time,
        NULLIF(m_time, 0.0) as m_time,
        NULLIF(m_stime, 0.0) as m_stime
    FROM top_functions
    WHERE calls > 0
    ORDER BY
      calls DESC,
      datid ASC,
      funcid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Function</th>'
            '<th rowspan="2" title="Number of times this function has been called">Executions</th>'
            '<th colspan="4" title="Function execution timing statistics">Time (s)</th>'
          '</tr>'
          '<tr>'
            '<th title="Total time spent in this function and all other functions called by it">Total</th>'
            '<th title="Total time spent in this function itself, not including other functions called by it">Self</th>'
            '<th title="Mean total time per execution">Mean</th>'
            '<th title="Mean self time per execution">Mean self</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td title="%s">%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    FOR r_result IN c_fun_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.schemaname,
            r_result.funcargs,
            r_result.funcname,
            r_result.calls,
            round(CAST(r_result.total_time AS numeric),2),
            round(CAST(r_result.self_time AS numeric),2),
            round(CAST(r_result.m_time AS numeric),3),
            round(CAST(r_result.m_stime AS numeric),3)
        );
    END LOOP;

   IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
   ELSE
        RETURN '';
   END IF;
END;
$function$;

-- Function: func_top_time_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.func_top_time_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_fun_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(f1.dbname,f2.dbname) as dbname,
        COALESCE(f1.schemaname,f2.schemaname) as schemaname,
        COALESCE(f1.funcname,f2.funcname) as funcname,
        COALESCE(f1.funcargs,f2.funcargs) as funcargs,
        NULLIF(f1.calls, 0) as calls1,
        NULLIF(f1.total_time, 0.0) as total_time1,
        NULLIF(f1.self_time, 0.0) as self_time1,
        NULLIF(f1.m_time, 0.0) as m_time1,
        NULLIF(f1.m_stime, 0.0) as m_stime1,
        NULLIF(f2.calls, 0) as calls2,
        NULLIF(f2.total_time, 0.0) as total_time2,
        NULLIF(f2.self_time, 0.0) as self_time2,
        NULLIF(f2.m_time, 0.0) as m_time2,
        NULLIF(f2.m_stime, 0.0) as m_stime2,
        row_number() OVER (ORDER BY f1.total_time DESC NULLS LAST) as rn_time1,
        row_number() OVER (ORDER BY f2.total_time DESC NULLS LAST) as rn_time2
    FROM top_functions1 f1
        FULL OUTER JOIN top_functions2 f2 USING (server_id, datid, funcid)
    ORDER BY
      COALESCE(f1.total_time, 0.0) + COALESCE(f2.total_time, 0.0) DESC,
      COALESCE(f1.datid,f2.datid) ASC,
      COALESCE(f1.funcid,f2.funcid) ASC
    ) t1
    WHERE COALESCE(total_time1, 0.0) + COALESCE(total_time2, 0.0) > 0.0
      AND least(
        rn_time1,
        rn_time2
      ) <= topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Function</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Number of times this function has been called">Executions</th>'
            '<th colspan="4" title="Function execution timing statistics">Time (s)</th>'
          '</tr>'
          '<tr>'
            '<th title="Total time spent in this function and all other functions called by it">Total</th>'
            '<th title="Total time spent in this function itself, not including other functions called by it">Self</th>'
            '<th title="Mean total time per execution">Mean</th>'
            '<th title="Mean self time per execution">Mean self</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr} title="%s">%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    FOR r_result IN c_fun_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.schemaname,
            r_result.funcargs,
            r_result.funcname,
            r_result.calls1,
            round(CAST(r_result.total_time1 AS numeric),2),
            round(CAST(r_result.self_time1 AS numeric),2),
            round(CAST(r_result.m_time1 AS numeric),3),
            round(CAST(r_result.m_stime1 AS numeric),3),
            r_result.calls2,
            round(CAST(r_result.total_time2 AS numeric),2),
            round(CAST(r_result.self_time2 AS numeric),2),
            round(CAST(r_result.m_time2 AS numeric),3),
            round(CAST(r_result.m_stime2 AS numeric),3)
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: func_top_time_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.func_top_time_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_fun_stats CURSOR FOR
    SELECT
        dbname,
        schemaname,
        funcname,
        funcargs,
        NULLIF(calls, 0) as calls,
        NULLIF(total_time, 0.0) as total_time,
        NULLIF(self_time, 0.0) as self_time,
        NULLIF(m_time, 0.0) as m_time,
        NULLIF(m_stime, 0.0) as m_stime
    FROM top_functions
    WHERE total_time > 0
    ORDER BY
      total_time DESC,
      datid ASC,
      funcid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Function</th>'
            '<th rowspan="2" title="Number of times this function has been called">Executions</th>'
            '<th colspan="4" title="Function execution timing statistics">Time (s)</th>'
          '</tr>'
          '<tr>'
            '<th title="Total time spent in this function and all other functions called by it">Total</th>'
            '<th title="Total time spent in this function itself, not including other functions called by it">Self</th>'
            '<th title="Mean total time per execution">Mean</th>'
            '<th title="Mean self time per execution">Mean self</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td title="%s">%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    FOR r_result IN c_fun_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.schemaname,
            r_result.funcargs,
            r_result.funcname,
            r_result.calls,
            round(CAST(r_result.total_time AS numeric),2),
            round(CAST(r_result.self_time AS numeric),2),
            round(CAST(r_result.m_time AS numeric),3),
            round(CAST(r_result.m_stime AS numeric),3)
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: func_top_trg_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.func_top_trg_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_fun_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(f1.dbname,f2.dbname) as dbname,
        COALESCE(f1.schemaname,f2.schemaname) as schemaname,
        COALESCE(f1.funcname,f2.funcname) as funcname,
        COALESCE(f1.funcargs,f2.funcargs) as funcargs,
        NULLIF(f1.calls, 0) as calls1,
        NULLIF(f1.total_time, 0.0) as total_time1,
        NULLIF(f1.self_time, 0.0) as self_time1,
        NULLIF(f1.m_time, 0.0) as m_time1,
        NULLIF(f1.m_stime, 0.0) as m_stime1,
        NULLIF(f2.calls, 0) as calls2,
        NULLIF(f2.total_time, 0.0) as total_time2,
        NULLIF(f2.self_time, 0.0) as self_time2,
        NULLIF(f2.m_time, 0.0) as m_time2,
        NULLIF(f2.m_stime, 0.0) as m_stime2,
        row_number() OVER (ORDER BY f1.total_time DESC NULLS LAST) as rn_time1,
        row_number() OVER (ORDER BY f2.total_time DESC NULLS LAST) as rn_time2
    FROM top_functions(sserver_id, start1_id, end1_id, true) f1
        FULL OUTER JOIN top_functions(sserver_id, start2_id, end2_id, true) f2 USING (server_id, datid, funcid)
    ORDER BY
      COALESCE(f1.total_time, 0.0) + COALESCE(f2.total_time, 0.0) DESC,
      COALESCE(f1.datid,f2.datid) ASC,
      COALESCE(f1.funcid,f2.funcid) ASC
    ) t1
    WHERE COALESCE(total_time1, 0.0) + COALESCE(total_time2, 0.0) > 0.0
      AND least(
        rn_time1,
        rn_time2
      ) <= topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Function</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Number of times this function has been called">Executions</th>'
            '<th colspan="4" title="Function execution timing statistics">Time (s)</th>'
          '</tr>'
          '<tr>'
            '<th title="Total time spent in this function and all other functions called by it">Total</th>'
            '<th title="Total time spent in this function itself, not including other functions called by it">Self</th>'
            '<th title="Mean total time per execution">Mean</th>'
            '<th title="Mean self time per execution">Mean self</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr} title="%s">%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    FOR r_result IN c_fun_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.schemaname,
            r_result.funcargs,
            r_result.funcname,
            r_result.calls1,
            round(CAST(r_result.total_time1 AS numeric),2),
            round(CAST(r_result.self_time1 AS numeric),2),
            round(CAST(r_result.m_time1 AS numeric),3),
            round(CAST(r_result.m_stime1 AS numeric),3),
            r_result.calls2,
            round(CAST(r_result.total_time2 AS numeric),2),
            round(CAST(r_result.self_time2 AS numeric),2),
            round(CAST(r_result.m_time2 AS numeric),3),
            round(CAST(r_result.m_stime2 AS numeric),3)
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: func_top_trg_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.func_top_trg_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_fun_stats CURSOR FOR
    SELECT
        dbname,
        schemaname,
        funcname,
        funcargs,
        NULLIF(calls, 0) as calls,
        NULLIF(total_time, 0.0) as total_time,
        NULLIF(self_time, 0.0) as self_time,
        NULLIF(m_time, 0.0) as m_time,
        NULLIF(m_stime, 0.0) as m_stime
    FROM top_functions(sserver_id, start_id, end_id, true)
    WHERE total_time > 0
    ORDER BY
      total_time DESC,
      datid ASC,
      funcid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Function</th>'
            '<th rowspan="2" title="Number of times this function has been called">Executions</th>'
            '<th colspan="4" title="Function execution timing statistics">Time (s)</th>'
          '</tr>'
          '<tr>'
            '<th title="Total time spent in this function and all other functions called by it">Total</th>'
            '<th title="Total time spent in this function itself, not including other functions called by it">Self</th>'
            '<th title="Mean total time per execution">Mean</th>'
            '<th title="Mean self time per execution">Mean self</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td title="%s">%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    FOR r_result IN c_fun_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.schemaname,
            r_result.funcargs,
            r_result.funcname,
            r_result.calls,
            round(CAST(r_result.total_time AS numeric),2),
            round(CAST(r_result.self_time AS numeric),2),
            round(CAST(r_result.m_time AS numeric),3),
            round(CAST(r_result.m_stime AS numeric),3)
        );
    END LOOP;

   IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
   ELSE
        RETURN '';
   END IF;
END;
$function$;

-- Function: get_baseline_samples
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_baseline_samples(sserver_id integer, baseline character varying)
 RETURNS TABLE(start_id integer, end_id integer)
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    SELECT min(sample_id), max(sample_id) INTO start_id,end_id
    FROM baselines JOIN bl_samples USING (bl_id,server_id)
    WHERE server_id = sserver_id AND bl_name = baseline;
    IF start_id IS NULL OR end_id IS NULL THEN
      RAISE 'Baseline not found';
    END IF;
    RETURN NEXT;
    RETURN;
END;
$function$;

-- Function: get_connstr
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_connstr(sserver_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
 SET lock_timeout TO '300000'
AS $function$
DECLARE
    server_connstr text = null;
BEGIN
    --Getting server_connstr
    SELECT connstr INTO server_connstr FROM servers n WHERE n.server_id = sserver_id;
    IF (server_connstr IS NULL) THEN
        RAISE 'server_id not found';
    ELSE
        RETURN server_connstr;
    END IF;
END;
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    tmp_text    text;
    tmp_report  text;
    report      text;
    i1_title    text;
    i2_title    text;
    topn        integer;
    stmt_all_cnt    integer;
    -- HTML elements templates
    report_tpl CONSTANT text := '<html><head><style>{css}</style><title>Postgres profile differential report {samples}</title></head><body><H1>Postgres profile differential report {samples}</H1>'
    '<p>pg_profile version {pgprofile_version}</p>'
    '<p>Server name: <strong>{server_name}</strong></p>'
    '{server_description}'
    '<p>First interval (1): <strong>{i1_title}</strong></p>'
    '<p>Second interval (2): <strong>{i2_title}</strong></p>'
    '{report_description}{report}</body></html>';
    report_css CONSTANT text := 'table, th, td {border: 1px solid black; border-collapse: collapse; padding: 4px;} '
    'table .value, table .mono {font-family: Monospace;} '
    'table .value {text-align: right;} '
    'table p {margin: 0.2em;}'
    '.int1 td:not(.hdr), td.int1 {background-color: #FFEEEE;} '
    '.int2 td:not(.hdr), td.int2 {background-color: #EEEEFF;} '
    'table.diff tr.int2 td {border-top: hidden;} '
    'table.stat tr:nth-child(even), table.setlist tr:nth-child(even) {background-color: #eee;} '
    'table.stat tr:nth-child(odd), table.setlist tr:nth-child(odd) {background-color: #fff;} '
    'table tr:hover td:not(.hdr) {background-color:#d9ffcc} '
    'table th {color: black; background-color: #ffcc99;}'
    '.label {color: grey;}'
    'table tr:target,td:target {border: solid; border-width: medium; border-color: limegreen;}'
    'table tr:target td:first-of-type, table td:target {font-weight: bold;}'
    'table tr.parent td {background-color: #D8E8C2;} '
    'table tr.child td {background-color: #BBDD97; border-top-style: hidden;} ';
    description_tpl CONSTANT text := '<h2>Report description</h2><p>{description_text}</p>';
    --Cursor and variable for checking existance of samples
    c_sample CURSOR (csample_id integer) FOR SELECT * FROM samples WHERE server_id = sserver_id AND sample_id = csample_id;
    sample_rec samples%rowtype;
    jreportset  jsonb;

    r_result RECORD;
BEGIN
    -- Interval expanding in case of growth stats requested
    IF with_growth THEN
      BEGIN
        SELECT left_bound, right_bound INTO STRICT start1_id, end1_id
        FROM get_sized_bounds(sserver_id, start1_id, end1_id);
      EXCEPTION
        WHEN OTHERS THEN
          RAISE 'Samples with sizes collected for requested interval (%) not found',
            format('%s - %s',start1_id, end1_id);
      END;
      BEGIN
        SELECT left_bound, right_bound INTO STRICT start2_id, end2_id
        FROM get_sized_bounds(sserver_id, start2_id, end2_id);
      EXCEPTION
        WHEN OTHERS THEN
          RAISE 'Samples with sizes collected for requested interval (%) not found',
            format('%s - %s',start2_id, end2_id);
      END;
    END IF;

    -- CSS
    report := replace(report_tpl,'{css}',report_css);

    -- Add provided description
    IF description IS NOT NULL THEN
      report := replace(report,'{report_description}',replace(description_tpl,'{description_text}',description));
    ELSE
      report := replace(report,'{report_description}','');
    END IF;

    -- pg_profile version
    IF (SELECT count(*) = 1 FROM pg_catalog.pg_extension WHERE extname = 'pg_profile') THEN
      SELECT extversion INTO STRICT r_result FROM pg_catalog.pg_extension WHERE extname = 'pg_profile';
      report := replace(report,'{pgprofile_version}',r_result.extversion);
    ELSE
      report := replace(report,'{pgprofile_version}','0.3.4');
    END IF;

    -- Server name and description substitution
    SELECT server_name,server_description INTO STRICT r_result
    FROM servers WHERE server_id = sserver_id;
    report := replace(report,'{server_name}',r_result.server_name);
    IF r_result.server_description IS NOT NULL AND r_result.server_description != ''
    THEN
      report := replace(report,'{server_description}','<p>'||r_result.server_description||'</p>');
    ELSE
      report := replace(report,'{server_description}','');
    END IF;

    -- Getting TopN setting
    BEGIN
        topn := current_setting('pg_profile.topn')::integer;
    EXCEPTION
        WHEN OTHERS THEN topn := 20;
    END;

    -- Check if all samples of requested intervals are available
    IF (
      SELECT count(*) != end1_id - start1_id + 1 FROM samples
      WHERE server_id = sserver_id AND sample_id BETWEEN start1_id AND end1_id
    ) THEN
      RAISE 'Not enough samples between %',
        format('%s AND %s', start1_id, end1_id);
    END IF;
    IF (
      SELECT count(*) != end2_id - start2_id + 1 FROM samples
      WHERE server_id = sserver_id AND sample_id BETWEEN start2_id AND end2_id
    ) THEN
      RAISE 'Not enough samples between %',
        format('%s AND %s', start2_id, end2_id);
    END IF;
    -- Checking sample existance, header generation
    OPEN c_sample(start1_id);
        FETCH c_sample INTO sample_rec;
        IF sample_rec IS NULL THEN
            RAISE 'Start sample % does not exists', start_id;
        END IF;
        i1_title := sample_rec.sample_time::text|| ' - ';
        tmp_text := '(1): [' || sample_rec.sample_id ||' - ';
    CLOSE c_sample;

    OPEN c_sample(end1_id);
        FETCH c_sample INTO sample_rec;
        IF sample_rec IS NULL THEN
            RAISE 'End sample % does not exists', end_id;
        END IF;
        i1_title := i1_title||sample_rec.sample_time::text;
        tmp_text := tmp_text || sample_rec.sample_id ||'] with ';
    CLOSE c_sample;

    OPEN c_sample(start2_id);
        FETCH c_sample INTO sample_rec;
        IF sample_rec IS NULL THEN
            RAISE 'Start sample % does not exists', start_id;
        END IF;
        i2_title := sample_rec.sample_time::text|| ' - ';
        tmp_text := tmp_text|| '(2): [' || sample_rec.sample_id ||' - ';
    CLOSE c_sample;

    OPEN c_sample(end2_id);
        FETCH c_sample INTO sample_rec;
        IF sample_rec IS NULL THEN
            RAISE 'End sample % does not exists', end_id;
        END IF;
        i2_title := i2_title||sample_rec.sample_time::text;
        tmp_text := tmp_text || sample_rec.sample_id ||']';
    CLOSE c_sample;
    report := replace(report,'{samples}',tmp_text);
    tmp_text := '';

    -- Insert report intervals
    report := replace(report,'{i1_title}',i1_title);
    report := replace(report,'{i2_title}',i2_title);

    -- Report internal temporary tables
    -- Creating temporary table for reported queries
    CREATE TEMPORARY TABLE IF NOT EXISTS queries_list (
      userid              oid,
      datid               oid,
      queryid             bigint,
      CONSTRAINT pk_queries_list PRIMARY KEY (userid, datid, queryid))
    ON COMMIT DELETE ROWS;
    /*
    * Caching temporary tables, containing object stats cache
    * used several times in a report functions
    */
    CREATE TEMPORARY TABLE top_statements1 AS
    SELECT * FROM top_statements(sserver_id, start1_id, end1_id);
    CREATE TEMPORARY TABLE top_tables1 AS
    SELECT * FROM top_tables(sserver_id, start1_id, end1_id);
    CREATE TEMPORARY TABLE top_indexes1 AS
    SELECT * FROM top_indexes(sserver_id, start1_id, end1_id);
    CREATE TEMPORARY TABLE top_io_tables1 AS
    SELECT * FROM top_io_tables(sserver_id, start1_id, end1_id);
    CREATE TEMPORARY TABLE top_io_indexes1 AS
    SELECT * FROM top_io_indexes(sserver_id, start1_id, end1_id);
    CREATE TEMPORARY TABLE top_functions1 AS
    SELECT * FROM top_functions(sserver_id, start1_id, end1_id, false);
    CREATE TEMPORARY TABLE top_kcache_statements1 AS
    SELECT * FROM top_kcache_statements(sserver_id, start1_id, end1_id);
    CREATE TEMPORARY TABLE top_statements2 AS
    SELECT * FROM top_statements(sserver_id, start2_id, end2_id);
    CREATE TEMPORARY TABLE top_tables2 AS
    SELECT * FROM top_tables(sserver_id, start2_id, end2_id);
    CREATE TEMPORARY TABLE top_indexes2 AS
    SELECT * FROM top_indexes(sserver_id, start2_id, end2_id);
    CREATE TEMPORARY TABLE top_io_tables2 AS
    SELECT * FROM top_io_tables(sserver_id, start2_id, end2_id);
    CREATE TEMPORARY TABLE top_io_indexes2 AS
    SELECT * FROM top_io_indexes(sserver_id, start2_id, end2_id);
    CREATE TEMPORARY TABLE top_functions2 AS
    SELECT * FROM top_functions(sserver_id, start2_id, end2_id, false);
    CREATE TEMPORARY TABLE top_kcache_statements2 AS
    SELECT * FROM top_kcache_statements(sserver_id, start2_id, end2_id);
    ANALYZE top_statements1;
    ANALYZE top_tables1;
    ANALYZE top_indexes1;
    ANALYZE top_io_tables1;
    ANALYZE top_io_indexes1;
    ANALYZE top_functions1;
    ANALYZE top_kcache_statements1;
    ANALYZE top_statements2;
    ANALYZE top_tables2;
    ANALYZE top_indexes2;
    ANALYZE top_io_tables2;
    ANALYZE top_io_indexes2;
    ANALYZE top_functions2;
    ANALYZE top_kcache_statements2;

    -- Populate report settings
    jreportset := jsonb_build_object(
    'htbl',jsonb_build_object(
      'value','class="value"',
      'interval1','class="int1"',
      'interval2','class="int2"',
      'label','class="label"',
      'stattbl','class="stat"',
      'difftbl','class="stat diff"',
      'rowtdspanhdr','rowspan="2" class="hdr"',
      'rowtdspanhdr_mono','rowspan="2" class="hdr mono"',
      'mono','class="mono"',
      'title1',format('title="%s"',i1_title),
      'title2',format('title="%s"',i2_title)
      ),
    'report_features',jsonb_build_object(
      'statstatements',profile_checkavail_statstatements(sserver_id, start1_id, end1_id) OR
        profile_checkavail_statstatements(sserver_id, start2_id, end2_id),
      'planning_times',profile_checkavail_planning_times(sserver_id, start1_id, end1_id) OR
        profile_checkavail_planning_times(sserver_id, start2_id, end2_id),
      'statement_wal_bytes',profile_checkavail_stmt_wal_bytes(sserver_id, start1_id, end1_id) OR
        profile_checkavail_stmt_wal_bytes(sserver_id, start2_id, end2_id),
      'wal_stats',profile_checkavail_walstats(sserver_id, start1_id, end1_id) OR
        profile_checkavail_walstats(sserver_id, start2_id, end2_id),
      'sess_stats',profile_checkavail_sessionstats(sserver_id, start1_id, end1_id) OR
        profile_checkavail_sessionstats(sserver_id, start2_id, end2_id),
      'function_stats',profile_checkavail_functions(sserver_id, start1_id, end1_id) OR
        profile_checkavail_functions(sserver_id, start2_id, end2_id),
      'trigger_function_stats',profile_checkavail_trg_functions(sserver_id, start1_id, end1_id) OR
        profile_checkavail_trg_functions(sserver_id, start2_id, end2_id),
      'table_sizes',profile_checkavail_tablesizes(sserver_id, start1_id, end1_id) OR
        profile_checkavail_tablesizes(sserver_id, start2_id, end2_id),
      'table_growth',profile_checkavail_tablegrowth(sserver_id, start1_id, end1_id) OR
        profile_checkavail_tablegrowth(sserver_id, start2_id, end2_id),
      'kcachestatements',profile_checkavail_rusage(sserver_id, start1_id, end1_id) OR
        profile_checkavail_rusage(sserver_id, start2_id, end2_id),
      'rusage.planstats',profile_checkavail_rusage_planstats(sserver_id, start1_id, end1_id) OR
        profile_checkavail_rusage_planstats(sserver_id, start2_id, end2_id)
      ),
    'report_properties',jsonb_build_object(
      'interval1_duration_sec',
        (SELECT extract(epoch FROM e.sample_time - s.sample_time)
        FROM samples s JOIN samples e USING (server_id)
        WHERE e.sample_id=end1_id and s.sample_id=start1_id
          AND server_id = sserver_id),
      'interval2_duration_sec',
        (SELECT extract(epoch FROM e.sample_time - s.sample_time)
        FROM samples s JOIN samples e USING (server_id)
        WHERE e.sample_id=end2_id and s.sample_id=start2_id
          AND server_id = sserver_id)
      )
    );

    -- Reporting possible statements overflow
    tmp_report := check_stmt_cnt(sserver_id, start1_id, end1_id);
    IF tmp_report != '' THEN
        tmp_text := tmp_text || '<H2>Warning!</H2>';
        tmp_text := tmp_text || '<p>Interval (1) contains sample(s) with captured statements count more than 90% of pg_stat_statements.max setting. Consider increasing this parameter.</p>';
        tmp_text := tmp_text || tmp_report;
    END IF;
    tmp_report := check_stmt_cnt(sserver_id, start2_id, end2_id);
    IF tmp_report != '' THEN
        tmp_text := tmp_text || '<p>Interval (2) contains sample(s) with captured statements count more than 90% of pg_stat_statements.max setting. Consider increasing this parameter.</p>';
        tmp_text := tmp_text || tmp_report;
    END IF;

    -- pg_stat_statements.track warning
    tmp_report := '';
    stmt_all_cnt := check_stmt_all_setting(sserver_id, start1_id, end1_id);
    IF stmt_all_cnt > 0 THEN
        tmp_report := tmp_report||'<p>Interval (1) includes '||stmt_all_cnt||' sample(s) with setting <i>pg_stat_statements.track = all</i>. '||
        'Value of %Total columns may be incorrect.</p>';
    END IF;
    stmt_all_cnt := check_stmt_all_setting(sserver_id, start2_id, end2_id);
    IF stmt_all_cnt > 0 THEN
        tmp_report := tmp_report||'Interval (2) includes '||stmt_all_cnt||' sample(s) with setting <i>pg_stat_statements.track = all</i>. '||
        'Value of %Total columns may be incorrect.';
    END IF;
    IF tmp_report != '' THEN
        tmp_text := tmp_text || '<p><b>Warning!</b></p>'||tmp_report;
    END IF;

    -- Table of Contents
    tmp_text := tmp_text ||'<H2>Report sections</H2><ul>';
    tmp_text := tmp_text || '<li><a HREF=#cl_stat>Server statistics</a></li>';
    tmp_text := tmp_text || '<ul>';
    tmp_text := tmp_text || '<li><a HREF=#db_stat>Database statistics</a></li>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'sess_stats')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#db_stat_sessions>Session statistics by database</a></li>';
    END IF;
    IF jsonb_extract_path_text(jreportset, 'report_features', 'statstatements')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#st_stat>Statement statistics by database</a></li>';
    END IF;
    tmp_text := tmp_text || '<li><a HREF=#clu_stat>Cluster statistics</a></li>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'wal_stats')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#wal_stat>WAL statistics</a></li>';
    END IF;
    tmp_text := tmp_text || '<li><a HREF=#tablespace_stat>Tablespace statistics</a></li>';
    tmp_text := tmp_text || '</ul>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'statstatements')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#sql_stat>SQL Query statistics</a></li>';
      tmp_text := tmp_text || '<ul>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
        tmp_text := tmp_text || '<li><a HREF=#top_ela>Top SQL by elapsed time</a></li>';
        tmp_text := tmp_text || '<li><a HREF=#top_plan>Top SQL by planning time</a></li>';
      END IF;
      tmp_text := tmp_text || '<li><a HREF=#top_exec>Top SQL by execution time</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_calls>Top SQL by executions</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_iowait>Top SQL by I/O wait time</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_pgs_fetched>Top SQL by shared blocks fetched</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_shared_reads>Top SQL by shared blocks read</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_shared_dirtied>Top SQL by shared blocks dirtied</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_shared_written>Top SQL by shared blocks written</a></li>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'statement_wal_bytes')::boolean THEN
        tmp_text := tmp_text || '<li><a HREF=#top_wal_bytes>Top SQL by WAL size</a></li>';
      END IF;
      tmp_text := tmp_text || '<li><a HREF=#top_temp>Top SQL by temp usage</a></li>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'kcachestatements')::boolean THEN
        tmp_text := tmp_text || '<li><a HREF=#kcache_stat>rusage statistics</a></li>';
        tmp_text := tmp_text || '<ul>';
        tmp_text := tmp_text || '<li><a HREF=#kcache_time>Top SQL by system and user time </a></li>';
        tmp_text := tmp_text || '<li><a HREF=#kcache_reads_writes>Top SQL by reads/writes done by filesystem layer </a></li>';
        tmp_text := tmp_text || '</ul>';
      END IF;
      tmp_text := tmp_text || '<li><a HREF=#sql_list>Complete list of SQL texts</a></li>';
      tmp_text := tmp_text || '</ul>';
    END IF;
    tmp_text := tmp_text || '<li><a HREF=#schema_stat>Schema object statistics</a></li>';
    tmp_text := tmp_text || '<ul>';
    tmp_text := tmp_text || '<li><a HREF=#scanned_tbl>Top tables by estimated sequentially scanned volume</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#fetch_tbl>Top tables by blocks fetched</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#read_tbl>Top tables by blocks read</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#dml_tbl>Top DML tables</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#vac_tbl>Top tables by updated/deleted tuples</a></li>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'table_growth')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#growth_tbl>Top growing tables</a></li>';
    END IF;
    tmp_text := tmp_text || '<li><a HREF=#fetch_idx>Top indexes by blocks fetched</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#read_idx>Top indexes by blocks read</a></li>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'table_growth')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#growth_idx>Top growing indexes</a></li>';
    END IF;
    tmp_text := tmp_text || '</ul>';

    IF jsonb_extract_path_text(jreportset, 'report_features', 'function_stats')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#func_stat>User function statistics</a></li>';
      tmp_text := tmp_text || '<ul>';
      tmp_text := tmp_text || '<li><a HREF=#funcs_time_stat>Top functions by total time</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#funcs_calls_stat>Top functions by executions</a></li>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'trigger_function_stats')::boolean THEN
        tmp_text := tmp_text || '<li><a HREF=#trg_funcs_time_stat>Top trigger functions by total time</a></li>';
      END IF;
      tmp_text := tmp_text || '</ul>';
    END IF;

    tmp_text := tmp_text || '<li><a HREF=#vacuum_stats>Vacuum-related statistics</a></li>';
    tmp_text := tmp_text || '<ul>';
    tmp_text := tmp_text || '<li><a HREF=#top_vacuum_cnt_tbl>Top tables by vacuum operations</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#top_analyze_cnt_tbl>Top tables by analyze operations</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#top_ix_vacuum_bytes_cnt_tbl>Top indexes by estimated vacuum I/O load</a></li>';
    tmp_text := tmp_text || '</ul>';

    tmp_text := tmp_text || '<li><a HREF=#pg_settings>Cluster settings during the report interval</a></li>';

    tmp_text := tmp_text || '</ul>';


    --Reporting cluster stats
    tmp_text := tmp_text || '<H2><a NAME=cl_stat>Server statistics</a></H2>';
    tmp_text := tmp_text || '<H3><a NAME=db_stat>Database statistics</a></H3>';
    tmp_report := dbstats_reset_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id);
    IF tmp_report != '' THEN
      tmp_text := tmp_text || '<p><b>Warning!</b> Database statistics reset detected during report period!</p>'||tmp_report||
        '<p>Statistics for listed databases and contained objects might be affected</p>';
    END IF;
    tmp_text := tmp_text || nodata_wrapper(dbstats_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

    IF jsonb_extract_path_text(jreportset, 'report_features', 'sess_stats')::boolean THEN
      tmp_text := tmp_text || '<H3><a NAME=db_stat_sessions>Session statistics by database</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(dbstats_sessions_diff_htbl(jreportset, sserver_id,
        start1_id, end1_id, start2_id, end2_id, topn));
    END IF;

    IF jsonb_extract_path_text(jreportset, 'report_features', 'statstatements')::boolean THEN
      tmp_text := tmp_text || '<H3><a NAME=st_stat>Statement statistics by database</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(statements_stats_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
    END IF;

    tmp_text := tmp_text || '<div>';
    tmp_text := tmp_text || '<div style="display:inline-block; margin-right:2em;">'
      '<H3><a NAME=clu_stat>Cluster statistics</a></H3>';
    tmp_report := cluster_stats_reset_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id);
    IF tmp_report != '' THEN
      tmp_text := tmp_text || '<p><b>Warning!</b> Cluster statistics reset detected during report period!</p>'||tmp_report||
        '<p>Cluster statistics might be affected</p>';
    END IF;
    tmp_text := tmp_text || nodata_wrapper(cluster_stats_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id)) ||
      '</div>';

    IF jsonb_extract_path_text(jreportset, 'report_features', 'wal_stats')::boolean THEN
      tmp_text := tmp_text || '<div style="display:inline-block"><H3><a NAME=wal_stat>WAL statistics</a></H3>';
      tmp_report := wal_stats_reset_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id);
      IF tmp_report != '' THEN
        tmp_text := tmp_text || '<p><b>Warning!</b> WAL statistics reset detected during report period!</p>'||tmp_report||
          '<p>WAL statistics might be affected</p>';
      END IF;
      tmp_text := tmp_text || nodata_wrapper(wal_stats_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id)) ||
        '</div>';
    END IF;
    tmp_text := tmp_text || '</div>';

    tmp_text := tmp_text || '<H3><a NAME=tablespace_stat>Tablespace statistics</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(tablespaces_stats_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id));

    IF jsonb_extract_path_text(jreportset, 'report_features', 'statstatements')::boolean THEN
      --Reporting on top queries by elapsed time
      tmp_text := tmp_text || '<H2><a NAME=sql_stat>SQL Query statistics</a></H2>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
        tmp_text := tmp_text || '<H3><a NAME=top_ela>Top SQL by elapsed time</a></H3>';
        tmp_text := tmp_text || nodata_wrapper(top_elapsed_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
        tmp_text := tmp_text || '<H3><a NAME=top_plan>Top SQL by planning time</a></H3>';
        tmp_text := tmp_text || nodata_wrapper(top_plan_time_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
      END IF;
      tmp_text := tmp_text || '<H3><a NAME=top_exec>Top SQL by execution time</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_exec_time_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
      -- Reporting on top queries by executions
      tmp_text := tmp_text || '<H3><a NAME=top_calls>Top SQL by executions</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_exec_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

      -- Reporting on top queries by I/O wait time
      tmp_text := tmp_text || '<H3><a NAME=top_iowait>Top SQL by I/O wait time</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_iowait_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

      -- Reporting on top queries by gets
      tmp_text := tmp_text || '<H3><a NAME=top_pgs_fetched>Top SQL by shared blocks fetched</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_shared_blks_fetched_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

      -- Reporting on top queries by shared reads
      tmp_text := tmp_text || '<H3><a NAME=top_shared_reads>Top SQL by shared blocks read</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_shared_reads_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

      -- Reporting on top queries by shared dirtied
      tmp_text := tmp_text || '<H3><a NAME=top_shared_dirtied>Top SQL by shared blocks dirtied</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_shared_dirtied_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

      -- Reporting on top queries by shared written
      tmp_text := tmp_text || '<H3><a NAME=top_shared_written>Top SQL by shared blocks written</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_shared_written_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

      -- Reporting on top queries by WAL bytes
      IF jsonb_extract_path_text(jreportset, 'report_features', 'statement_wal_bytes')::boolean THEN
        tmp_text := tmp_text || '<H3><a NAME=top_wal_bytes>Top SQL by WAL size</a></H3>';
        tmp_text := tmp_text || nodata_wrapper(top_wal_size_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
      END IF;

      -- Reporting on top queries by temp usage
      tmp_text := tmp_text || '<H3><a NAME=top_temp>Top SQL by temp usage</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_temp_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

      IF jsonb_extract_path_text(jreportset, 'report_features', 'kcachestatements')::boolean THEN
        --Reporting kcache queries
        tmp_text := tmp_text || '<H3><a NAME=kcache_stat>rusage statistics</a></H3>';
        tmp_text := tmp_text||'<H4><a NAME=kcache_time>Top SQL by system and user time </a></H4>';
        tmp_text := tmp_text || nodata_wrapper(top_cpu_time_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
        tmp_text := tmp_text||'<H4><a NAME=kcache_reads_writes>Top SQL by reads/writes done by filesystem layer </a></H4>';
        tmp_text := tmp_text || nodata_wrapper(top_io_filesystem_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
      END IF;
      -- Listing queries
      tmp_text := tmp_text || '<H3><a NAME=sql_list>Complete list of SQL texts</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(report_queries(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id));
    END IF;

    -- Reporting Object stats
    -- Reporting scanned table
    tmp_text := tmp_text || '<H2><a NAME=schema_stat>Schema object statistics</a></H2>';
    tmp_text := tmp_text || '<H3><a NAME=scanned_tbl>Top tables by estimated sequentially scanned volume</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_scan_tables_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=fetch_tbl>Top tables by blocks fetched</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(tbl_top_fetch_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=read_tbl>Top tables by blocks read</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(tbl_top_io_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=dml_tbl>Top DML tables</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_dml_tables_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=vac_tbl>Top tables by updated/deleted tuples</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_upd_vac_tables_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

    IF jsonb_extract_path_text(jreportset, 'report_features', 'table_growth')::boolean THEN
      tmp_text := tmp_text || '<H3><a NAME=growth_tbl>Top growing tables</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_growth_tables_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
    END IF;

    tmp_text := tmp_text || '<H3><a NAME=fetch_idx>Top indexes by blocks fetched</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(ix_top_fetch_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=read_idx>Top indexes by blocks read</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(ix_top_io_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

    IF jsonb_extract_path_text(jreportset, 'report_features', 'table_growth')::boolean THEN
      tmp_text := tmp_text || '<H3><a NAME=growth_idx>Top growing indexes</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_growth_indexes_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
    END IF;

    IF jsonb_extract_path_text(jreportset, 'report_features', 'function_stats')::boolean THEN
      tmp_text := tmp_text || '<H2><a NAME=func_stat>User function statistics</a></H2>';
      tmp_text := tmp_text || '<H3><a NAME=funcs_time_stat>Top functions by total time</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(func_top_time_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

      tmp_text := tmp_text || '<H3><a NAME=funcs_calls_stat>Top functions by executions</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(func_top_calls_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

      IF jsonb_extract_path_text(jreportset, 'report_features', 'trigger_function_stats')::boolean THEN
        tmp_text := tmp_text || '<H3><a NAME=trg_funcs_time_stat>Top trigger functions by total time</a></H3>';
        tmp_text := tmp_text || nodata_wrapper(func_top_trg_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
      END IF;
    END IF;

    -- Reporting vacuum related stats
    tmp_text := tmp_text || '<H2><a NAME=vacuum_stats>Vacuum-related statistics</a></H2>';
    tmp_text := tmp_text || '<H3><a NAME=top_vacuum_cnt_tbl>Top tables by vacuum operations</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_vacuumed_tables_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
    tmp_text := tmp_text || '<H3><a NAME=top_analyze_cnt_tbl>Top tables by analyze operations</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_analyzed_tables_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));
    tmp_text := tmp_text || '<H3><a NAME=top_ix_vacuum_bytes_cnt_tbl>Top indexes by estimated vacuum I/O load</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_vacuumed_indexes_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id, topn));

    -- Database settings report
    tmp_text := tmp_text || '<H2><a NAME=pg_settings>Cluster settings during the report intervals</a></H2>';
    tmp_text := tmp_text || nodata_wrapper(settings_and_changes_diff_htbl(jreportset, sserver_id, start1_id, end1_id, start2_id, end2_id));

    /*
    * Dropping cache temporary tables
    * This is needed to avoid conflict with existing table if several
    * reports are collected in one session
    */
    DROP TABLE top_statements1;
    DROP TABLE top_tables1;
    DROP TABLE top_indexes1;
    DROP TABLE top_io_tables1;
    DROP TABLE top_io_indexes1;
    DROP TABLE top_functions1;
    DROP TABLE top_kcache_statements1;
    DROP TABLE top_statements2;
    DROP TABLE top_tables2;
    DROP TABLE top_indexes2;
    DROP TABLE top_io_tables2;
    DROP TABLE top_io_indexes2;
    DROP TABLE top_functions2;
    DROP TABLE top_kcache_statements2;

    report := replace(report,'{report}',tmp_text);
    RETURN report;
END;
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(server name, baseline1 character varying, baseline2 character varying, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport(get_server_by_name(server),bl1.start_id,bl1.end_id,
    bl2.start_id,bl2.end_id,description,with_growth)
  FROM get_baseline_samples(get_server_by_name(server), baseline1) bl1
    CROSS JOIN get_baseline_samples(get_server_by_name(server), baseline2) bl2
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(baseline1 character varying, baseline2 character varying, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport('local',baseline1,baseline2,description,with_growth);
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(server name, baseline character varying, start2_id integer, end2_id integer, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport(get_server_by_name(server),bl1.start_id,bl1.end_id,
    start2_id,end2_id,description,with_growth)
  FROM get_baseline_samples(get_server_by_name(server), baseline) bl1
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(baseline character varying, start2_id integer, end2_id integer, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport('local',baseline,
    start2_id,end2_id,description,with_growth);
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(start1_id integer, end1_id integer, start2_id integer, end2_id integer, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport('local',start1_id,end1_id,start2_id,end2_id,description,with_growth);
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(server name, start1_id integer, end1_id integer, baseline character varying, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport(get_server_by_name(server),start1_id,end1_id,
    bl2.start_id,bl2.end_id,description,with_growth)
  FROM get_baseline_samples(get_server_by_name(server), baseline) bl2
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(start1_id integer, end1_id integer, baseline character varying, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport('local',start1_id,end1_id,
    baseline,description,with_growth);
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(server name, time_range1 tstzrange, time_range2 tstzrange, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport(get_server_by_name(server),tm1.start_id,tm1.end_id,
    tm2.start_id,tm2.end_id,description,with_growth)
  FROM get_sampleids_by_timerange(get_server_by_name(server), time_range1) tm1
    CROSS JOIN get_sampleids_by_timerange(get_server_by_name(server), time_range2) tm2
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(server name, baseline character varying, time_range tstzrange, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport(get_server_by_name(server),bl1.start_id,bl1.end_id,
    tm2.start_id,tm2.end_id,description,with_growth)
  FROM get_baseline_samples(get_server_by_name(server), baseline) bl1
    CROSS JOIN get_sampleids_by_timerange(get_server_by_name(server), time_range) tm2
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(server name, time_range tstzrange, baseline character varying, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport(get_server_by_name(server),tm1.start_id,tm1.end_id,
    bl2.start_id,bl2.end_id,description,with_growth)
  FROM get_baseline_samples(get_server_by_name(server), baseline) bl2
    CROSS JOIN get_sampleids_by_timerange(get_server_by_name(server), time_range) tm1
$function$;

-- Function: get_diffreport
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_diffreport(server name, start1_id integer, end1_id integer, start2_id integer, end2_id integer, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_diffreport(get_server_by_name(server),start1_id,end1_id,
    start2_id,end2_id,description,with_growth);
$function$;

-- Function: get_report
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_report(sserver_id integer, time_range tstzrange, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_report(sserver_id, start_id, end_id, description, with_growth)
  FROM get_sampleids_by_timerange(sserver_id, time_range)
$function$;

-- Function: get_report
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_report(baseline character varying, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN get_report('local',baseline,description,with_growth);
END;
$function$;

-- Function: get_report
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_report(server name, baseline character varying, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_report(get_server_by_name(server), start_id, end_id, description, with_growth)
  FROM get_baseline_samples(get_server_by_name(server), baseline)
$function$;

-- Function: get_report
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_report(sserver_id integer, start_id integer, end_id integer, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    tmp_text    text;
    tmp_report  text;
    report      text;
    topn        integer;
    stmt_all_cnt    integer;
    -- HTML elements templates
    report_tpl CONSTANT text := '<html><head><style>{css}</style><title>Postgres profile report {samples}</title></head><body><H1>Postgres profile report {samples}</H1>'
    '<p>pg_profile version {pgprofile_version}</p>'
    '<p>Server name: <strong>{server_name}</strong></p>'
    '{server_description}'
    '<p>Report interval: <strong>{report_start} - {report_end}</strong></p>'
    '{report_description}{report}</body></html>';
    report_css CONSTANT text := 'table, th, td {border: 1px solid black; border-collapse: collapse; padding: 4px;} '
    'table tr td.value, table tr td.mono {font-family: Monospace;} '
    'table tr td.value {text-align: right;} '
    'table p {margin: 0.2em;}'
    'table tr.parent td:not(.hdr) {background-color: #D8E8C2;} '
    'table tr.child td {background-color: #BBDD97; border-top-style: hidden;} '
    'table.stat tr:nth-child(even), table.setlist tr:nth-child(even) {background-color: #eee;} '
    'table.stat tr:nth-child(odd), table.setlist tr:nth-child(odd) {background-color: #fff;} '
    'table tr:hover td:not(.hdr) {background-color:#d9ffcc} '
    'table th {color: black; background-color: #ffcc99;}'
    'table tr:target,td:target {border: solid; border-width: medium; border-color: limegreen;}'
    'table tr:target td:first-of-type, table td:target {font-weight: bold;}';
    description_tpl CONSTANT text := '<h2>Report description</h2><p>{description_text}</p>';
    --Cursor and variable for checking existance of samples
    c_sample CURSOR (csample_id integer) FOR SELECT * FROM samples WHERE server_id = sserver_id AND sample_id = csample_id;
    sample_rec samples%rowtype;
    jreportset  jsonb;

    r_result RECORD;
BEGIN
    -- Interval expanding in case of growth stats requested
    IF with_growth THEN
      BEGIN
        SELECT left_bound, right_bound INTO STRICT start_id, end_id
        FROM get_sized_bounds(sserver_id, start_id, end_id);
      EXCEPTION
        WHEN OTHERS THEN
          RAISE 'Samples with sizes collected for requested interval (%) not found',
            format('%s - %s',start_id, end_id);
      END;
    END IF;

    -- CSS
    report := replace(report_tpl,'{css}',report_css);

    -- Add provided description
    IF description IS NOT NULL THEN
      report := replace(report,'{report_description}',replace(description_tpl,'{description_text}',description));
    ELSE
      report := replace(report,'{report_description}','');
    END IF;

    -- pg_profile version
    IF (SELECT count(*) = 1 FROM pg_catalog.pg_extension WHERE extname = 'pg_profile') THEN
      SELECT extversion INTO STRICT r_result FROM pg_catalog.pg_extension WHERE extname = 'pg_profile';
      report := replace(report,'{pgprofile_version}',r_result.extversion);
    ELSE
      report := replace(report,'{pgprofile_version}','0.3.4');
    END IF;

    -- Server name and description substitution
    SELECT server_name,server_description INTO STRICT r_result
    FROM servers WHERE server_id = sserver_id;
    report := replace(report,'{server_name}',r_result.server_name);
    IF r_result.server_description IS NOT NULL AND r_result.server_description != ''
    THEN
      report := replace(report,'{server_description}','<p>'||r_result.server_description||'</p>');
    ELSE
      report := replace(report,'{server_description}','');
    END IF;

    -- Getting TopN setting
    BEGIN
        topn := current_setting('pg_profile.topn')::integer;
    EXCEPTION
        WHEN OTHERS THEN topn := 20;
    END;

    -- Check if all samples of requested interval are available
    IF (
      SELECT count(*) != end_id - start_id + 1 FROM samples
      WHERE server_id = sserver_id AND sample_id BETWEEN start_id AND end_id
    ) THEN
      RAISE 'Not enough samples between %',
        format('%s AND %s', start_id, end_id);
    END IF;
    -- Checking sample existance, header generation
    OPEN c_sample(start_id);
        FETCH c_sample INTO sample_rec;
        IF sample_rec IS NULL THEN
            RAISE 'Start sample % does not exists', start_id;
        END IF;
        report := replace(report,'{report_start}',sample_rec.sample_time::text);
        tmp_text := '(StartID: ' || sample_rec.sample_id ||', ';
    CLOSE c_sample;

    OPEN c_sample(end_id);
        FETCH c_sample INTO sample_rec;
        IF sample_rec IS NULL THEN
            RAISE 'End sample % does not exists', end_id;
        END IF;
        report := replace(report,'{report_end}',sample_rec.sample_time::text);
        tmp_text := tmp_text || 'EndID: ' || sample_rec.sample_id ||')';
    CLOSE c_sample;
    report := replace(report,'{samples}',tmp_text);
    tmp_text := '';

    -- Report internal temporary tables
    -- Creating temporary table for reported queries
    CREATE TEMPORARY TABLE IF NOT EXISTS queries_list (
      userid              oid,
      datid               oid,
      queryid             bigint,
      CONSTRAINT pk_queries_list PRIMARY KEY (userid, datid, queryid))
    ON COMMIT DELETE ROWS;
    /*
    * Caching temporary tables, containing object stats cache
    * used several times in a report functions
    */
    CREATE TEMPORARY TABLE top_statements AS
    SELECT * FROM top_statements(sserver_id, start_id, end_id);
    CREATE TEMPORARY TABLE top_tables AS
    SELECT * FROM top_tables(sserver_id, start_id, end_id);
    CREATE TEMPORARY TABLE top_indexes AS
    SELECT * FROM top_indexes(sserver_id, start_id, end_id);
    CREATE TEMPORARY TABLE top_io_tables AS
    SELECT * FROM top_io_tables(sserver_id, start_id, end_id);
    CREATE TEMPORARY TABLE top_io_indexes AS
    SELECT * FROM top_io_indexes(sserver_id, start_id, end_id);
    CREATE TEMPORARY TABLE top_functions AS
    SELECT * FROM top_functions(sserver_id, start_id, end_id, false);
    CREATE TEMPORARY TABLE top_kcache_statements AS
    SELECT * FROM top_kcache_statements(sserver_id, start_id, end_id);
    ANALYZE top_statements;
    ANALYZE top_tables;
    ANALYZE top_indexes;
    ANALYZE top_io_tables;
    ANALYZE top_io_indexes;
    ANALYZE top_functions;
    ANALYZE top_kcache_statements;

    -- Populate report settings
    jreportset := jsonb_build_object(
    'htbl',jsonb_build_object(
      'reltr','class="parent"',
      'toasttr','class="child"',
      'reltdhdr','class="hdr"',
      'stattbl','class="stat"',
      'value','class="value"',
      'mono','class="mono"',
      'reltdspanhdr','rowspan="2" class="hdr"'
    ),
    'report_features',jsonb_build_object(
      'statstatements',profile_checkavail_statstatements(sserver_id, start_id, end_id),
      'planning_times',profile_checkavail_planning_times(sserver_id, start_id, end_id),
      'statement_wal_bytes',profile_checkavail_stmt_wal_bytes(sserver_id, start_id, end_id),
      'wal_stats',profile_checkavail_walstats(sserver_id, start_id, end_id),
      'sess_stats',profile_checkavail_sessionstats(sserver_id, start_id, end_id),
      'function_stats',profile_checkavail_functions(sserver_id, start_id, end_id),
      'trigger_function_stats',profile_checkavail_trg_functions(sserver_id, start_id, end_id),
      'table_sizes',profile_checkavail_tablesizes(sserver_id, start_id, end_id),
      'table_growth',profile_checkavail_tablegrowth(sserver_id, start_id, end_id),
      'kcachestatements',profile_checkavail_rusage(sserver_id,start_id,end_id),
      'rusage.planstats',profile_checkavail_rusage_planstats(sserver_id,start_id,end_id)
    ),
    'report_properties',jsonb_build_object(
      'interval_duration_sec',
        (SELECT extract(epoch FROM e.sample_time - s.sample_time)
        FROM samples s JOIN samples e USING (server_id)
        WHERE e.sample_id=end_id and s.sample_id=start_id
          AND server_id = sserver_id))
    );

    -- Reporting possible statements overflow
    tmp_report := check_stmt_cnt(sserver_id, start_id, end_id);
    IF tmp_report != '' THEN
        tmp_text := tmp_text || '<H2>Warning!</H2>';
        tmp_text := tmp_text || '<p>This interval contains sample(s) with captured statements count more than 90% of pg_stat_statements.max setting. Consider increasing this parameter.</p>';
        tmp_text := tmp_text || tmp_report;
    END IF;

    -- pg_stat_statements.track warning
    stmt_all_cnt := check_stmt_all_setting(sserver_id, start_id, end_id);
    tmp_report := '';
    IF stmt_all_cnt > 0 THEN
        tmp_report := 'Report includes '||stmt_all_cnt||' sample(s) with setting <i>pg_stat_statements.track = all</i>.'||
        'Value of %Total columns may be incorrect.';
    END IF;
    IF tmp_report != '' THEN
        tmp_text := tmp_text || '<p><b>Warning!</b>'||tmp_report||'</p>';
    END IF;

    -- Table of Contents
    tmp_text := tmp_text ||'<H2>Report sections</H2><ul>';
    tmp_text := tmp_text || '<li><a HREF=#cl_stat>Server statistics</a></li>';
    tmp_text := tmp_text || '<ul>';
    tmp_text := tmp_text || '<li><a HREF=#db_stat>Database statistics</a></li>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'sess_stats')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#db_stat_sessions>Session statistics by database</a></li>';
    END IF;
    IF jsonb_extract_path_text(jreportset, 'report_features', 'statstatements')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#st_stat>Statement statistics by database</a></li>';
    END IF;
    tmp_text := tmp_text || '<li><a HREF=#clu_stat>Cluster statistics</a></li>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'wal_stats')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#wal_stat>WAL statistics</a></li>';
    END IF;
    tmp_text := tmp_text || '<li><a HREF=#tablespace_stat>Tablespace statistics</a></li>';
    tmp_text := tmp_text || '</ul>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'statstatements')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#sql_stat>SQL Query statistics</a></li>';
      tmp_text := tmp_text || '<ul>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
        tmp_text := tmp_text || '<li><a HREF=#top_ela>Top SQL by elapsed time</a></li>';
        tmp_text := tmp_text || '<li><a HREF=#top_plan>Top SQL by planning time</a></li>';
      END IF;
      tmp_text := tmp_text || '<li><a HREF=#top_exec>Top SQL by execution time</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_calls>Top SQL by executions</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_iowait>Top SQL by I/O wait time</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_pgs_fetched>Top SQL by shared blocks fetched</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_shared_reads>Top SQL by shared blocks read</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_shared_dirtied>Top SQL by shared blocks dirtied</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#top_shared_written>Top SQL by shared blocks written</a></li>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'statement_wal_bytes')::boolean THEN
        tmp_text := tmp_text || '<li><a HREF=#top_wal_bytes>Top SQL by WAL size</a></li>';
      END IF;
      tmp_text := tmp_text || '<li><a HREF=#top_temp>Top SQL by temp usage</a></li>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'kcachestatements')::boolean THEN
        tmp_text := tmp_text || '<li><a HREF=#kcache_stat>rusage statistics</a></li>';
        tmp_text := tmp_text || '<ul>';
        tmp_text := tmp_text || '<li><a HREF=#kcache_time>Top SQL by system and user time </a></li>';
        tmp_text := tmp_text || '<li><a HREF=#kcache_reads_writes>Top SQL by reads/writes done by filesystem layer </a></li>';
        tmp_text := tmp_text || '</ul>';
      END IF;
      -- SQL texts
      tmp_text := tmp_text || '<li><a HREF=#sql_list>Complete list of SQL texts</a></li>';
      tmp_text := tmp_text || '</ul>';
    END IF;

    tmp_text := tmp_text || '<li><a HREF=#schema_stat>Schema object statistics</a></li>';
    tmp_text := tmp_text || '<ul>';
    tmp_text := tmp_text || '<li><a HREF=#scanned_tbl>Top tables by estimated sequentially scanned volume</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#fetch_tbl>Top tables by blocks fetched</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#read_tbl>Top tables by blocks read</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#dml_tbl>Top DML tables</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#vac_tbl>Top tables by updated/deleted tuples</a></li>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'table_growth')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#growth_tbl>Top growing tables</a></li>';
    END IF;
    tmp_text := tmp_text || '<li><a HREF=#fetch_idx>Top indexes by blocks fetched</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#read_idx>Top indexes by blocks read</a></li>';
    IF jsonb_extract_path_text(jreportset, 'report_features', 'table_growth')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#growth_idx>Top growing indexes</a></li>';
    END IF;
    tmp_text := tmp_text || '<li><a HREF=#ix_unused>Unused indexes</a></li>';
    tmp_text := tmp_text || '</ul>';

    IF jsonb_extract_path_text(jreportset, 'report_features', 'function_stats')::boolean THEN
      tmp_text := tmp_text || '<li><a HREF=#func_stat>User function statistics</a></li>';
      tmp_text := tmp_text || '<ul>';
      tmp_text := tmp_text || '<li><a HREF=#funcs_time_stat>Top functions by total time</a></li>';
      tmp_text := tmp_text || '<li><a HREF=#funcs_calls_stat>Top functions by executions</a></li>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'trigger_function_stats')::boolean THEN
        tmp_text := tmp_text || '<li><a HREF=#trg_funcs_time_stat>Top trigger functions by total time</a></li>';
      END IF;
      tmp_text := tmp_text || '</ul>';
    END IF;


    tmp_text := tmp_text || '<li><a HREF=#vacuum_stats>Vacuum-related statistics</a></li>';
    tmp_text := tmp_text || '<ul>';
    tmp_text := tmp_text || '<li><a HREF=#top_vacuum_cnt_tbl>Top tables by vacuum operations</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#top_analyze_cnt_tbl>Top tables by analyze operations</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#top_ix_vacuum_bytes_cnt_tbl>Top indexes by estimated vacuum I/O load</a></li>';

    tmp_text := tmp_text || '<li><a HREF=#dead_tbl>Top tables by dead tuples ratio</a></li>';
    tmp_text := tmp_text || '<li><a HREF=#mod_tbl>Top tables by modified tuples ratio</a></li>';
    tmp_text := tmp_text || '</ul>';
    tmp_text := tmp_text || '<li><a HREF=#pg_settings>Cluster settings during the report interval</a></li>';
    tmp_text := tmp_text || '</ul>';


    --Reporting cluster stats
    tmp_text := tmp_text || '<H2><a NAME=cl_stat>Server statistics</a></H2>';
    tmp_text := tmp_text || '<H3><a NAME=db_stat>Database statistics</a></H3>';
    tmp_report := dbstats_reset_htbl(jreportset, sserver_id, start_id, end_id);
    IF tmp_report != '' THEN
      tmp_text := tmp_text || '<p><b>Warning!</b> Database statistics reset detected during report period!</p>'||tmp_report||
        '<p>Statistics for listed databases and contained objects might be affected</p>';
    END IF;
    tmp_text := tmp_text || nodata_wrapper(dbstats_htbl(jreportset, sserver_id, start_id, end_id, topn));

    IF jsonb_extract_path_text(jreportset, 'report_features', 'sess_stats')::boolean THEN
      tmp_text := tmp_text || '<H3><a NAME=db_stat_sessions>Session statistics by database</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(dbstats_sessions_htbl(jreportset, sserver_id, start_id, end_id, topn));
    END IF;

    IF jsonb_extract_path_text(jreportset, 'report_features', 'statstatements')::boolean THEN
      tmp_text := tmp_text || '<H3><a NAME=st_stat>Statement statistics by database</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(statements_stats_htbl(jreportset, sserver_id, start_id, end_id, topn));
    END IF;

    tmp_text := tmp_text || '<div>';
    tmp_text := tmp_text || '<div style="display:inline-block; margin-right:2em;">'
      '<H3><a NAME=clu_stat>Cluster statistics</a></H3>';
    tmp_report := cluster_stats_reset_htbl(jreportset, sserver_id, start_id, end_id);
    IF tmp_report != '' THEN
      tmp_text := tmp_text || '<p><b>Warning!</b> Cluster statistics reset detected during report period!</p>'||tmp_report||
        '<p>Cluster statistics might be affected</p>';
    END IF;
    tmp_text := tmp_text || nodata_wrapper(cluster_stats_htbl(jreportset, sserver_id, start_id, end_id)) || '</div>';

    IF jsonb_extract_path_text(jreportset, 'report_features', 'wal_stats')::boolean THEN
      tmp_text := tmp_text || '<div style="display:inline-block"><H3><a NAME=wal_stat>WAL statistics</a></H3>';
      tmp_report := wal_stats_reset_htbl(jreportset, sserver_id, start_id, end_id);
      IF tmp_report != '' THEN
        tmp_text := tmp_text || '<p><b>Warning!</b> WAL statistics reset detected during report period!</p>'||tmp_report||
          '<p>WAL statistics might be affected</p>';
      END IF;
      tmp_text := tmp_text || nodata_wrapper(wal_stats_htbl(jreportset, sserver_id, start_id, end_id)) ||
        '</div>';
    END IF;
    tmp_text := tmp_text || '</div>';

    tmp_text := tmp_text || '<H3><a NAME=tablespace_stat>Tablespace statistics</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(tablespaces_stats_htbl(jreportset, sserver_id, start_id, end_id));

    --Reporting on top queries by elapsed time
    IF jsonb_extract_path_text(jreportset, 'report_features', 'statstatements')::boolean THEN
      tmp_text := tmp_text || '<H2><a NAME=sql_stat>SQL Query statistics</a></H2>';
      IF jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
        tmp_text := tmp_text || '<H3><a NAME=top_ela>Top SQL by elapsed time</a></H3>';
        tmp_text := tmp_text || nodata_wrapper(top_elapsed_htbl(jreportset, sserver_id, start_id, end_id, topn));
        tmp_text := tmp_text || '<H3><a NAME=top_plan>Top SQL by planning time</a></H3>';
        tmp_text := tmp_text || nodata_wrapper(top_plan_time_htbl(jreportset, sserver_id, start_id, end_id, topn));
      END IF;
      tmp_text := tmp_text || '<H3><a NAME=top_exec>Top SQL by execution time</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_exec_time_htbl(jreportset, sserver_id, start_id, end_id, topn));

      -- Reporting on top queries by executions
      tmp_text := tmp_text || '<H3><a NAME=top_calls>Top SQL by executions</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_exec_htbl(jreportset, sserver_id, start_id, end_id, topn));

      -- Reporting on top queries by I/O wait time
      tmp_text := tmp_text || '<H3><a NAME=top_iowait>Top SQL by I/O wait time</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_iowait_htbl(jreportset, sserver_id, start_id, end_id, topn));

      -- Reporting on top queries by fetched blocks
      tmp_text := tmp_text || '<H3><a NAME=top_pgs_fetched>Top SQL by shared blocks fetched</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_shared_blks_fetched_htbl(jreportset, sserver_id, start_id, end_id, topn));

      -- Reporting on top queries by shared reads
      tmp_text := tmp_text || '<H3><a NAME=top_shared_reads>Top SQL by shared blocks read</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_shared_reads_htbl(jreportset, sserver_id, start_id, end_id, topn));

      -- Reporting on top queries by shared dirtied
      tmp_text := tmp_text || '<H3><a NAME=top_shared_dirtied>Top SQL by shared blocks dirtied</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_shared_dirtied_htbl(jreportset, sserver_id, start_id, end_id, topn));

      -- Reporting on top queries by shared written
      tmp_text := tmp_text || '<H3><a NAME=top_shared_written>Top SQL by shared blocks written</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_shared_written_htbl(jreportset, sserver_id, start_id, end_id, topn));

      -- Reporting on top queries by WAL bytes
      IF jsonb_extract_path_text(jreportset, 'report_features', 'statement_wal_bytes')::boolean THEN
        tmp_text := tmp_text || '<H3><a NAME=top_wal_bytes>Top SQL by WAL size</a></H3>';
        tmp_text := tmp_text || nodata_wrapper(top_wal_size_htbl(jreportset, sserver_id, start_id, end_id, topn));
      END IF;

      -- Reporting on top queries by temp usage
      tmp_text := tmp_text || '<H3><a NAME=top_temp>Top SQL by temp usage</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_temp_htbl(jreportset, sserver_id, start_id, end_id, topn));

      --Kcache section
     IF jsonb_extract_path_text(jreportset, 'report_features', 'kcachestatements')::boolean THEN
      -- Reporting kcache queries
        tmp_text := tmp_text||'<H3><a NAME=kcache_stat>rusage statistics</a></H3>';
        tmp_text := tmp_text||'<H4><a NAME=kcache_time>Top SQL by system and user time </a></H4>';
        tmp_text := tmp_text || nodata_wrapper(top_cpu_time_htbl(jreportset, sserver_id, start_id, end_id, topn));
        tmp_text := tmp_text||'<H4><a NAME=kcache_reads_writes>Top SQL by reads/writes done by filesystem layer </a></H4>';
        tmp_text := tmp_text || nodata_wrapper(top_io_filesystem_htbl(jreportset, sserver_id, start_id, end_id, topn));
     END IF;

      -- Listing queries
      tmp_text := tmp_text || '<H3><a NAME=sql_list>Complete list of SQL texts</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(report_queries(jreportset, sserver_id, start_id, end_id));
    END IF;

    -- Reporting Object stats
    -- Reporting scanned table
    tmp_text := tmp_text || '<H2><a NAME=schema_stat>Schema object statistics</a></H2>';
    tmp_text := tmp_text || '<H3><a NAME=scanned_tbl>Top tables by estimated sequentially scanned volume</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_scan_tables_htbl(jreportset, sserver_id, start_id, end_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=fetch_tbl>Top tables by blocks fetched</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(tbl_top_fetch_htbl(jreportset, sserver_id, start_id, end_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=read_tbl>Top tables by blocks read</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(tbl_top_io_htbl(jreportset, sserver_id, start_id, end_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=dml_tbl>Top DML tables</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_dml_tables_htbl(jreportset, sserver_id, start_id, end_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=vac_tbl>Top tables by updated/deleted tuples</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_upd_vac_tables_htbl(jreportset, sserver_id, start_id, end_id, topn));

    IF jsonb_extract_path_text(jreportset, 'report_features', 'table_growth')::boolean THEN
      tmp_text := tmp_text || '<H3><a NAME=growth_tbl>Top growing tables</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_growth_tables_htbl(jreportset, sserver_id, start_id, end_id, topn));
    END IF;

    tmp_text := tmp_text || '<H3><a NAME=fetch_idx>Top indexes by blocks fetched</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(ix_top_fetch_htbl(jreportset, sserver_id, start_id, end_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=read_idx>Top indexes by blocks read</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(ix_top_io_htbl(jreportset, sserver_id, start_id, end_id, topn));

    IF jsonb_extract_path_text(jreportset, 'report_features', 'table_growth')::boolean THEN
      tmp_text := tmp_text || '<H3><a NAME=growth_idx>Top growing indexes</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(top_growth_indexes_htbl(jreportset, sserver_id, start_id, end_id, topn));
    END IF;

    tmp_text := tmp_text || '<H3><a NAME=ix_unused>Unused indexes</a></H3>';
    tmp_text := tmp_text || '<p>This table contains non-scanned indexes (during report period), ordered by number of DML operations on underlying tables. Constraint indexes are excluded.</p>';
    tmp_text := tmp_text || nodata_wrapper(ix_unused_htbl(jreportset, sserver_id, start_id, end_id, topn));

    IF jsonb_extract_path_text(jreportset, 'report_features', 'function_stats')::boolean THEN
      tmp_text := tmp_text || '<H2><a NAME=func_stat>User function statistics</a></H2>';
      tmp_text := tmp_text || '<H3><a NAME=funcs_time_stat>Top functions by total time</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(func_top_time_htbl(jreportset, sserver_id, start_id, end_id, topn));

      tmp_text := tmp_text || '<H3><a NAME=funcs_calls_stat>Top functions by executions</a></H3>';
      tmp_text := tmp_text || nodata_wrapper(func_top_calls_htbl(jreportset, sserver_id, start_id, end_id, topn));

      IF jsonb_extract_path_text(jreportset, 'report_features', 'trigger_function_stats')::boolean THEN
        tmp_text := tmp_text || '<H3><a NAME=trg_funcs_time_stat>Top trigger functions by total time</a></H3>';
        tmp_text := tmp_text || nodata_wrapper(func_top_trg_htbl(jreportset, sserver_id, start_id, end_id, topn));
      END IF;
    END IF;

    -- Reporting vacuum related stats
    tmp_text := tmp_text || '<H2><a NAME=vacuum_stats>Vacuum-related statistics</a></H2>';
    tmp_text := tmp_text || '<H3><a NAME=top_vacuum_cnt_tbl>Top tables by vacuum operations</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_vacuumed_tables_htbl(jreportset, sserver_id, start_id, end_id, topn));
    tmp_text := tmp_text || '<H3><a NAME=top_analyze_cnt_tbl>Top tables by analyze operations</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_analyzed_tables_htbl(jreportset, sserver_id, start_id, end_id, topn));
    tmp_text := tmp_text || '<H3><a NAME=top_ix_vacuum_bytes_cnt_tbl>Top indexes by estimated vacuum I/O load</a></H3>';
    tmp_text := tmp_text || nodata_wrapper(top_vacuumed_indexes_htbl(jreportset, sserver_id, start_id, end_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=dead_tbl>Top tables by dead tuples ratio</a></H3>';
    tmp_text := tmp_text || '<p>Data in this section is not differential. This data is valid for last report sample only.</p>';
    tmp_text := tmp_text || nodata_wrapper(tbl_top_dead_htbl(jreportset, sserver_id, start_id, end_id, topn));

    tmp_text := tmp_text || '<H3><a NAME=mod_tbl>Top tables by modified tuples ratio</a></H3>';
    tmp_text := tmp_text || '<p>Table shows modified tuples statistics since last analyze.</p>';
    tmp_text := tmp_text || '<p>Data in this section is not differential. This data is valid for last report sample only.</p>';
    tmp_text := tmp_text || nodata_wrapper(tbl_top_mods_htbl(jreportset, sserver_id, start_id, end_id, topn));

    -- Database settings report
    tmp_text := tmp_text || '<H2><a NAME=pg_settings>Cluster settings during the report interval</a></H2>';
    tmp_text := tmp_text || nodata_wrapper(settings_and_changes_htbl(jreportset, sserver_id, start_id, end_id));

    -- Reporting possible statements overflow
    tmp_report := check_stmt_cnt(sserver_id);
    IF tmp_report != '' THEN
        tmp_text := tmp_text || '<H2>Warning!</H2>';
        tmp_text := tmp_text || '<p>Sample repository contains samples with captured statements count more than 90% of pg_stat_statements.max setting. Consider increasing this parameter.</p>';
        tmp_text := tmp_text || tmp_report;
    END IF;

    /*
    * Dropping cache temporary tables
    * This is needed to avoid conflict with existing table if several
    * reports are collected in one session
    */
    DROP TABLE top_statements;
    DROP TABLE top_tables;
    DROP TABLE top_indexes;
    DROP TABLE top_io_tables;
    DROP TABLE top_io_indexes;
    DROP TABLE top_functions;
    DROP TABLE top_kcache_statements;

    RETURN replace(report,'{report}',tmp_text);
END;
$function$;

-- Function: get_report
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_report(time_range tstzrange, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_report(get_server_by_name('local'), start_id, end_id, description, with_growth)
  FROM get_sampleids_by_timerange(get_server_by_name('local'), time_range)
$function$;

-- Function: get_report
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_report(server name, time_range tstzrange, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_report(get_server_by_name(server), start_id, end_id, description,with_growth)
  FROM get_sampleids_by_timerange(get_server_by_name(server), time_range)
$function$;

-- Function: get_report
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_report(server name, start_id integer, end_id integer, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_report(get_server_by_name(server), start_id, end_id,
    description, with_growth);
$function$;

-- Function: get_report
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_report(start_id integer, end_id integer, description text DEFAULT NULL::text, with_growth boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_report('local',start_id,end_id,description,with_growth);
$function$;

-- Function: get_report_latest
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_report_latest(server name DEFAULT NULL::name)
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT get_report(srv.server_id, s.sample_id, e.sample_id, NULL)
  FROM samples s JOIN samples e ON (s.server_id = e.server_id AND s.sample_id = e.sample_id - 1)
    JOIN servers srv ON (e.server_id = srv.server_id AND e.sample_id = srv.last_sample_id)
  WHERE srv.server_name = COALESCE(server, 'local')
$function$;

-- Function: get_sampleids_by_timerange
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_sampleids_by_timerange(sserver_id integer, time_range tstzrange)
 RETURNS TABLE(start_id integer, end_id integer)
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  SELECT min(s1.sample_id),max(s2.sample_id) INTO start_id,end_id FROM
    samples s1 JOIN
    /* Here redundant join condition s1.sample_id < s2.sample_id is needed
     * Otherwise optimizer is using tstzrange(s1.sample_time,s2.sample_time) && time_range
     * as first join condition and some times failes with error
     * ERROR:  range lower bound must be less than or equal to range upper bound
     */
    samples s2 ON (s1.sample_id < s2.sample_id AND s1.server_id = s2.server_id AND s1.sample_id + 1 = s2.sample_id)
  WHERE s1.server_id = sserver_id AND tstzrange(s1.sample_time,s2.sample_time) && time_range;

    IF start_id IS NULL OR end_id IS NULL THEN
      RAISE 'Suitable samples not found';
    END IF;

    RETURN NEXT;
    RETURN;
END;
$function$;

-- Function: get_server_by_name
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_server_by_name(server name)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    sserver_id     integer;
BEGIN
    SELECT server_id INTO sserver_id FROM servers WHERE server_name=server;
    IF sserver_id IS NULL THEN
        RAISE 'Server not found.';
    END IF;

    RETURN sserver_id;
END;
$function$;

-- Function: get_sized_bounds
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.get_sized_bounds(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(left_bound integer, right_bound integer)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
SELECT
  left_bound.sample_id AS left_bound,
  right_bound.sample_id AS right_bound
FROM (
    SELECT
      sample_id
    FROM
      sample_stat_tables_total
    WHERE
      server_id = sserver_id
      AND sample_id >= end_id
    GROUP BY
      sample_id
    HAVING
      count(relsize_diff) > 0
    ORDER BY sample_id ASC
    LIMIT 1
  ) right_bound,
  (
    SELECT
      sample_id
    FROM
      sample_stat_tables_total
    WHERE
      server_id = sserver_id
      AND sample_id <= start_id
    GROUP BY
      sample_id
    HAVING
      count(relsize_diff) > 0
    ORDER BY sample_id DESC
    LIMIT 1
  ) left_bound
$function$;

-- Function: gin_extract_query_trgm
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_query_trgm$function$;

-- Function: gin_extract_value_trgm
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gin_extract_value_trgm(text, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_value_trgm$function$;

-- Function: gin_trgm_consistent
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_consistent$function$;

-- Function: gin_trgm_triconsistent
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal)
 RETURNS "char"
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_triconsistent$function$;

-- Function: gtrgm_compress
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_compress$function$;

-- Function: gtrgm_consistent
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_consistent$function$;

-- Function: gtrgm_decompress
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_decompress$function$;

-- Function: gtrgm_distance
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_distance$function$;

-- Function: gtrgm_in
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_in(cstring)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_in$function$;

-- Function: gtrgm_out
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_out(gtrgm)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_out$function$;

-- Function: gtrgm_penalty
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_penalty$function$;

-- Function: gtrgm_picksplit
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_picksplit$function$;

-- Function: gtrgm_same
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_same$function$;

-- Function: gtrgm_union
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.gtrgm_union(internal, internal)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_union$function$;

-- Function: import_data
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.import_data(data regclass)
 RETURNS bigint
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  import_meta     jsonb;
  tables_list     jsonb;
  servers_list    jsonb; -- import servers list

  row_proc        bigint;
  rows_processed  bigint = 0;
  new_server_id   integer = null;

  r_result        RECORD;
BEGIN
  -- Get import metadata
  EXECUTE format('SELECT row_data::jsonb FROM %s WHERE section_id = 0',data)
  INTO STRICT import_meta;

  -- Check dump compatibility
  IF (SELECT count(*) < 1 FROM import_queries_version_order
      WHERE extension = import_meta ->> 'extension'
        AND version = import_meta ->> 'version')
  THEN
    RAISE 'Unsupported extension version: %', (import_meta ->> 'extension')||' '||(import_meta ->> 'version');
  END IF;

  -- Get import tables list
  EXECUTE format('SELECT row_data::jsonb FROM %s WHERE section_id = $1',data)
  USING (import_meta ->> 'tab_list_section')::integer
  INTO STRICT tables_list;
  -- Servers processing
  -- Get import servers list
  EXECUTE format($q$SELECT
      jsonb_agg(srvjs.row_data::jsonb)
    FROM
      jsonb_to_recordset($1) as tbllist(section_id integer, relname text),
      %1$s srvjs
    WHERE
      tbllist.relname = 'servers'
      AND srvjs.section_id = tbllist.section_id$q$,
    data)
  USING tables_list
  INTO STRICT servers_list;

  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_srv_map (
    imp_srv_id bigint PRIMARY KEY,
    local_srv_id bigint
  );

  TRUNCATE tmp_srv_map;

  /*
   * Performing importing to local servers matching. We need to consider several cases:
   * - creation dates and system identifiers matched - we have a match
   * - creation dates and system identifiers don't match, but names matched - conflict as we can't create a new server
   * - nothing matched - a new local server is to be created
   * By the way, we'll populate tmp_srv_map table, containing
   * a mapping between local and importing servers to use on data load.
   */
  FOR r_result IN EXECUTE format($q$SELECT
      imp_srv.server_name         imp_server_name,
      ls.server_name              local_server_name,
      imp_srv.server_created      imp_server_created,
      ls.server_created           local_server_created,
      d.row_data->>'reset_val'    imp_system_identifier,
      ls.system_identifier        local_system_identifier,
      imp_srv.server_id           imp_server_id,
      ls.server_id                local_server_id,
      imp_srv.server_description  imp_server_description,
      imp_srv.db_exclude          imp_server_db_exclude,
      imp_srv.connstr             imp_server_connstr,
      imp_srv.max_sample_age      imp_server_max_sample_age,
      imp_srv.last_sample_id      imp_server_last_sample_id,
      imp_srv.size_smp_wnd_start  imp_size_smp_wnd_start,
      imp_srv.size_smp_wnd_dur    imp_size_smp_wnd_dur,
      imp_srv.size_smp_interval   imp_size_smp_interval,
      imp_srv.sizes_limited       imp_sizes_limited
    FROM
      jsonb_to_recordset($1) as
        imp_srv(
          server_id           integer,
          server_name         name,
          server_description  text,
          server_created      timestamp with time zone,
          db_exclude          name[],
          enabled             boolean,
          connstr             text,
          max_sample_age      integer,
          last_sample_id      integer,
          size_smp_wnd_start  time with time zone,
          size_smp_wnd_dur    interval hour to second,
          size_smp_interval   interval day to minute,
          sizes_limited       boolean
        )
      JOIN jsonb_to_recordset($2) AS tbllist(section_id integer, relname text)
        ON (tbllist.relname = 'sample_settings')
      JOIN %s d ON
        (d.section_id = tbllist.section_id AND d.row_data->>'name' = 'system_identifier'
          AND (d.row_data->>'server_id')::integer = imp_srv.server_id)
      LEFT OUTER JOIN (
        SELECT
          srv.server_id,
          srv.server_name,
          srv.server_created,
          set.reset_val as system_identifier
        FROM servers srv
          LEFT OUTER JOIN sample_settings set ON (set.server_id = srv.server_id AND set.name = 'system_identifier')
        ) ls ON
        ((imp_srv.server_created = ls.server_created AND d.row_data->>'reset_val' = ls.system_identifier)
          OR imp_srv.server_name = ls.server_name)
    $q$,
    data)
  USING
    servers_list,
    tables_list
  LOOP
    IF r_result.imp_server_created = r_result.local_server_created AND
      r_result.imp_system_identifier = r_result.local_system_identifier
    THEN
      /* use this local server when matched by server creation time and system identifier */
      INSERT INTO tmp_srv_map (imp_srv_id,local_srv_id) VALUES
        (r_result.imp_server_id,r_result.local_server_id);
      /* Update local server if new last_sample_id is greatest*/
      UPDATE servers
      SET
        (
          db_exclude,
          connstr,
          max_sample_age,
          last_sample_id,
          size_smp_wnd_start,
          size_smp_wnd_dur,
          size_smp_interval,
          sizes_limited
        ) = (
          r_result.imp_server_db_exclude,
          r_result.imp_server_connstr,
          r_result.imp_server_max_sample_age,
          r_result.imp_server_last_sample_id,
          r_result.imp_size_smp_wnd_start,
          r_result.imp_size_smp_wnd_dur,
          r_result.imp_size_smp_interval,
          COALESCE(r_result.imp_sizes_limited, true)
        )
      WHERE server_id = r_result.local_server_id
        AND last_sample_id < r_result.imp_server_last_sample_id;
    ELSIF r_result.imp_server_name = r_result.local_server_name
    THEN
      /* Names matched, but identifiers does not - we have a conflict */
      RAISE 'Local server "%" creation date or system identifier does not match imported one (try renaming local server)',
        r_result.local_server_name;
    ELSIF r_result.local_server_name IS NULL
    THEN
      /* No match at all - we are creating a new server */
      INSERT INTO servers AS srv (
        server_name,
        server_description,
        server_created,
        db_exclude,
        enabled,
        connstr,
        max_sample_age,
        last_sample_id,
        size_smp_wnd_start,
        size_smp_wnd_dur,
        size_smp_interval,
        sizes_limited)
      VALUES (
        r_result.imp_server_name,
        r_result.imp_server_description,
        r_result.imp_server_created,
        r_result.imp_server_db_exclude,
        FALSE,
        r_result.imp_server_connstr,
        r_result.imp_server_max_sample_age,
        r_result.imp_server_last_sample_id,
        r_result.imp_size_smp_wnd_start,
        r_result.imp_size_smp_wnd_dur,
        r_result.imp_size_smp_interval,
        COALESCE(r_result.imp_sizes_limited, true)
      )
      RETURNING server_id INTO new_server_id;
      INSERT INTO tmp_srv_map (imp_srv_id,local_srv_id) VALUES
        (r_result.imp_server_id,new_server_id);
    ELSE
      /* This shouldn't ever happen */
      RAISE 'Import and local servers matching exception';
    END IF;
  END LOOP;
  ANALYZE tmp_srv_map;
  -- Load tables data
  FOR r_result IN (
    -- get most recent versions of queries for importing tables
    WITH RECURSIVE ver_order (extension,version,level) AS (
      SELECT
        extension,
        version,
        1 as level
      FROM import_queries_version_order
      WHERE extension = import_meta ->> 'extension'
        AND version = import_meta ->> 'version'
      UNION ALL
      SELECT
        vo.parent_extension,
        vo.parent_version,
        vor.level + 1 as level
      FROM import_queries_version_order vo
        JOIN ver_order vor ON
          ((vo.extension, vo.version) = (vor.extension, vor.version))
      WHERE vo.parent_version IS NOT NULL
    )
    SELECT
      q.query,
      tbllist.section_id as section_id,
      tbllist.relname
    FROM
      ver_order vo JOIN
      (SELECT min(o.level) as level,vq.extension, vq.relname FROM ver_order o
      JOIN import_queries vq ON (o.extension, o.version) = (vq.extension, vq.from_version)
      GROUP BY vq.extension, vq.relname) as min_level ON
        (vo.extension,vo.level) = (min_level.extension,min_level.level)
      JOIN import_queries q ON
        (q.extension,q.from_version,q.relname) = (vo.extension,vo.version,min_level.relname)
      RIGHT OUTER JOIN jsonb_to_recordset(tables_list) as tbllist(section_id integer, relname text) ON
        (tbllist.relname = q.relname)
    WHERE tbllist.relname NOT IN ('servers')
    ORDER BY tbllist.section_id ASC, q.exec_order ASC
  )
  LOOP
    -- Forgotten query for table check
    IF r_result.query IS NULL THEN
      RAISE 'There is no import query for relation %', r_result.relname;
    END IF;
    -- execute load query for each import relation
    EXECUTE
      format(r_result.query,
        data)
    USING
      r_result.section_id;
    GET DIAGNOSTICS row_proc = ROW_COUNT;
    rows_processed := rows_processed + row_proc;
  END LOOP;

  RETURN rows_processed;
END;
$function$;

-- Function: index_size_failures
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.index_size_failures(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, datid oid, indexrelid oid, size_failed boolean)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT
    server_id,
    datid,
    indexrelid,
    bool_or(size_failed) as size_failed
  FROM
    sample_stat_indexes_failures
  WHERE
    server_id = sserver_id AND sample_id IN (start_id, end_id)
  GROUP BY
    server_id,
    datid,
    indexrelid
$function$;

-- Function: ix_top_fetch_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.ix_top_fetch_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.tablespacename,st2.tablespacename) as tablespacename,
        COALESCE(st1.schemaname,st2.schemaname) as schemaname,
        COALESCE(st1.relname,st2.relname) as relname,
        COALESCE(st1.indexrelname,st2.indexrelname) as indexrelname,
        NULLIF(st1.idx_scan, 0) as idx_scan1,
        NULLIF(st1.idx_blks_fetch, 0) as idx_blks_fetch1,
        NULLIF(st1.idx_blks_fetch_pct, 0.0) as idx_blks_fetch_pct1,
        NULLIF(st2.idx_scan, 0) as idx_scan2,
        NULLIF(st2.idx_blks_fetch, 0) as idx_blks_fetch2,
        NULLIF(st2.idx_blks_fetch_pct, 0.0) as idx_blks_fetch_pct2,
        row_number() OVER (ORDER BY st1.idx_blks_fetch DESC NULLS LAST) as rn_fetched1,
        row_number() OVER (ORDER BY st2.idx_blks_fetch DESC NULLS LAST) as rn_fetched2
    FROM
        top_io_indexes1 st1
        FULL OUTER JOIN top_io_indexes2 st2 USING (server_id, datid, relid, indexrelid)
    WHERE COALESCE(st1.idx_blks_fetch, 0) + COALESCE(st2.idx_blks_fetch, 0) > 0
    ORDER BY
      COALESCE(st1.idx_blks_fetch, 0) + COALESCE(st2.idx_blks_fetch, 0) DESC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.relid,st2.relid) ASC,
      COALESCE(st1.indexrelid,st2.indexrelid) ASC
    ) t1
    WHERE least(
        rn_fetched1,
        rn_fetched2
      ) <= topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th>Index</th>'
            '<th>I</th>'
            '<th title="Number of scans performed on index">Scans</th>'
            '<th title="Number of blocks fetched (read+hit) from this index">Blks</th>'
            '<th title="Blocks fetched from this index as a percentage of all blocks fetched in a cluster">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates

    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_tbl_stats LOOP
    report := report||format(
        jtab_tpl #>> ARRAY['row_tpl'],
        r_result.dbname,
        r_result.tablespacename,
        r_result.schemaname,
        r_result.relname,
        r_result.indexrelname,
        r_result.idx_scan1,
        r_result.idx_blks_fetch1,
        round(r_result.idx_blks_fetch_pct1,2),
        r_result.idx_scan2,
        r_result.idx_blks_fetch2,
        round(r_result.idx_blks_fetch_pct2,2)
    );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: ix_top_fetch_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.ix_top_fetch_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        tablespacename,
        schemaname,
        relname,
        indexrelname,
        NULLIF(idx_scan, 0) as idx_scan,
        NULLIF(idx_blks_fetch, 0) as idx_blks_fetch,
        NULLIF(idx_blks_fetch_pct, 0.0) as idx_blks_fetch_pct
    FROM top_io_indexes
    WHERE idx_blks_fetch > 0
    ORDER BY
      idx_blks_fetch DESC,
      datid ASC,
      relid ASC,
      indexrelid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th>Index</th>'
            '<th title="Number of scans performed on index">Scans</th>'
            '<th title="Number of blocks fetched (read+hit) from this index">Blks</th>'
            '<th title="Blocks fetched from this index as a percentage of all blocks fetched in a cluster">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_tbl_stats LOOP
    report := report||format(
        jtab_tpl #>> ARRAY['row_tpl'],
        r_result.dbname,
        r_result.tablespacename,
        r_result.schemaname,
        r_result.relname,
        r_result.indexrelname,
        r_result.idx_scan,
        r_result.idx_blks_fetch,
        round(r_result.idx_blks_fetch_pct,2)
    );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: ix_top_io_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.ix_top_io_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.tablespacename,st2.tablespacename) as tablespacename,
        COALESCE(st1.schemaname,st2.schemaname) as schemaname,
        COALESCE(st1.relname,st2.relname) as relname,
        COALESCE(st1.indexrelname,st2.indexrelname) as indexrelname,
        NULLIF(st1.idx_scan, 0) as idx_scan1,
        NULLIF(st1.idx_blks_read, 0) as idx_blks_read1,
        NULLIF(st1.idx_blks_read_pct, 0.0) as idx_blks_read_pct1,
        NULLIF(st1.idx_blks_hit_pct, 0.0) as idx_blks_hit_pct1,
        NULLIF(st2.idx_scan, 0) as idx_scan2,
        NULLIF(st2.idx_blks_read, 0) as idx_blks_read2,
        NULLIF(st2.idx_blks_read_pct, 0.0) as idx_blks_read_pct2,
        NULLIF(st2.idx_blks_hit_pct, 0.0) as idx_blks_hit_pct2,
        row_number() OVER (ORDER BY st1.idx_blks_read DESC NULLS LAST) as rn_read1,
        row_number() OVER (ORDER BY st2.idx_blks_read DESC NULLS LAST) as rn_read2
    FROM
        top_io_indexes1 st1
        FULL OUTER JOIN top_io_indexes2 st2 USING (server_id, datid, relid, indexrelid)
    WHERE COALESCE(st1.idx_blks_read, 0) + COALESCE(st2.idx_blks_read, 0) > 0
    ORDER BY
      COALESCE(st1.idx_blks_read, 0) + COALESCE(st2.idx_blks_read, 0) DESC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.relid,st2.relid) ASC,
      COALESCE(st1.indexrelid,st2.indexrelid) ASC
    ) t1
    WHERE least(
        rn_read1,
        rn_read2
      ) <= topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th>Index</th>'
            '<th>I</th>'
            '<th title="Number of scans performed on index">Scans</th>'
            '<th title="Number of disk blocks read from this index">Blk Reads</th>'
            '<th title="Disk blocks read from this index as a percentage of all blocks read in a cluster">%Total</th>'
            '<th title="Index blocks buffer cache hit percentage">Hits(%)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_tbl_stats LOOP
    report := report||format(
        jtab_tpl #>> ARRAY['row_tpl'],
        r_result.dbname,
        r_result.tablespacename,
        r_result.schemaname,
        r_result.relname,
        r_result.indexrelname,
        r_result.idx_scan1,
        r_result.idx_blks_read1,
        round(r_result.idx_blks_read_pct1,2),
        round(r_result.idx_blks_hit_pct1,2),
        r_result.idx_scan2,
        r_result.idx_blks_read2,
        round(r_result.idx_blks_read_pct2,2),
        round(r_result.idx_blks_hit_pct2,2)
    );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: ix_top_io_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.ix_top_io_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        tablespacename,
        schemaname,
        relname,
        indexrelname,
        NULLIF(idx_scan, 0) as idx_scan,
        NULLIF(idx_blks_read, 0) as idx_blks_read,
        NULLIF(idx_blks_read_pct, 0.0) as idx_blks_read_pct,
        NULLIF(idx_blks_hit_pct, 0.0) as idx_blks_hit_pct
    FROM top_io_indexes
    WHERE idx_blks_read > 0
    ORDER BY
      idx_blks_read DESC,
      datid ASC,
      relid ASC,
      indexrelid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th>Index</th>'
            '<th title="Number of scans performed on index">Scans</th>'
            '<th title="Number of disk blocks read from this index">Blk Reads</th>'
            '<th title="Disk blocks read from this index as a percentage of all blocks read in a cluster">%Total</th>'
            '<th title="Index blocks buffer cache hit percentage">Hits(%)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_tbl_stats LOOP
    report := report||format(
        jtab_tpl #>> ARRAY['row_tpl'],
        r_result.dbname,
        r_result.tablespacename,
        r_result.schemaname,
        r_result.relname,
        r_result.indexrelname,
        r_result.idx_scan,
        r_result.idx_blks_read,
        round(r_result.idx_blks_read_pct,2),
        round(r_result.idx_blks_hit_pct,2)
    );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: ix_unused_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.ix_unused_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    jtab_tpl    jsonb;

    --Cursor for indexes stats
    c_ix_stats CURSOR FOR
    SELECT
        st.dbname,
        st.tablespacename,
        st.schemaname,
        st.relname,
        st.indexrelname,
        pg_size_pretty(NULLIF(st.growth, 0)) as growth,
        pg_size_pretty(NULLIF(st_last.relsize, 0)) as relsize,
        NULLIF(tbl_n_tup_ins, 0) as tbl_n_tup_ins,
        NULLIF(tbl_n_tup_upd - COALESCE(tbl_n_tup_hot_upd,0), 0) as tbl_n_ind_upd,
        NULLIF(tbl_n_tup_del, 0) as tbl_n_tup_del
    FROM top_indexes st
        JOIN v_sample_stat_indexes st_last using (server_id,datid,relid,indexrelid)
    WHERE st_last.sample_id=end_id AND COALESCE(st.idx_scan, 0) = 0 AND NOT st.indisunique
      AND COALESCE(tbl_n_tup_ins, 0) + COALESCE(tbl_n_tup_upd, 0) + COALESCE(tbl_n_tup_del, 0) > 0
    ORDER BY
      COALESCE(tbl_n_tup_ins, 0) + COALESCE(tbl_n_tup_upd, 0) + COALESCE(tbl_n_tup_del, 0) DESC,
      st.datid ASC,
      st.relid ASC,
      st.indexrelid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Tablespaces</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th rowspan="2">Index</th>'
            '<th colspan="2">Index</th>'
            '<th colspan="3">Table</th>'
          '</tr>'
          '<tr>'
            '<th title="Index size, as it was at the moment of last sample in report interval">Size</th>'
            '<th title="Index size increment during report interval">Growth</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (without HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_ix_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.indexrelname,
            r_result.relsize,
            r_result.growth,
            r_result.tbl_n_tup_ins,
            r_result.tbl_n_ind_upd,
            r_result.tbl_n_tup_del
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: jsonb_replace
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.jsonb_replace(dict jsonb, templates jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    res_jsonb           jsonb;
    jsontemplkey        text;
    jsondictkey         text;
BEGIN
    res_jsonb := templates;
    FOR jsontemplkey IN SELECT jsonb_object_keys(res_jsonb) LOOP
      FOR jsondictkey IN SELECT jsonb_object_keys(dict) LOOP
        res_jsonb := jsonb_set(res_jsonb, ARRAY[jsontemplkey],
          to_jsonb(replace(res_jsonb #>> ARRAY[jsontemplkey], '{'||jsondictkey||'}', dict #>> ARRAY[jsondictkey])));
      END LOOP;
    END LOOP;

    RETURN res_jsonb;
END;
$function$;

-- Function: keep_baseline
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.keep_baseline(baseline character varying DEFAULT NULL::character varying, days integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN keep_baseline('local',baseline,days);
END;
$function$;

-- Function: keep_baseline
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.keep_baseline(server name, baseline character varying DEFAULT NULL::character varying, days integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE baselines SET keep_until = now() + (days || ' days')::interval WHERE (baseline IS NULL OR bl_name = baseline) AND server_id IN (SELECT server_id FROM servers WHERE server_name = server);
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$function$;

-- Function: nodata_wrapper
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.nodata_wrapper(section_text text)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    IF section_text IS NULL OR section_text = '' THEN
        RETURN '<p>No data in this section</p>';
    ELSE
        RETURN section_text;
    END IF;
END;
$function$;

-- Function: pg_stat_statements
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.pg_stat_statements(showtext boolean, OUT userid oid, OUT dbid oid, OUT queryid bigint, OUT query text, OUT calls bigint, OUT total_time double precision, OUT min_time double precision, OUT max_time double precision, OUT mean_time double precision, OUT stddev_time double precision, OUT rows bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT blk_read_time double precision, OUT blk_write_time double precision)
 RETURNS SETOF record
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', $function$pg_stat_statements_1_3$function$;

-- Function: pg_stat_statements_reset
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.pg_stat_statements_reset(userid oid DEFAULT 0, dbid oid DEFAULT 0, queryid bigint DEFAULT 0)
 RETURNS void
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', $function$pg_stat_statements_reset_1_7$function$;

-- Function: profile_checkavail_functions
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_functions(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- Check if we have planning times collected for report interval
  SELECT COALESCE(sum(calls), 0) > 0
  FROM sample_stat_user_func_total sn
  WHERE sn.server_id = sserver_id AND sn.sample_id BETWEEN start_id + 1 AND end_id
$function$;

-- Function: profile_checkavail_planning_times
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_planning_times(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- Check if we have planning times collected for report interval
  SELECT COALESCE(sum(total_plan_time), 0) > 0
  FROM sample_statements_total sn
  WHERE sn.server_id = sserver_id AND sn.sample_id BETWEEN start_id + 1 AND end_id
$function$;

-- Function: profile_checkavail_rusage
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_rusage(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT
    count(*) = end_id - start_id
  FROM
    (SELECT
      sum(exec_user_time) > 0 as exec
    FROM sample_kcache_total
    WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY server_id, sample_id) exec_time_samples
  WHERE exec_time_samples.exec
$function$;

-- Function: profile_checkavail_rusage_planstats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_rusage_planstats(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT
    count(*) = end_id - start_id
  FROM
    (SELECT
      sum(plan_user_time) > 0 as plan
    FROM sample_kcache_total
    WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY server_id, sample_id) plan_time_samples
  WHERE plan_time_samples.plan
$function$;

-- Function: profile_checkavail_sessionstats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_sessionstats(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- Check if there is table sizes collected in both bounds
  SELECT
    count(session_time) +
    count(active_time) +
    count(idle_in_transaction_time) +
    count(sessions) +
    count(sessions_abandoned) +
    count(sessions_fatal) +
    count(sessions_killed) > 0
  FROM sample_stat_database
  WHERE
    server_id = sserver_id
    AND sample_id BETWEEN start_id + 1 AND end_id
$function$;

-- Function: profile_checkavail_statstatements
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_statstatements(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- Check if there was available pg_stat_statements statistics for report interval
  SELECT count(sn.sample_id) = count(st.sample_id)
  FROM samples sn LEFT OUTER JOIN sample_statements_total st USING (server_id, sample_id)
  WHERE sn.server_id = sserver_id AND sn.sample_id BETWEEN start_id + 1 AND end_id
$function$;

-- Function: profile_checkavail_stmt_wal_bytes
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_stmt_wal_bytes(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- Check if we have statement wal sizes collected for report interval
  SELECT COALESCE(sum(wal_bytes), 0) > 0
  FROM sample_statements_total sn
  WHERE sn.server_id = sserver_id AND sn.sample_id BETWEEN start_id + 1 AND end_id
$function$;

-- Function: profile_checkavail_tablegrowth
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_tablegrowth(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- Check if there is table sizes collected in both bounds
  SELECT
    count(DISTINCT sample_id) = 2
  FROM sample_stat_tables_total
  WHERE
    server_id = sserver_id
    AND sample_id IN (start_id, end_id)
    AND relsize_diff IS NOT NULL
$function$;

-- Function: profile_checkavail_tablesizes
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_tablesizes(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- Check if there is table sizes collected in ending bound
  SELECT
    count(DISTINCT sample_id) = 1
  FROM sample_stat_tables_total
  WHERE
    server_id = sserver_id
    AND sample_id = end_id
    AND relsize_diff IS NOT NULL
$function$;

-- Function: profile_checkavail_trg_functions
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_trg_functions(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- Check if we have planning times collected for report interval
  SELECT COALESCE(sum(calls), 0) > 0
  FROM sample_stat_user_func_total sn
  WHERE sn.server_id = sserver_id AND sn.sample_id BETWEEN start_id + 1 AND end_id
    AND sn.trg_fn
$function$;

-- Function: profile_checkavail_walstats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.profile_checkavail_walstats(sserver_id integer, start_id integer, end_id integer)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
-- Check if there is table sizes collected in both bounds
  SELECT
    count(wal_bytes) > 0
  FROM sample_stat_wal
  WHERE
    server_id = sserver_id
    AND sample_id BETWEEN start_id + 1 AND end_id
$function$;

-- Function: rename_server
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.rename_server(server name, server_new_name name)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET server_name = server_new_name WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$function$;

-- Function: report_queries
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.report_queries(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer DEFAULT NULL::integer, end2_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    c_queries CURSOR FOR
    SELECT
      left(md5(userid::text || datid::text || queryid::text),10) AS queryid_pgc,
      query,
      row_number() OVER (qid ORDER BY ss.queryid_md5 ASC) AS q_ord,
      count(*) OVER (qid) AS q_cnt
    FROM
      queries_list ql
      JOIN (
          SELECT DISTINCT server_id, datid, userid, queryid, queryid_md5
          FROM sample_statements
          WHERE
            server_id = sserver_id
            AND (
              sample_id BETWEEN start1_id AND end1_id
              OR sample_id BETWEEN start2_id AND end2_id
            )
        ) ss USING (datid, userid, queryid)
      JOIN stmt_list USING (server_id, queryid_md5)
    WINDOW qid AS (PARTITION BY userid, datid, queryid)
    ORDER BY queryid, datid, userid, queryid_md5 ASC;

    qr_result   RECORD;
    report      text := '';
    query_text  text := '';
    jtab_tpl    jsonb;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table class="stmtlist">'
          '<tr>'
            '<th>QueryID</th>'
            '<th>Query Text</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl_first',
        '<tr>'
          '<td class="mono hdr" id="%2$s" rowspan="%1$s">%2$s</td>'
          '<td {mono}>%3$s</td>'
        '</tr>',
      'stmt_tpl_next',
        '<tr>'
          '<td {mono}>%1$s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR qr_result IN c_queries LOOP
        query_text := replace(qr_result.query,'<','&lt;');
        query_text := replace(query_text,'>','&gt;');
        IF qr_result.q_ord = 1 THEN
          report := report||format(
              jtab_tpl #>> ARRAY['stmt_tpl_first'],
              qr_result.q_cnt,
              qr_result.queryid_pgc,
              query_text
          );
        ELSE
          report := report||format(
              jtab_tpl #>> ARRAY['stmt_tpl_next'],
              query_text
          );
        END IF;
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: sample_dbobj_delta
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.sample_dbobj_delta(properties jsonb, sserver_id integer, s_id integer, topn integer, skip_sizes boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    qres    record;
    result  jsonb;
BEGIN

    -- Calculating difference from previous sample and storing it in sample_stat_ tables
    IF (properties #>> '{collect_timings}')::boolean THEN
      result := jsonb_set(properties,'{timings,calculate tables stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;
    -- Stats of user tables
    FOR qres IN
        SELECT
            diff.server_id,
            sample_id,
            diff.datid,
            diff.relid,
            schemaname,
            relname,
            seq_scan,
            seq_tup_read,
            idx_scan,
            idx_tup_fetch,
            n_tup_ins,
            n_tup_upd,
            n_tup_del,
            n_tup_hot_upd,
            n_live_tup,
            n_dead_tup,
            n_mod_since_analyze,
            n_ins_since_vacuum,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze,
            vacuum_count,
            autovacuum_count,
            analyze_count,
            autoanalyze_count,
            heap_blks_read,
            heap_blks_hit,
            idx_blks_read,
            idx_blks_hit,
            toast_blks_read,
            toast_blks_hit,
            tidx_blks_read,
            tidx_blks_hit,
            relsize,
            relsize_diff,
            tablespaceid,
            relkind,
            toastrelid,
            toastschemaname,
            toastrelname,
            toastseq_scan,
            toastseq_tup_read,
            toastidx_scan,
            toastidx_tup_fetch,
            toastn_tup_ins,
            toastn_tup_upd,
            toastn_tup_del,
            toastn_tup_hot_upd,
            toastn_live_tup,
            toastn_dead_tup,
            toastn_mod_since_analyze,
            toastn_ins_since_vacuum,
            toastlast_vacuum,
            toastlast_autovacuum,
            toastlast_analyze,
            toastlast_autoanalyze,
            toastvacuum_count,
            toastautovacuum_count,
            toastanalyze_count,
            toastautoanalyze_count,
            toastheap_blks_read,
            toastheap_blks_hit,
            toastidx_blks_read,
            toastidx_blks_hit,
            toastrelsize,
            toastrelsize_diff,
            toastrelkind
        FROM
            (SELECT
                cur.server_id AS server_id,
                cur.sample_id AS sample_id,
                cur.datid AS datid,
                cur.relid AS relid,
                cur.schemaname AS schemaname,
                cur.relname AS relname,
                cur.seq_scan - COALESCE(lst.seq_scan,0) AS seq_scan,
                cur.seq_tup_read - COALESCE(lst.seq_tup_read,0) AS seq_tup_read,
                cur.idx_scan - COALESCE(lst.idx_scan,0) AS idx_scan,
                cur.idx_tup_fetch - COALESCE(lst.idx_tup_fetch,0) AS idx_tup_fetch,
                cur.n_tup_ins - COALESCE(lst.n_tup_ins,0) AS n_tup_ins,
                cur.n_tup_upd - COALESCE(lst.n_tup_upd,0) AS n_tup_upd,
                cur.n_tup_del - COALESCE(lst.n_tup_del,0) AS n_tup_del,
                cur.n_tup_hot_upd - COALESCE(lst.n_tup_hot_upd,0) AS n_tup_hot_upd,
                cur.n_live_tup AS n_live_tup,
                cur.n_dead_tup AS n_dead_tup,
                cur.n_mod_since_analyze AS n_mod_since_analyze,
                cur.n_ins_since_vacuum AS n_ins_since_vacuum,
                cur.last_vacuum AS last_vacuum,
                cur.last_autovacuum AS last_autovacuum,
                cur.last_analyze AS last_analyze,
                cur.last_autoanalyze AS last_autoanalyze,
                cur.vacuum_count - COALESCE(lst.vacuum_count,0) AS vacuum_count,
                cur.autovacuum_count - COALESCE(lst.autovacuum_count,0) AS autovacuum_count,
                cur.analyze_count - COALESCE(lst.analyze_count,0) AS analyze_count,
                cur.autoanalyze_count - COALESCE(lst.autoanalyze_count,0) AS autoanalyze_count,
                cur.heap_blks_read - COALESCE(lst.heap_blks_read,0) AS heap_blks_read,
                cur.heap_blks_hit - COALESCE(lst.heap_blks_hit,0) AS heap_blks_hit,
                cur.idx_blks_read - COALESCE(lst.idx_blks_read,0) AS idx_blks_read,
                cur.idx_blks_hit - COALESCE(lst.idx_blks_hit,0) AS idx_blks_hit,
                cur.toast_blks_read - COALESCE(lst.toast_blks_read,0) AS toast_blks_read,
                cur.toast_blks_hit - COALESCE(lst.toast_blks_hit,0) AS toast_blks_hit,
                cur.tidx_blks_read - COALESCE(lst.tidx_blks_read,0) AS tidx_blks_read,
                cur.tidx_blks_hit - COALESCE(lst.tidx_blks_hit,0) AS tidx_blks_hit,
                cur.relsize AS relsize,
                cur.relsize - COALESCE(lst.relsize,0) AS relsize_diff,
                cur.tablespaceid AS tablespaceid,
                cur.relkind AS relkind,
                tcur.relid AS toastrelid,
                tcur.schemaname AS toastschemaname,
                tcur.relname AS toastrelname,
                tcur.seq_scan - COALESCE(tlst.seq_scan,0) AS toastseq_scan,
                tcur.seq_tup_read - COALESCE(tlst.seq_tup_read,0) AS toastseq_tup_read,
                tcur.idx_scan - COALESCE(tlst.idx_scan,0) AS toastidx_scan,
                tcur.idx_tup_fetch - COALESCE(tlst.idx_tup_fetch,0) AS toastidx_tup_fetch,
                tcur.n_tup_ins - COALESCE(tlst.n_tup_ins,0) AS toastn_tup_ins,
                tcur.n_tup_upd - COALESCE(tlst.n_tup_upd,0) AS toastn_tup_upd,
                tcur.n_tup_del - COALESCE(tlst.n_tup_del,0) AS toastn_tup_del,
                tcur.n_tup_hot_upd - COALESCE(tlst.n_tup_hot_upd,0) AS toastn_tup_hot_upd,
                tcur.n_live_tup AS toastn_live_tup,
                tcur.n_dead_tup AS toastn_dead_tup,
                tcur.n_mod_since_analyze AS toastn_mod_since_analyze,
                tcur.n_ins_since_vacuum AS toastn_ins_since_vacuum,
                tcur.last_vacuum AS toastlast_vacuum,
                tcur.last_autovacuum AS toastlast_autovacuum,
                tcur.last_analyze AS toastlast_analyze,
                tcur.last_autoanalyze AS toastlast_autoanalyze,
                tcur.vacuum_count - COALESCE(tlst.vacuum_count,0) AS toastvacuum_count,
                tcur.autovacuum_count - COALESCE(tlst.autovacuum_count,0) AS toastautovacuum_count,
                tcur.analyze_count - COALESCE(tlst.analyze_count,0) AS toastanalyze_count,
                tcur.autoanalyze_count - COALESCE(tlst.autoanalyze_count,0) AS toastautoanalyze_count,
                tcur.heap_blks_read - COALESCE(tlst.heap_blks_read,0) AS toastheap_blks_read,
                tcur.heap_blks_hit - COALESCE(tlst.heap_blks_hit,0) AS toastheap_blks_hit,
                tcur.idx_blks_read - COALESCE(tlst.idx_blks_read,0) AS toastidx_blks_read,
                tcur.idx_blks_hit - COALESCE(tlst.idx_blks_hit,0) AS toastidx_blks_hit,
                tcur.relsize AS toastrelsize,
                tcur.relsize - COALESCE(tlst.relsize,0) AS toastrelsize_diff,
                tcur.relkind AS toastrelkind,
                -- Seq. scanned blocks rank
                -- Coalesce is used here in case of skipped size collection
                row_number() OVER (ORDER BY
                  (cur.seq_scan - COALESCE(lst.seq_scan,0)) * COALESCE(cur.relsize,lst.relsize) +
                  (tcur.seq_scan - COALESCE(tlst.seq_scan,0)) * COALESCE(tcur.relsize,tlst.relsize) DESC) scan_rank,
                row_number() OVER (ORDER BY cur.n_tup_ins + cur.n_tup_upd + cur.n_tup_del -
                  COALESCE(lst.n_tup_ins + lst.n_tup_upd + lst.n_tup_del, 0) +
                  COALESCE(tcur.n_tup_ins + tcur.n_tup_upd + tcur.n_tup_del, 0) -
                  COALESCE(tlst.n_tup_ins + tlst.n_tup_upd + tlst.n_tup_del, 0) DESC) dml_rank,
                row_number() OVER (ORDER BY cur.n_tup_upd+cur.n_tup_del -
                  COALESCE(lst.n_tup_upd + lst.n_tup_del, 0) +
                  COALESCE(tcur.n_tup_upd + tcur.n_tup_del, 0) -
                  COALESCE(tlst.n_tup_upd + tlst.n_tup_del, 0) DESC) vacuum_dml_rank,
                row_number() OVER (ORDER BY cur.relsize - COALESCE(lst.relsize, 0) +
                  COALESCE(tcur.relsize,0) - COALESCE(tlst.relsize, 0) DESC) growth_rank,
                row_number() OVER (ORDER BY
                  cur.n_dead_tup / NULLIF(cur.n_live_tup+cur.n_dead_tup, 0)
                  DESC NULLS LAST) dead_pct_rank,
                row_number() OVER (ORDER BY
                  cur.n_mod_since_analyze / NULLIF(cur.n_live_tup, 0)
                  DESC NULLS LAST) mod_pct_rank,
                -- Read rank
                row_number() OVER (ORDER BY
                  cur.heap_blks_read - COALESCE(lst.heap_blks_read,0) +
                  cur.idx_blks_read - COALESCE(lst.idx_blks_read,0) +
                  cur.toast_blks_read - COALESCE(lst.toast_blks_read,0) +
                  cur.tidx_blks_read - COALESCE(lst.tidx_blks_read,0) DESC) read_rank,
                -- Page processing rank
                row_number() OVER (ORDER BY cur.heap_blks_read+cur.heap_blks_hit+cur.idx_blks_read+cur.idx_blks_hit+
                  cur.toast_blks_read+cur.toast_blks_hit+cur.tidx_blks_read+cur.tidx_blks_hit-
                  COALESCE(lst.heap_blks_read+lst.heap_blks_hit+lst.idx_blks_read+lst.idx_blks_hit+
                  lst.toast_blks_read+lst.toast_blks_hit+lst.tidx_blks_read+lst.tidx_blks_hit, 0) DESC) gets_rank,
                -- Vacuum rank
                row_number() OVER (ORDER BY cur.vacuum_count - COALESCE(lst.vacuum_count, 0) +
                  cur.autovacuum_count - COALESCE(lst.autovacuum_count, 0) DESC) vacuum_rank,
                row_number() OVER (ORDER BY cur.analyze_count - COALESCE(lst.analyze_count,0) +
                  cur.autoanalyze_count - COALESCE(lst.autoanalyze_count,0) DESC) analyze_rank
            FROM
              -- main relations diff
              last_stat_tables cur JOIN sample_stat_database dbcur USING (server_id, sample_id, datid)
              LEFT OUTER JOIN sample_stat_database dblst ON
                (dbcur.server_id = dblst.server_id AND dbcur.datid = dblst.datid AND dblst.sample_id = dbcur.sample_id - 1 AND dbcur.stats_reset = dblst.stats_reset)
              LEFT OUTER JOIN last_stat_tables lst ON
                (dblst.server_id=lst.server_id AND lst.sample_id = dblst.sample_id AND lst.datid=dblst.datid AND cur.relid=lst.relid)
              -- toast relations diff
              LEFT OUTER JOIN last_stat_tables tcur ON
                (tcur.server_id=dbcur.server_id AND tcur.sample_id = dbcur.sample_id  AND tcur.datid=dbcur.datid AND cur.reltoastrelid=tcur.relid)
              LEFT OUTER JOIN last_stat_tables tlst ON
                (tlst.server_id=dblst.server_id AND tlst.sample_id = dblst.sample_id AND tlst.datid=dblst.datid AND lst.reltoastrelid=tlst.relid)
            WHERE cur.sample_id=s_id AND cur.server_id=sserver_id
              AND cur.relkind IN ('r','m')) diff
          /* We must include in sample all tables mentioned in
           * samples, taken since previous sample with sizes
           * as we need next size point for them to use in
           * interpolation
           */
          LEFT OUTER JOIN (
            SELECT DISTINCT
              server_id,
              datid,
              relid
            FROM sample_stat_tables
            WHERE
              server_id = sserver_id
              AND sample_id > (
                SELECT max(sample_id)
                FROM sample_stat_tables_total
                WHERE server_id = sserver_id
                  AND relsize_diff IS NOT NULL
              )
          ) track_size ON ((track_size.server_id, track_size.datid, track_size.relid) =
            (diff.server_id, diff.datid, diff.relid) AND diff.relsize IS NOT NULL)
        WHERE
          track_size.relid IS NOT NULL OR
          least(
            scan_rank,
            dml_rank,
            growth_rank,
            dead_pct_rank,
            mod_pct_rank,
            vacuum_dml_rank,
            read_rank,
            gets_rank,
            vacuum_rank,
            analyze_rank
          ) <= topn
    LOOP
        IF qres.toastrelid IS NOT NULL THEN
          INSERT INTO tables_list(
            server_id,
            datid,
            relid,
            relkind,
            reltoastrelid,
            schemaname,
            relname
          )
          VALUES (qres.server_id,qres.datid,qres.toastrelid,qres.toastrelkind,NULL,qres.toastschemaname,qres.toastrelname) ON CONFLICT DO NOTHING;
          INSERT INTO sample_stat_tables(
            server_id,
            sample_id,
            datid,
            relid,
            tablespaceid,
            seq_scan,
            seq_tup_read,
            idx_scan,
            idx_tup_fetch,
            n_tup_ins,
            n_tup_upd,
            n_tup_del,
            n_tup_hot_upd,
            n_live_tup,
            n_dead_tup,
            n_mod_since_analyze,
            n_ins_since_vacuum,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze,
            vacuum_count,
            autovacuum_count,
            analyze_count,
            autoanalyze_count,
            heap_blks_read,
            heap_blks_hit,
            idx_blks_read,
            idx_blks_hit,
            toast_blks_read,
            toast_blks_hit,
            tidx_blks_read,
            tidx_blks_hit,
            relsize,
            relsize_diff
          )
          VALUES (
              qres.server_id,
              qres.sample_id,
              qres.datid,
              qres.toastrelid,
              qres.tablespaceid,
              qres.toastseq_scan,
              qres.toastseq_tup_read,
              qres.toastidx_scan,
              qres.toastidx_tup_fetch,
              qres.toastn_tup_ins,
              qres.toastn_tup_upd,
              qres.toastn_tup_del,
              qres.toastn_tup_hot_upd,
              qres.toastn_live_tup,
              qres.toastn_dead_tup,
              qres.toastn_mod_since_analyze,
              qres.toastn_ins_since_vacuum,
              qres.toastlast_vacuum,
              qres.toastlast_autovacuum,
              qres.toastlast_analyze,
              qres.toastlast_autoanalyze,
              qres.toastvacuum_count,
              qres.toastautovacuum_count,
              qres.toastanalyze_count,
              qres.toastautoanalyze_count,
              qres.toastheap_blks_read,
              qres.toastheap_blks_hit,
              qres.toastidx_blks_read,
              qres.toastidx_blks_hit,
              0,
              0,
              0,
              0,
              qres.toastrelsize,
              qres.toastrelsize_diff
          );
        END IF;

        INSERT INTO tables_list(
            server_id,
            datid,
            relid,
            relkind,
            reltoastrelid,
            schemaname,
            relname
          )
        VALUES (qres.server_id,qres.datid,qres.relid,qres.relkind,NULLIF(qres.toastrelid,0),qres.schemaname,qres.relname)
          ON CONFLICT DO NOTHING;
        INSERT INTO sample_stat_tables(
            server_id,
            sample_id,
            datid,
            relid,
            tablespaceid,
            seq_scan,
            seq_tup_read,
            idx_scan,
            idx_tup_fetch,
            n_tup_ins,
            n_tup_upd,
            n_tup_del,
            n_tup_hot_upd,
            n_live_tup,
            n_dead_tup,
            n_mod_since_analyze,
            n_ins_since_vacuum,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze,
            vacuum_count,
            autovacuum_count,
            analyze_count,
            autoanalyze_count,
            heap_blks_read,
            heap_blks_hit,
            idx_blks_read,
            idx_blks_hit,
            toast_blks_read,
            toast_blks_hit,
            tidx_blks_read,
            tidx_blks_hit,
            relsize,
            relsize_diff
          )
          VALUES (
            qres.server_id,
            qres.sample_id,
            qres.datid,
            qres.relid,
            qres.tablespaceid,
            qres.seq_scan,
            qres.seq_tup_read,
            qres.idx_scan,
            qres.idx_tup_fetch,
            qres.n_tup_ins,
            qres.n_tup_upd,
            qres.n_tup_del,
            qres.n_tup_hot_upd,
            qres.n_live_tup,
            qres.n_dead_tup,
            qres.n_mod_since_analyze,
            qres.n_ins_since_vacuum,
            qres.last_vacuum,
            qres.last_autovacuum,
            qres.last_analyze,
            qres.last_autoanalyze,
            qres.vacuum_count,
            qres.autovacuum_count,
            qres.analyze_count,
            qres.autoanalyze_count,
            qres.heap_blks_read,
            qres.heap_blks_hit,
            qres.idx_blks_read,
            qres.idx_blks_hit,
            qres.toast_blks_read,
            qres.toast_blks_hit,
            qres.tidx_blks_read,
            qres.tidx_blks_hit,
            qres.relsize,
            qres.relsize_diff
        );
    END LOOP;

    -- Total table stats
    INSERT INTO sample_stat_tables_total(
      server_id,
      sample_id,
      datid,
      tablespaceid,
      relkind,
      seq_scan,
      seq_tup_read,
      idx_scan,
      idx_tup_fetch,
      n_tup_ins,
      n_tup_upd,
      n_tup_del,
      n_tup_hot_upd,
      vacuum_count,
      autovacuum_count,
      analyze_count,
      autoanalyze_count,
      heap_blks_read,
      heap_blks_hit,
      idx_blks_read,
      idx_blks_hit,
      toast_blks_read,
      toast_blks_hit,
      tidx_blks_read,
      tidx_blks_hit,
      relsize_diff
    )
    SELECT
      cur.server_id,
      cur.sample_id,
      cur.datid,
      cur.tablespaceid,
      cur.relkind,
      sum(cur.seq_scan - COALESCE(lst.seq_scan,0)),
      sum(cur.seq_tup_read - COALESCE(lst.seq_tup_read,0)),
      sum(cur.idx_scan - COALESCE(lst.idx_scan,0)),
      sum(cur.idx_tup_fetch - COALESCE(lst.idx_tup_fetch,0)),
      sum(cur.n_tup_ins - COALESCE(lst.n_tup_ins,0)),
      sum(cur.n_tup_upd - COALESCE(lst.n_tup_upd,0)),
      sum(cur.n_tup_del - COALESCE(lst.n_tup_del,0)),
      sum(cur.n_tup_hot_upd - COALESCE(lst.n_tup_hot_upd,0)),
      sum(cur.vacuum_count - COALESCE(lst.vacuum_count,0)),
      sum(cur.autovacuum_count - COALESCE(lst.autovacuum_count,0)),
      sum(cur.analyze_count - COALESCE(lst.analyze_count,0)),
      sum(cur.autoanalyze_count - COALESCE(lst.autoanalyze_count,0)),
      sum(cur.heap_blks_read - COALESCE(lst.heap_blks_read,0)),
      sum(cur.heap_blks_hit - COALESCE(lst.heap_blks_hit,0)),
      sum(cur.idx_blks_read - COALESCE(lst.idx_blks_read,0)),
      sum(cur.idx_blks_hit - COALESCE(lst.idx_blks_hit,0)),
      sum(cur.toast_blks_read - COALESCE(lst.toast_blks_read,0)),
      sum(cur.toast_blks_hit - COALESCE(lst.toast_blks_hit,0)),
      sum(cur.tidx_blks_read - COALESCE(lst.tidx_blks_read,0)),
      sum(cur.tidx_blks_hit - COALESCE(lst.tidx_blks_hit,0)),
      CASE
        WHEN skip_sizes THEN NULL
        ELSE sum(cur.relsize - COALESCE(lst.relsize,0))
      END
    FROM last_stat_tables cur JOIN sample_stat_database dbcur USING (server_id, sample_id, datid)
      LEFT OUTER JOIN sample_stat_database dblst ON
        (dbcur.server_id = dblst.server_id AND dbcur.datid = dblst.datid AND dblst.sample_id = dbcur.sample_id - 1 AND dbcur.stats_reset = dblst.stats_reset)
      LEFT OUTER JOIN last_stat_tables lst ON
        (dblst.server_id=lst.server_id AND lst.sample_id = dblst.sample_id AND lst.datid=dblst.datid AND cur.relid=lst.relid AND cur.tablespaceid=lst.tablespaceid)
    WHERE cur.sample_id = s_id AND cur.server_id = sserver_id
    GROUP BY cur.server_id, cur.sample_id, cur.datid, cur.relkind, cur.tablespaceid;

    IF (result #>> '{collect_timings}')::boolean THEN
      result := jsonb_set(result,'{timings,calculate tables stats,end}',to_jsonb(clock_timestamp()));
      result := jsonb_set(result,'{timings,calculate indexes stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Index stats
    FOR qres IN
        SELECT
            diff.server_id,
            sample_id,
            diff.datid,
            relid,
            diff.indexrelid,
            tablespaceid,
            schemaname,
            relname,
            indexrelname,
            idx_scan,
            idx_tup_read,
            idx_tup_fetch,
            idx_blks_read,
            idx_blks_hit,
            relsize,
            relsize_diff,
            indisunique,
            relkind,
            reltoastrelid,
            reltablespaceid,
            mrelid,
            mrelkind,
            mreltoastrelid,
            mschemaname,
            mrelname,
            trelid,
            trelkind,
            treltoastrelid,
            tschemaname,
            trelname,
            tbl_seq_scan,
            tbl_seq_tup_read,
            tbl_idx_scan,
            tbl_idx_tup_fetch,
            tbl_n_tup_ins,
            tbl_n_tup_upd,
            tbl_n_tup_del,
            tbl_n_tup_hot_upd,
            tbl_n_live_tup,
            tbl_n_dead_tup,
            tbl_n_mod_since_analyze,
            tbl_n_ins_since_vacuum,
            tbl_last_vacuum,
            tbl_last_autovacuum,
            tbl_last_analyze,
            tbl_last_autoanalyze,
            tbl_vacuum_count,
            tbl_autovacuum_count,
            tbl_analyze_count,
            tbl_autoanalyze_count,
            tbl_heap_blks_read,
            tbl_heap_blks_hit,
            tbl_idx_blks_read,
            tbl_idx_blks_hit,
            tbl_toast_blks_read,
            tbl_toast_blks_hit,
            tbl_tidx_blks_read,
            tbl_tidx_blks_hit,
            tbl_relsize,
            tbl_relsize_diff
        FROM
            (SELECT
                cur.server_id,
                cur.sample_id,
                cur.datid,
                cur.relid,
                cur.indexrelid,
                cur.tablespaceid,
                cur.schemaname,
                cur.relname,
                cur.indexrelname,
                cur.idx_scan - COALESCE(lst.idx_scan,0) AS idx_scan,
                cur.idx_tup_read - COALESCE(lst.idx_tup_read,0) AS idx_tup_read,
                cur.idx_tup_fetch - COALESCE(lst.idx_tup_fetch,0) AS idx_tup_fetch,
                cur.idx_blks_read - COALESCE(lst.idx_blks_read,0) AS idx_blks_read,
                cur.idx_blks_hit - COALESCE(lst.idx_blks_hit,0) AS idx_blks_hit,
                cur.relsize,
                cur.relsize - COALESCE(lst.relsize,0) AS relsize_diff,
                cur.indisunique,
                tblcur.relkind AS relkind,
                tblcur.reltoastrelid AS reltoastrelid,
                tblcur.tablespaceid AS reltablespaceid,
                mtbl.relid AS mrelid,
                mtbl.relkind AS mrelkind,
                mtbl.reltoastrelid AS mreltoastrelid,
                mtbl.schemaname AS mschemaname,
                mtbl.relname AS mrelname,
                ttbl.relid AS trelid,
                ttbl.relkind AS trelkind,
                ttbl.reltoastrelid AS treltoastrelid,
                ttbl.schemaname AS tschemaname,
                ttbl.relname AS trelname,
                -- Underlying table stats
                tblcur.seq_scan - COALESCE(tbllst.seq_scan,0) AS tbl_seq_scan,
                tblcur.seq_tup_read - COALESCE(tbllst.seq_tup_read,0) AS tbl_seq_tup_read,
                tblcur.idx_scan - COALESCE(tbllst.idx_scan,0) AS tbl_idx_scan,
                tblcur.idx_tup_fetch - COALESCE(tbllst.idx_tup_fetch,0) AS tbl_idx_tup_fetch,
                tblcur.n_tup_ins - COALESCE(tbllst.n_tup_ins,0) AS tbl_n_tup_ins,
                tblcur.n_tup_upd - COALESCE(tbllst.n_tup_upd,0) AS tbl_n_tup_upd,
                tblcur.n_tup_del - COALESCE(tbllst.n_tup_del,0) AS tbl_n_tup_del,
                tblcur.n_tup_hot_upd - COALESCE(tbllst.n_tup_hot_upd,0) AS tbl_n_tup_hot_upd,
                tblcur.n_live_tup AS tbl_n_live_tup,
                tblcur.n_dead_tup AS tbl_n_dead_tup,
                tblcur.n_mod_since_analyze AS tbl_n_mod_since_analyze,
                tblcur.n_ins_since_vacuum as tbl_n_ins_since_vacuum,
                tblcur.last_vacuum AS tbl_last_vacuum,
                tblcur.last_autovacuum AS tbl_last_autovacuum,
                tblcur.last_analyze AS tbl_last_analyze,
                tblcur.last_autoanalyze AS tbl_last_autoanalyze,
                tblcur.vacuum_count - COALESCE(tbllst.vacuum_count,0) AS tbl_vacuum_count,
                tblcur.autovacuum_count - COALESCE(tbllst.autovacuum_count,0) AS tbl_autovacuum_count,
                tblcur.analyze_count - COALESCE(tbllst.analyze_count,0) AS tbl_analyze_count,
                tblcur.autoanalyze_count - COALESCE(tbllst.autoanalyze_count,0) AS tbl_autoanalyze_count,
                tblcur.heap_blks_read - COALESCE(tbllst.heap_blks_read,0) AS tbl_heap_blks_read,
                tblcur.heap_blks_hit - COALESCE(tbllst.heap_blks_hit,0) AS tbl_heap_blks_hit,
                tblcur.idx_blks_read - COALESCE(tbllst.idx_blks_read,0) AS tbl_idx_blks_read,
                tblcur.idx_blks_hit - COALESCE(tbllst.idx_blks_hit,0) AS tbl_idx_blks_hit,
                tblcur.toast_blks_read - COALESCE(tbllst.toast_blks_read,0) AS tbl_toast_blks_read,
                tblcur.toast_blks_hit - COALESCE(tbllst.toast_blks_hit,0) AS tbl_toast_blks_hit,
                tblcur.tidx_blks_read - COALESCE(tbllst.tidx_blks_read,0) AS tbl_tidx_blks_read,
                tblcur.tidx_blks_hit - COALESCE(tbllst.tidx_blks_hit,0) AS tbl_tidx_blks_hit,
                tblcur.relsize AS tbl_relsize,
                tblcur.relsize - COALESCE(tbllst.relsize,0) AS tbl_relsize_diff,
                -- Index ranks
                row_number() OVER (ORDER BY cur.relsize - COALESCE(lst.relsize,0) DESC) grow_rank,
                row_number() OVER (ORDER BY cur.idx_blks_read - COALESCE(lst.idx_blks_read,0) DESC) read_rank,
                row_number() OVER (ORDER BY cur.idx_blks_read+cur.idx_blks_hit-
                  COALESCE(lst.idx_blks_read+lst.idx_blks_hit,0) DESC) gets_rank,
                row_number() OVER (PARTITION BY cur.idx_scan - COALESCE(lst.idx_scan,0) = 0
                  ORDER BY tblcur.n_tup_ins - COALESCE(tbllst.n_tup_ins,0) +
                  tblcur.n_tup_upd - COALESCE(tbllst.n_tup_upd,0) +
                  tblcur.n_tup_del - COALESCE(tbllst.n_tup_del,0) DESC) dml_unused_rank,
                row_number() OVER (ORDER BY (tblcur.vacuum_count - COALESCE(tbllst.vacuum_count,0) +
                  tblcur.autovacuum_count - COALESCE(tbllst.autovacuum_count,0)) *
                    -- Coalesce is used here in case of skipped size collection
                    COALESCE(cur.relsize,lst.relsize) DESC) vacuum_bytes_rank
            FROM last_stat_indexes cur JOIN last_stat_tables tblcur USING (server_id, sample_id, datid, relid)
              JOIN sample_stat_database dbcur USING (server_id, sample_id, datid)
              LEFT OUTER JOIN sample_stat_database dblst ON
                (dbcur.server_id = dblst.server_id AND dbcur.datid = dblst.datid AND dblst.sample_id = dbcur.sample_id - 1 AND dbcur.stats_reset = dblst.stats_reset)
              LEFT OUTER JOIN last_stat_indexes lst ON
                (dblst.server_id = lst.server_id AND lst.sample_id=dblst.sample_id AND dblst.datid = lst.datid AND cur.relid = lst.relid AND cur.indexrelid = lst.indexrelid)
              LEFT OUTER JOIN last_stat_tables tbllst ON
                (tbllst.server_id = dblst.server_id AND tbllst.sample_id = dblst.sample_id AND tbllst.datid = dblst.datid AND tbllst.relid = lst.relid)
              -- Join main table if index is toast index
              LEFT OUTER JOIN last_stat_tables mtbl ON (tblcur.relkind = 't' AND mtbl.server_id = dbcur.server_id AND mtbl.sample_id = dbcur.sample_id
                AND mtbl.datid = dbcur.datid AND mtbl.reltoastrelid = tblcur.relid)
              -- Join toast table if exists
              LEFT OUTER JOIN last_stat_tables ttbl ON (ttbl.relkind = 't' AND ttbl.server_id = dbcur.server_id AND ttbl.sample_id = dbcur.sample_id
                AND ttbl.datid = dbcur.datid AND tblcur.reltoastrelid = ttbl.relid)
            WHERE cur.sample_id = s_id AND cur.server_id = sserver_id) diff
          /* We must include in sample all indexes mentioned in
           * samples, taken since previous sample with sizes
           * as we need next size point for them to use in
           * interpolation
           */
          LEFT OUTER JOIN (
            SELECT DISTINCT
              server_id,
              datid,
              indexrelid
            FROM sample_stat_indexes
            WHERE
              server_id = sserver_id
              AND sample_id > (
                SELECT max(sample_id)
                FROM sample_stat_indexes_total
                WHERE server_id = sserver_id
                  AND relsize_diff IS NOT NULL
              )
          ) track_size ON ((track_size.server_id, track_size.datid, track_size.indexrelid) =
            (diff.server_id, diff.datid, diff.indexrelid) AND diff.relsize IS NOT NULL)
        WHERE
          track_size.indexrelid IS NOT NULL OR
          least(
            grow_rank,
            read_rank,
            gets_rank,
            vacuum_bytes_rank
          ) <= topn
          OR (dml_unused_rank <= topn AND idx_scan = 0)
    LOOP
        -- Insert TOAST table (if exists) in tables list before parent table
        IF qres.trelid IS NOT NULL THEN
          INSERT INTO tables_list(
            server_id,
            datid,
            relid,
            relkind,
            reltoastrelid,
            schemaname,
            relname
          )
          VALUES (qres.server_id,qres.datid,qres.trelid,qres.trelkind,NULLIF(qres.treltoastrelid,0),qres.tschemaname,qres.trelname) ON CONFLICT DO NOTHING;
        END IF;
        -- Insert index parent table in tables list
        INSERT INTO tables_list(
            server_id,
            datid,
            relid,
            relkind,
            reltoastrelid,
            schemaname,
            relname
          )
          VALUES (qres.server_id,qres.datid,qres.relid,qres.relkind,NULLIF(qres.reltoastrelid,0),qres.schemaname,qres.relname) ON CONFLICT DO NOTHING;
        -- Insert main table (if index is on toast table)
        IF qres.mrelid IS NOT NULL THEN
          INSERT INTO tables_list(
            server_id,
            datid,
            relid,
            relkind,
            reltoastrelid,
            schemaname,
            relname
          )
          VALUES (qres.server_id,qres.datid,qres.mrelid,qres.mrelkind,NULLIF(qres.mreltoastrelid,0),qres.mschemaname,qres.mrelname) ON CONFLICT DO NOTHING;
        END IF;
        -- insert index to index list
        INSERT INTO indexes_list(
          server_id,
          datid,
          indexrelid,
          relid,
          schemaname,
          indexrelname
        )
        VALUES (qres.server_id,qres.datid,qres.indexrelid,qres.relid,qres.schemaname,qres.indexrelname) ON CONFLICT DO NOTHING;
        -- insert index stats
        INSERT INTO sample_stat_indexes(
          server_id,
          sample_id,
          datid,
          indexrelid,
          tablespaceid,
          idx_scan,
          idx_tup_read,
          idx_tup_fetch,
          idx_blks_read,
          idx_blks_hit,
          relsize,
          relsize_diff,
          indisunique
        )
        VALUES (
            qres.server_id,
            qres.sample_id,
            qres.datid,
            qres.indexrelid,
            qres.tablespaceid,
            qres.idx_scan,
            qres.idx_tup_read,
            qres.idx_tup_fetch,
            qres.idx_blks_read,
            qres.idx_blks_hit,
            qres.relsize,
            qres.relsize_diff,
            qres.indisunique
        );
        -- insert underlying table stats
        INSERT INTO sample_stat_tables(
          server_id,
          sample_id,
          datid,
          relid,
          tablespaceid,
          seq_scan,
          seq_tup_read,
          idx_scan,
          idx_tup_fetch,
          n_tup_ins,
          n_tup_upd,
          n_tup_del,
          n_tup_hot_upd,
          n_live_tup,
          n_dead_tup,
          n_mod_since_analyze,
          n_ins_since_vacuum,
          last_vacuum,
          last_autovacuum,
          last_analyze,
          last_autoanalyze,
          vacuum_count,
          autovacuum_count,
          analyze_count,
          autoanalyze_count,
          heap_blks_read,
          heap_blks_hit,
          idx_blks_read,
          idx_blks_hit,
          toast_blks_read,
          toast_blks_hit,
          tidx_blks_read,
          tidx_blks_hit,
          relsize,
          relsize_diff
        )
        VALUES (
            qres.server_id,
            qres.sample_id,
            qres.datid,
            qres.relid,
            qres.reltablespaceid,
            qres.tbl_seq_scan,
            qres.tbl_seq_tup_read,
            qres.tbl_idx_scan,
            qres.tbl_idx_tup_fetch,
            qres.tbl_n_tup_ins,
            qres.tbl_n_tup_upd,
            qres.tbl_n_tup_del,
            qres.tbl_n_tup_hot_upd,
            qres.tbl_n_live_tup,
            qres.tbl_n_dead_tup,
            qres.tbl_n_mod_since_analyze,
            qres.tbl_n_ins_since_vacuum,
            qres.tbl_last_vacuum,
            qres.tbl_last_autovacuum,
            qres.tbl_last_analyze,
            qres.tbl_last_autoanalyze,
            qres.tbl_vacuum_count,
            qres.tbl_autovacuum_count,
            qres.tbl_analyze_count,
            qres.tbl_autoanalyze_count,
            qres.tbl_heap_blks_read,
            qres.tbl_heap_blks_hit,
            qres.tbl_idx_blks_read,
            qres.tbl_idx_blks_hit,
            qres.tbl_toast_blks_read,
            qres.tbl_toast_blks_hit,
            qres.tbl_tidx_blks_read,
            qres.tbl_tidx_blks_hit,
            qres.tbl_relsize,
            qres.tbl_relsize_diff
        ) ON CONFLICT DO NOTHING;
    END LOOP;

    -- Total indexes stats
    INSERT INTO sample_stat_indexes_total(
      server_id,
      sample_id,
      datid,
      tablespaceid,
      idx_scan,
      idx_tup_read,
      idx_tup_fetch,
      idx_blks_read,
      idx_blks_hit,
      relsize_diff
    )
    SELECT
      cur.server_id,
      cur.sample_id,
      cur.datid,
      cur.tablespaceid,
      sum(cur.idx_scan - COALESCE(lst.idx_scan,0)),
      sum(cur.idx_tup_read - COALESCE(lst.idx_tup_read,0)),
      sum(cur.idx_tup_fetch - COALESCE(lst.idx_tup_fetch,0)),
      sum(cur.idx_blks_read - COALESCE(lst.idx_blks_read,0)),
      sum(cur.idx_blks_hit - COALESCE(lst.idx_blks_hit,0)),
      CASE
        WHEN skip_sizes THEN NULL
        ELSE sum(cur.relsize - COALESCE(lst.relsize,0))
      END
    FROM last_stat_indexes cur JOIN sample_stat_database dbcur USING (server_id, sample_id, datid)
      LEFT OUTER JOIN sample_stat_database dblst ON
        (dbcur.server_id = dblst.server_id AND dbcur.datid = dblst.datid AND dblst.sample_id = dbcur.sample_id - 1 AND dbcur.stats_reset = dblst.stats_reset)
      LEFT OUTER JOIN last_stat_indexes lst
        ON (lst.server_id = dblst.server_id AND lst.sample_id = dblst.sample_id AND lst.datid = dblst.datid AND lst.relid = cur.relid AND lst.indexrelid = cur.indexrelid AND cur.tablespaceid=lst.tablespaceid)
    WHERE cur.sample_id = s_id AND cur.server_id = sserver_id
    GROUP BY cur.server_id, cur.sample_id, cur.datid,cur.tablespaceid;

    IF (result #>> '{collect_timings}')::boolean THEN
      result := jsonb_set(result,'{timings,calculate indexes stats,end}',to_jsonb(clock_timestamp()));
      result := jsonb_set(result,'{timings,calculate functions stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- User functions stats
    FOR qres IN
        SELECT
            server_id,
            sample_id,
            datid,
            funcid,
            schemaname,
            funcname,
            funcargs,
            calls,
            total_time,
            self_time,
            trg_fn
        FROM
            (SELECT
                cur.server_id,
                cur.sample_id,
                cur.datid,
                cur.funcid,
                cur.schemaname,
                cur.funcname,
                cur.funcargs,
                cur.calls - COALESCE(lst.calls,0) AS calls,
                cur.total_time - COALESCE(lst.total_time,0) AS total_time,
                cur.self_time - COALESCE(lst.self_time,0) AS self_time,
                cur.trg_fn,
                row_number() OVER (PARTITION BY cur.trg_fn ORDER BY cur.total_time - COALESCE(lst.total_time,0) DESC) time_rank,
                row_number() OVER (PARTITION BY cur.trg_fn ORDER BY cur.self_time - COALESCE(lst.self_time,0) DESC) stime_rank,
                row_number() OVER (PARTITION BY cur.trg_fn ORDER BY cur.calls - COALESCE(lst.calls,0) DESC) calls_rank
            FROM last_stat_user_functions cur JOIN sample_stat_database dbcur USING (server_id, sample_id, datid)
              LEFT OUTER JOIN sample_stat_database dblst ON
                (dbcur.server_id = dblst.server_id AND dbcur.datid = dblst.datid AND dblst.sample_id = dbcur.sample_id - 1 AND dbcur.stats_reset = dblst.stats_reset)
              LEFT OUTER JOIN last_stat_user_functions lst ON
                (lst.server_id = dblst.server_id AND lst.sample_id = dblst.sample_id AND lst.datid = dblst.datid AND cur.funcid=lst.funcid)
            WHERE cur.sample_id = s_id AND cur.server_id = sserver_id
                AND cur.calls - COALESCE(lst.calls,0) > 0) diff
        WHERE
          least(
            time_rank,
            calls_rank,
            stime_rank
          ) <= topn
    LOOP
        INSERT INTO funcs_list(
          server_id,
          datid,
          funcid,
          schemaname,
          funcname,
          funcargs
        )
        VALUES (qres.server_id,qres.datid,qres.funcid,qres.schemaname,qres.funcname,qres.funcargs) ON CONFLICT DO NOTHING;
        INSERT INTO sample_stat_user_functions(
          server_id,
          sample_id,
          datid,
          funcid,
          calls,
          total_time,
          self_time,
          trg_fn
        )
        VALUES (
            qres.server_id,
            qres.sample_id,
            qres.datid,
            qres.funcid,
            qres.calls,
            qres.total_time,
            qres.self_time,
            qres.trg_fn
        );
    END LOOP;

    -- Total functions stats
    INSERT INTO sample_stat_user_func_total(
      server_id,
      sample_id,
      datid,
      calls,
      total_time,
      trg_fn
    )
    SELECT
      cur.server_id,
      cur.sample_id,
      cur.datid,
      sum(cur.calls - COALESCE(lst.calls,0)),
      sum(cur.total_time - COALESCE(lst.total_time,0)),
      cur.trg_fn
    FROM last_stat_user_functions cur JOIN sample_stat_database dbcur USING (server_id, sample_id, datid)
      LEFT OUTER JOIN sample_stat_database dblst ON
        (dbcur.server_id = dblst.server_id AND dbcur.datid = dblst.datid AND dblst.sample_id = dbcur.sample_id - 1 AND dbcur.stats_reset = dblst.stats_reset)
      LEFT OUTER JOIN last_stat_user_functions lst ON
        (lst.server_id = dblst.server_id AND lst.sample_id = dblst.sample_id AND lst.datid = dblst.datid AND cur.funcid=lst.funcid)
    WHERE cur.sample_id = s_id AND cur.server_id = sserver_id
    GROUP BY cur.server_id, cur.sample_id, cur.datid, cur.trg_fn;

    IF (result #>> '{collect_timings}')::boolean THEN
      result := jsonb_set(result,'{timings,calculate functions stats,end}',to_jsonb(clock_timestamp()));
    END IF;

    /*
    Save sizes collection failures due to locks on relations*/
    IF NOT skip_sizes THEN
      INSERT INTO sample_stat_tables_failures (
        server_id,
        sample_id,
        datid,
        relid,
        size_failed,
        toastsize_failed
        )
      SELECT
        t.server_id,
        t.sample_id,
        t.datid,
        t.relid,
        lt.relsize IS NULL,
        ltt.relid IS NOT NULL AND ltt.relsize IS NULL
      FROM
        sample_stat_tables t
        JOIN last_stat_tables lt USING (server_id,sample_id,datid,relid)
        JOIN tables_list tlist USING (server_id,datid,relid)
        LEFT OUTER JOIN last_stat_tables ltt
          ON (t.server_id, t.sample_id, t.datid, tlist.reltoastrelid) =
            (ltt.server_id, ltt.sample_id, ltt.datid, ltt.relid)
      WHERE t.server_id = sserver_id AND t.sample_id = s_id AND
        (lt.relsize IS NULL OR (ltt.relid IS NOT NULL AND ltt.relsize IS NULL));

      INSERT INTO sample_stat_indexes_failures (
        server_id,
        sample_id,
        datid,
        indexrelid,
        size_failed
        )
      SELECT
        server_id,
        sample_id,
        datid,
        indexrelid,
        li.relsize IS NULL
      FROM
        sample_stat_indexes i
        JOIN last_stat_indexes li USING (server_id,sample_id,datid,indexrelid)
      WHERE server_id = sserver_id AND sample_id = s_id AND li.relsize IS NULL;
    END IF;

    /*
    Preserve previous relation sizes in last_* tables if we couldn't collect
    size this time (for example, due to locked relation)*/
    -- Tables
    UPDATE last_stat_tables cur
    SET relsize = lst.relsize
    FROM last_stat_tables lst
    WHERE
      cur.server_id = sserver_id AND lst.server_id = cur.server_id AND
      cur.sample_id = s_id AND lst.sample_id = cur.sample_id - 1 AND
      cur.datid = lst.datid AND cur.relid = lst.relid AND
      cur.relsize IS NULL;
    -- Indexes
    UPDATE last_stat_indexes cur
    SET relsize = lst.relsize
    FROM last_stat_indexes lst
    WHERE
      cur.server_id = sserver_id AND lst.server_id = cur.server_id AND
      cur.sample_id = s_id AND lst.sample_id = cur.sample_id - 1 AND
      cur.datid = lst.datid AND cur.relid = lst.relid AND
      cur.indexrelid = lst.indexrelid AND
      cur.relsize IS NULL;

    -- Clear data in last_ tables, holding data only for next diff sample
    DELETE FROM last_stat_tables WHERE server_id=sserver_id AND sample_id != s_id;

    DELETE FROM last_stat_indexes WHERE server_id=sserver_id AND sample_id != s_id;

    DELETE FROM last_stat_user_functions WHERE server_id=sserver_id AND sample_id != s_id;

    RETURN result;
END;
$function$;

-- Function: set_limit
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.set_limit(real)
 RETURNS real
 LANGUAGE c
 STRICT
AS '$libdir/pg_trgm', $function$set_limit$function$;

-- Function: set_server_connstr
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.set_server_connstr(server name, server_connstr text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET connstr = server_connstr WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$function$;

-- Function: set_server_db_exclude
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.set_server_db_exclude(server name, exclude_db name[])
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET db_exclude = exclude_db WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$function$;

-- Function: set_server_description
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.set_server_description(server name, description text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET server_description = description WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$function$;

-- Function: set_server_max_sample_age
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.set_server_max_sample_age(server name, max_sample_age integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET max_sample_age = set_server_max_sample_age.max_sample_age WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$function$;

-- Function: set_server_size_sampling
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.set_server_size_sampling(server name, window_start time with time zone DEFAULT NULL::time with time zone, window_duration interval DEFAULT NULL::interval, sample_interval interval DEFAULT NULL::interval, limited_sizes_collection boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers
    SET
      (size_smp_wnd_start, size_smp_wnd_dur, size_smp_interval, sizes_limited) =
      (window_start, window_duration, sample_interval, limited_sizes_collection)
    WHERE
      server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$function$;

-- Function: settings_and_changes
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.settings_and_changes(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(first_seen timestamp with time zone, setting_scope smallint, name text, setting text, reset_val text, boot_val text, unit text, sourcefile text, sourceline integer, pending_restart boolean, changed boolean, default_val boolean)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT
    first_seen,
    setting_scope,
    name,
    setting,
    reset_val,
    boot_val,
    unit,
    sourcefile,
    sourceline,
    pending_restart,
    false,
    COALESCE(boot_val = reset_val, false)
  FROM v_sample_settings
  WHERE server_id = sserver_id AND sample_id = start_id
  UNION ALL
  SELECT
    first_seen,
    setting_scope,
    name,
    setting,
    reset_val,
    boot_val,
    unit,
    sourcefile,
    sourceline,
    pending_restart,
    true,
    COALESCE(boot_val = reset_val, false)
  FROM sample_settings s
    JOIN samples s_start ON (s_start.server_id = s.server_id AND s_start.sample_id = start_id)
    JOIN samples s_end ON (s_end.server_id = s.server_id AND s_end.sample_id = end_id)
  WHERE s.server_id = sserver_id AND s.first_seen > s_start.sample_time AND s.first_seen <= s_end.sample_time
$function$;

-- Function: settings_and_changes_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.settings_and_changes_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report_defined text := '';
    report_default text := '';
    defined_tpl    text := '';
    default_tpl    text := '';

    jtab_tpl    jsonb;
    notes       text[];

    v_init_tpl  text;
    v_new_tpl   text;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_settings CURSOR FOR
    SELECT
      first_seen,
      setting_scope,
      st1.name as name1,
      st2.name as name2,
      name,
      setting,
      reset_val,
      COALESCE(st1.unit,st2.unit) as unit,
      COALESCE(st1.sourcefile,st2.sourcefile) as sourcefile,
      COALESCE(st1.sourceline,st2.sourceline) as sourceline,
      pending_restart,
      changed,
      default_val
    FROM settings_and_changes(sserver_id, start1_id, end1_id) st1
      FULL OUTER JOIN settings_and_changes(sserver_id, start2_id, end2_id) st2
        USING(first_seen, setting_scope, name, setting, reset_val, pending_restart, changed, default_val)
    ORDER BY default_val AND NOT changed ASC, name,setting_scope,first_seen,pending_restart ASC NULLS FIRST;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table class="setlist">'
          '{defined_tpl}'
          '{default_tpl}'
        '</table>',
      'defined_tpl',
        '<tr><th colspan="5">Defined settings</th></tr>'
          '<tr>'
            '<th>Setting</th>'
            '<th>reset_val</th>'
            '<th>Unit</th>'
            '<th>Source</th>'
            '<th>Notes</th>'
          '</tr>'
          '{rows_defined}',
      'default_tpl',
        '<tr><th colspan="5">Default settings</th></tr>'
          '<tr>'
            '<th>Setting</th>'
            '<th>reset_val</th>'
            '<th>Unit</th>'
            '<th>Source</th>'
            '<th>Notes</th>'
          '</tr>'
          '{rows_default}',
      'init_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'new_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {value}><strong>%s</strong></td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}><strong>%s</strong></td>'
        '</tr>',
      'init_tpl_i1',
        '<tr {interval1}>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'new_tpl_i1',
        '<tr {interval1}>'
          '<td>%s</td>'
          '<td {value}><strong>%s</strong></td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}><strong>%s</strong></td>'
        '</tr>',
      'init_tpl_i2',
        '<tr {interval2}>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'new_tpl_i2',
        '<tr {interval2}>'
          '<td>%s</td>'
          '<td {value}><strong>%s</strong></td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}><strong>%s</strong></td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_settings LOOP
      CASE
        WHEN r_result.name1 IS NULL THEN
          v_init_tpl := 'init_tpl_i2';
          v_new_tpl := 'new_tpl_i2';
        WHEN r_result.name2 IS NULL THEN
          v_init_tpl := 'init_tpl_i1';
          v_new_tpl := 'new_tpl_i1';
        ELSE
          v_init_tpl := 'init_tpl';
          v_new_tpl := 'new_tpl';
      END CASE;
        notes := ARRAY[''];
        IF r_result.changed THEN
          notes := array_append(notes,r_result.first_seen::text);
        END IF;
        IF r_result.pending_restart THEN
          notes := array_append(notes,'Pending restart');
        END IF;
        notes := array_remove(notes,'');
        IF r_result.default_val AND NOT r_result.changed THEN
          report_default := report_default||format(
              jtab_tpl #>> ARRAY[v_init_tpl],
              r_result.name,
              r_result.reset_val,
              r_result.unit,
              r_result.sourcefile || ':' || r_result.sourceline::text,
              array_to_string(notes,',')
          );
        ELSIF NOT r_result.changed THEN
          report_defined := report_defined||format(
              jtab_tpl #>> ARRAY[v_init_tpl],
              r_result.name,
              r_result.reset_val,
              r_result.unit,
              r_result.sourcefile || ':' || r_result.sourceline::text,
              array_to_string(notes,',')
          );
        ELSE
          report_defined := report_defined||format(
              jtab_tpl #>> ARRAY[v_new_tpl],
              r_result.name,
              r_result.reset_val,
              r_result.unit,
              r_result.sourcefile || ':' || r_result.sourceline::text,
              array_to_string(notes,',')
          );
        END IF;

    END LOOP;

    IF report_default = '' and report_defined = '' THEN
        RETURN '!!!';
    ELSE
        -- apply settings to templates
        defined_tpl := replace(jtab_tpl #>> ARRAY['defined_tpl'],'{rows_defined}', report_defined);
        defined_tpl := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{defined_tpl}', defined_tpl);

        IF report_default != '' THEN
          default_tpl := replace(jtab_tpl #>> ARRAY['default_tpl'],'{rows_default}', report_default);
          RETURN replace(defined_tpl,'{default_tpl}',default_tpl);
        END IF;
        RETURN defined_tpl;
    END IF;
END;
$function$;

-- Function: settings_and_changes_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.settings_and_changes_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report_defined text := '';
    report_default text := '';
    defined_tpl    text := '';
    default_tpl    text := '';

    jtab_tpl       jsonb;
    notes          text[];

    --Cursor for top(cnt) queries ordered by elapsed time
    c_settings CURSOR FOR
    SELECT
      first_seen,
      setting_scope,
      name,
      setting,
      reset_val,
      unit,
      sourcefile,
      sourceline,
      pending_restart,
      changed,
      default_val
    FROM settings_and_changes(sserver_id, start_id, end_id) st
    ORDER BY default_val AND NOT changed ASC, name,setting_scope,first_seen,pending_restart ASC NULLS FIRST;

    r_result RECORD;
BEGIN

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table class="setlist">'
          '{defined_tpl}'
          '{default_tpl}'
        '</table>',
      'defined_tpl',
        '<tr><th colspan="5">Defined settings</th></tr>'
        '<tr>'
          '<th>Setting</th>'
          '<th>reset_val</th>'
          '<th>Unit</th>'
          '<th>Source</th>'
          '<th>Notes</th>'
        '</tr>'
        '{rows_defined}',
      'default_tpl',
        '<tr><th colspan="5">Default settings</th></tr>'
        '<tr>'
           '<th>Setting</th>'
           '<th>reset_val</th>'
           '<th>Unit</th>'
           '<th>Source</th>'
           '<th>Notes</th>'
         '</tr>'
         '{rows_default}',
      'init_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'new_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {value}><strong>%s</strong></td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}><strong>%s</strong></td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_settings LOOP
        notes := ARRAY[''];
        IF r_result.changed THEN
          notes := array_append(notes,r_result.first_seen::text);
        END IF;
        IF r_result.pending_restart THEN
          notes := array_append(notes,'Pending restart');
        END IF;
        notes := array_remove(notes,'');
        IF r_result.default_val AND NOT r_result.changed THEN
            report_default := report_default||format(
              jtab_tpl #>> ARRAY['init_tpl'],
              r_result.name,
              r_result.reset_val,
              r_result.unit,
              r_result.sourcefile || ':' || r_result.sourceline::text,
              array_to_string(notes,', ')
          );
        ELSIF NOT r_result.changed THEN
            report_defined := report_defined ||format(
              jtab_tpl #>> ARRAY['init_tpl'],
              r_result.name,
              r_result.reset_val,
              r_result.unit,
              r_result.sourcefile || ':' || r_result.sourceline::text,
              array_to_string(notes,',  ')
          );
        ELSE
            report_defined := report_defined ||format(
              jtab_tpl #>> ARRAY['new_tpl'],
              r_result.name,
              r_result.reset_val,
              r_result.unit,
              r_result.sourcefile || ':' || r_result.sourceline::text,
              array_to_string(notes,',  ')
          );
        END IF;
    END LOOP;

    IF report_default = '' and report_defined = '' THEN
        RETURN '!!!';
    ELSE
        -- apply settings to templates
        defined_tpl := replace(jtab_tpl #>> ARRAY['defined_tpl'],'{rows_defined}', report_defined);
        defined_tpl := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{defined_tpl}', defined_tpl);

        IF report_default != '' THEN
          default_tpl := replace(jtab_tpl #>> ARRAY['default_tpl'],'{rows_default}', report_default);
          RETURN replace(defined_tpl,'{default_tpl}',default_tpl);
        END IF;
        RETURN defined_tpl;
    END IF;
END;
$function$;

-- Function: show_baselines
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.show_baselines(server name DEFAULT 'local'::name)
 RETURNS TABLE(baseline character varying, min_sample integer, max_sample integer, keep_until_time timestamp with time zone)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT bl_name as baseline,min_sample_id,max_sample_id, keep_until
    FROM baselines b JOIN
        (SELECT server_id,bl_id,min(sample_id) min_sample_id,max(sample_id) max_sample_id FROM bl_samples GROUP BY server_id,bl_id) b_agg
    USING (server_id,bl_id)
    WHERE server_id IN (SELECT server_id FROM servers WHERE server_name = server)
    ORDER BY min_sample_id;
$function$;

-- Function: show_limit
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.show_limit()
 RETURNS real
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_limit$function$;

-- Function: show_samples
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.show_samples(server name, days integer DEFAULT NULL::integer)
 RETURNS TABLE(sample integer, sample_time timestamp with time zone, sizes_collected boolean, dbstats_reset timestamp with time zone, bgwrstats_reset timestamp with time zone, archstats_reset timestamp with time zone)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT
    s.sample_id,
    s.sample_time,
    count(relsize_diff) > 0 AS sizes_collected,
    max(nullif(db1.stats_reset,coalesce(db2.stats_reset,db1.stats_reset))) AS dbstats_reset,
    max(nullif(bgwr1.stats_reset,coalesce(bgwr2.stats_reset,bgwr1.stats_reset))) AS bgwrstats_reset,
    max(nullif(arch1.stats_reset,coalesce(arch2.stats_reset,arch1.stats_reset))) AS archstats_reset
  FROM samples s JOIN servers n USING (server_id)
    JOIN sample_stat_database db1 USING (server_id,sample_id)
    JOIN sample_stat_cluster bgwr1 USING (server_id,sample_id)
    JOIN sample_stat_tables_total USING (server_id,sample_id)
    LEFT OUTER JOIN sample_stat_archiver arch1 USING (server_id,sample_id)
    LEFT OUTER JOIN sample_stat_database db2 ON (db1.server_id = db2.server_id AND db1.datid = db2.datid AND db2.sample_id = db1.sample_id - 1)
    LEFT OUTER JOIN sample_stat_cluster bgwr2 ON (bgwr1.server_id = bgwr2.server_id AND bgwr2.sample_id = bgwr1.sample_id - 1)
    LEFT OUTER JOIN sample_stat_archiver arch2 ON (arch1.server_id = arch2.server_id AND arch2.sample_id = arch1.sample_id - 1)
  WHERE (days IS NULL OR s.sample_time > now() - (days || ' days')::interval)
    AND server_name = server
  GROUP BY s.sample_id, s.sample_time
  ORDER BY s.sample_id ASC
$function$;

-- Function: show_samples
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.show_samples(days integer DEFAULT NULL::integer)
 RETURNS TABLE(sample integer, sample_time timestamp with time zone, sizes_collected boolean, dbstats_reset timestamp with time zone, clustats_reset timestamp with time zone, archstats_reset timestamp with time zone)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT * FROM show_samples('local',days);
$function$;

-- Function: show_servers
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.show_servers()
 RETURNS TABLE(server_name name, connstr text, enabled boolean, description text)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT server_name, connstr, enabled, server_description FROM servers;
$function$;

-- Function: show_servers_size_sampling
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.show_servers_size_sampling()
 RETURNS TABLE(server_name name, window_start time with time zone, window_end time with time zone, window_duration interval, sample_interval interval, limited_collection boolean)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT
    server_name,
    size_smp_wnd_start,
    size_smp_wnd_start + size_smp_wnd_dur,
    size_smp_wnd_dur,
    size_smp_interval,
    sizes_limited
  FROM
    servers
$function$;

-- Function: show_trgm
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.show_trgm(text)
 RETURNS text[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_trgm$function$;

-- Function: similarity
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity$function$;

-- Function: similarity_dist
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.similarity_dist(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_dist$function$;

-- Function: similarity_op
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_op$function$;

-- Function: snapshot
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.snapshot(server name)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN take_sample(server);
END;
$function$;

-- Function: snapshot
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.snapshot()
 RETURNS TABLE(server name, result text, elapsed interval)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
SELECT * FROM take_sample()
$function$;

-- Function: statements_stats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.statements_stats(sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS TABLE(dbname name, datid oid, calls bigint, plans bigint, total_exec_time double precision, total_plan_time double precision, blk_read_time double precision, blk_write_time double precision, trg_fn_total_time double precision, shared_gets bigint, local_gets bigint, shared_blks_dirtied bigint, local_blks_dirtied bigint, temp_blks_read bigint, temp_blks_written bigint, local_blks_read bigint, local_blks_written bigint, statements bigint, wal_bytes bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        sample_db.datname AS dbname,
        sample_db.datid AS datid,
        sum(st.calls)::bigint AS calls,
        sum(st.plans)::bigint AS plans,
        sum(st.total_exec_time)/1000::double precision AS total_exec_time,
        sum(st.total_plan_time)/1000::double precision AS total_plan_time,
        sum(st.blk_read_time)/1000::double precision AS blk_read_time,
        sum(st.blk_write_time)/1000::double precision AS blk_write_time,
        (sum(trg.total_time)/1000)::double precision AS trg_fn_total_time,
        sum(st.shared_blks_hit)::bigint + sum(st.shared_blks_read)::bigint AS shared_gets,
        sum(st.local_blks_hit)::bigint + sum(st.local_blks_read)::bigint AS local_gets,
        sum(st.shared_blks_dirtied)::bigint AS shared_blks_dirtied,
        sum(st.local_blks_dirtied)::bigint AS local_blks_dirtied,
        sum(st.temp_blks_read)::bigint AS temp_blks_read,
        sum(st.temp_blks_written)::bigint AS temp_blks_written,
        sum(st.local_blks_read)::bigint AS local_blks_read,
        sum(st.local_blks_written)::bigint AS local_blks_written,
        sum(st.statements)::bigint AS statements,
        sum(st.wal_bytes)::bigint AS wal_bytes
    FROM sample_statements_total st
        LEFT OUTER JOIN sample_stat_user_func_total trg
          ON (st.server_id = trg.server_id AND st.sample_id = trg.sample_id AND st.datid = trg.datid AND trg.trg_fn)
        -- Database name
        JOIN sample_stat_database sample_db
        ON (st.server_id=sample_db.server_id AND st.sample_id=sample_db.sample_id AND st.datid=sample_db.datid)
    WHERE st.server_id = sserver_id AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY sample_db.datname, sample_db.datid;
$function$;

-- Function: statements_stats_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.statements_stats_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        COALESCE(COALESCE(st1.dbname,st2.dbname),'Total') as dbname,
        NULLIF(sum(st1.calls), 0) as calls1,
        NULLIF(sum(st1.total_exec_time), 0.0) as total_exec_time1,
        NULLIF(sum(st1.total_plan_time), 0.0) as total_plan_time1,
        NULLIF(sum(st1.blk_read_time), 0.0) as blk_read_time1,
        NULLIF(sum(st1.blk_write_time), 0.0) as blk_write_time1,
        NULLIF(sum(st1.trg_fn_total_time), 0.0) as trg_fn_total_time1,
        NULLIF(sum(st1.shared_gets), 0) as shared_gets1,
        NULLIF(sum(st1.local_gets), 0) as local_gets1,
        NULLIF(sum(st1.shared_blks_dirtied), 0) as shared_blks_dirtied1,
        NULLIF(sum(st1.local_blks_dirtied), 0) as local_blks_dirtied1,
        NULLIF(sum(st1.temp_blks_read), 0) as temp_blks_read1,
        NULLIF(sum(st1.temp_blks_written), 0) as temp_blks_written1,
        NULLIF(sum(st1.local_blks_read), 0) as local_blks_read1,
        NULLIF(sum(st1.local_blks_written), 0) as local_blks_written1,
        NULLIF(sum(st1.statements), 0) as statements1,
        NULLIF(sum(st1.wal_bytes), 0) as wal_bytes1,
        NULLIF(sum(st2.calls), 0) as calls2,
        NULLIF(sum(st2.total_exec_time), 0.0) as total_exec_time2,
        NULLIF(sum(st2.total_plan_time), 0.0) as total_plan_time2,
        NULLIF(sum(st2.blk_read_time), 0.0) as blk_read_time2,
        NULLIF(sum(st2.blk_write_time), 0.0) as blk_write_time2,
        NULLIF(sum(st2.trg_fn_total_time), 0.0) as trg_fn_total_time2,
        NULLIF(sum(st2.shared_gets), 0) as shared_gets2,
        NULLIF(sum(st2.local_gets), 0) as local_gets2,
        NULLIF(sum(st2.shared_blks_dirtied), 0) as shared_blks_dirtied2,
        NULLIF(sum(st2.local_blks_dirtied), 0) as local_blks_dirtied2,
        NULLIF(sum(st2.temp_blks_read), 0) as temp_blks_read2,
        NULLIF(sum(st2.temp_blks_written), 0) as temp_blks_written2,
        NULLIF(sum(st2.local_blks_read), 0) as local_blks_read2,
        NULLIF(sum(st2.local_blks_written), 0) as local_blks_written2,
        NULLIF(sum(st2.statements), 0) as statements2,
        NULLIF(sum(st2.wal_bytes), 0) as wal_bytes2
    FROM statements_stats(sserver_id,start1_id,end1_id,topn) st1
        FULL OUTER JOIN statements_stats(sserver_id,start2_id,end2_id,topn) st2 USING (datid)
    GROUP BY ROLLUP(COALESCE(st1.dbname,st2.dbname))
    ORDER BY COALESCE(st1.dbname,st2.dbname) NULLS LAST;

    r_result RECORD;
BEGIN
    -- Statements stats per database TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Number of query executions">Calls</th>'
            '{time_hdr}'
            '<th colspan="2" title="Number of blocks fetched (hit + read)">Fetched (blk)</th>'
            '<th colspan="2" title="Number of blocks dirtied">Dirtied (blk)</th>'
            '<th colspan="2" title="Number of blocks, used in operations (like sorts and joins)">Temp (blk)</th>'
            '<th colspan="2" title="Number of blocks, used for temporary tables">Local (blk)</th>'
            '<th rowspan="2">Statements</th>'
            '{wal_bytes_hdr}'
          '</tr>'
          '<tr>'
            '{plan_time_hdr}'
            '<th title="Time spent executing queries">Exec</th>'
            '<th title="Time spent reading blocks">Read</th>'   -- I/O time
            '<th title="Time spent writing blocks">Write</th>'
            '<th title="Time spent in trigger functions">Trg</th>'    -- Trigger functions time
            '<th>Shared</th>' -- Fetched (blk)
            '<th>Local</th>'
            '<th>Shared</th>' -- Dirtied (blk)
            '<th>Local</th>'
            '<th>Read</th>'   -- Work area  blocks
            '<th>Write</th>'
            '<th>Read</th>'   -- Local blocks
            '<th>Write</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stdb_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%1$s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%2$s</td>'
          '{plan_time_cell1}'
          '<td {value}>%4$s</td>'
          '<td {value}>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
          '{wal_bytes_cell1}'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%18$s</td>'
          '{plan_time_cell2}'
          '<td {value}>%20$s</td>'
          '<td {value}>%21$s</td>'
          '<td {value}>%22$s</td>'
          '<td {value}>%23$s</td>'
          '<td {value}>%24$s</td>'
          '<td {value}>%25$s</td>'
          '<td {value}>%26$s</td>'
          '<td {value}>%27$s</td>'
          '<td {value}>%28$s</td>'
          '<td {value}>%29$s</td>'
          '<td {value}>%30$s</td>'
          '<td {value}>%31$s</td>'
          '<td {value}>%32$s</td>'
          '{wal_bytes_cell2}'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'time_hdr', -- Time header for stat_statements less then v1.8
        '<th colspan="4">Time (s)</th>',
      'time_hdr_plan_time', -- Time header for stat_statements v1.8 - added plan time field
        '<th colspan="5">Time (s)</th>',
      'plan_time_hdr',
        '<th title="Time spent planning queries">Plan</th>',
      'plan_time_cell1',
        '<td {value}>%3$s</td>',
      'plan_time_cell2',
        '<td {value}>%19$s</td>',
      'wal_bytes_hdr',
        '<th rowspan="2">WAL size</th>',
      'wal_bytes_cell1',
        '<td {value}>%17$s</td>',
      'wal_bytes_cell2',
        '<td {value}>%33$s</td>');
    -- Conditional template
    -- Planning times
    IF jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{time_hdr}',jtab_tpl->>'time_hdr_plan_time')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{plan_time_hdr}',jtab_tpl->>'plan_time_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{plan_time_cell1}',jtab_tpl->>'plan_time_cell1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{plan_time_cell2}',jtab_tpl->>'plan_time_cell2')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{time_hdr}',jtab_tpl->>'time_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{plan_time_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{plan_time_cell1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{plan_time_cell2}','')));
    END IF;
    -- WAL size
    IF jsonb_extract_path_text(jreportset, 'report_features', 'statement_wal_bytes')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{wal_bytes_hdr}',jtab_tpl->>'wal_bytes_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{wal_bytes_cell1}',jtab_tpl->>'wal_bytes_cell1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{wal_bytes_cell2}',jtab_tpl->>'wal_bytes_cell2')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{wal_bytes_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{wal_bytes_cell1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{wal_bytes_cell2}','')));
    END IF;
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['stdb_tpl'],
            r_result.dbname,
            r_result.calls1,
            round(CAST(r_result.total_plan_time1 AS numeric),2),
            round(CAST(r_result.total_exec_time1 AS numeric),2),
            round(CAST(r_result.blk_read_time1 AS numeric),2),
            round(CAST(r_result.blk_write_time1 AS numeric),2),
            round(CAST(r_result.trg_fn_total_time1 AS numeric),2),
            r_result.shared_gets1,
            r_result.local_gets1,
            r_result.shared_blks_dirtied1,
            r_result.local_blks_dirtied1,
            r_result.temp_blks_read1,
            r_result.temp_blks_written1,
            r_result.local_blks_read1,
            r_result.local_blks_written1,
            r_result.statements1,
            pg_size_pretty(r_result.wal_bytes1),
            r_result.calls2,
            round(CAST(r_result.total_plan_time2 AS numeric),2),
            round(CAST(r_result.total_exec_time2 AS numeric),2),
            round(CAST(r_result.blk_read_time2 AS numeric),2),
            round(CAST(r_result.blk_write_time2 AS numeric),2),
            round(CAST(r_result.trg_fn_total_time2 AS numeric),2),
            r_result.shared_gets2,
            r_result.local_gets2,
            r_result.shared_blks_dirtied2,
            r_result.local_blks_dirtied2,
            r_result.temp_blks_read2,
            r_result.temp_blks_written2,
            r_result.local_blks_read2,
            r_result.local_blks_written2,
            r_result.statements2,
            pg_size_pretty(r_result.wal_bytes2)
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN report;
END;
$function$;

-- Function: statements_stats_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.statements_stats_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        COALESCE(dbname,'Total') as dbname_t,
        NULLIF(sum(calls), 0) as calls,
        NULLIF(sum(total_exec_time), 0.0) as total_exec_time,
        NULLIF(sum(total_plan_time), 0.0) as total_plan_time,
        NULLIF(sum(blk_read_time), 0.0) as blk_read_time,
        NULLIF(sum(blk_write_time), 0.0) as blk_write_time,
        NULLIF(sum(trg_fn_total_time), 0.0) as trg_fn_total_time,
        NULLIF(sum(shared_gets), 0) as shared_gets,
        NULLIF(sum(local_gets), 0) as local_gets,
        NULLIF(sum(shared_blks_dirtied), 0) as shared_blks_dirtied,
        NULLIF(sum(local_blks_dirtied), 0) as local_blks_dirtied,
        NULLIF(sum(temp_blks_read), 0) as temp_blks_read,
        NULLIF(sum(temp_blks_written), 0) as temp_blks_written,
        NULLIF(sum(local_blks_read), 0) as local_blks_read,
        NULLIF(sum(local_blks_written), 0) as local_blks_written,
        NULLIF(sum(statements), 0) as statements,
        NULLIF(sum(wal_bytes), 0) as wal_bytes
    FROM statements_stats(sserver_id,start_id,end_id,topn)
    GROUP BY ROLLUP(dbname)
    ORDER BY dbname NULLS LAST;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2"title="Number of query executions">Calls</th>'
            '{time_hdr}'
            '<th colspan="2" title="Number of blocks fetched (hit + read)">Fetched (blk)</th>'
            '<th colspan="2" title="Number of blocks dirtied">Dirtied (blk)</th>'
            '<th colspan="2" title="Number of blocks, used in operations (like sorts and joins)">Temp (blk)</th>'
            '<th colspan="2" title="Number of blocks, used for temporary tables">Local (blk)</th>'
            '<th rowspan="2">Statements</th>'
            '{wal_bytes_hdr}'
          '</tr>'
          '<tr>'
            '{plan_time_hdr}'
            '<th title="Time spent executing queries">Exec</th>'
            '<th title="Time spent reading blocks">Read</th>'   -- I/O time
            '<th title="Time spent writing blocks">Write</th>'
            '<th title="Time spent in trigger functions">Trg</th>'    -- Trigger functions time
            '<th>Shared</th>' -- Fetched
            '<th>Local</th>'
            '<th>Shared</th>' -- Dirtied
            '<th>Local</th>'
            '<th>Read</th>'   -- Work area read blks
            '<th>Write</th>'  -- Work area write blks
            '<th>Read</th>'   -- Local read blks
            '<th>Write</th>'  -- Local write blks
          '</tr>'
          '{rows}'
        '</table>',
      'stdb_tpl',
        '<tr>'
          '<td>%1$s</td>'
          '<td {value}>%2$s</td>'
          '{plan_time_cell}'
          '<td {value}>%4$s</td>'
          '<td {value}>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
          '{wal_bytes_cell}'
        '</tr>',
      'time_hdr', -- Time header for stat_statements less then v1.8
        '<th colspan="4">Time (s)</th>',
      'time_hdr_plan_time', -- Time header for stat_statements v1.8 - added plan time field
        '<th colspan="5">Time (s)</th>',
      'plan_time_hdr',
        '<th title="Time spent planning queries">Plan</th>',
      'plan_time_cell',
        '<td {value}>%3$s</td>',
      'wal_bytes_hdr',
        '<th rowspan="2">WAL size</th>',
      'wal_bytes_cell',
        '<td {value}>%17$s</td>');
    -- Conditional template
    -- Planning times
    IF jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{time_hdr}',jtab_tpl->>'time_hdr_plan_time')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{plan_time_hdr}',jtab_tpl->>'plan_time_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{plan_time_cell}',jtab_tpl->>'plan_time_cell')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{time_hdr}',jtab_tpl->>'time_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{plan_time_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{plan_time_cell}','')));
    END IF;
    -- WAL size
    IF jsonb_extract_path_text(jreportset, 'report_features', 'statement_wal_bytes')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{wal_bytes_hdr}',jtab_tpl->>'wal_bytes_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{wal_bytes_cell}',jtab_tpl->>'wal_bytes_cell')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{wal_bytes_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stdb_tpl}',to_jsonb(replace(jtab_tpl->>'stdb_tpl','{wal_bytes_cell}','')));
    END IF;

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['stdb_tpl'],
            r_result.dbname_t,
            r_result.calls,
            round(CAST(r_result.total_plan_time AS numeric),2),
            round(CAST(r_result.total_exec_time AS numeric),2),
            round(CAST(r_result.blk_read_time AS numeric),2),
            round(CAST(r_result.blk_write_time AS numeric),2),
            round(CAST(r_result.trg_fn_total_time AS numeric),2),
            r_result.shared_gets,
            r_result.local_gets,
            r_result.shared_blks_dirtied,
            r_result.local_blks_dirtied,
            r_result.temp_blks_read,
            r_result.temp_blks_written,
            r_result.local_blks_read,
            r_result.local_blks_written,
            r_result.statements,
            pg_size_pretty(r_result.wal_bytes)
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN report;
END;
$function$;

-- Function: strict_word_similarity
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.strict_word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity$function$;

-- Function: strict_word_similarity_commutator_op
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.strict_word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_commutator_op$function$;

-- Function: strict_word_similarity_dist_commutator_op
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_commutator_op$function$;

-- Function: strict_word_similarity_dist_op
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_op$function$;

-- Function: strict_word_similarity_op
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.strict_word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_op$function$;

-- Function: table_size_failures
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.table_size_failures(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, datid oid, relid oid, size_failed boolean, toastsize_failed boolean)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT
    server_id,
    datid,
    relid,
    bool_or(size_failed) as size_failed,
    bool_or(toastsize_failed) as toastsize_failed
  FROM
    sample_stat_tables_failures
  WHERE
    server_id = sserver_id AND sample_id IN (start_id, end_id)
  GROUP BY
    server_id,
    datid,
    relid
$function$;

-- Function: tablespace_stats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.tablespace_stats(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, tablespaceid oid, tablespacename name, tablespacepath text, size_delta bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        st.server_id,
        st.tablespaceid,
        st.tablespacename,
        st.tablespacepath,
        sum(st.size_delta)::bigint AS size_delta
    FROM v_sample_stat_tablespaces st
    WHERE st.server_id = sserver_id
      AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id, st.tablespaceid, st.tablespacename, st.tablespacepath
$function$;

-- Function: tablespaces_stats_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.tablespaces_stats_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for stats
    c_tbl_stats CURSOR FOR
    SELECT
        COALESCE(stat1.tablespacename,stat2.tablespacename) AS tablespacename,
        COALESCE(stat1.tablespacepath,stat2.tablespacepath) AS tablespacepath,
        pg_size_pretty(NULLIF(st_last1.size, 0)) as size1,
        pg_size_pretty(NULLIF(st_last2.size, 0)) as size2,
        pg_size_pretty(NULLIF(stat1.size_delta, 0)) as size_delta1,
        pg_size_pretty(NULLIF(stat2.size_delta, 0)) as size_delta2
    FROM tablespace_stats(sserver_id,start1_id,end1_id) stat1
        FULL OUTER JOIN tablespace_stats(sserver_id,start2_id,end2_id) stat2 USING (server_id,tablespaceid)
        LEFT OUTER JOIN v_sample_stat_tablespaces st_last1 ON
        (st_last1.server_id = stat1.server_id AND st_last1.sample_id = end1_id AND st_last1.tablespaceid = stat1.tablespaceid)
        LEFT OUTER JOIN v_sample_stat_tablespaces st_last2 ON
        (st_last2.server_id = stat2.server_id AND st_last2.sample_id = end2_id AND st_last2.tablespaceid = stat2.tablespaceid)
    ORDER BY COALESCE(stat1.tablespacename,stat2.tablespacename);

    r_result RECORD;
BEGIN
     -- Tablespace stats template
     jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Tablespace</th>'
            '<th>Path</th>'
            '<th>I</th>'
            '<th title="Tablespace size as it was at the moment of last sample in report interval">Size</th>'
            '<th title="Tablespace size increment during report interval">Growth</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'ts_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr_mono}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['ts_tpl'],
            r_result.tablespacename,
            r_result.tablespacepath,
            r_result.size1,
            r_result.size_delta1,
            r_result.size2,
            r_result.size_delta2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;
    RETURN report;

END;
$function$;

-- Function: tablespaces_stats_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.tablespaces_stats_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for stats
    c_tbl_stats CURSOR FOR
    SELECT
        st.tablespacename,
        st.tablespacepath,
        pg_size_pretty(NULLIF(st_last.size, 0)) as size,
        pg_size_pretty(NULLIF(st.size_delta, 0)) as size_delta
    FROM tablespace_stats(sserver_id,start_id,end_id) st
      LEFT OUTER JOIN v_sample_stat_tablespaces st_last ON
        (st_last.server_id = st.server_id AND st_last.sample_id = end_id AND st_last.tablespaceid = st.tablespaceid)
    ORDER BY st.tablespacename ASC;

    r_result RECORD;
BEGIN
       --- Populate templates

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Tablespace</th>'
            '<th>Path</th>'
            '<th title="Tablespace size as it was at the moment of last sample in report interval">Size</th>'
            '<th title="Tablespace size increment during report interval">Growth</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'ts_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
          report := report||format(
              jtab_tpl #>> ARRAY['ts_tpl'],
              r_result.tablespacename,
              r_result.tablespacepath,
              r_result.size,
              r_result.size_delta
          );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;


    RETURN  report;
END;
$function$;

-- Function: take_sample
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.take_sample(server name, skip_sizes boolean DEFAULT NULL::boolean)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    sserver_id    integer;
BEGIN
    SELECT server_id INTO sserver_id FROM servers WHERE server_name = server;
    IF sserver_id IS NULL THEN
        RAISE 'Server not found';
    ELSE
        RETURN take_sample(sserver_id, skip_sizes);
    END IF;
END;
$function$;

-- Function: take_sample
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.take_sample(sserver_id integer, skip_sizes boolean)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    s_id              integer;
    topn              integer;
    ret               integer;
    server_properties jsonb = '{"extensions":[],"settings":[],"timings":{}}'; -- version, extensions, etc.
    qres              record;
    server_connstr    text;
    settings_refresh  boolean = true;
    collect_timings   boolean = false;
    limited_sizes_allowed boolean = NULL;

    server_query      text;
    server_host       text = NULL;
BEGIN
    -- Get server connstr
    server_connstr := get_connstr(sserver_id);
    /*
     When host= parameter is not specified, connection to unix socket is assumed.
     Unix socket can be in non-default location, so we need to specify it
    */
    IF (SELECT count(*) = 0 FROM regexp_matches(server_connstr,$o$((\s|^)host\s*=)$o$)) AND
      (SELECT count(*) != 0 FROM pg_catalog.pg_settings
      WHERE name = 'unix_socket_directories' AND boot_val != reset_val)
    THEN
      -- Get suitable socket name from available list
      server_host := (SELECT COALESCE(t[1],t[4])
        FROM pg_catalog.pg_settings,
          regexp_matches(reset_val,'("(("")|[^"])+")|([^,]+)','g') AS t
        WHERE name = 'unix_socket_directories' AND boot_val != reset_val
          -- libpq can't handle sockets with comma in their names
          AND position(',' IN COALESCE(t[1],t[4])) = 0
        LIMIT 1
      );
      -- quoted string processing
      IF starts_with(server_host,'"') AND
         starts_with(reverse(server_host),'"') AND
         (length(server_host) > 1)
      THEN
        server_host := replace(substring(server_host,2,length(server_host)-2),'""','"');
      END IF;
      -- append host parameter to the connection string
      IF server_host IS NOT NULL AND server_host != '' THEN
        server_connstr := concat_ws(server_connstr, format('host=%L',server_host), ' ');
      ELSE
        server_connstr := concat_ws(server_connstr, format('host=%L','localhost'), ' ');
      END IF;
    END IF;

    -- Getting timing collection setting
    BEGIN
        collect_timings := current_setting('pg_profile.track_sample_timings')::boolean;
    EXCEPTION
        WHEN OTHERS THEN collect_timings := false;
    END;

    server_properties := jsonb_set(server_properties,'{collect_timings}',to_jsonb(collect_timings));

    -- Getting TopN setting
    BEGIN
        topn := current_setting('pg_profile.topn')::integer;
    EXCEPTION
        WHEN OTHERS THEN topn := 20;
    END;


    -- Adding dblink extension schema to search_path if it does not already there
    IF (SELECT count(*) = 0 FROM pg_catalog.pg_extension WHERE extname = 'dblink') THEN
      RAISE 'dblink extension must be installed';
    END IF;
    SELECT extnamespace::regnamespace AS dblink_schema INTO STRICT qres FROM pg_catalog.pg_extension WHERE extname = 'dblink';
    IF NOT string_to_array(current_setting('search_path'),',') @> ARRAY[qres.dblink_schema::text] THEN
      EXECUTE 'SET LOCAL search_path TO ' || current_setting('search_path')||','|| qres.dblink_schema;
    END IF;

    IF dblink_get_connections() @> ARRAY['server_connection'] THEN
        PERFORM dblink_disconnect('server_connection');
    END IF;

    -- Creating a new sample record
    UPDATE servers SET last_sample_id = last_sample_id + 1 WHERE server_id = sserver_id
      RETURNING last_sample_id INTO s_id;
    INSERT INTO samples(sample_time,server_id,sample_id)
      VALUES (now(),sserver_id,s_id);

    -- Only one running take_sample() function allowed per server!
    -- Explicitly lock server in servers table
    BEGIN
        SELECT * INTO qres FROM servers WHERE server_id = sserver_id FOR UPDATE NOWAIT;
    EXCEPTION
        WHEN OTHERS THEN RAISE 'Can''t get lock on server. Is there another take_sample() function running on this server?';
    END;
    -- Getting max_sample_age setting
    BEGIN
        ret := COALESCE(current_setting('pg_profile.max_sample_age')::integer);
    EXCEPTION
        WHEN OTHERS THEN ret := 7;
    END;
    -- Applying skip sizes policy
    limited_sizes_allowed := qres.sizes_limited;
    IF skip_sizes IS NULL THEN
      IF num_nulls(qres.size_smp_wnd_start, qres.size_smp_wnd_dur, qres.size_smp_interval) > 0 THEN
        skip_sizes = false;
      ELSE
        /*
        Skip sizes collection if there was a sample with sizes recently
        or if we are not in size collection time window
        */
        SELECT
          count(*) > 0 OR
          NOT current_time BETWEEN qres.size_smp_wnd_start AND qres.size_smp_wnd_start + qres.size_smp_wnd_dur
            INTO STRICT skip_sizes
        FROM
          sample_stat_tables_total st
          JOIN samples s USING (server_id, sample_id)
        WHERE
          server_id = sserver_id
          AND st.relsize_diff IS NOT NULL
          AND sample_time > now() - qres.size_smp_interval;
      END IF;
    END IF;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,connect}',jsonb_build_object('start',clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,total}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Server connection
    PERFORM dblink_connect('server_connection',server_connstr);
    -- Setting lock_timout prevents hanging of take_sample() call due to DDL in long transaction
    PERFORM dblink('server_connection','SET lock_timeout=3000');
    -- Reset search_path for security reasons
    PERFORM dblink('server_connection','SET search_path=''''');

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,connect,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,get server environment}',jsonb_build_object('start',clock_timestamp()));
    END IF;
    -- Get settings values for the server
    FOR qres IN
      SELECT * FROM dblink('server_connection',
          'SELECT name, '
          'reset_val, '
          'unit, '
          'pending_restart '
          'FROM pg_catalog.pg_settings '
          'WHERE name IN ('
            '''server_version_num'''
          ')')
        AS dbl(name text, reset_val text, unit text, pending_restart boolean)
    LOOP
      server_properties := jsonb_insert(server_properties,'{"settings",0}',to_jsonb(qres));
    END LOOP;

    -- Get extensions, that we need to perform statements stats collection
    FOR qres IN
      SELECT * FROM dblink('server_connection',
          'SELECT extname, '
          'extnamespace::regnamespace::name AS extnamespace, '
          'extversion '
          'FROM pg_catalog.pg_extension '
          'WHERE extname IN ('
            '''pg_stat_statements'','
            '''pg_stat_kcache'''
          ')')
        AS dbl(extname name, extnamespace name, extversion text)
    LOOP
      server_properties := jsonb_insert(server_properties,'{"extensions",0}',to_jsonb(qres));
    END LOOP;

    -- Collecting postgres parameters
    /* We might refresh all parameters if version() was changed
    * This is needed for deleting obsolete parameters, not appearing in new
    * Postgres version.
    */
    SELECT ss.setting != dblver.version INTO settings_refresh
    FROM v_sample_settings ss, dblink('server_connection','SELECT version() as version') AS dblver (version text)
    WHERE ss.server_id = sserver_id AND ss.sample_id = s_id AND ss.name='version' AND ss.setting_scope = 2;
    settings_refresh := COALESCE(settings_refresh,true);

    -- Constructing server sql query for settings
    server_query := 'SELECT 1 as setting_scope,name,setting,reset_val,boot_val,unit,sourcefile,sourceline,pending_restart '
      'FROM pg_catalog.pg_settings '
      'UNION ALL SELECT 2 as setting_scope,''version'',version(),version(),NULL,NULL,NULL,NULL,False '
      'UNION ALL SELECT 2 as setting_scope,''pg_postmaster_start_time'','
      'pg_catalog.pg_postmaster_start_time()::text,'
      'pg_catalog.pg_postmaster_start_time()::text,NULL,NULL,NULL,NULL,False '
      'UNION ALL SELECT 2 as setting_scope,''pg_conf_load_time'','
      'pg_catalog.pg_conf_load_time()::text,pg_catalog.pg_conf_load_time()::text,NULL,NULL,NULL,NULL,False '
      'UNION ALL SELECT 2 as setting_scope,''system_identifier'','
      'system_identifier::text,system_identifier::text,system_identifier::text,'
      'NULL,NULL,NULL,False FROM pg_catalog.pg_control_system()';

    INSERT INTO sample_settings(
      server_id,
      first_seen,
      setting_scope,
      name,
      setting,
      reset_val,
      boot_val,
      unit,
      sourcefile,
      sourceline,
      pending_restart
    )
    SELECT
      s.server_id as server_id,
      s.sample_time as first_seen,
      cur.setting_scope,
      cur.name,
      cur.setting,
      cur.reset_val,
      cur.boot_val,
      cur.unit,
      cur.sourcefile,
      cur.sourceline,
      cur.pending_restart
    FROM
      sample_settings lst JOIN (
        -- Getting last versions of settings
        SELECT server_id, name, max(first_seen) as first_seen
        FROM sample_settings
        WHERE server_id = sserver_id AND (
          NOT settings_refresh
          -- system identifier shouldn't have a duplicate in case of version change
          -- this breaks export/import procedures, as those are related to this ID
          OR name = 'system_identifier'
        )
        GROUP BY server_id, name
      ) lst_times
      USING (server_id, name, first_seen)
      -- Getting current settings values
      RIGHT OUTER JOIN dblink('server_connection',server_query
          ) AS cur (
            setting_scope smallint,
            name text,
            setting text,
            reset_val text,
            boot_val text,
            unit text,
            sourcefile text,
            sourceline integer,
            pending_restart boolean
          )
        USING (setting_scope, name)
      JOIN samples s ON (s.server_id = sserver_id AND s.sample_id = s_id)
    WHERE
      cur.reset_val IS NOT NULL AND (
        lst.name IS NULL
        OR cur.reset_val != lst.reset_val
        OR cur.pending_restart != lst.pending_restart
        OR lst.sourcefile != cur.sourcefile
        OR lst.sourceline != cur.sourceline
        OR lst.unit != cur.unit
      );

    -- Check system identifier change
    SELECT min(reset_val::bigint) != max(reset_val::bigint) AS sysid_changed INTO STRICT qres
    FROM sample_settings
    WHERE server_id = sserver_id AND name = 'system_identifier';
    IF qres.sysid_changed THEN
      RAISE 'Server system_identifier has changed! Ensure server connection string is correct. Consider creating a new server for this cluster.';
    END IF;

    -- for server named 'local' check system identifier match
    IF (SELECT
      count(*) > 0
    FROM servers srv
      JOIN sample_settings ss USING (server_id)
      CROSS JOIN pg_catalog.pg_control_system() cs
    WHERE server_id = sserver_id AND ss.name = 'system_identifier'
      AND srv.server_name = 'local' AND reset_val::bigint != system_identifier)
    THEN
      RAISE 'Local system_identifier does not match with server specified by connection string of "local" server';
    END IF;

    INSERT INTO sample_settings(
      server_id,
      first_seen,
      setting_scope,
      name,
      setting,
      reset_val,
      boot_val,
      unit,
      sourcefile,
      sourceline,
      pending_restart
    )
    SELECT
      s.server_id,
      s.sample_time,
      1 as setting_scope,
      'pg_profile.topn',
      topn,
      topn,
      topn,
      null,
      null,
      null,
      false
    FROM samples s LEFT OUTER JOIN  v_sample_settings prm ON
      (s.server_id = prm.server_id AND s.sample_id = prm.sample_id AND prm.name = 'pg_profile.topn' AND prm.setting_scope = 1)
    WHERE s.server_id = sserver_id AND s.sample_id = s_id AND (prm.setting IS NULL OR prm.setting::integer != topn);

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,get server environment,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,collect database stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Construct pg_stat_database query
    CASE
      WHEN (
        SELECT count(*) = 1 FROM jsonb_to_recordset(server_properties #> '{settings}')
          AS x(name text, reset_val text)
        WHERE name = 'server_version_num'
          AND reset_val::integer < 140000
      )
      THEN
        server_query := 'SELECT '
            'dbs.datid, '
            'dbs.datname, '
            'dbs.xact_commit, '
            'dbs.xact_rollback, '
            'dbs.blks_read, '
            'dbs.blks_hit, '
            'dbs.tup_returned, '
            'dbs.tup_fetched, '
            'dbs.tup_inserted, '
            'dbs.tup_updated, '
            'dbs.tup_deleted, '
            'dbs.conflicts, '
            'dbs.temp_files, '
            'dbs.temp_bytes, '
            'dbs.deadlocks, '
            'dbs.blk_read_time, '
            'dbs.blk_write_time, '
            'NULL as session_time, '
            'NULL as active_time, '
            'NULL as idle_in_transaction_time, '
            'NULL as sessions, '
            'NULL as sessions_abandoned, '
            'NULL as sessions_fatal, '
            'NULL as sessions_killed, '
            'dbs.stats_reset, '
            'pg_database_size(dbs.datid) as datsize, '
            '0 as datsize_delta, '
            'db.datistemplate '
          'FROM pg_catalog.pg_stat_database dbs '
          'JOIN pg_catalog.pg_database db ON (dbs.datid = db.oid) '
          'WHERE dbs.datname IS NOT NULL';
      WHEN (
        SELECT count(*) = 1 FROM jsonb_to_recordset(server_properties #> '{settings}')
          AS x(name text, reset_val text)
        WHERE name = 'server_version_num'
          AND reset_val::integer >= 140000
      )
      THEN
        server_query := 'SELECT '
            'dbs.datid, '
            'dbs.datname, '
            'dbs.xact_commit, '
            'dbs.xact_rollback, '
            'dbs.blks_read, '
            'dbs.blks_hit, '
            'dbs.tup_returned, '
            'dbs.tup_fetched, '
            'dbs.tup_inserted, '
            'dbs.tup_updated, '
            'dbs.tup_deleted, '
            'dbs.conflicts, '
            'dbs.temp_files, '
            'dbs.temp_bytes, '
            'dbs.deadlocks, '
            'dbs.blk_read_time, '
            'dbs.blk_write_time, '
            'dbs.session_time, '
            'dbs.active_time, '
            'dbs.idle_in_transaction_time, '
            'dbs.sessions, '
            'dbs.sessions_abandoned, '
            'dbs.sessions_fatal, '
            'dbs.sessions_killed, '
            'dbs.stats_reset, '
            'pg_database_size(dbs.datid) as datsize, '
            '0 as datsize_delta, '
            'db.datistemplate '
          'FROM pg_catalog.pg_stat_database dbs '
          'JOIN pg_catalog.pg_database db ON (dbs.datid = db.oid) '
          'WHERE dbs.datname IS NOT NULL';
    END CASE;

    -- pg_stat_database data
    INSERT INTO last_stat_database (
        server_id,
        sample_id,
        datid,
        datname,
        xact_commit,
        xact_rollback,
        blks_read,
        blks_hit,
        tup_returned,
        tup_fetched,
        tup_inserted,
        tup_updated,
        tup_deleted,
        conflicts,
        temp_files,
        temp_bytes,
        deadlocks,
        blk_read_time,
        blk_write_time,
        session_time,
        active_time,
        idle_in_transaction_time,
        sessions,
        sessions_abandoned,
        sessions_fatal,
        sessions_killed,
        stats_reset,
        datsize,
        datsize_delta,
        datistemplate)
    SELECT
        sserver_id,
        s_id,
        datid,
        datname,
        xact_commit AS xact_commit,
        xact_rollback AS xact_rollback,
        blks_read AS blks_read,
        blks_hit AS blks_hit,
        tup_returned AS tup_returned,
        tup_fetched AS tup_fetched,
        tup_inserted AS tup_inserted,
        tup_updated AS tup_updated,
        tup_deleted AS tup_deleted,
        conflicts AS conflicts,
        temp_files AS temp_files,
        temp_bytes AS temp_bytes,
        deadlocks AS deadlocks,
        blk_read_time AS blk_read_time,
        blk_write_time AS blk_write_time,
        session_time AS session_time,
        active_time AS active_time,
        idle_in_transaction_time AS idle_in_transaction_time,
        sessions AS sessions,
        sessions_abandoned AS sessions_abandoned,
        sessions_fatal AS sessions_fatal,
        sessions_killed AS sessions_killed,
        stats_reset,
        datsize AS datsize,
        datsize_delta AS datsize_delta,
        datistemplate AS datistemplate
    FROM dblink('server_connection',server_query) AS rs (
        datid oid,
        datname name,
        xact_commit bigint,
        xact_rollback bigint,
        blks_read bigint,
        blks_hit bigint,
        tup_returned bigint,
        tup_fetched bigint,
        tup_inserted bigint,
        tup_updated bigint,
        tup_deleted bigint,
        conflicts bigint,
        temp_files bigint,
        temp_bytes bigint,
        deadlocks bigint,
        blk_read_time double precision,
        blk_write_time double precision,
        session_time double precision,
        active_time double precision,
        idle_in_transaction_time double precision,
        sessions bigint,
        sessions_abandoned bigint,
        sessions_fatal bigint,
        sessions_killed bigint,
        stats_reset timestamp with time zone,
        datsize bigint,
        datsize_delta bigint,
        datistemplate boolean
        );

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,collect database stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,calculate database stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;
    -- Calc stat_database diff
    INSERT INTO sample_stat_database(
      server_id,
      sample_id,
      datid,
      datname,
      xact_commit,
      xact_rollback,
      blks_read,
      blks_hit,
      tup_returned,
      tup_fetched,
      tup_inserted,
      tup_updated,
      tup_deleted,
      conflicts,
      temp_files,
      temp_bytes,
      deadlocks,
      blk_read_time,
      blk_write_time,
      session_time,
      active_time,
      idle_in_transaction_time,
      sessions,
      sessions_abandoned,
      sessions_fatal,
      sessions_killed,
      stats_reset,
      datsize,
      datsize_delta,
      datistemplate
    )
    SELECT
        cur.server_id,
        cur.sample_id,
        cur.datid,
        cur.datname,
        cur.xact_commit - COALESCE(lst.xact_commit,0),
        cur.xact_rollback - COALESCE(lst.xact_rollback,0),
        cur.blks_read - COALESCE(lst.blks_read,0),
        cur.blks_hit - COALESCE(lst.blks_hit,0),
        cur.tup_returned - COALESCE(lst.tup_returned,0),
        cur.tup_fetched - COALESCE(lst.tup_fetched,0),
        cur.tup_inserted - COALESCE(lst.tup_inserted,0),
        cur.tup_updated - COALESCE(lst.tup_updated,0),
        cur.tup_deleted - COALESCE(lst.tup_deleted,0),
        cur.conflicts - COALESCE(lst.conflicts,0),
        cur.temp_files - COALESCE(lst.temp_files,0),
        cur.temp_bytes - COALESCE(lst.temp_bytes,0),
        cur.deadlocks - COALESCE(lst.deadlocks,0),
        cur.blk_read_time - COALESCE(lst.blk_read_time,0),
        cur.blk_write_time - COALESCE(lst.blk_write_time,0),
        cur.session_time - COALESCE(lst.session_time,0),
        cur.active_time - COALESCE(lst.active_time,0),
        cur.idle_in_transaction_time - COALESCE(lst.idle_in_transaction_time,0),
        cur.sessions - COALESCE(lst.sessions,0),
        cur.sessions_abandoned - COALESCE(lst.sessions_abandoned,0),
        cur.sessions_fatal - COALESCE(lst.sessions_fatal,0),
        cur.sessions_killed - COALESCE(lst.sessions_killed,0),
        cur.stats_reset,
        cur.datsize as datsize,
        cur.datsize - COALESCE(lst.datsize,0) as datsize_delta,
        cur.datistemplate
    FROM last_stat_database cur
      LEFT OUTER JOIN last_stat_database lst ON
        (lst.server_id, lst.sample_id, lst.datid, lst.datname, lst.stats_reset) =
        (cur.server_id, cur.sample_id - 1, cur.datid, cur.datname, cur.stats_reset)
    WHERE cur.sample_id = s_id AND cur.server_id = sserver_id;

    /*
    * In case of statistics reset full database size is incorrectly
    * considered as increment by previous query. So, we need to update it
    * with correct value
    */
    UPDATE sample_stat_database sdb
    SET datsize_delta = cur.datsize - lst.datsize
    FROM
      last_stat_database cur
      JOIN last_stat_database lst ON
        (lst.server_id, lst.sample_id, lst.datid, lst.datname) =
        (cur.server_id, cur.sample_id - 1, cur.datid, cur.datname)
    WHERE cur.stats_reset != lst.stats_reset AND
      cur.sample_id = s_id AND cur.server_id = sserver_id AND
      (sdb.server_id, sdb.sample_id, sdb.datid, sdb.datname) =
      (cur.server_id, cur.sample_id, cur.datid, cur.datname);

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,calculate database stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,collect tablespace stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Construct tablespace stats query
    server_query := 'SELECT '
        'oid as tablespaceid,'
        'spcname as tablespacename,'
        'pg_catalog.pg_tablespace_location(oid) as tablespacepath,'
        'pg_catalog.pg_tablespace_size(oid) as size,'
        '0 as size_delta '
        'FROM pg_catalog.pg_tablespace ';

    -- Get tablespace stats
    INSERT INTO last_stat_tablespaces(
      server_id,
      sample_id,
      tablespaceid,
      tablespacename,
      tablespacepath,
      size,
      size_delta
    )
    SELECT
      sserver_id,
      s_id,
      dbl.tablespaceid,
      dbl.tablespacename,
      dbl.tablespacepath,
      dbl.size AS size,
      dbl.size_delta AS size_delta
    FROM dblink('server_connection', server_query)
    AS dbl (
        tablespaceid            oid,
        tablespacename          name,
        tablespacepath          text,
        size                    bigint,
        size_delta              bigint
    );

    ANALYZE last_stat_tablespaces;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,collect tablespace stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,collect statement stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Search for statements statistics extension
    CASE
      -- pg_stat_statements statistics collection
      WHEN (
        SELECT count(*) = 1
        FROM jsonb_to_recordset(server_properties #> '{extensions}') AS ext(extname text)
        WHERE extname = 'pg_stat_statements'
      ) THEN
        PERFORM collect_pg_stat_statements_stats(server_properties, sserver_id, s_id, topn);
      ELSE
        NULL;
    END CASE;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,collect statement stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,query pg_stat_bgwriter}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- pg_stat_bgwriter data
    CASE
      WHEN (
        SELECT count(*) = 1 FROM jsonb_to_recordset(server_properties #> '{settings}')
          AS x(name text, reset_val text)
        WHERE name = 'server_version_num'
          AND reset_val::integer < 100000
      )
      THEN
        server_query := 'SELECT '
          'checkpoints_timed,'
          'checkpoints_req,'
          'checkpoint_write_time,'
          'checkpoint_sync_time,'
          'buffers_checkpoint,'
          'buffers_clean,'
          'maxwritten_clean,'
          'buffers_backend,'
          'buffers_backend_fsync,'
          'buffers_alloc,'
          'stats_reset,'
          'CASE WHEN pg_catalog.pg_is_in_recovery() THEN 0 '
            'ELSE pg_catalog.pg_xlog_location_diff(pg_catalog.pg_current_xlog_location(),''0/00000000'') '
          'END AS wal_size '
          'FROM pg_catalog.pg_stat_bgwriter';
      WHEN (
        SELECT count(*) = 1 FROM jsonb_to_recordset(server_properties #> '{settings}')
          AS x(name text, reset_val text)
        WHERE name = 'server_version_num'
          AND reset_val::integer >= 100000
      )
      THEN
        server_query := 'SELECT '
          'checkpoints_timed,'
          'checkpoints_req,'
          'checkpoint_write_time,'
          'checkpoint_sync_time,'
          'buffers_checkpoint,'
          'buffers_clean,'
          'maxwritten_clean,'
          'buffers_backend,'
          'buffers_backend_fsync,'
          'buffers_alloc,'
          'stats_reset,'
          'CASE WHEN pg_catalog.pg_is_in_recovery() THEN 0 '
              'ELSE pg_catalog.pg_wal_lsn_diff(pg_catalog.pg_current_wal_lsn(),''0/00000000'') '
          'END AS wal_size '
        'FROM pg_catalog.pg_stat_bgwriter';
    END CASE;

    IF server_query IS NOT NULL THEN
      INSERT INTO last_stat_cluster (
        server_id,
        sample_id,
        checkpoints_timed,
        checkpoints_req,
        checkpoint_write_time,
        checkpoint_sync_time,
        buffers_checkpoint,
        buffers_clean,
        maxwritten_clean,
        buffers_backend,
        buffers_backend_fsync,
        buffers_alloc,
        stats_reset,
        wal_size)
      SELECT
        sserver_id,
        s_id,
        checkpoints_timed AS checkpoints_timed,
        checkpoints_req AS checkpoints_req,
        checkpoint_write_time AS checkpoint_write_time,
        checkpoint_sync_time AS checkpoint_sync_time,
        buffers_checkpoint AS buffers_checkpoint,
        buffers_clean AS buffers_clean,
        maxwritten_clean AS maxwritten_clean,
        buffers_backend AS buffers_backend,
        buffers_backend_fsync AS buffers_backend_fsync,
        buffers_alloc AS buffers_alloc,
        stats_reset,
        wal_size AS wal_size
      FROM dblink('server_connection',server_query) AS rs (
        checkpoints_timed bigint,
        checkpoints_req bigint,
        checkpoint_write_time double precision,
        checkpoint_sync_time double precision,
        buffers_checkpoint bigint,
        buffers_clean bigint,
        maxwritten_clean bigint,
        buffers_backend bigint,
        buffers_backend_fsync bigint,
        buffers_alloc bigint,
        stats_reset timestamp with time zone,
        wal_size bigint);
    END IF;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,query pg_stat_bgwriter,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,query pg_stat_wal}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- pg_stat_wal data
    CASE
      WHEN (
        SELECT count(*) = 1 FROM jsonb_to_recordset(server_properties #> '{settings}')
          AS x(name text, reset_val text)
        WHERE name = 'server_version_num'
          AND reset_val::integer >= 140000
      )
      THEN
        server_query := 'SELECT '
          'wal_records,'
          'wal_fpi,'
          'wal_bytes,'
          'wal_buffers_full,'
          'wal_write,'
          'wal_sync,'
          'wal_write_time,'
          'wal_sync_time,'
          'stats_reset '
          'FROM pg_catalog.pg_stat_wal';
      ELSE
        server_query := NULL;
    END CASE;

    IF server_query IS NOT NULL THEN
      INSERT INTO last_stat_wal (
        server_id,
        sample_id,
        wal_records,
        wal_fpi,
        wal_bytes,
        wal_buffers_full,
        wal_write,
        wal_sync,
        wal_write_time,
        wal_sync_time,
        stats_reset
      )
      SELECT
        sserver_id,
        s_id,
        wal_records,
        wal_fpi,
        wal_bytes,
        wal_buffers_full,
        wal_write,
        wal_sync,
        wal_write_time,
        wal_sync_time,
        stats_reset
      FROM dblink('server_connection',server_query) AS rs (
        wal_records         bigint,
        wal_fpi             bigint,
        wal_bytes           numeric,
        wal_buffers_full    bigint,
        wal_write           bigint,
        wal_sync            bigint,
        wal_write_time      double precision,
        wal_sync_time       double precision,
        stats_reset         timestamp with time zone);
    END IF;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,query pg_stat_wal,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,query pg_stat_archiver}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- pg_stat_archiver data
    CASE
      WHEN (
        SELECT count(*) = 1 FROM jsonb_to_recordset(server_properties #> '{settings}')
          AS x(name text, reset_val text)
        WHERE name = 'server_version_num'
          AND reset_val::integer > 90500
      )
      THEN
        server_query := 'SELECT '
          'archived_count,'
          'last_archived_wal,'
          'last_archived_time,'
          'failed_count,'
          'last_failed_wal,'
          'last_failed_time,'
          'stats_reset '
          'FROM pg_catalog.pg_stat_archiver';
    END CASE;

    IF server_query IS NOT NULL THEN
      INSERT INTO last_stat_archiver (
        server_id,
        sample_id,
        archived_count,
        last_archived_wal,
        last_archived_time,
        failed_count,
        last_failed_wal,
        last_failed_time,
        stats_reset)
      SELECT
        sserver_id,
        s_id,
        archived_count as archived_count,
        last_archived_wal as last_archived_wal,
        last_archived_time as last_archived_time,
        failed_count as failed_count,
        last_failed_wal as last_failed_wal,
        last_failed_time as last_failed_time,
        stats_reset as stats_reset
      FROM dblink('server_connection',server_query) AS rs (
        archived_count              bigint,
        last_archived_wal           text,
        last_archived_time          timestamp with time zone,
        failed_count                bigint,
        last_failed_wal             text,
        last_failed_time            timestamp with time zone,
        stats_reset                 timestamp with time zone
      );
    END IF;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,query pg_stat_archiver,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,collect object stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Collecting stat info for objects of all databases
    server_properties := collect_obj_stats(server_properties, sserver_id, s_id, server_connstr, skip_sizes, limited_sizes_allowed);

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,collect object stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,disconnect}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    PERFORM dblink_disconnect('server_connection');

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,disconnect,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,maintain repository}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Updating dictionary table in case of object renaming:
    -- Databases
    UPDATE sample_stat_database AS db
    SET datname = lst.datname
    FROM last_stat_database AS lst
    WHERE db.server_id = lst.server_id AND db.datid = lst.datid
      AND db.datname != lst.datname
      AND lst.sample_id = s_id;
    -- Tables
    UPDATE tables_list AS tl
    SET schemaname = lst.schemaname, relname = lst.relname
    FROM last_stat_tables AS lst
    WHERE tl.server_id = lst.server_id AND tl.datid = lst.datid AND tl.relid = lst.relid AND tl.relkind = lst.relkind
      AND (tl.schemaname != lst.schemaname OR tl.relname != lst.relname)
      AND lst.sample_id = s_id;
    -- Indexes
    UPDATE indexes_list AS il
    SET schemaname = lst.schemaname, indexrelname = lst.indexrelname
    FROM last_stat_indexes AS lst
    WHERE il.server_id = lst.server_id AND il.datid = lst.datid AND il.indexrelid = lst.indexrelid
      AND il.relid = lst.relid
      AND (il.schemaname != lst.schemaname OR il.indexrelname != lst.indexrelname)
      AND lst.sample_id = s_id;
    -- Functions
    UPDATE funcs_list AS fl
    SET schemaname = lst.schemaname, funcname = lst.funcname, funcargs = lst.funcargs
    FROM last_stat_user_functions AS lst
    WHERE fl.server_id = lst.server_id AND fl.datid = lst.datid AND fl.funcid = lst.funcid
      AND (fl.schemaname != lst.schemaname OR fl.funcname != lst.funcname OR fl.funcargs != lst.funcargs)
      AND lst.sample_id = s_id;
    -- Tablespaces
    UPDATE tablespaces_list AS tl
    SET tablespacename = lst.tablespacename, tablespacepath = lst.tablespacepath
    FROM last_stat_tablespaces AS lst
    WHERE tl.server_id = lst.server_id AND tl.tablespaceid = lst.tablespaceid
      AND (tl.tablespacename != lst.tablespacename OR tl.tablespacepath != lst.tablespacepath)
      AND lst.sample_id = s_id;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,maintain repository,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,calculate tablespace stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Calculate diffs for tablespaces
    FOR qres IN
        SELECT
            server_id,
            sample_id,
            tablespaceid,
            tablespacename,
            tablespacepath,
            size,
            size_delta
        FROM
            (SELECT
                cur.server_id,
                cur.sample_id,
                cur.tablespaceid as tablespaceid,
                cur.tablespacename AS tablespacename,
                cur.tablespacepath AS tablespacepath,
                cur.size as size,
                cur.size - COALESCE(lst.size,0) AS size_delta
            FROM last_stat_tablespaces cur LEFT OUTER JOIN last_stat_tablespaces lst ON
              (cur.server_id = lst.server_id AND lst.sample_id=cur.sample_id-1 AND cur.tablespaceid = lst.tablespaceid)
            WHERE cur.sample_id=s_id AND cur.server_id=sserver_id ) diff
    LOOP
      -- insert tablespaces to tablespaces_list
      INSERT INTO tablespaces_list(
        server_id,
        tablespaceid,
        tablespacename,
        tablespacepath
      )
      VALUES (qres.server_id,qres.tablespaceid,qres.tablespacename,qres.tablespacepath) ON CONFLICT DO NOTHING;
      INSERT INTO sample_stat_tablespaces(
        server_id,
        sample_id,
        tablespaceid,
        size,
        size_delta
      )
      VALUES (
          qres.server_id,
          qres.sample_id,
          qres.tablespaceid,
          qres.size,
          qres.size_delta
      );
    END LOOP;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,calculate tablespace stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,calculate object stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- collect databases objects stats
    server_properties := sample_dbobj_delta(server_properties,sserver_id,s_id,topn,skip_sizes);

    DELETE FROM last_stat_tablespaces WHERE server_id = sserver_id AND sample_id != s_id;

    DELETE FROM last_stat_database WHERE server_id = sserver_id AND sample_id != s_id;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,calculate object stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,calculate cluster stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Calc stat cluster diff
    INSERT INTO sample_stat_cluster(
      server_id,
      sample_id,
      checkpoints_timed,
      checkpoints_req,
      checkpoint_write_time,
      checkpoint_sync_time,
      buffers_checkpoint,
      buffers_clean,
      maxwritten_clean,
      buffers_backend,
      buffers_backend_fsync,
      buffers_alloc,
      stats_reset,
      wal_size
    )
    SELECT
        cur.server_id,
        cur.sample_id,
        cur.checkpoints_timed - COALESCE(lst.checkpoints_timed,0),
        cur.checkpoints_req - COALESCE(lst.checkpoints_req,0),
        cur.checkpoint_write_time - COALESCE(lst.checkpoint_write_time,0),
        cur.checkpoint_sync_time - COALESCE(lst.checkpoint_sync_time,0),
        cur.buffers_checkpoint - COALESCE(lst.buffers_checkpoint,0),
        cur.buffers_clean - COALESCE(lst.buffers_clean,0),
        cur.maxwritten_clean - COALESCE(lst.maxwritten_clean,0),
        cur.buffers_backend - COALESCE(lst.buffers_backend,0),
        cur.buffers_backend_fsync - COALESCE(lst.buffers_backend_fsync,0),
        cur.buffers_alloc - COALESCE(lst.buffers_alloc,0),
        cur.stats_reset,
        cur.wal_size - COALESCE(lst.wal_size,0)
    FROM last_stat_cluster cur
    LEFT OUTER JOIN last_stat_cluster lst ON
      (cur.stats_reset = lst.stats_reset AND cur.server_id = lst.server_id AND lst.sample_id = cur.sample_id - 1)
    WHERE cur.sample_id = s_id AND cur.server_id = sserver_id;

    DELETE FROM last_stat_cluster WHERE server_id = sserver_id AND sample_id != s_id;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,calculate cluster stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,calculate WAL stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Calc WAL stat diff
    INSERT INTO sample_stat_wal(
      server_id,
      sample_id,
      wal_records,
      wal_fpi,
      wal_bytes,
      wal_buffers_full,
      wal_write,
      wal_sync,
      wal_write_time,
      wal_sync_time,
      stats_reset
    )
    SELECT
        cur.server_id,
        cur.sample_id,
        cur.wal_records - COALESCE(lst.wal_records,0),
        cur.wal_fpi - COALESCE(lst.wal_fpi,0),
        cur.wal_bytes - COALESCE(lst.wal_bytes,0),
        cur.wal_buffers_full - COALESCE(lst.wal_buffers_full,0),
        cur.wal_write - COALESCE(lst.wal_write,0),
        cur.wal_sync - COALESCE(lst.wal_sync,0),
        cur.wal_write_time - COALESCE(lst.wal_write_time,0),
        cur.wal_sync_time - COALESCE(lst.wal_sync_time,0),
        cur.stats_reset
    FROM last_stat_wal cur
    LEFT OUTER JOIN last_stat_wal lst ON
      (cur.stats_reset = lst.stats_reset AND cur.server_id = lst.server_id AND lst.sample_id = cur.sample_id - 1)
    WHERE cur.sample_id = s_id AND cur.server_id = sserver_id;

    DELETE FROM last_stat_wal WHERE server_id = sserver_id AND sample_id != s_id;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,calculate WAL stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,calculate archiver stats}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Calc stat archiver diff
    INSERT INTO sample_stat_archiver(
      server_id,
      sample_id,
      archived_count,
      last_archived_wal,
      last_archived_time,
      failed_count,
      last_failed_wal,
      last_failed_time,
      stats_reset
    )
    SELECT
        cur.server_id,
        cur.sample_id,
        cur.archived_count - COALESCE(lst.archived_count,0),
        cur.last_archived_wal,
        cur.last_archived_time,
        cur.failed_count - COALESCE(lst.failed_count,0),
        cur.last_failed_wal,
        cur.last_failed_time,
        cur.stats_reset
    FROM last_stat_archiver cur
    LEFT OUTER JOIN last_stat_archiver lst ON
      (cur.stats_reset = lst.stats_reset AND cur.server_id = lst.server_id AND lst.sample_id = cur.sample_id - 1)
    WHERE cur.sample_id = s_id AND cur.server_id = sserver_id;

    DELETE FROM last_stat_archiver WHERE server_id = sserver_id AND sample_id != s_id;

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,calculate archiver stats,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,delete obsolete samples}',jsonb_build_object('start',clock_timestamp()));
    END IF;

    -- Deleting obsolete baselines
    DELETE FROM baselines
    WHERE keep_until < now()
      AND server_id = sserver_id;
    -- Deleting obsolete samples
    DELETE FROM samples s
      USING servers n
    WHERE n.server_id = s.server_id AND s.server_id = sserver_id
        AND s.sample_time < now() - (COALESCE(n.max_sample_age,ret) || ' days')::interval
        AND (s.server_id,s.sample_id) NOT IN (SELECT server_id,sample_id FROM bl_samples WHERE server_id = sserver_id);
    -- Deleting unused statements
    DELETE FROM stmt_list
        WHERE server_id = sserver_id AND queryid_md5 NOT IN
            (SELECT queryid_md5 FROM sample_statements
                UNION
             SELECT queryid_md5 FROM sample_kcache);

    -- Delete unused tablespaces from list
    DELETE FROM tablespaces_list
    WHERE server_id = sserver_id
      AND (server_id, tablespaceid) NOT IN (
        SELECT server_id, tablespaceid FROM sample_stat_tablespaces
        WHERE server_id = sserver_id
    );

    -- Delete unused indexes from indexes list
    DELETE FROM indexes_list
    WHERE server_id = sserver_id
      AND(server_id, datid, indexrelid) NOT IN (
        SELECT server_id, datid, indexrelid FROM sample_stat_indexes
    );

    -- Delete unused tables from tables list
    WITH used_tables AS (
        SELECT server_id, datid, relid FROM sample_stat_tables WHERE server_id = sserver_id
        UNION ALL
        SELECT server_id, datid, relid FROM indexes_list WHERE server_id = sserver_id)
    DELETE FROM tables_list
    WHERE server_id = sserver_id
      AND (server_id, datid, relid) NOT IN (SELECT server_id, datid, relid FROM used_tables)
      AND (server_id, datid, reltoastrelid) NOT IN (SELECT server_id, datid, relid FROM used_tables);

    -- Delete unused functions from functions list
    DELETE FROM funcs_list
    WHERE server_id = sserver_id
      AND (server_id, funcid) NOT IN (
        SELECT server_id, funcid FROM sample_stat_user_functions WHERE server_id = sserver_id
    );

    -- Delete obsolete values of postgres parameters
    DELETE FROM sample_settings ss
    USING (
      SELECT server_id, max(first_seen) AS first_seen, setting_scope, name
      FROM sample_settings
      WHERE server_id = sserver_id AND first_seen <= (SELECT min(sample_time) FROM samples WHERE server_id = sserver_id)
      GROUP BY server_id, setting_scope, name) AS ss_ref
    WHERE ss.server_id = ss_ref.server_id AND ss.setting_scope = ss_ref.setting_scope AND ss.name = ss_ref.name
      AND ss.first_seen < ss_ref.first_seen;
    -- Delete obsolete values of postgres parameters from previous versions of postgres on server
    DELETE FROM sample_settings
    WHERE server_id = sserver_id AND first_seen <
      (SELECT min(first_seen) FROM sample_settings WHERE server_id = sserver_id AND name = 'version' AND setting_scope = 2);

    IF (server_properties #>> '{collect_timings}')::boolean THEN
      server_properties := jsonb_set(server_properties,'{timings,delete obsolete samples,end}',to_jsonb(clock_timestamp()));
      server_properties := jsonb_set(server_properties,'{timings,total,end}',to_jsonb(clock_timestamp()));
      -- Save timing statistics of sample
      INSERT INTO sample_timings
      SELECT sserver_id, s_id, key,(value::jsonb #>> '{end}')::timestamp with time zone - (value::jsonb #>> '{start}')::timestamp with time zone as time_spent
      FROM jsonb_each_text(server_properties #> '{timings}');
    END IF;

    RETURN 0;
END;
$function$;

-- Function: take_sample
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.take_sample()
 RETURNS TABLE(server name, result text, elapsed interval)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT * FROM take_sample_subset(1,0);
$function$;

-- Function: take_sample_subset
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.take_sample_subset(sets_cnt integer DEFAULT 1, current_set integer DEFAULT 0)
 RETURNS TABLE(server name, result text, elapsed interval)
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    c_servers CURSOR FOR
      SELECT server_id,server_name FROM (
        SELECT server_id,server_name, row_number() OVER () AS srv_rn
        FROM servers WHERE enabled
        ) AS t1
      WHERE srv_rn % sets_cnt = current_set;
    server_sampleres        integer;
    etext               text := '';
    edetail             text := '';
    econtext            text := '';

    qres          RECORD;
    start_clock   timestamp (2) with time zone;
BEGIN
    IF sets_cnt IS NULL OR sets_cnt < 1 THEN
      RAISE 'sets_cnt value is invalid. Must be positive';
    END IF;
    IF current_set IS NULL OR current_set < 0 OR current_set > sets_cnt - 1 THEN
      RAISE 'current_cnt value is invalid. Must be between 0 and sets_cnt - 1';
    END IF;
    FOR qres IN c_servers LOOP
        BEGIN
            start_clock := clock_timestamp()::timestamp (2) with time zone;
            server := qres.server_name;
            server_sampleres := take_sample(qres.server_id, NULL);
            elapsed := clock_timestamp()::timestamp (2) with time zone - start_clock;
            CASE server_sampleres
              WHEN 0 THEN
                result := 'OK';
              ELSE
                result := 'FAIL';
            END CASE;
            RETURN NEXT;
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    GET STACKED DIAGNOSTICS etext = MESSAGE_TEXT,
                        edetail = PG_EXCEPTION_DETAIL,
                        econtext = PG_EXCEPTION_CONTEXT;
                    result := format (E'%s\n%s\n%s', etext, econtext, edetail);
                    elapsed := clock_timestamp()::timestamp (2) with time zone - start_clock;
                    RETURN NEXT;
                END;
        END;
    END LOOP;
    RETURN;
END;
$function$;

-- Function: tbl_top_dead_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.tbl_top_dead_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR (n_id integer, e_id integer, cnt integer) FOR
    SELECT
        sample_db.datname AS dbname,
        schemaname,
        relname,
        NULLIF(n_live_tup, 0) as n_live_tup,
        n_dead_tup as n_dead_tup,
        n_dead_tup * 100 / NULLIF(COALESCE(n_live_tup, 0) + COALESCE(n_dead_tup, 0), 0) AS dead_pct,
        last_autovacuum,
        pg_size_pretty(relsize) AS relsize
    FROM v_sample_stat_tables st
        -- Database name
        JOIN sample_stat_database sample_db USING (server_id, sample_id, datid)
    WHERE st.server_id=n_id AND NOT sample_db.datistemplate AND sample_id = e_id
        -- Min 5 MB in size
        AND st.relsize > 5 * 1024^2
        AND st.n_dead_tup > 0
    ORDER BY n_dead_tup*100/NULLIF(COALESCE(n_live_tup, 0) + COALESCE(n_dead_tup, 0), 0) DESC,
      st.datid ASC, st.relid ASC
    LIMIT cnt;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th title="Estimated number of live rows">Live</th>'
            '<th title="Estimated number of dead rows">Dead</th>'
            '<th title="Dead rows count as a percentage of total rows count">%Dead</th>'
            '<th title="Last autovacuum ran time">Last AV</th>'
            '<th title="Table size without indexes and TOAST">Size</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting vacuum stats
    FOR r_result IN c_tbl_stats(sserver_id, end_id, topn) LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.schemaname,
            r_result.relname,
            r_result.n_live_tup,
            r_result.n_dead_tup,
            r_result.dead_pct,
            r_result.last_autovacuum,
            r_result.relsize
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: tbl_top_fetch_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.tbl_top_fetch_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.dbname,st2.dbname) AS dbname,
        COALESCE(st1.tablespacename,st2.tablespacename) AS tablespacename,
        COALESCE(st1.schemaname,st2.schemaname) AS schemaname,
        COALESCE(st1.relname,st2.relname) AS relname,
        NULLIF(st1.heap_blks_fetch, 0) AS heap_blks_fetch1,
        NULLIF(st1.heap_blks_proc_pct, 0.0) AS heap_blks_proc_pct1,
        NULLIF(st1.idx_blks_fetch, 0) AS idx_blks_fetch1,
        NULLIF(st1.idx_blks_fetch_pct, 0.0) AS idx_blks_fetch_pct1,
        NULLIF(st1.toast_blks_fetch, 0) AS toast_blks_fetch1,
        NULLIF(st1.toast_blks_fetch_pct, 0.0) AS toast_blks_fetch_pct1,
        NULLIF(st1.tidx_blks_fetch, 0) AS tidx_blks_fetch1,
        NULLIF(st1.tidx_blks_fetch_pct, 0.0) AS tidx_blks_fetch_pct1,
        NULLIF(st2.heap_blks_fetch, 0) AS heap_blks_fetch2,
        NULLIF(st2.heap_blks_proc_pct, 0.0) AS heap_blks_proc_pct2,
        NULLIF(st2.idx_blks_fetch, 0) AS idx_blks_fetch2,
        NULLIF(st2.idx_blks_fetch_pct, 0.0) AS idx_blks_fetch_pct2,
        NULLIF(st2.toast_blks_fetch, 0) AS toast_blks_fetch2,
        NULLIF(st2.toast_blks_fetch_pct, 0.0) AS toast_blks_fetch_pct2,
        NULLIF(st2.tidx_blks_fetch, 0) AS tidx_blks_fetch2,
        NULLIF(st2.tidx_blks_fetch_pct, 0.0) AS tidx_blks_fetch_pct2,
        row_number() OVER (ORDER BY COALESCE(st1.heap_blks_fetch, 0) + COALESCE(st1.idx_blks_fetch, 0) +
          COALESCE(st1.toast_blks_fetch, 0) + COALESCE(st1.tidx_blks_fetch, 0) DESC NULLS LAST) rn_fetched1,
        row_number() OVER (ORDER BY COALESCE(st2.heap_blks_fetch, 0) + COALESCE(st2.idx_blks_fetch, 0) +
          COALESCE(st2.toast_blks_fetch, 0) + COALESCE(st2.tidx_blks_fetch, 0) DESC NULLS LAST) rn_fetched2
    FROM top_io_tables1 st1
        FULL OUTER JOIN top_io_tables2 st2 USING (server_id, datid, relid)
    WHERE COALESCE(st1.heap_blks_fetch, 0) + COALESCE(st1.idx_blks_fetch, 0) + COALESCE(st1.toast_blks_fetch, 0) + COALESCE(st1.tidx_blks_fetch, 0) +
        COALESCE(st2.heap_blks_fetch, 0) + COALESCE(st2.idx_blks_fetch, 0) + COALESCE(st2.toast_blks_fetch, 0) + COALESCE(st2.tidx_blks_fetch, 0) > 0
    ORDER BY
      COALESCE(st1.heap_blks_fetch, 0) + COALESCE(st1.idx_blks_fetch, 0) + COALESCE(st1.toast_blks_fetch, 0) + COALESCE(st1.tidx_blks_fetch, 0) +
      COALESCE(st2.heap_blks_fetch, 0) + COALESCE(st2.idx_blks_fetch, 0) + COALESCE(st2.toast_blks_fetch, 0) + COALESCE(st2.tidx_blks_fetch, 0) DESC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.relid,st2.relid) ASC
    ) t1
    WHERE least(
        rn_fetched1,
        rn_fetched2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Tablespace</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th rowspan="2">I</th>'
            '<th colspan="2">Heap</th>'
            '<th colspan="2">Ix</th>'
            '<th colspan="2">TOAST</th>'
            '<th colspan="2">TOAST-Ix</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of blocks fetched (read+hit) from this table">Blks</th>'
            '<th title="Heap blocks fetched for this table as a percentage of all blocks fetched in a cluster">%Total</th>'
            '<th title="Number of blocks fetched (read+hit) from all indexes on this table">Blks</th>'
            '<th title="Indexes blocks fetched for this table as a percentage of all blocks fetched in a cluster">%Total</th>'
            '<th title="Number of blocks fetched (read+hit) from this table''s TOAST table (if any)">Blks</th>'
            '<th title="TOAST blocks fetched for this table as a percentage of all blocks fetched in a cluster">%Total</th>'
            '<th title="Number of blocks fetched (read+hit) from this table''s TOAST table indexes (if any)">Blks</th>'
            '<th title="TOAST table index blocks fetched for this table as a percentage of all blocks fetched in a cluster">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.heap_blks_fetch1,
            round(r_result.heap_blks_proc_pct1,2),
            r_result.idx_blks_fetch1,
            round(r_result.idx_blks_fetch_pct1,2),
            r_result.toast_blks_fetch1,
            round(r_result.toast_blks_fetch_pct1,2),
            r_result.tidx_blks_fetch1,
            round(r_result.tidx_blks_fetch_pct1,2),
            r_result.heap_blks_fetch2,
            round(r_result.heap_blks_proc_pct2,2),
            r_result.idx_blks_fetch2,
            round(r_result.idx_blks_fetch_pct2,2),
            r_result.toast_blks_fetch2,
            round(r_result.toast_blks_fetch_pct2,2),
            r_result.tidx_blks_fetch2,
            round(r_result.tidx_blks_fetch_pct2,2)
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: tbl_top_fetch_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.tbl_top_fetch_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        tablespacename,
        schemaname,
        relname,
        NULLIF(heap_blks_fetch, 0) as heap_blks_fetch,
        NULLIF(heap_blks_proc_pct, 0.0) as heap_blks_proc_pct,
        NULLIF(idx_blks_fetch, 0) as idx_blks_fetch,
        NULLIF(idx_blks_fetch_pct, 0.0) as idx_blks_fetch_pct,
        NULLIF(toast_blks_fetch, 0) as toast_blks_fetch,
        NULLIF(toast_blks_fetch_pct, 0.0) as toast_blks_fetch_pct,
        NULLIF(tidx_blks_fetch, 0) as tidx_blks_fetch,
        NULLIF(tidx_blks_fetch_pct, 0.0) as tidx_blks_fetch_pct
    FROM top_io_tables
    WHERE COALESCE(heap_blks_fetch, 0) + COALESCE(idx_blks_fetch, 0) + COALESCE(toast_blks_fetch, 0) + COALESCE(tidx_blks_fetch, 0) > 0
    ORDER BY
      COALESCE(heap_blks_fetch, 0) + COALESCE(idx_blks_fetch, 0) + COALESCE(toast_blks_fetch, 0) + COALESCE(tidx_blks_fetch, 0) DESC,
      datid ASC,
      relid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Tablespace</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th colspan="2">Heap</th>'
            '<th colspan="2">Ix</th>'
            '<th colspan="2">TOAST</th>'
            '<th colspan="2">TOAST-Ix</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of blocks fetched (read+hit) from this table">Blks</th>'
            '<th title="Heap blocks fetched for this table as a percentage of all blocks fetched in a cluster">%Total</th>'
            '<th title="Number of blocks fetched (read+hit) from all indexes on this table">Blks</th>'
            '<th title="Indexes blocks fetched for this table as a percentage of all blocks fetched in a cluster">%Total</th>'
            '<th title="Number of blocks fetched (read+hit) from this table''s TOAST table (if any)">Blks</th>'
            '<th title="TOAST blocks fetched for this table as a percentage of all blocks fetched in a cluster">%Total</th>'
            '<th title="Number of blocks fetched (read+hit) from this table''s TOAST table indexes (if any)">Blks</th>'
            '<th title="TOAST table index blocks fetched for this table as a percentage of all blocks fetched in a cluster">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.heap_blks_fetch,
            round(r_result.heap_blks_proc_pct,2),
            r_result.idx_blks_fetch,
            round(r_result.idx_blks_fetch_pct,2),
            r_result.toast_blks_fetch,
            round(r_result.toast_blks_fetch_pct,2),
            r_result.tidx_blks_fetch,
            round(r_result.tidx_blks_fetch_pct,2)
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: tbl_top_io_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.tbl_top_io_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.dbname,st2.dbname) AS dbname,
        COALESCE(st1.schemaname,st2.schemaname) AS schemaname,
        COALESCE(st1.relname,st2.relname) AS relname,
        NULLIF(st1.heap_blks_read, 0) AS heap_blks_read1,
        NULLIF(st1.heap_blks_read_pct, 0.0) AS heap_blks_read_pct1,
        NULLIF(st1.idx_blks_read, 0) AS idx_blks_read1,
        NULLIF(st1.idx_blks_read_pct, 0.0) AS idx_blks_read_pct1,
        NULLIF(st1.toast_blks_read, 0) AS toast_blks_read1,
        NULLIF(st1.toast_blks_read_pct, 0.0) AS toast_blks_read_pct1,
        NULLIF(st1.tidx_blks_read, 0) AS tidx_blks_read1,
        NULLIF(st1.tidx_blks_read_pct, 0.0) AS tidx_blks_read_pct1,
        100.0 - (COALESCE(st1.heap_blks_read, 0) + COALESCE(st1.idx_blks_read, 0) +
          COALESCE(st1.toast_blks_read, 0) + COALESCE(st1.tidx_blks_read, 0)) * 100.0 /
        NULLIF(st1.heap_blks_fetch + st1.idx_blks_fetch +
          st1.toast_blks_fetch + st1.tidx_blks_fetch, 0) as hit_pct1,
        NULLIF(st2.heap_blks_read, 0) AS heap_blks_read2,
        NULLIF(st2.heap_blks_read_pct, 0.0) AS heap_blks_read_pct2,
        NULLIF(st2.idx_blks_read, 0) AS idx_blks_read2,
        NULLIF(st2.idx_blks_read_pct, 0.0) AS idx_blks_read_pct2,
        NULLIF(st2.toast_blks_read, 0) AS toast_blks_read2,
        NULLIF(st2.toast_blks_read_pct, 0.0) AS toast_blks_read_pct2,
        NULLIF(st2.tidx_blks_read, 0) AS tidx_blks_read2,
        NULLIF(st2.tidx_blks_read_pct, 0.0) AS tidx_blks_read_pct2,
        100.0 - (COALESCE(st2.heap_blks_read, 0) + COALESCE(st2.idx_blks_read, 0) +
          COALESCE(st2.toast_blks_read, 0) + COALESCE(st2.tidx_blks_read, 0)) * 100.0 /
        NULLIF(st2.heap_blks_fetch + st2.idx_blks_fetch +
          st2.toast_blks_fetch + st2.tidx_blks_fetch, 0) as hit_pct2,
        row_number() OVER (ORDER BY COALESCE(st1.heap_blks_read, 0) + COALESCE(st1.idx_blks_read, 0) +
          COALESCE(st1.toast_blks_read, 0) + COALESCE(st1.tidx_blks_read, 0) DESC NULLS LAST) rn_read1,
        row_number() OVER (ORDER BY COALESCE(st2.heap_blks_read, 0) + COALESCE(st2.idx_blks_read, 0) +
          COALESCE(st2.toast_blks_read, 0) + COALESCE(st2.tidx_blks_read, 0) DESC NULLS LAST) rn_read2
    FROM top_io_tables1 st1
        FULL OUTER JOIN top_io_tables2 st2 USING (server_id, datid, relid)
    WHERE COALESCE(st1.heap_blks_read, 0) + COALESCE(st1.idx_blks_read, 0) +
          COALESCE(st1.toast_blks_read, 0) + COALESCE(st1.tidx_blks_read, 0) +
          COALESCE(st2.heap_blks_read, 0) + COALESCE(st2.idx_blks_read, 0) +
          COALESCE(st2.toast_blks_read, 0) + COALESCE(st2.tidx_blks_read, 0) > 0
    ORDER BY
      COALESCE(st1.heap_blks_read, 0) + COALESCE(st1.idx_blks_read, 0) +
      COALESCE(st1.toast_blks_read, 0) + COALESCE(st1.tidx_blks_read, 0) +
      COALESCE(st2.heap_blks_read, 0) + COALESCE(st2.idx_blks_read, 0) +
      COALESCE(st2.toast_blks_read, 0) + COALESCE(st2.tidx_blks_read, 0) DESC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.relid,st2.relid) ASC
    ) t1
    WHERE least(
        rn_read1,
        rn_read2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th rowspan="2">I</th>'
            '<th colspan="2">Heap</th>'
            '<th colspan="2">Ix</th>'
            '<th colspan="2">TOAST</th>'
            '<th colspan="2">TOAST-Ix</th>'
            '<th rowspan="2" title="Number of heap, indexes, toast and toast index blocks '
              'fetched from shared buffers as a percentage of all their blocks fetched from '
              'shared buffers and file system">Hit(%)</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of disk blocks read from this table">Blks</th>'
            '<th title="Heap block reads for this table as a percentage of all blocks read in a cluster">%Total</th>'
            '<th title="Number of disk blocks read from all indexes on this table">Blks</th>'
            '<th title="Indexes block reads for this table as a percentage of all blocks read in a cluster">%Total</th>'
            '<th title="Number of disk blocks read from this table''s TOAST table (if any)">Blks</th>'
            '<th title="TOAST block reads for this table as a percentage of all blocks read in a cluster">%Total</th>'
            '<th title="Number of disk blocks read from this table''s TOAST table indexes (if any)">Blks</th>'
            '<th title="TOAST table index block reads for this table as a percentage of all blocks read in a cluster">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.schemaname,
            r_result.relname,
            r_result.heap_blks_read1,
            round(r_result.heap_blks_read_pct1,2),
            r_result.idx_blks_read1,
            round(r_result.idx_blks_read_pct1,2),
            r_result.toast_blks_read1,
            round(r_result.toast_blks_read_pct1,2),
            r_result.tidx_blks_read1,
            round(r_result.tidx_blks_read_pct1,2),
            round(r_result.hit_pct1,2),
            r_result.heap_blks_read2,
            round(r_result.heap_blks_read_pct2,2),
            r_result.idx_blks_read2,
            round(r_result.idx_blks_read_pct2,2),
            r_result.toast_blks_read2,
            round(r_result.toast_blks_read_pct2,2),
            r_result.tidx_blks_read2,
            round(r_result.tidx_blks_read_pct2,2),
            round(r_result.hit_pct2,2)
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: tbl_top_io_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.tbl_top_io_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        tablespacename,
        schemaname,
        relname,
        NULLIF(heap_blks_read, 0) as heap_blks_read,
        NULLIF(heap_blks_read_pct, 0.0) as heap_blks_read_pct,
        NULLIF(idx_blks_read, 0) as idx_blks_read,
        NULLIF(idx_blks_read_pct, 0.0) as idx_blks_read_pct,
        NULLIF(toast_blks_read, 0) as toast_blks_read,
        NULLIF(toast_blks_read_pct, 0.0) as toast_blks_read_pct,
        NULLIF(tidx_blks_read, 0) as tidx_blks_read,
        NULLIF(tidx_blks_read_pct, 0.0) as tidx_blks_read_pct,
        100.0 - (COALESCE(heap_blks_read, 0) + COALESCE(idx_blks_read, 0) +
          COALESCE(toast_blks_read, 0) + COALESCE(tidx_blks_read, 0)) * 100.0 /
        NULLIF(heap_blks_fetch + idx_blks_fetch +
          toast_blks_fetch + tidx_blks_fetch, 0) as hit_pct
    FROM top_io_tables
    WHERE COALESCE(heap_blks_read, 0) + COALESCE(idx_blks_read, 0) + COALESCE(toast_blks_read, 0) + COALESCE(tidx_blks_read, 0) > 0
    ORDER BY
      COALESCE(heap_blks_read, 0) + COALESCE(idx_blks_read, 0) + COALESCE(toast_blks_read, 0) + COALESCE(tidx_blks_read, 0) DESC,
      datid ASC,
      relid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Tablespace</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th colspan="2">Heap</th>'
            '<th colspan="2">Ix</th>'
            '<th colspan="2">TOAST</th>'
            '<th colspan="2">TOAST-Ix</th>'
            '<th rowspan="2" title="Number of heap, indexes, toast and toast index blocks '
              'fetched from shared buffers as a percentage of all their blocks fetched from '
              'shared buffers and file system">Hit(%)</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of disk blocks read from this table">Blks</th>'
            '<th title="Heap block reads for this table as a percentage of all blocks read in a cluster">%Total</th>'
            '<th title="Number of disk blocks read from all indexes on this table">Blks</th>'
            '<th title="Indexes block reads for this table as a percentage of all blocks read in a cluster">%Total</th>'
            '<th title="Number of disk blocks read from this table''s TOAST table (if any)">Blks</th>'
            '<th title="TOAST block reads for this table as a percentage of all blocks read in a cluster">%Total</th>'
            '<th title="Number of disk blocks read from this table''s TOAST table indexes (if any)">Blks</th>'
            '<th title="TOAST table index block reads for this table as a percentage of all blocks read in a cluster">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.heap_blks_read,
            round(r_result.heap_blks_read_pct,2),
            r_result.idx_blks_read,
            round(r_result.idx_blks_read_pct,2),
            r_result.toast_blks_read,
            round(r_result.toast_blks_read_pct,2),
            r_result.tidx_blks_read,
            round(r_result.tidx_blks_read_pct,2),
            round(r_result.hit_pct,2)
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: tbl_top_mods_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.tbl_top_mods_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR (n_id integer, e_id integer, cnt integer) FOR
    SELECT
        sample_db.datname AS dbname,
        schemaname,
        relname,
        n_live_tup,
        n_dead_tup,
        n_mod_since_analyze AS mods,
        n_mod_since_analyze*100/NULLIF(COALESCE(n_live_tup, 0) + COALESCE(n_dead_tup, 0), 0) AS mods_pct,
        last_autoanalyze,
        pg_size_pretty(relsize) AS relsize
    FROM v_sample_stat_tables st
        -- Database name and existance condition
        JOIN sample_stat_database sample_db USING (server_id, sample_id, datid)
    WHERE st.server_id = n_id AND NOT sample_db.datistemplate AND sample_id = e_id
        AND st.relkind IN ('r','m')
        -- Min 5 MB in size
        AND relsize > 5 * 1024^2
        AND n_mod_since_analyze > 0
        AND n_live_tup + n_dead_tup > 0
    ORDER BY n_mod_since_analyze*100/NULLIF(COALESCE(n_live_tup, 0) + COALESCE(n_dead_tup, 0), 0) DESC,
      st.datid ASC, st.relid ASC
    LIMIT cnt;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th title="Estimated number of live rows">Live</th>'
            '<th title="Estimated number of dead rows">Dead</th>'
            '<th title="Estimated number of rows modified since this table was last analyzed">Mod</th>'
            '<th title="Modified rows count as a percentage of total rows count">%Mod</th>'
            '<th title="Last autoanalyze ran time">Last AA</th>'
            '<th title="Table size without indexes and TOAST">Size</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting vacuum stats
    FOR r_result IN c_tbl_stats(sserver_id, end_id, topn) LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.schemaname,
            r_result.relname,
            r_result.n_live_tup,
            r_result.n_dead_tup,
            r_result.mods,
            r_result.mods_pct,
            r_result.last_autoanalyze,
            r_result.relsize
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_analyzed_tables_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_analyzed_tables_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(tbl1.dbname,tbl2.dbname) as dbname,
        COALESCE(tbl1.tablespacename,tbl2.tablespacename) AS tablespacename,
        COALESCE(tbl1.schemaname,tbl2.schemaname) as schemaname,
        COALESCE(tbl1.relname,tbl2.relname) as relname,
        NULLIF(tbl1.analyze_count, 0) as analyze_count1,
        NULLIF(tbl1.autoanalyze_count, 0) as autoanalyze_count1,
        NULLIF(tbl1.n_tup_ins, 0) as n_tup_ins1,
        NULLIF(tbl1.n_tup_upd, 0) as n_tup_upd1,
        NULLIF(tbl1.n_tup_del, 0) as n_tup_del1,
        NULLIF(tbl1.n_tup_hot_upd, 0) as n_tup_hot_upd1,
        NULLIF(tbl2.analyze_count, 0) as analyze_count2,
        NULLIF(tbl2.autoanalyze_count, 0) as autoanalyze_count2,
        NULLIF(tbl2.n_tup_ins, 0) as n_tup_ins2,
        NULLIF(tbl2.n_tup_upd, 0) as n_tup_upd2,
        NULLIF(tbl2.n_tup_del, 0) as n_tup_del2,
        NULLIF(tbl2.n_tup_hot_upd, 0) as n_tup_hot_upd2,
        row_number() OVER (ORDER BY COALESCE(tbl1.analyze_count, 0) + COALESCE(tbl1.autoanalyze_count, 0) DESC) as rn_analyze1,
        row_number() OVER (ORDER BY COALESCE(tbl2.analyze_count, 0) + COALESCE(tbl2.autoanalyze_count, 0) DESC) as rn_analyze2
    FROM top_tables1 tbl1
        FULL OUTER JOIN top_tables2 tbl2 USING (server_id,datid,relid)
    WHERE COALESCE(tbl1.analyze_count, 0) + COALESCE(tbl1.autoanalyze_count, 0) +
          COALESCE(tbl2.analyze_count, 0) + COALESCE(tbl2.autoanalyze_count, 0) > 0
    ORDER BY COALESCE(tbl1.analyze_count, 0) + COALESCE(tbl1.autoanalyze_count, 0) +
          COALESCE(tbl2.analyze_count, 0) + COALESCE(tbl2.autoanalyze_count, 0) DESC,
      COALESCE(tbl1.datid,tbl2.datid) ASC,
      COALESCE(tbl1.relid,tbl2.relid) ASC
    ) t1
    WHERE least(
        rn_analyze1,
        rn_analyze2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th>I</th>'
            '<th title="Number of times this table has been manually analyzed">Analyze count</th>'
            '<th title="Number of times this table has been analyzed by the autovacuum daemon">Autoanalyze count</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.analyze_count1,
            r_result.autoanalyze_count1,
            r_result.n_tup_ins1,
            r_result.n_tup_upd1,
            r_result.n_tup_del1,
            r_result.n_tup_hot_upd1,
            r_result.analyze_count2,
            r_result.autoanalyze_count2,
            r_result.n_tup_ins2,
            r_result.n_tup_upd2,
            r_result.n_tup_del2,
            r_result.n_tup_hot_upd2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_analyzed_tables_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_analyzed_tables_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        top.tablespacename,
        top.schemaname,
        top.relname,
        NULLIF(top.analyze_count, 0) as analyze_count,
        NULLIF(top.autoanalyze_count, 0) as autoanalyze_count,
        NULLIF(top.n_tup_ins, 0) as n_tup_ins,
        NULLIF(top.n_tup_upd, 0) as n_tup_upd,
        NULLIF(top.n_tup_del, 0) as n_tup_del,
        NULLIF(top.n_tup_hot_upd, 0) as n_tup_hot_upd
    FROM top_tables top
    WHERE COALESCE(top.analyze_count, 0) + COALESCE(top.autoanalyze_count, 0) > 0
    ORDER BY COALESCE(top.analyze_count, 0) + COALESCE(top.autoanalyze_count, 0) DESC,
      top.datid ASC,
      top.relid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN

    -- Populate templates
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th title="Number of times this table has been manually analyzed">Analyze count</th>'
            '<th title="Number of times this table has been analyzed by the autovacuum daemon">Autoanalyze count</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'rel_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
    );

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
      report := report||format(
          jtab_tpl #>> ARRAY['rel_tpl'],
          r_result.dbname,
          r_result.tablespacename,
          r_result.schemaname,
          r_result.relname,
          r_result.analyze_count,
          r_result.autoanalyze_count,
          r_result.n_tup_ins,
          r_result.n_tup_upd,
          r_result.n_tup_del,
          r_result.n_tup_hot_upd
      );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_cpu_time_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_cpu_time_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(kc1.datid,kc2.datid) as datid,
        COALESCE(kc1.userid,kc2.userid) as userid,
        COALESCE(kc1.queryid,kc2.queryid) as queryid,
        COALESCE(kc1.dbname,kc2.dbname) as dbname,
        NULLIF(kc1.plan_user_time, 0.0) as plan_user_time1,
        NULLIF(kc1.exec_user_time, 0.0) as exec_user_time1,
        NULLIF(kc1.user_time_pct, 0.0) as user_time_pct1,
        NULLIF(kc1.plan_system_time, 0.0) as plan_system_time1,
        NULLIF(kc1.exec_system_time, 0.0) as exec_system_time1,
        NULLIF(kc1.system_time_pct, 0.0) as system_time_pct1,
        NULLIF(kc2.plan_user_time, 0.0) as plan_user_time2,
        NULLIF(kc2.exec_user_time, 0.0) as exec_user_time2,
        NULLIF(kc2.user_time_pct, 0.0) as user_time_pct2,
        NULLIF(kc2.plan_system_time, 0.0) as plan_system_time2,
        NULLIF(kc2.exec_system_time, 0.0) as exec_system_time2,
        NULLIF(kc2.system_time_pct, 0.0) as system_time_pct2,
        row_number() over (ORDER BY COALESCE(kc1.exec_user_time, 0.0) + COALESCE(kc1.exec_system_time, 0.0) DESC NULLS LAST) as time1,
        row_number() over (ORDER BY COALESCE(kc2.exec_user_time, 0.0) + COALESCE(kc2.exec_system_time, 0.0) DESC NULLS LAST) as time2
    FROM top_kcache_statements1 kc1
        FULL OUTER JOIN top_kcache_statements2 kc2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(kc1.plan_user_time, 0.0) + COALESCE(kc2.plan_user_time, 0.0) +
        COALESCE(kc1.plan_system_time, 0.0) + COALESCE(kc2.plan_system_time, 0.0) +
        COALESCE(kc1.exec_user_time, 0.0) + COALESCE(kc2.exec_user_time, 0.0) +
        COALESCE(kc1.exec_system_time, 0.0) + COALESCE(kc2.exec_system_time, 0.0) > 0
    ORDER BY COALESCE(kc1.plan_user_time, 0.0) + COALESCE(kc2.plan_user_time, 0.0) +
        COALESCE(kc1.plan_system_time, 0.0) + COALESCE(kc2.plan_system_time, 0.0) +
        COALESCE(kc1.exec_user_time, 0.0) + COALESCE(kc2.exec_user_time, 0.0) +
        COALESCE(kc1.exec_system_time, 0.0) + COALESCE(kc2.exec_system_time, 0.0) DESC,
        COALESCE(kc1.datid,kc2.datid),
        COALESCE(kc1.userid,kc2.userid),
        COALESCE(kc1.queryid,kc2.queryid)
        ) t1
    WHERE least(
        time1,
        time2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
        '<tr>'
          '<th rowspan="2">Query ID</th>'
          '<th rowspan="2">Database</th>'
          '<th rowspan="2">I</th>'
          '<th title="Userspace CPU" colspan="{cputime_colspan}">User Time</th>'
          '<th title="Kernelspace CPU" colspan="{cputime_colspan}">System Time</th>'
        '</tr>'
        '<tr>'
          '{user_plan_time_hdr}'
          '<th title="User CPU time elapsed during execution">Exec (s)</th>'
          '<th title="User CPU time elapsed by this statement as a percentage of total user CPU time">%Total</th>'
          '{system_plan_time_hdr}'
          '<th title="System CPU time elapsed during execution">Exec (s)</th>'
          '<th title="System CPU time elapsed by this statement as a percentage of total system CPU time">%Total</th>'
        '</tr>'
        '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {label} {title1}>1</td>'
          '{user_plan_time_tpl1}'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '{system_plan_time_tpl1}'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '{user_plan_time_tpl2}'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '{system_plan_time_tpl2}'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'user_plan_time_hdr',
        '<th title="User CPU time elapsed during planning">Plan (s)</th>',
      'system_plan_time_hdr',
        '<th title="System CPU time elapsed during planning">Plan (s)</th>',
      'user_plan_time_tpl1',
        '<td {value}>%5$s</td>',
      'system_plan_time_tpl1',
        '<td {value}>%8$s</td>',
      'user_plan_time_tpl2',
        '<td {value}>%11$s</td>',
      'system_plan_time_tpl2',
        '<td {value}>%14$s</td>'
    );
    -- Conditional template
    IF jsonb_extract_path_text(jreportset, 'report_features', 'rusage.planstats')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{cputime_colspan}','3')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{user_plan_time_hdr}',jtab_tpl->>'user_plan_time_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{system_plan_time_hdr}',jtab_tpl->>'system_plan_time_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{user_plan_time_tpl1}',jtab_tpl->>'user_plan_time_tpl1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{system_plan_time_tpl1}',jtab_tpl->>'system_plan_time_tpl1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{user_plan_time_tpl2}',jtab_tpl->>'user_plan_time_tpl2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{system_plan_time_tpl2}',jtab_tpl->>'system_plan_time_tpl2')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{cputime_colspan}','2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{user_plan_time_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{system_plan_time_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{user_plan_time_tpl1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{system_plan_time_tpl1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{user_plan_time_tpl2}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{system_plan_time_tpl2}','')));
    END IF;
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL,
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.plan_user_time1 AS numeric),2),
            round(CAST(r_result.exec_user_time1 AS numeric),2),
            round(CAST(r_result.user_time_pct1 AS numeric),2),
            round(CAST(r_result.plan_system_time1 AS numeric),2),
            round(CAST(r_result.exec_system_time1 AS numeric),2),
            round(CAST(r_result.system_time_pct1 AS numeric),2),
            round(CAST(r_result.plan_user_time2 AS numeric),2),
            round(CAST(r_result.exec_user_time2 AS numeric),2),
            round(CAST(r_result.user_time_pct2 AS numeric),2),
            round(CAST(r_result.plan_system_time2 AS numeric),2),
            round(CAST(r_result.exec_system_time2 AS numeric),2),
            round(CAST(r_result.system_time_pct2 AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_cpu_time_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_cpu_time_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR FOR
    SELECT
        kc.datid as datid,
        kc.userid as userid,
        kc.queryid as queryid,
        kc.dbname,
        NULLIF(kc.plan_user_time, 0.0) as plan_user_time,
        NULLIF(kc.exec_user_time, 0.0) as exec_user_time,
        NULLIF(kc.user_time_pct, 0.0) as user_time_pct,
        NULLIF(kc.plan_system_time, 0.0) as plan_system_time,
        NULLIF(kc.exec_system_time, 0.0) as exec_system_time,
        NULLIF(kc.system_time_pct, 0.0) as system_time_pct
    FROM top_kcache_statements kc
    WHERE COALESCE(kc.plan_user_time, 0.0) + COALESCE(kc.plan_system_time, 0.0) +
      COALESCE(kc.exec_user_time, 0.0) + COALESCE(kc.exec_system_time, 0.0) > 0
    ORDER BY COALESCE(kc.plan_user_time, 0.0) + COALESCE(kc.plan_system_time, 0.0) +
      COALESCE(kc.exec_user_time, 0.0) + COALESCE(kc.exec_system_time, 0.0) DESC,
      kc.datid,
      kc.userid,
      kc.queryid
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
        '<tr>'
          '<th rowspan="2">Query ID</th>'
          '<th rowspan="2">Database</th>'
          '<th title="Userspace CPU" colspan="{cputime_colspan}">User Time</th>'
          '<th title="Kernelspace CPU" colspan="{cputime_colspan}">System Time</th>'
        '</tr>'
        '<tr>'
          '{user_plan_time_hdr}'
          '<th title="User CPU time elapsed during execution">Exec (s)</th>'
          '<th title="User CPU time elapsed by this statement as a percentage of total user CPU time">%Total</th>'
          '{system_plan_time_hdr}'
          '<th title="System CPU time elapsed during execution">Exec (s)</th>'
          '<th title="System CPU time elapsed by this statement as a percentage of total system CPU time">%Total</th>'
        '</tr>'
        '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%4$s</td>'
          '{user_plan_time_tpl}'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '{system_plan_time_tpl}'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
        '</tr>',
      'user_plan_time_hdr',
        '<th title="User CPU time elapsed during planning">Plan (s)</th>',
      'system_plan_time_hdr',
        '<th title="System CPU time elapsed during planning">Plan (s)</th>',
      'user_plan_time_tpl',
        '<td {value}>%5$s</td>',
      'system_plan_time_tpl',
        '<td {value}>%8$s</td>'
    );
    -- Conditional template
    IF jsonb_extract_path_text(jreportset, 'report_features', 'rusage.planstats')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{cputime_colspan}','3')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{user_plan_time_hdr}',jtab_tpl->>'user_plan_time_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{system_plan_time_hdr}',jtab_tpl->>'system_plan_time_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{user_plan_time_tpl}',jtab_tpl->>'user_plan_time_tpl')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{system_plan_time_tpl}',jtab_tpl->>'system_plan_time_tpl')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{cputime_colspan}','2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{user_plan_time_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{system_plan_time_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{user_plan_time_tpl}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{system_plan_time_tpl}','')));
    END IF;
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL,
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.plan_user_time AS numeric),2),
            round(CAST(r_result.exec_user_time AS numeric),2),
            round(CAST(r_result.user_time_pct AS numeric),2),
            round(CAST(r_result.plan_system_time AS numeric),2),
            round(CAST(r_result.exec_system_time AS numeric),2),
            round(CAST(r_result.system_time_pct AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_dml_tables_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_dml_tables_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(tbl1.dbname,tbl2.dbname) AS dbname,
        COALESCE(tbl1.tablespacename,tbl2.tablespacename) AS tablespacename,
        COALESCE(tbl1.schemaname,tbl2.schemaname) AS schemaname,
        COALESCE(tbl1.relname,tbl2.relname) AS relname,
        NULLIF(tbl1.n_tup_ins, 0) AS n_tup_ins1,
        NULLIF(tbl1.n_tup_upd, 0) AS n_tup_upd1,
        NULLIF(tbl1.n_tup_del, 0) AS n_tup_del1,
        NULLIF(tbl1.n_tup_hot_upd, 0) AS n_tup_hot_upd1,
        NULLIF(tbl1.toastn_tup_ins, 0) AS toastn_tup_ins1,
        NULLIF(tbl1.toastn_tup_upd, 0) AS toastn_tup_upd1,
        NULLIF(tbl1.toastn_tup_del, 0) AS toastn_tup_del1,
        NULLIF(tbl1.toastn_tup_hot_upd, 0) AS toastn_tup_hot_upd1,
        NULLIF(tbl2.n_tup_ins, 0) AS n_tup_ins2,
        NULLIF(tbl2.n_tup_upd, 0) AS n_tup_upd2,
        NULLIF(tbl2.n_tup_del, 0) AS n_tup_del2,
        NULLIF(tbl2.n_tup_hot_upd, 0) AS n_tup_hot_upd2,
        NULLIF(tbl2.toastn_tup_ins, 0) AS toastn_tup_ins2,
        NULLIF(tbl2.toastn_tup_upd, 0) AS toastn_tup_upd2,
        NULLIF(tbl2.toastn_tup_del, 0) AS toastn_tup_del2,
        NULLIF(tbl2.toastn_tup_hot_upd, 0) AS toastn_tup_hot_upd2,
        row_number() OVER (ORDER BY COALESCE(tbl1.n_tup_ins, 0) + COALESCE(tbl1.n_tup_upd, 0) + COALESCE(tbl1.n_tup_del, 0) +
          COALESCE(tbl1.toastn_tup_ins, 0) + COALESCE(tbl1.toastn_tup_upd, 0) + COALESCE(tbl1.toastn_tup_del, 0) DESC NULLS LAST) AS rn_dml1,
        row_number() OVER (ORDER BY COALESCE(tbl2.n_tup_ins, 0) + COALESCE(tbl2.n_tup_upd, 0) + COALESCE(tbl2.n_tup_del, 0) +
          COALESCE(tbl2.toastn_tup_ins, 0) + COALESCE(tbl2.toastn_tup_upd, 0) + COALESCE(tbl2.toastn_tup_del, 0) DESC NULLS LAST) AS rn_dml2
    FROM top_tables1 tbl1
        FULL OUTER JOIN top_tables2 tbl2 USING (server_id, datid, relid)
    WHERE COALESCE(tbl1.n_tup_ins, 0) + COALESCE(tbl1.n_tup_upd, 0) + COALESCE(tbl1.n_tup_del, 0) +
        COALESCE(tbl1.toastn_tup_ins, 0) + COALESCE(tbl1.toastn_tup_upd, 0) + COALESCE(tbl1.toastn_tup_del, 0) +
        COALESCE(tbl2.n_tup_ins, 0) + COALESCE(tbl2.n_tup_upd, 0) + COALESCE(tbl2.n_tup_del, 0) +
        COALESCE(tbl2.toastn_tup_ins, 0) + COALESCE(tbl2.toastn_tup_upd, 0) + COALESCE(tbl2.toastn_tup_del, 0) > 0
    ORDER BY COALESCE(tbl1.n_tup_ins, 0) + COALESCE(tbl1.n_tup_upd, 0) + COALESCE(tbl1.n_tup_del, 0) +
          COALESCE(tbl1.toastn_tup_ins, 0) + COALESCE(tbl1.toastn_tup_upd, 0) + COALESCE(tbl1.toastn_tup_del, 0) +
          COALESCE(tbl2.n_tup_ins, 0) + COALESCE(tbl2.n_tup_upd, 0) + COALESCE(tbl2.n_tup_del, 0) +
          COALESCE(tbl2.toastn_tup_ins, 0) + COALESCE(tbl2.toastn_tup_upd, 0) + COALESCE(tbl2.toastn_tup_del, 0) DESC,
      COALESCE(tbl1.datid,tbl2.datid) ASC,
      COALESCE(tbl1.relid,tbl2.relid) ASC
    ) t1
    WHERE least(
        rn_dml1,
        rn_dml2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Tablespace</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th rowspan="2">I</th>'
            '<th colspan="4">Table</th>'
            '<th colspan="4">TOAST</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.n_tup_ins1,
            r_result.n_tup_upd1,
            r_result.n_tup_del1,
            r_result.n_tup_hot_upd1,
            r_result.toastn_tup_ins1,
            r_result.toastn_tup_upd1,
            r_result.toastn_tup_del1,
            r_result.toastn_tup_hot_upd1,
            r_result.n_tup_ins2,
            r_result.n_tup_upd2,
            r_result.n_tup_del2,
            r_result.n_tup_hot_upd2,
            r_result.toastn_tup_ins2,
            r_result.toastn_tup_upd2,
            r_result.toastn_tup_del2,
            r_result.toastn_tup_hot_upd2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_dml_tables_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_dml_tables_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        tablespacename,
        schemaname,
        relname,
        reltoastrelid,
        NULLIF(seq_scan, 0) as seq_scan,
        NULLIF(seq_tup_read, 0) as seq_tup_read,
        NULLIF(idx_scan, 0) as idx_scan,
        NULLIF(idx_tup_fetch, 0) as idx_tup_fetch,
        NULLIF(n_tup_ins, 0) as n_tup_ins,
        NULLIF(n_tup_upd, 0) as n_tup_upd,
        NULLIF(n_tup_del, 0) as n_tup_del,
        NULLIF(n_tup_hot_upd, 0) as n_tup_hot_upd,
        NULLIF(toastseq_scan, 0) as toastseq_scan,
        NULLIF(toastseq_tup_read, 0) as toastseq_tup_read,
        NULLIF(toastidx_scan, 0) as toastidx_scan,
        NULLIF(toastidx_tup_fetch, 0) as toastidx_tup_fetch,
        NULLIF(toastn_tup_ins, 0) as toastn_tup_ins,
        NULLIF(toastn_tup_upd, 0) as toastn_tup_upd,
        NULLIF(toastn_tup_del, 0) as toastn_tup_del,
        NULLIF(toastn_tup_hot_upd, 0) as toastn_tup_hot_upd
    FROM top_tables
    WHERE COALESCE(n_tup_ins, 0) + COALESCE(n_tup_upd, 0) + COALESCE(n_tup_del, 0) +
      COALESCE(toastn_tup_ins, 0) + COALESCE(toastn_tup_upd, 0) + COALESCE(toastn_tup_del, 0) > 0
    ORDER BY COALESCE(n_tup_ins, 0) + COALESCE(n_tup_upd, 0) + COALESCE(n_tup_del, 0) +
      COALESCE(toastn_tup_ins, 0) + COALESCE(toastn_tup_upd, 0) + COALESCE(toastn_tup_del, 0) DESC,
      datid ASC,
      relid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN

    -- Populate templates
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
            '<th title="Number of sequential scans initiated on this table">SeqScan</th>'
            '<th title="Number of live rows fetched by sequential scans">SeqFet</th>'
            '<th title="Number of index scans initiated on this table">IxScan</th>'
            '<th title="Number of live rows fetched by index scans">IxFet</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'rel_tpl',
        '<tr {reltr}>'
          '<td {reltdhdr}>%s</td>'
          '<td {reltdhdr}>%s</td>'
          '<td {reltdhdr}>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'rel_wtoast_tpl',
        '<tr {reltr}>'
          '<td {reltdspanhdr}>%s</td>'
          '<td {reltdspanhdr}>%s</td>'
          '<td {reltdspanhdr}>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {toasttr}>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
        IF r_result.reltoastrelid IS NULL THEN
          report := report||format(
              jtab_tpl #>> ARRAY['rel_tpl'],
              r_result.dbname,
              r_result.tablespacename,
              r_result.schemaname,
              r_result.relname,
              r_result.n_tup_ins,
              r_result.n_tup_upd,
              r_result.n_tup_del,
              r_result.n_tup_hot_upd,
              r_result.seq_scan,
              r_result.seq_tup_read,
              r_result.idx_scan,
              r_result.idx_tup_fetch
          );
        ELSE
          report := report||format(
              jtab_tpl #>> ARRAY['rel_wtoast_tpl'],
              r_result.dbname,
              r_result.tablespacename,
              r_result.schemaname,
              r_result.relname,
              r_result.n_tup_ins,
              r_result.n_tup_upd,
              r_result.n_tup_del,
              r_result.n_tup_hot_upd,
              r_result.seq_scan,
              r_result.seq_tup_read,
              r_result.idx_scan,
              r_result.idx_tup_fetch,
              r_result.relname||'(TOAST)',
              r_result.toastn_tup_ins,
              r_result.toastn_tup_upd,
              r_result.toastn_tup_del,
              r_result.toastn_tup_hot_upd,
              r_result.toastseq_scan,
              r_result.toastseq_tup_read,
              r_result.toastidx_scan,
              r_result.toastidx_tup_fetch
          );
        END IF;
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_elapsed_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_elapsed_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.total_time_pct, 0.0) as total_time_pct1,
        NULLIF(st1.total_plan_time, 0.0) as total_plan_time1,
        NULLIF(st1.total_exec_time, 0.0) as total_exec_time1,
        NULLIF(st1.blk_read_time, 0.0) as blk_read_time1,
        NULLIF(st1.blk_write_time, 0.0) as blk_write_time1,
        NULLIF(st1.user_time, 0.0) as user_time1,
        NULLIF(st1.system_time, 0.0) as system_time1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.plans, 0) as plans1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.total_time_pct, 0.0) as total_time_pct2,
        NULLIF(st2.total_plan_time, 0.0) as total_plan_time2,
        NULLIF(st2.total_exec_time, 0.0) as total_exec_time2,
        NULLIF(st2.blk_read_time, 0.0) as blk_read_time2,
        NULLIF(st2.blk_write_time, 0.0) as blk_write_time2,
        NULLIF(st2.user_time, 0.0) as user_time2,
        NULLIF(st2.system_time, 0.0) as system_time2,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.plans, 0) as plans2,
        row_number() over (ORDER BY st1.total_time DESC NULLS LAST) as rn_time1,
        row_number() over (ORDER BY st2.total_time DESC NULLS LAST) as rn_time2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    ORDER BY COALESCE(st1.total_time,0) + COALESCE(st2.total_time,0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_time1,
        rn_time2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when planning timing is available
    IF NOT jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
      RETURN '';
    END IF;

    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Elapsed time as a percentage of total cluster elapsed time">%Total</th>'
            '<th colspan="3">Time (s)</th>'
            '<th colspan="2">I/O time (s)</th>'
            '{kcache_hdr1}'
            '<th rowspan="2" title="Number of times the statement was planned">Plans</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Time spent by the statement">Elapsed</th>'
            '<th title="Time spent planning statement">Plan</th>'
            '<th title="Time spent executing statement">Exec</th>'
            '<th title="Time spent reading blocks by statement">Read</th>'
            '<th title="Time spent writing blocks by statement">Write</th>'
            '{kcache_hdr2}'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
          '{kcache_row1}'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
          '<td {value}>%17$s</td>'
          '<td {value}>%18$s</td>'
          '<td {value}>%19$s</td>'
          '<td {value}>%20$s</td>'
          '{kcache_row2}'
          '<td {value}>%23$s</td>'
          '<td {value}>%24$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'kcache_hdr1',
        '<th colspan="2">CPU time (s)</th>',
      'kcache_hdr2',
        '<th>Usr</th>'
        '<th>Sys</th>',
      'kcache_row1',
        '<td {value}>%11$s</td>'
        '<td {value}>%12$s</td>',
      'kcache_row2',
        '<td {value}>%21$s</td>'
        '<td {value}>%22$s</td>'
      );
    -- Conditional template
    IF jsonb_extract_path_text(jreportset, 'report_features', 'kcachestatements')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr1}',jtab_tpl->>'kcache_hdr1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr2}',jtab_tpl->>'kcache_hdr2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row1}',jtab_tpl->>'kcache_row1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row2}',jtab_tpl->>'kcache_row2')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr2}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row2}','')));
    END IF;
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.total_time_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),2),
            round(CAST(r_result.total_plan_time1 AS numeric),2),
            round(CAST(r_result.total_exec_time1 AS numeric),2),
            round(CAST(r_result.blk_read_time1 AS numeric),2),
            round(CAST(r_result.blk_write_time1 AS numeric),2),
            round(CAST(r_result.user_time1 AS numeric),2),
            round(CAST(r_result.system_time1 AS numeric),2),
            r_result.plans1,
            r_result.calls1,
            round(CAST(r_result.total_time_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),2),
            round(CAST(r_result.total_plan_time2 AS numeric),2),
            round(CAST(r_result.total_exec_time2 AS numeric),2),
            round(CAST(r_result.blk_read_time2 AS numeric),2),
            round(CAST(r_result.blk_write_time2 AS numeric),2),
            round(CAST(r_result.user_time2 AS numeric),2),
            round(CAST(r_result.system_time2 AS numeric),2),
            r_result.plans2,
            r_result.calls2
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_elapsed_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_elapsed_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.total_time_pct, 0) as total_time_pct,
        NULLIF(st.total_time, 0) as total_time,
        NULLIF(st.total_plan_time, 0) as total_plan_time,
        NULLIF(st.total_exec_time, 0) as total_exec_time,
        NULLIF(st.blk_read_time, 0.0) as blk_read_time,
        NULLIF(st.blk_write_time, 0.0) as blk_write_time,
        NULLIF(st.user_time, 0.0) as user_time,
        NULLIF(st.system_time, 0.0) as system_time,
        NULLIF(st.calls, 0) as calls,
        NULLIF(st.plans, 0) as plans
    FROM top_statements st
    ORDER BY st.total_time DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when planning timing is available
    IF NOT jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
      RETURN '';
    END IF;

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2" title="Elapsed time as a percentage of total cluster elapsed time">%Total</th>'
            '<th colspan="3">Time (s)</th>'
            '<th colspan="2">I/O time (s)</th>'
            '{kcache_hdr1}'
            '<th rowspan="2" title="Number of times the statement was planned">Plans</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Time spent by the statement">Elapsed</th>'
            '<th title="Time spent planning statement">Plan</th>'
            '<th title="Time spent executing statement">Exec</th>'
            '<th title="Time spent reading blocks by statement">Read</th>'
            '<th title="Time spent writing blocks by statement">Write</th>'
            '{kcache_hdr2}'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%4$s</td>'
          '<td {value}>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
          '{kcache_row}'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
        '</tr>',
      'kcache_hdr1',
        '<th colspan="2">CPU time (s)</th>',
      'kcache_hdr2',
        '<th>Usr</th>'
        '<th>Sys</th>',
      'kcache_row',
        '<td {value}>%11$s</td>'
        '<td {value}>%12$s</td>'
      );
    -- Conditional template
    IF jsonb_extract_path_text(jreportset, 'report_features', 'kcachestatements')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr1}',jtab_tpl->>'kcache_hdr1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr2}',jtab_tpl->>'kcache_hdr2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row}',jtab_tpl->>'kcache_row')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr2}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row}','')));
    END IF;
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.total_time_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),2),
            round(CAST(r_result.total_plan_time AS numeric),2),
            round(CAST(r_result.total_exec_time AS numeric),2),
            round(CAST(r_result.blk_read_time AS numeric),2),
            round(CAST(r_result.blk_write_time AS numeric),2),
            round(CAST(r_result.user_time AS numeric),2),
            round(CAST(r_result.system_time AS numeric),2),
            r_result.plans,
            r_result.calls
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_exec_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_exec_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    -- Cursor for topn querues ordered by executions
    c_calls CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.calls_pct, 0.0) as calls_pct1,
        NULLIF(st1.total_exec_time, 0.0) as total_exec_time1,
        NULLIF(st1.min_exec_time, 0.0) as min_exec_time1,
        NULLIF(st1.max_exec_time, 0.0) as max_exec_time1,
        NULLIF(st1.mean_exec_time, 0.0) as mean_exec_time1,
        NULLIF(st1.stddev_exec_time, 0.0) as stddev_exec_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.calls_pct, 0.0) as calls_pct2,
        NULLIF(st2.total_exec_time, 0.0) as total_exec_time2,
        NULLIF(st2.min_exec_time, 0.0) as min_exec_time2,
        NULLIF(st2.max_exec_time, 0.0) as max_exec_time2,
        NULLIF(st2.mean_exec_time, 0.0) as mean_exec_time2,
        NULLIF(st2.stddev_exec_time, 0.0) as stddev_exec_time2,
        NULLIF(st2.rows, 0) as rows2,
        row_number() over (ORDER BY st1.calls DESC NULLS LAST) as rn_calls1,
        row_number() over (ORDER BY st2.calls DESC NULLS LAST) as rn_calls2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    ORDER BY COALESCE(st1.calls,0) + COALESCE(st2.calls,0) DESC,
      COALESCE(st1.total_time,0) + COALESCE(st2.total_time,0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_calls1,
        rn_calls2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Executions sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>I</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
            '<th title="Executions of this statement as a percentage of total executions of all statements in a cluster">%Total</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th>Mean(ms)</th>'
            '<th>Min(ms)</th>'
            '<th>Max(ms)</th>'
            '<th>StdErr(ms)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top 10 queries by executions
    FOR r_result IN c_calls LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.calls1,
            round(CAST(r_result.calls_pct1 AS numeric),2),
            r_result.rows1,
            round(CAST(r_result.mean_exec_time1 AS numeric),3),
            round(CAST(r_result.min_exec_time1 AS numeric),3),
            round(CAST(r_result.max_exec_time1 AS numeric),3),
            round(CAST(r_result.stddev_exec_time1 AS numeric),3),
            round(CAST(r_result.total_exec_time1 AS numeric),1),
            r_result.calls2,
            round(CAST(r_result.calls_pct2 AS numeric),2),
            r_result.rows2,
            round(CAST(r_result.mean_exec_time2 AS numeric),3),
            round(CAST(r_result.min_exec_time2 AS numeric),3),
            round(CAST(r_result.max_exec_time2 AS numeric),3),
            round(CAST(r_result.stddev_exec_time2 AS numeric),3),
            round(CAST(r_result.total_exec_time2 AS numeric),1)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_exec_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_exec_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    -- Cursor for topn querues ordered by executions
    c_calls CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.calls, 0) as calls,
        NULLIF(st.calls_pct, 0.0) as calls_pct,
        NULLIF(st.total_exec_time, 0.0) as total_exec_time,
        NULLIF(st.min_exec_time, 0.0) as min_exec_time,
        NULLIF(st.max_exec_time, 0.0) as max_exec_time,
        NULLIF(st.mean_exec_time, 0.0) as mean_exec_time,
        NULLIF(st.stddev_exec_time, 0.0) as stddev_exec_time,
        NULLIF(st.rows, 0) as rows
    FROM top_statements st
    ORDER BY st.calls DESC,
      st.total_time DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
            '<th title="Executions of this statement as a percentage of total executions of all statements in a cluster">%Total</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th>Mean(ms)</th>'
            '<th>Min(ms)</th>'
            '<th>Max(ms)</th>'
            '<th>StdErr(ms)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top 10 queries by executions
    FOR r_result IN c_calls LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.calls,
            round(CAST(r_result.calls_pct AS numeric),2),
            r_result.rows,
            round(CAST(r_result.mean_exec_time AS numeric),3),
            round(CAST(r_result.min_exec_time AS numeric),3),
            round(CAST(r_result.max_exec_time AS numeric),3),
            round(CAST(r_result.stddev_exec_time AS numeric),3),
            round(CAST(r_result.total_exec_time AS numeric),1)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_exec_time_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_exec_time_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.total_exec_time, 0.0) as total_exec_time1,
        NULLIF(st1.total_exec_time_pct, 0.0) as total_exec_time_pct1,
        NULLIF(st1.exec_time_pct, 0.0) as exec_time_pct1,
        NULLIF(st1.blk_read_time, 0.0) as blk_read_time1,
        NULLIF(st1.blk_write_time, 0.0) as blk_write_time1,
        NULLIF(st1.min_exec_time, 0.0) as min_exec_time1,
        NULLIF(st1.max_exec_time, 0.0) as max_exec_time1,
        NULLIF(st1.mean_exec_time, 0.0) as mean_exec_time1,
        NULLIF(st1.stddev_exec_time, 0.0) as stddev_exec_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.user_time, 0.0) as user_time1,
        NULLIF(st1.system_time, 0.0) as system_time1,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.total_exec_time, 0.0) as total_exec_time2,
        NULLIF(st2.total_exec_time_pct, 0.0) as total_exec_time_pct2,
        NULLIF(st2.exec_time_pct, 0.0) as exec_time_pct2,
        NULLIF(st2.blk_read_time, 0.0) as blk_read_time2,
        NULLIF(st2.blk_write_time, 0.0) as blk_write_time2,
        NULLIF(st2.min_exec_time, 0.0) as min_exec_time2,
        NULLIF(st2.max_exec_time, 0.0) as max_exec_time2,
        NULLIF(st2.mean_exec_time, 0.0) as mean_exec_time2,
        NULLIF(st2.stddev_exec_time, 0.0) as stddev_exec_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.user_time, 0.0) as user_time2,
        NULLIF(st2.system_time, 0.0) as system_time2,
        row_number() over (ORDER BY st1.total_exec_time DESC NULLS LAST) as rn_time1,
        row_number() over (ORDER BY st2.total_exec_time DESC NULLS LAST) as rn_time2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    ORDER BY COALESCE(st1.total_exec_time,0) + COALESCE(st2.total_exec_time,0) DESC,
      COALESCE(st1.total_time,0) + COALESCE(st2.total_time,0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_time1,
        rn_time2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Time spent executing statement">Exec (s)</th>'
            '{elapsed_pct_hdr}'
            '<th rowspan="2" title="Exec time as a percentage of total cluster elapsed time">%Total</th>'
            '<th colspan="2">I/O time (s)</th>'
            '{kcache_hdr1}'
            '<th rowspan="2" title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th colspan="4" title="Execution time statistics">Execution times (ms)</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Time spent reading blocks by statement">Read</th>'
            '<th title="Time spent writing blocks by statement">Write</th>'
            '{kcache_hdr2}'
            '<th>Mean</th>'
            '<th>Min</th>'
            '<th>Max</th>'
            '<th>StdErr</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%5$s</td>'
          '{elapsed_pct_row1}'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '{kcache_row1}'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%17$s</td>'
          '{elapsed_pct_row2}'
          '<td {value}>%18$s</td>'
          '<td {value}>%19$s</td>'
          '<td {value}>%20$s</td>'
          '{kcache_row2}'
          '<td {value}>%23$s</td>'
          '<td {value}>%24$s</td>'
          '<td {value}>%25$s</td>'
          '<td {value}>%26$s</td>'
          '<td {value}>%27$s</td>'
          '<td {value}>%28$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'elapsed_pct_hdr',
        '<th rowspan="2" title="Exec time as a percentage of statement elapsed time">%Elapsed</th>',
      'elapsed_pct_row1',
        '<td {value}>%29$s</td>',
      'elapsed_pct_row2',
        '<td {value}>%30$s</td>',
      'kcache_hdr1',
        '<th colspan="2">CPU time (s)</th>',
      'kcache_hdr2',
        '<th>Usr</th>'
        '<th>Sys</th>',
      'kcache_row1',
        '<td {value}>%9$s</td>'
        '<td {value}>%10$s</td>',
      'kcache_row2',
        '<td {value}>%21$s</td>'
        '<td {value}>%22$s</td>'
      );
    -- Conditional template
    IF jsonb_extract_path_text(jreportset, 'report_features', 'kcachestatements')::boolean AND
      NOT jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
      /* We won't show kcache CPU stats here if planning times are available as CPU stats is then
      shown in "Top SQL by elapsed time" section */
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr1}',jtab_tpl->>'kcache_hdr1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr2}',jtab_tpl->>'kcache_hdr2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row1}',jtab_tpl->>'kcache_row1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row2}',jtab_tpl->>'kcache_row2')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr2}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row2}','')));
    END IF;
    -- Planning times
    IF jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{elapsed_pct_hdr}',jtab_tpl->>'elapsed_pct_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{elapsed_pct_row1}',jtab_tpl->>'elapsed_pct_row1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{elapsed_pct_row2}',jtab_tpl->>'elapsed_pct_row2')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{elapsed_pct_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{elapsed_pct_row1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{elapsed_pct_row2}','')));
    END IF;
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.total_exec_time1 AS numeric),2),
            round(CAST(r_result.total_exec_time_pct1 AS numeric),2),
            round(CAST(r_result.blk_read_time1 AS numeric),2),
            round(CAST(r_result.blk_write_time1 AS numeric),2),
            round(CAST(r_result.user_time1 AS numeric),2),
            round(CAST(r_result.system_time1 AS numeric),2),
            r_result.rows1,
            round(CAST(r_result.mean_exec_time1 AS numeric),3),
            round(CAST(r_result.min_exec_time1 AS numeric),3),
            round(CAST(r_result.max_exec_time1 AS numeric),3),
            round(CAST(r_result.stddev_exec_time1 AS numeric),3),
            r_result.calls1,
            round(CAST(r_result.total_exec_time2 AS numeric),2),
            round(CAST(r_result.total_exec_time_pct2 AS numeric),2),
            round(CAST(r_result.blk_read_time2 AS numeric),2),
            round(CAST(r_result.blk_write_time2 AS numeric),2),
            round(CAST(r_result.user_time2 AS numeric),2),
            round(CAST(r_result.system_time2 AS numeric),2),
            r_result.rows2,
            round(CAST(r_result.mean_exec_time2 AS numeric),3),
            round(CAST(r_result.min_exec_time2 AS numeric),3),
            round(CAST(r_result.max_exec_time2 AS numeric),3),
            round(CAST(r_result.stddev_exec_time2 AS numeric),3),
            r_result.calls2,
            round(CAST(r_result.exec_time_pct1 AS numeric),2),
            round(CAST(r_result.exec_time_pct2 AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_exec_time_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_exec_time_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for queries ordered by execution time
    c_elapsed_time CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.calls, 0) as calls,
        NULLIF(st.total_exec_time, 0.0) as total_exec_time,
        NULLIF(st.total_exec_time_pct, 0.0) as total_exec_time_pct,
        NULLIF(st.exec_time_pct, 0.0) as exec_time_pct,
        NULLIF(st.blk_read_time, 0.0) as blk_read_time,
        NULLIF(st.blk_write_time, 0.0) as blk_write_time,
        NULLIF(st.min_exec_time, 0.0) as min_exec_time,
        NULLIF(st.max_exec_time, 0.0) as max_exec_time,
        NULLIF(st.mean_exec_time, 0.0) as mean_exec_time,
        NULLIF(st.stddev_exec_time, 0.0) as stddev_exec_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.user_time, 0.0) as user_time,
        NULLIF(st.system_time, 0.0) as system_time
    FROM top_statements st
    ORDER BY st.total_exec_time DESC,
      st.total_time DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2" title="Time spent executing statement">Exec (s)</th>'
            '{elapsed_pct_hdr}'
            '<th rowspan="2" title="Exec time as a percentage of total cluster elapsed time">%Total</th>'
            '<th colspan="2">I/O time (s)</th>'
            '{kcache_hdr1}'
            '<th rowspan="2" title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th colspan="4" title="Execution time statistics">Execution times (ms)</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Time spent reading blocks by statement">Read</th>'
            '<th title="Time spent writing blocks by statement">Write</th>'
            '{kcache_hdr2}'
            '<th>Mean</th>'
            '<th>Min</th>'
            '<th>Max</th>'
            '<th>StdErr</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%4$s</td>'
          '<td {value}>%5$s</td>'
          '{elapsed_pct_row}'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '{kcache_row}'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
        '</tr>',
      'elapsed_pct_hdr',
        '<th rowspan="2" title="Exec time as a percentage of statement elapsed time">%Elapsed</th>',
      'elapsed_pct_row',
        '<td {value}>%17$s</td>',
      'kcache_hdr1',
        '<th colspan="2">CPU time (s)</th>',
      'kcache_hdr2',
        '<th>Usr</th>'
        '<th>Sys</th>',
      'kcache_row',
        '<td {value}>%9$s</td>'
        '<td {value}>%10$s</td>'
      );
    -- Conditional template
    -- kcache
    IF jsonb_extract_path_text(jreportset, 'report_features', 'kcachestatements')::boolean AND
      NOT jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
      /* We won't show kcache CPU stats here if planning times are available as CPU stats is then
      shown in "Top SQL by elapsed time" section */
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr1}',jtab_tpl->>'kcache_hdr1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr2}',jtab_tpl->>'kcache_hdr2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row}',jtab_tpl->>'kcache_row')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{kcache_hdr2}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{kcache_row}','')));
    END IF;
    -- Planning times
    IF jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{elapsed_pct_hdr}',jtab_tpl->>'elapsed_pct_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{elapsed_pct_row}',jtab_tpl->>'elapsed_pct_row')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{elapsed_pct_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl','{elapsed_pct_row}','')));
    END IF;
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.total_exec_time AS numeric),2),
            round(CAST(r_result.total_exec_time_pct AS numeric),2),
            round(CAST(r_result.blk_read_time AS numeric),2),
            round(CAST(r_result.blk_write_time AS numeric),2),
            round(CAST(r_result.user_time AS numeric),2),
            round(CAST(r_result.system_time AS numeric),2),
            r_result.rows,
            round(CAST(r_result.mean_exec_time AS numeric),3),
            round(CAST(r_result.min_exec_time AS numeric),3),
            round(CAST(r_result.max_exec_time AS numeric),3),
            round(CAST(r_result.stddev_exec_time AS numeric),3),
            r_result.calls,
            round(CAST(r_result.exec_time_pct AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_functions
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_functions(sserver_id integer, start_id integer, end_id integer, trigger_fn boolean)
 RETURNS TABLE(server_id integer, datid oid, funcid oid, dbname name, schemaname name, funcname name, funcargs text, calls bigint, total_time double precision, self_time double precision, m_time double precision, m_stime double precision)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        st.server_id,
        st.datid,
        st.funcid,
        sample_db.datname AS dbname,
        st.schemaname,
        st.funcname,
        st.funcargs,
        sum(st.calls)::bigint AS calls,
        sum(st.total_time)/1000 AS total_time,
        sum(st.self_time)/1000 AS self_time,
        sum(st.total_time)/NULLIF(sum(st.calls),0)/1000 AS m_time,
        sum(st.self_time)/NULLIF(sum(st.calls),0)/1000 AS m_stime
    FROM v_sample_stat_user_functions st
        -- Database name
        JOIN sample_stat_database sample_db
        ON (st.server_id=sample_db.server_id AND st.sample_id=sample_db.sample_id AND st.datid=sample_db.datid)
    WHERE
      st.server_id = sserver_id
      AND st.trg_fn = trigger_fn
      AND NOT sample_db.datistemplate
      AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id,st.datid,st.funcid,sample_db.datname,st.schemaname,st.funcname,st.funcargs
$function$;

-- Function: top_growth_indexes_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_growth_indexes_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for indexes stats
    c_ix_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(ix1.dbname,ix2.dbname) as dbname,
        COALESCE(ix1.tablespacename,ix2.tablespacename) as tablespacename,
        COALESCE(ix1.schemaname,ix2.schemaname) as schemaname,
        COALESCE(ix1.relname,ix2.relname) as relname,
        COALESCE(ix1.indexrelname,ix2.indexrelname) as indexrelname,
        CASE WHEN sf1.size_failed THEN 'N/A'
          ELSE pg_size_pretty(NULLIF(ix1.growth, 0)) END AS growth1,
        pg_size_pretty(NULLIF(ix_last1.relsize, 0)) as relsize1,
        NULLIF(ix1.tbl_n_tup_ins, 0) as tbl_n_tup_ins1,
        NULLIF(ix1.tbl_n_tup_upd - COALESCE(ix1.tbl_n_tup_hot_upd,0), 0) as tbl_n_tup_upd1,
        NULLIF(ix1.tbl_n_tup_del, 0) as tbl_n_tup_del1,
        CASE WHEN sf2.size_failed THEN 'N/A'
          ELSE pg_size_pretty(NULLIF(ix2.growth, 0)) END AS growth2,
        pg_size_pretty(NULLIF(ix_last2.relsize, 0)) as relsize2,
        NULLIF(ix2.tbl_n_tup_ins, 0) as tbl_n_tup_ins2,
        NULLIF(ix2.tbl_n_tup_upd - COALESCE(ix2.tbl_n_tup_hot_upd,0), 0) as tbl_n_tup_upd2,
        NULLIF(ix2.tbl_n_tup_del, 0) as tbl_n_tup_del2,
        row_number() over (ORDER BY ix1.growth DESC NULLS LAST) as rn_growth1,
        row_number() over (ORDER BY ix2.growth DESC NULLS LAST) as rn_growth2
    FROM top_indexes1 ix1
        FULL OUTER JOIN top_indexes2 ix2 USING (server_id, datid, indexrelid)
        -- Is there any failed size collections on a indexes of 1st interval?
        LEFT OUTER JOIN index_size_failures(sserver_id, start1_id, end1_id) sf1
          USING (server_id, datid, indexrelid)
        -- Is there any failed size collections on a indexes of 2st interval?
        LEFT OUTER JOIN index_size_failures(sserver_id, start2_id, end2_id) sf2
          USING (server_id, datid, indexrelid)
        LEFT OUTER JOIN v_sample_stat_indexes ix_last1
            ON (ix_last1.sample_id = end1_id AND ix_last1.server_id=ix1.server_id AND ix_last1.datid = ix1.datid AND ix_last1.indexrelid = ix1.indexrelid AND ix_last1.relid = ix1.relid)
        LEFT OUTER JOIN v_sample_stat_indexes ix_last2
            ON (ix_last2.sample_id = end2_id AND ix_last2.server_id=ix2.server_id AND ix_last2.datid = ix2.datid AND ix_last2.indexrelid = ix2.indexrelid AND ix_last2.relid = ix2.relid)
    WHERE COALESCE(ix1.growth, 0) + COALESCE(ix2.growth, 0) > 0
    ORDER BY COALESCE(ix1.growth, 0) + COALESCE(ix2.growth, 0) DESC,
      COALESCE(ix1.tbl_n_tup_ins,0) + COALESCE(ix1.tbl_n_tup_upd,0) + COALESCE(ix1.tbl_n_tup_del,0) +
      COALESCE(ix2.tbl_n_tup_ins,0) + COALESCE(ix2.tbl_n_tup_upd,0) + COALESCE(ix2.tbl_n_tup_del,0) DESC,
      COALESCE(ix1.datid,ix2.datid) ASC,
      COALESCE(ix1.relid,ix2.relid) ASC,
      COALESCE(ix1.indexrelid,ix2.indexrelid) ASC
    ) t1
    WHERE least(
        rn_growth1,
        rn_growth2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Tablespace</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th rowspan="2">Index</th>'
            '<th rowspan="2">I</th>'
            '<th colspan="2">Index</th>'
            '<th colspan="3">Table</th>'
          '</tr>'
          '<tr>'
            '<th title="Index size, as it was at the moment of last sample in report interval">Size</th>'
            '<th title="Index size increment during report interval">Growth</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (without HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting table stats
    FOR r_result IN c_ix_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.indexrelname,
            r_result.relsize1,
            r_result.growth1,
            r_result.tbl_n_tup_ins1,
            r_result.tbl_n_tup_upd1,
            r_result.tbl_n_tup_del1,
            r_result.relsize2,
            r_result.growth2,
            r_result.tbl_n_tup_ins2,
            r_result.tbl_n_tup_upd2,
            r_result.tbl_n_tup_del2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_growth_indexes_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_growth_indexes_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Indexes stats template
    jtab_tpl    jsonb;

    --Cursor for indexes stats
    c_ix_stats CURSOR FOR
    SELECT
        st.dbname,
        st.tablespacename,
        st.schemaname,
        st.relname,
        st.indexrelname,
        CASE WHEN sf.size_failed THEN 'N/A'
          ELSE pg_size_pretty(NULLIF(st.growth, 0)) END AS growth,
        pg_size_pretty(NULLIF(st_last.relsize, 0)) as relsize,
        NULLIF(tbl_n_tup_ins, 0) as tbl_n_tup_ins,
        NULLIF(tbl_n_tup_upd - COALESCE(tbl_n_tup_hot_upd,0), 0) as tbl_n_tup_upd,
        NULLIF(tbl_n_tup_del, 0) as tbl_n_tup_del
    FROM top_indexes st
        JOIN v_sample_stat_indexes st_last using (server_id,datid,relid,indexrelid)
        -- Is there any failed size collections on indexes?
        LEFT OUTER JOIN index_size_failures(sserver_id, start_id, end_id) sf
          USING (server_id, datid, indexrelid)
    WHERE st_last.sample_id = end_id
      AND st.growth > 0
    ORDER BY st.growth DESC,
      COALESCE(tbl_n_tup_ins,0) + COALESCE(tbl_n_tup_upd,0) + COALESCE(tbl_n_tup_del,0) DESC,
      st.datid ASC,
      st.relid ASC,
      st.indexrelid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Tablespace</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th rowspan="2">Index</th>'
            '<th colspan="2">Index</th>'
            '<th colspan="3">Table</th>'
          '</tr>'
          '<tr>'
            '<th title="Index size, as it was at the moment of last sample in report interval">Size</th>'
            '<th title="Index size increment during report interval">Growth</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (without HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting table stats
    FOR r_result IN c_ix_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.indexrelname,
            r_result.relsize,
            r_result.growth,
            r_result.tbl_n_tup_ins,
            r_result.tbl_n_tup_upd,
            r_result.tbl_n_tup_del
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_growth_tables_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_growth_tables_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(tbl1.dbname,tbl2.dbname) as dbname,
        COALESCE(tbl1.tablespacename,tbl2.tablespacename) AS tablespacename,
        COALESCE(tbl1.schemaname,tbl2.schemaname) as schemaname,
        COALESCE(tbl1.relname,tbl2.relname) as relname,
        NULLIF(tbl1.n_tup_ins, 0) as n_tup_ins1,
        NULLIF(tbl1.n_tup_upd, 0) as n_tup_upd1,
        NULLIF(tbl1.n_tup_del, 0) as n_tup_del1,
        NULLIF(tbl1.n_tup_hot_upd, 0) as n_tup_hot_upd1,
        CASE WHEN sf1.size_failed THEN 'N/A'
          ELSE pg_size_pretty(NULLIF(tbl1.growth, 0)) END AS growth1,
        pg_size_pretty(NULLIF(st_last1.relsize, 0)) AS relsize1,
        NULLIF(tbl1.toastn_tup_ins, 0) as toastn_tup_ins1,
        NULLIF(tbl1.toastn_tup_upd, 0) as toastn_tup_upd1,
        NULLIF(tbl1.toastn_tup_del, 0) as toastn_tup_del1,
        NULLIF(tbl1.toastn_tup_hot_upd, 0) as toastn_tup_hot_upd1,
        CASE WHEN sf1.toastsize_failed THEN 'N/A'
          ELSE pg_size_pretty(NULLIF(tbl1.toastgrowth, 0)) END AS toastgrowth1,
        pg_size_pretty(NULLIF(stt_last1.relsize, 0)) AS toastrelsize1,
        NULLIF(tbl2.n_tup_ins, 0) as n_tup_ins2,
        NULLIF(tbl2.n_tup_upd, 0) as n_tup_upd2,
        NULLIF(tbl2.n_tup_del, 0) as n_tup_del2,
        NULLIF(tbl2.n_tup_hot_upd, 0) as n_tup_hot_upd2,
        CASE WHEN sf2.size_failed THEN 'N/A'
          ELSE pg_size_pretty(NULLIF(tbl2.growth, 0)) END AS growth2,
        pg_size_pretty(NULLIF(st_last2.relsize, 0)) AS relsize2,
        NULLIF(tbl2.toastn_tup_ins, 0) as toastn_tup_ins2,
        NULLIF(tbl2.toastn_tup_upd, 0) as toastn_tup_upd2,
        NULLIF(tbl2.toastn_tup_del, 0) as toastn_tup_del2,
        NULLIF(tbl2.toastn_tup_hot_upd, 0) as toastn_tup_hot_upd2,
        CASE WHEN sf2.toastsize_failed THEN 'N/A'
          ELSE pg_size_pretty(NULLIF(tbl2.toastgrowth, 0)) END AS toastgrowth2,
        pg_size_pretty(NULLIF(stt_last2.relsize, 0)) AS toastrelsize2,
        row_number() OVER (ORDER BY COALESCE(tbl1.growth, 0) + COALESCE(tbl1.toastgrowth, 0) DESC NULLS LAST) as rn_growth1,
        row_number() OVER (ORDER BY COALESCE(tbl2.growth, 0) + COALESCE(tbl2.toastgrowth, 0) DESC NULLS LAST) as rn_growth2
    FROM top_tables1 tbl1
        FULL OUTER JOIN top_tables2 tbl2 USING (server_id,datid,relid)
        -- Is there any failed size collections on a tables of 1st interval?
        LEFT OUTER JOIN table_size_failures(sserver_id, start1_id, end1_id) sf1
          USING (server_id, datid, relid)
        -- Is there any failed size collections on a tables of 2nd interval?
        LEFT OUTER JOIN table_size_failures(sserver_id, start2_id, end2_id) sf2
          USING (server_id, datid, relid)
        LEFT OUTER JOIN v_sample_stat_tables st_last1 ON (tbl1.server_id = st_last1.server_id
          AND tbl1.datid = st_last1.datid AND tbl1.relid = st_last1.relid AND st_last1.sample_id=end1_id)
        LEFT OUTER JOIN v_sample_stat_tables st_last2 ON (tbl2.server_id = st_last2.server_id
          AND tbl2.datid = st_last2.datid AND tbl2.relid = st_last2.relid AND st_last2.sample_id=end2_id)
        -- join toast tables last sample stats (to get relsize)
        LEFT OUTER JOIN v_sample_stat_tables stt_last1 ON (st_last1.server_id = stt_last1.server_id
          AND st_last1.datid = stt_last1.datid AND st_last1.reltoastrelid = stt_last1.relid
          AND st_last1.sample_id=stt_last1.sample_id)
        LEFT OUTER JOIN v_sample_stat_tables stt_last2 ON (st_last2.server_id = stt_last2.server_id
          AND st_last2.datid = stt_last2.datid AND st_last2.reltoastrelid = stt_last2.relid
          AND st_last2.sample_id=stt_last2.sample_id)
    WHERE COALESCE(tbl1.growth, 0) + COALESCE(tbl1.toastgrowth, 0) +
      COALESCE(tbl2.growth, 0) + COALESCE(tbl2.toastgrowth, 0) > 0
    ORDER BY COALESCE(tbl1.growth, 0) + COALESCE(tbl1.toastgrowth, 0) +
      COALESCE(tbl2.growth, 0) + COALESCE(tbl2.toastgrowth, 0) DESC,
      COALESCE(tbl1.datid,tbl2.datid) ASC,
      COALESCE(tbl1.relid,tbl2.relid) ASC
    ) t1
    WHERE least(
        rn_growth1,
        rn_growth2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Tablespace</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th rowspan="2">I</th>'
            '<th colspan="6">Table</th>'
            '<th colspan="6">TOAST</th>'
          '</tr>'
          '<tr>'
            '<th title="Table size, as it was at the moment of last sample in report interval">Size</th>'
            '<th title="Table size increment during report interval">Growth</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
            '<th title="Table size, as it was at the moment of last sample in report interval (TOAST)">Size</th>'
            '<th title="Table size increment during report interval (TOAST)">Growth</th>'
            '<th title="Number of rows inserted (TOAST)">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows) (TOAST)">Upd</th>'
            '<th title="Number of rows deleted (TOAST)">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required) (TOAST)">Upd(HOT)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.relsize1,
            r_result.growth1,
            r_result.n_tup_ins1,
            r_result.n_tup_upd1,
            r_result.n_tup_del1,
            r_result.n_tup_hot_upd1,
            r_result.toastrelsize1,
            r_result.toastgrowth1,
            r_result.toastn_tup_ins1,
            r_result.toastn_tup_upd1,
            r_result.toastn_tup_del1,
            r_result.toastn_tup_hot_upd1,
            r_result.relsize2,
            r_result.growth2,
            r_result.n_tup_ins2,
            r_result.n_tup_upd2,
            r_result.n_tup_del2,
            r_result.n_tup_hot_upd2,
            r_result.toastrelsize2,
            r_result.toastgrowth2,
            r_result.toastn_tup_ins2,
            r_result.toastn_tup_upd2,
            r_result.toastn_tup_del2,
            r_result.toastn_tup_hot_upd2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_growth_tables_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_growth_tables_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        top.tablespacename,
        top.schemaname,
        top.relname,
        top.reltoastrelid,
        NULLIF(top.n_tup_ins, 0) as n_tup_ins,
        NULLIF(top.n_tup_upd, 0) as n_tup_upd,
        NULLIF(top.n_tup_del, 0) as n_tup_del,
        NULLIF(top.n_tup_hot_upd, 0) as n_tup_hot_upd,
        CASE WHEN sf.size_failed THEN 'N/A'
          ELSE pg_size_pretty(NULLIF(top.growth, 0)) END AS growth,
        pg_size_pretty(NULLIF(st_last.relsize, 0)) AS relsize,
        NULLIF(top.toastn_tup_ins, 0) as toastn_tup_ins,
        NULLIF(top.toastn_tup_upd, 0) as toastn_tup_upd,
        NULLIF(top.toastn_tup_del, 0) as toastn_tup_del,
        NULLIF(top.toastn_tup_hot_upd, 0) as toastn_tup_hot_upd,
        CASE WHEN sf.toastsize_failed THEN 'N/A'
          ELSE pg_size_pretty(NULLIF(top.toastgrowth, 0)) END AS toastgrowth,
        pg_size_pretty(NULLIF(stt_last.relsize, 0)) AS toastrelsize
    FROM top_tables top
        JOIN v_sample_stat_tables st_last
          USING (server_id, datid, relid)
        -- Is there any failed size collections on a tables?
        LEFT OUTER JOIN table_size_failures(sserver_id, start_id, end_id) sf
          USING (server_id, datid, relid)
        LEFT OUTER JOIN v_sample_stat_tables stt_last
          ON (top.server_id=stt_last.server_id AND top.datid=stt_last.datid AND top.reltoastrelid=stt_last.relid AND stt_last.sample_id=end_id)
    WHERE st_last.sample_id = end_id AND COALESCE(top.growth, 0) + COALESCE(top.toastgrowth, 0) > 0
    ORDER BY COALESCE(top.growth, 0) + COALESCE(top.toastgrowth, 0) DESC,
      top.datid ASC,
      top.relid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN

    -- Populate templates
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th title="Table size, as it was at the moment of last sample in report interval">Size</th>'
            '<th title="Table size increment during report interval">Growth</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'rel_tpl',
        '<tr {reltr}>'
          '<td {reltdhdr}>%s</td>'
          '<td {reltdhdr}>%s</td>'
          '<td {reltdhdr}>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'rel_wtoast_tpl',
        '<tr {reltr}>'
          '<td {reltdspanhdr}>%s</td>'
          '<td {reltdspanhdr}>%s</td>'
          '<td {reltdspanhdr}>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {toasttr}>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
      IF r_result.reltoastrelid IS NULL THEN
        report := report||format(
            jtab_tpl #>> ARRAY['rel_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.relsize,
            r_result.growth,
            r_result.n_tup_ins,
            r_result.n_tup_upd,
            r_result.n_tup_del,
            r_result.n_tup_hot_upd
        );
      ELSE
        report := report||format(
            jtab_tpl #>> ARRAY['rel_wtoast_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.relsize,
            r_result.growth,
            r_result.n_tup_ins,
            r_result.n_tup_upd,
            r_result.n_tup_del,
            r_result.n_tup_hot_upd,
            r_result.relname||'(TOAST)',
            r_result.toastrelsize,
            r_result.toastgrowth,
            r_result.toastn_tup_ins,
            r_result.toastn_tup_upd,
            r_result.toastn_tup_del,
            r_result.toastn_tup_hot_upd
        );
      END IF;
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_indexes
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_indexes(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, datid oid, relid oid, indexrelid oid, indisunique boolean, dbname name, tablespacename name, schemaname name, relname name, indexrelname name, idx_scan bigint, growth bigint, tbl_n_tup_ins bigint, tbl_n_tup_upd bigint, tbl_n_tup_del bigint, tbl_n_tup_hot_upd bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        st.server_id,
        st.datid,
        st.relid,
        st.indexrelid,
        st.indisunique,
        sample_db.datname,
        tablespaces_list.tablespacename,
        COALESCE(mtbl.schemaname,st.schemaname)::name AS schemaname,
        COALESCE(mtbl.relname||'(TOAST)',st.relname)::name as relname,
        st.indexrelname,
        sum(st.idx_scan)::bigint as idx_scan,
        sum(st.relsize_diff)::bigint as growth,
        sum(tbl.n_tup_ins)::bigint as tbl_n_tup_ins,
        sum(tbl.n_tup_upd)::bigint as tbl_n_tup_upd,
        sum(tbl.n_tup_del)::bigint as tbl_n_tup_del,
        sum(tbl.n_tup_hot_upd)::bigint as tbl_n_tup_hot_upd
    FROM v_sample_stat_indexes st JOIN v_sample_stat_tables tbl USING (server_id, sample_id, datid, relid)
        -- Database name
        JOIN sample_stat_database sample_db
        ON (st.server_id=sample_db.server_id AND st.sample_id=sample_db.sample_id AND st.datid=sample_db.datid)
        JOIN tablespaces_list ON  (st.server_id=tablespaces_list.server_id AND st.tablespaceid=tablespaces_list.tablespaceid)
        -- join main table for indexes on toast
        LEFT OUTER JOIN tables_list mtbl ON (st.server_id = mtbl.server_id AND st.datid = mtbl.datid AND st.relid = mtbl.reltoastrelid)
    WHERE st.server_id=sserver_id AND NOT sample_db.datistemplate AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id,st.datid,st.relid,st.indexrelid,st.indisunique,sample_db.datname,
      COALESCE(mtbl.schemaname,st.schemaname),COALESCE(mtbl.relname||'(TOAST)',st.relname), tablespaces_list.tablespacename,st.indexrelname
$function$;

-- Function: top_io_filesystem_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_io_filesystem_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(kc1.datid,kc2.datid) as datid,
        COALESCE(kc1.userid,kc2.userid) as userid,
        COALESCE(kc1.queryid,kc2.queryid) as queryid,
        COALESCE(kc1.dbname,kc2.dbname) as dbname,
        NULLIF(kc1.plan_reads, 0) as plan_reads1,
        NULLIF(kc1.exec_reads, 0) as exec_reads1,
        NULLIF(kc1.reads_total_pct, 0.0) as reads_total_pct1,
        NULLIF(kc1.plan_writes, 0)  as plan_writes1,
        NULLIF(kc1.exec_writes, 0)  as exec_writes1,
        NULLIF(kc1.writes_total_pct, 0.0) as writes_total_pct1,
        NULLIF(kc2.plan_reads, 0) as plan_reads2,
        NULLIF(kc2.exec_reads, 0) as exec_reads2,
        NULLIF(kc2.reads_total_pct, 0.0) as reads_total_pct2,
        NULLIF(kc2.plan_writes, 0) as plan_writes2,
        NULLIF(kc2.exec_writes, 0) as exec_writes2,
        NULLIF(kc2.writes_total_pct, 0.0) as writes_total_pct2,
        row_number() OVER (ORDER BY COALESCE(kc1.exec_reads, 0.0) + COALESCE(kc1.exec_writes, 0.0) DESC NULLS LAST) as io_count1,
        row_number() OVER (ORDER BY COALESCE(kc2.exec_reads, 0.0) + COALESCE(kc2.exec_writes, 0.0)  DESC NULLS LAST) as io_count2
    FROM top_kcache_statements1 kc1
        FULL OUTER JOIN top_kcache_statements2 kc2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(kc1.plan_writes, 0.0) + COALESCE(kc2.plan_writes, 0.0) +
        COALESCE(kc1.plan_reads, 0.0) + COALESCE(kc2.plan_reads, 0.0) +
        COALESCE(kc1.exec_writes, 0.0) + COALESCE(kc2.exec_writes, 0.0) +
        COALESCE(kc1.exec_reads, 0.0) + COALESCE(kc2.exec_reads, 0.0) > 0
    ORDER BY COALESCE(kc1.plan_writes, 0.0) + COALESCE(kc2.plan_writes, 0.0) +
        COALESCE(kc1.plan_reads, 0.0) + COALESCE(kc2.plan_reads, 0.0) +
        COALESCE(kc1.exec_writes, 0.0) + COALESCE(kc2.exec_writes, 0.0) +
        COALESCE(kc1.exec_reads, 0.0) + COALESCE(kc2.exec_reads, 0.0) DESC,
        COALESCE(kc1.datid,kc2.datid),
        COALESCE(kc1.userid,kc2.userid),
        COALESCE(kc1.queryid,kc2.queryid)
        ) t1
    WHERE least(
        io_count1,
        io_count2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">I</th>'
            '<th title="Filesystem reads" colspan="{fs_colspan}">Read Bytes</th>'
            '<th title="Filesystem writes" colspan="{fs_colspan}">Write Bytes</th>'
          '</tr>'
          '<tr>'
            '{plan_reads_hdr}'
            '<th title="Filesystem read amount during execution">Exec</th>'
            '<th title="Filesystem read amount of this statement as a percentage of all statements FS read amount">%Total</th>'
            '{plan_writes_hdr}'
            '<th title="Filesystem write amount during execution">Exec</th>'
            '<th title="Filesystem write amount of this statement as a percentage of all statements FS write amount">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {label} {title1}>1</td>'
          '{plan_reads_tpl1}'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '{plan_writes_tpl1}'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '{plan_reads_tpl2}'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '{plan_writes_tpl2}'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'plan_reads_hdr',
        '<th title="Filesystem read amount during planning">Plan</th>',
      'plan_writes_hdr',
        '<th title="Filesystem write amount during planning">Plan</th>',
      'plan_reads_tpl1',
        '<td {value}>%5$s</td>',
      'plan_writes_tpl1',
        '<td {value}>%8$s</td>',
      'plan_reads_tpl2',
        '<td {value}>%11$s</td>',
      'plan_writes_tpl2',
        '<td {value}>%14$s</td>'
    );
    -- Conditional template
    IF jsonb_extract_path_text(jreportset, 'report_features', 'rusage.planstats')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{fs_colspan}','3')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{plan_reads_hdr}',jtab_tpl->>'plan_reads_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{plan_writes_hdr}',jtab_tpl->>'plan_writes_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_reads_tpl1}',jtab_tpl->>'plan_reads_tpl1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_writes_tpl1}',jtab_tpl->>'plan_writes_tpl1')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_reads_tpl2}',jtab_tpl->>'plan_reads_tpl2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_writes_tpl2}',jtab_tpl->>'plan_writes_tpl2')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{fs_colspan}','2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{plan_reads_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{plan_writes_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_reads_tpl1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_writes_tpl1}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_reads_tpl2}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_writes_tpl2}','')));
    END IF;
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL,
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            pg_size_pretty(r_result.plan_reads1),
            pg_size_pretty(r_result.exec_reads1),
            round(CAST(r_result.reads_total_pct1 AS numeric),2),
            pg_size_pretty(r_result.plan_writes1),
            pg_size_pretty(r_result.exec_writes1),
            round(CAST(r_result.writes_total_pct1 AS numeric),2),
            pg_size_pretty(r_result.plan_reads2),
            pg_size_pretty(r_result.exec_reads2),
            round(CAST(r_result.reads_total_pct2 AS numeric),2),
            pg_size_pretty(r_result.plan_writes2),
            pg_size_pretty(r_result.exec_writes2),
            round(CAST(r_result.writes_total_pct2 AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_io_filesystem_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_io_filesystem_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR FOR
    SELECT
        kc.datid as datid,
        kc.userid as userid,
        kc.queryid as queryid,
        kc.dbname,
        NULLIF(kc.plan_reads, 0) as plan_reads,
        NULLIF(kc.exec_reads, 0) as exec_reads,
        NULLIF(kc.reads_total_pct, 0.0) as reads_total_pct,
        NULLIF(kc.plan_writes, 0)  as plan_writes,
        NULLIF(kc.exec_writes, 0)  as exec_writes,
        NULLIF(kc.writes_total_pct, 0.0) as writes_total_pct
    FROM top_kcache_statements kc
    WHERE COALESCE(kc.plan_reads, 0) + COALESCE(kc.plan_writes, 0) +
      COALESCE(kc.exec_reads, 0) + COALESCE(kc.exec_writes, 0) > 0
    ORDER BY COALESCE(kc.plan_reads, 0) + COALESCE(kc.plan_writes, 0) +
      COALESCE(kc.exec_reads, 0) + COALESCE(kc.exec_writes, 0) DESC,
      kc.datid,
      kc.userid,
      kc.queryid
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th title="Filesystem reads" colspan="{fs_colspan}">Read Bytes</th>'
            '<th title="Filesystem writes" colspan="{fs_colspan}">Write Bytes</th>'
          '</tr>'
          '<tr>'
            '{plan_reads_hdr}'
            '<th title="Filesystem read amount during execution">Exec</th>'
            '<th title="Filesystem read amount of this statement as a percentage of all statements FS read amount">%Total</th>'
            '{plan_writes_hdr}'
            '<th title="Filesystem write amount during execution">Exec</th>'
            '<th title="Filesystem write amount of this statement as a percentage of all statements FS write amount">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%4$s</td>'
          '{plan_reads_tpl}'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '{plan_writes_tpl}'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
        '</tr>',
      'plan_reads_hdr',
        '<th title="Filesystem read amount during planning">Plan</th>',
      'plan_writes_hdr',
        '<th title="Filesystem write amount during planning">Plan</th>',
      'plan_reads_tpl',
        '<td {value}>%5$s</td>',
      'plan_writes_tpl',
        '<td {value}>%8$s</td>'
    );

    -- Conditional template
    IF jsonb_extract_path_text(jreportset, 'report_features', 'rusage.planstats')::boolean THEN
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{fs_colspan}','3')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{plan_reads_hdr}',jtab_tpl->>'plan_reads_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{plan_writes_hdr}',jtab_tpl->>'plan_writes_hdr')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_reads_tpl}',jtab_tpl->>'plan_reads_tpl')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_writes_tpl}',jtab_tpl->>'plan_writes_tpl')));
    ELSE
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr','{fs_colspan}','2')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{plan_reads_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{tab_hdr}',to_jsonb(replace(jtab_tpl->>'tab_hdr',
        '{plan_writes_hdr}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_reads_tpl}','')));
      jtab_tpl := jsonb_set(jtab_tpl,'{stmt_tpl}',to_jsonb(replace(jtab_tpl->>'stmt_tpl',
        '{plan_writes_tpl}','')));
    END IF;
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL,
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            pg_size_pretty(r_result.plan_reads),
            pg_size_pretty(r_result.exec_reads),
            round(CAST(r_result.reads_total_pct AS numeric),2),
            pg_size_pretty(r_result.plan_writes),
            pg_size_pretty(r_result.exec_writes),
            round(CAST(r_result.writes_total_pct AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_io_indexes
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_io_indexes(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, datid oid, relid oid, dbname name, tablespacename name, schemaname name, relname name, indexrelid oid, indexrelname name, idx_scan bigint, idx_blks_read bigint, idx_blks_read_pct numeric, idx_blks_hit_pct numeric, idx_blks_fetch bigint, idx_blks_fetch_pct numeric)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    WITH total AS (SELECT
      COALESCE(sum(heap_blks_read)) + COALESCE(sum(idx_blks_read)) AS total_blks_read,
      COALESCE(sum(heap_blks_read)) + COALESCE(sum(idx_blks_read)) +
      COALESCE(sum(heap_blks_hit)) + COALESCE(sum(idx_blks_hit)) AS total_blks_fetch
    FROM sample_stat_tables_total
    WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id
    )
    SELECT
        st.server_id,
        st.datid,
        st.relid,
        sample_db.datname AS dbname,
        tablespaces_list.tablespacename,
        COALESCE(mtbl.schemaname,st.schemaname)::name AS schemaname,
        COALESCE(mtbl.relname||'(TOAST)',st.relname)::name AS relname,
        st.indexrelid,
        st.indexrelname,
        sum(st.idx_scan)::bigint AS idx_scan,
        sum(st.idx_blks_read)::bigint AS idx_blks_read,
        sum(st.idx_blks_read) * 100 / NULLIF(min(total.total_blks_read), 0) AS idx_blks_read_pct,
        sum(st.idx_blks_hit) * 100 / NULLIF(COALESCE(sum(st.idx_blks_hit), 0) + COALESCE(sum(st.idx_blks_read), 0), 0) AS idx_blks_hit_pct,
        COALESCE(sum(st.idx_blks_read), 0)::bigint + COALESCE(sum(st.idx_blks_hit), 0)::bigint AS idx_blks_fetch,
        (COALESCE(sum(st.idx_blks_read), 0) + COALESCE(sum(st.idx_blks_hit), 0)) * 100 / NULLIF(min(total_blks_fetch), 0) AS idx_blks_fetch_pct
    FROM v_sample_stat_indexes st
        -- Database name
        JOIN sample_stat_database sample_db
        ON (st.server_id=sample_db.server_id AND st.sample_id=sample_db.sample_id AND st.datid=sample_db.datid)
        JOIN tablespaces_list ON  (st.server_id=tablespaces_list.server_id AND st.tablespaceid=tablespaces_list.tablespaceid)
        -- join main table for indexes on toast
        LEFT OUTER JOIN tables_list mtbl ON (st.server_id = mtbl.server_id AND st.datid = mtbl.datid AND st.relid = mtbl.reltoastrelid)
        CROSS JOIN total
    WHERE st.server_id = sserver_id AND NOT sample_db.datistemplate AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id,st.datid,st.relid,sample_db.datname,
      COALESCE(mtbl.schemaname,st.schemaname), COALESCE(mtbl.relname||'(TOAST)',st.relname),
      st.schemaname,st.relname,tablespaces_list.tablespacename, st.indexrelid,st.indexrelname
    HAVING min(sample_db.stats_reset) = max(sample_db.stats_reset)
$function$;

-- Function: top_io_tables
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_io_tables(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, datid oid, relid oid, dbname name, tablespacename name, schemaname name, relname name, heap_blks_read bigint, heap_blks_read_pct numeric, heap_blks_fetch bigint, heap_blks_proc_pct numeric, idx_blks_read bigint, idx_blks_read_pct numeric, idx_blks_fetch bigint, idx_blks_fetch_pct numeric, toast_blks_read bigint, toast_blks_read_pct numeric, toast_blks_fetch bigint, toast_blks_fetch_pct numeric, tidx_blks_read bigint, tidx_blks_read_pct numeric, tidx_blks_fetch bigint, tidx_blks_fetch_pct numeric, seq_scan bigint, idx_scan bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    WITH total AS (SELECT
      COALESCE(sum(heap_blks_read), 0) + COALESCE(sum(idx_blks_read), 0) AS total_blks_read,
      COALESCE(sum(heap_blks_read), 0) + COALESCE(sum(idx_blks_read), 0) +
      COALESCE(sum(heap_blks_hit), 0) + COALESCE(sum(idx_blks_hit), 0) AS total_blks_fetch
    FROM sample_stat_tables_total
    WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id
    )
    SELECT
        st.server_id,
        st.datid,
        st.relid,
        sample_db.datname AS dbname,
        tablespaces_list.tablespacename,
        st.schemaname,
        st.relname,
        sum(st.heap_blks_read)::bigint AS heap_blks_read,
        sum(st.heap_blks_read) * 100 / NULLIF(min(total.total_blks_read), 0) AS heap_blks_read_pct,
        COALESCE(sum(st.heap_blks_read), 0)::bigint + COALESCE(sum(st.heap_blks_hit), 0)::bigint AS heap_blks_fetch,
        (COALESCE(sum(st.heap_blks_read), 0) + COALESCE(sum(st.heap_blks_hit), 0)) * 100 / NULLIF(min(total.total_blks_fetch), 0) AS heap_blks_proc_pct,
        sum(st.idx_blks_read)::bigint AS idx_blks_read,
        sum(st.idx_blks_read) * 100 / NULLIF(min(total.total_blks_read), 0) AS idx_blks_read_pct,
        COALESCE(sum(st.idx_blks_read), 0)::bigint + COALESCE(sum(st.idx_blks_hit), 0)::bigint AS idx_blks_fetch,
        (COALESCE(sum(st.idx_blks_read), 0) + COALESCE(sum(st.idx_blks_hit), 0)) * 100 / NULLIF(min(total.total_blks_fetch), 0) AS idx_blks_fetch_pct,
        sum(st.toast_blks_read)::bigint AS toast_blks_read,
        sum(st.toast_blks_read) * 100 / NULLIF(min(total.total_blks_read), 0) AS toast_blks_read_pct,
        COALESCE(sum(st.toast_blks_read), 0)::bigint + COALESCE(sum(st.toast_blks_hit), 0)::bigint AS toast_blks_fetch,
        (COALESCE(sum(st.toast_blks_read), 0) + COALESCE(sum(st.toast_blks_hit), 0)) * 100 / NULLIF(min(total.total_blks_fetch), 0) AS toast_blks_fetch_pct,
        sum(st.tidx_blks_read)::bigint AS tidx_blks_read,
        sum(st.tidx_blks_read) * 100 / NULLIF(min(total.total_blks_read), 0) AS tidx_blks_read_pct,
        COALESCE(sum(st.tidx_blks_read), 0)::bigint + COALESCE(sum(st.tidx_blks_hit), 0)::bigint AS tidx_blks_fetch,
        (COALESCE(sum(st.tidx_blks_read), 0) + COALESCE(sum(st.tidx_blks_hit), 0)) * 100 / NULLIF(min(total.total_blks_fetch), 0) AS tidx_blks_fetch_pct,
        sum(st.seq_scan)::bigint AS seq_scan,
        sum(st.idx_scan)::bigint AS idx_scan
    FROM v_sample_stat_tables st
        -- Database name
        JOIN sample_stat_database sample_db
          USING (server_id, sample_id, datid)
        JOIN tablespaces_list USING(server_id,tablespaceid)
        CROSS JOIN total
    WHERE st.server_id = sserver_id
      AND st.relkind IN ('r','m')
      AND NOT sample_db.datistemplate
      AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id,st.datid,st.relid,sample_db.datname,tablespaces_list.tablespacename, st.schemaname,st.relname
    HAVING min(sample_db.stats_reset) = max(sample_db.stats_reset)
$function$;

-- Function: top_iowait_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_iowait_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) querues ordered by I/O Wait time
    c_iowait_time CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.io_time, 0.0) as io_time1,
        NULLIF(st1.blk_read_time, 0.0) as blk_read_time1,
        NULLIF(st1.blk_write_time, 0.0) as blk_write_time1,
        NULLIF(st1.io_time_pct, 0.0) as io_time_pct1,
        NULLIF(st1.shared_blks_read, 0) as shared_blks_read1,
        NULLIF(st1.local_blks_read, 0) as local_blks_read1,
        NULLIF(st1.temp_blks_read, 0) as temp_blks_read1,
        NULLIF(st1.shared_blks_written, 0) as shared_blks_written1,
        NULLIF(st1.local_blks_written, 0) as local_blks_written1,
        NULLIF(st1.temp_blks_written, 0) as temp_blks_written1,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.io_time, 0.0) as io_time2,
        NULLIF(st2.blk_read_time, 0.0) as blk_read_time2,
        NULLIF(st2.blk_write_time, 0.0) as blk_write_time2,
        NULLIF(st2.io_time_pct, 0.0) as io_time_pct2,
        NULLIF(st2.shared_blks_read, 0) as shared_blks_read2,
        NULLIF(st2.local_blks_read, 0) as local_blks_read2,
        NULLIF(st2.temp_blks_read, 0) as temp_blks_read2,
        NULLIF(st2.shared_blks_written, 0) as shared_blks_written2,
        NULLIF(st2.local_blks_written, 0) as local_blks_written2,
        NULLIF(st2.temp_blks_written, 0) as temp_blks_written2,
        row_number() over (ORDER BY st1.io_time DESC NULLS LAST) as rn_iotime1,
        row_number() over (ORDER BY st2.io_time DESC NULLS LAST) as rn_iotime2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(st1.io_time, 0.0) + COALESCE(st2.io_time, 0.0) > 0
    ORDER BY COALESCE(st1.io_time, 0.0) + COALESCE(st2.io_time, 0.0) DESC,
      COALESCE(st1.total_time, 0.0) + COALESCE(st2.total_time, 0.0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_iotime1,
        rn_iotime2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- IOWait time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Time spent by the statement reading and writing blocks">IO(s)</th>'
            '<th rowspan="2" title="Time spent by the statement reading blocks">R(s)</th>'
            '<th rowspan="2" title="Time spent by the statement writing blocks">W(s)</th>'
            '<th rowspan="2" title="I/O time of this statement as a percentage of total I/O time for all statements in a cluster">%Total</th>'
            '<th colspan="3" title="Number of blocks read by the statement">Reads</th>'
            '<th colspan="3" title="Number of blocks written by the statement">Writes</th>'
            '<th rowspan="2" title="Time spent by the statement">Elapsed(s)</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of shared blocks read by the statement">Shr</th>'
            '<th title="Number of local blocks read by the statement (usually used for temporary tables)">Loc</th>'
            '<th title="Number of temp blocks read by the statement (usually used for operations like sorts and joins)">Tmp</th>'
            '<th title="Number of shared blocks written by the statement">Shr</th>'
            '<th title="Number of local blocks written by the statement (usually used for temporary tables)">Loc</th>'
            '<th title="Number of temp blocks written by the statement (usually used for operations like sorts and joins)">Tmp</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top 10 queries by I/O wait time
    FOR r_result IN c_iowait_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.io_time1 AS numeric),3),
            round(CAST(r_result.blk_read_time1 AS numeric),3),
            round(CAST(r_result.blk_write_time1 AS numeric),3),
            round(CAST(r_result.io_time_pct1 AS numeric),2),
            round(CAST(r_result.shared_blks_read1 AS numeric)),
            round(CAST(r_result.local_blks_read1 AS numeric)),
            round(CAST(r_result.temp_blks_read1 AS numeric)),
            round(CAST(r_result.shared_blks_written1 AS numeric)),
            round(CAST(r_result.local_blks_written1 AS numeric)),
            round(CAST(r_result.temp_blks_written1 AS numeric)),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.calls1,
            round(CAST(r_result.io_time2 AS numeric),3),
            round(CAST(r_result.blk_read_time2 AS numeric),3),
            round(CAST(r_result.blk_write_time2 AS numeric),3),
            round(CAST(r_result.io_time_pct2 AS numeric),2),
            round(CAST(r_result.shared_blks_read2 AS numeric)),
            round(CAST(r_result.local_blks_read2 AS numeric)),
            round(CAST(r_result.temp_blks_read2 AS numeric)),
            round(CAST(r_result.shared_blks_written2 AS numeric)),
            round(CAST(r_result.local_blks_written2 AS numeric)),
            round(CAST(r_result.temp_blks_written2 AS numeric)),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.calls2
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_iowait_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_iowait_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) querues ordered by I/O Wait time
    c_iowait_time CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.io_time, 0.0) as io_time,
        NULLIF(st.blk_read_time, 0.0) as blk_read_time,
        NULLIF(st.blk_write_time, 0.0) as blk_write_time,
        NULLIF(st.io_time_pct, 0.0) as io_time_pct,
        NULLIF(st.shared_blks_read, 0) as shared_blks_read,
        NULLIF(st.local_blks_read, 0) as local_blks_read,
        NULLIF(st.temp_blks_read, 0) as temp_blks_read,
        NULLIF(st.shared_blks_written, 0) as shared_blks_written,
        NULLIF(st.local_blks_written, 0) as local_blks_written,
        NULLIF(st.temp_blks_written, 0) as temp_blks_written,
        NULLIF(st.calls, 0) as calls
    FROM top_statements st
    WHERE st.io_time > 0
    ORDER BY st.io_time DESC,
      st.total_time DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2" title="Time spent by the statement reading and writing blocks">IO(s)</th>'
            '<th rowspan="2" title="Time spent by the statement reading blocks">R(s)</th>'
            '<th rowspan="2" title="Time spent by the statement writing blocks">W(s)</th>'
            '<th rowspan="2" title="I/O time of this statement as a percentage of total I/O time for all statements in a cluster">%Total</th>'
            '<th colspan="3" title="Number of blocks read by the statement">Reads</th>'
            '<th colspan="3" title="Number of blocks written by the statement">Writes</th>'
            '<th rowspan="2" title="Time spent by the statement">Elapsed(s)</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of shared blocks read by the statement">Shr</th>'
            '<th title="Number of local blocks read by the statement (usually used for temporary tables)">Loc</th>'
            '<th title="Number of temp blocks read by the statement (usually used for operations like sorts and joins)">Tmp</th>'
            '<th title="Number of shared blocks written by the statement">Shr</th>'
            '<th title="Number of local blocks written by the statement (usually used for temporary tables)">Loc</th>'
            '<th title="Number of temp blocks written by the statement (usually used for operations like sorts and joins)">Tmp</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top 10 queries by I/O wait time
    FOR r_result IN c_iowait_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.io_time AS numeric),3),
            round(CAST(r_result.blk_read_time AS numeric),3),
            round(CAST(r_result.blk_write_time AS numeric),3),
            round(CAST(r_result.io_time_pct AS numeric),2),
            round(CAST(r_result.shared_blks_read AS numeric)),
            round(CAST(r_result.local_blks_read AS numeric)),
            round(CAST(r_result.temp_blks_read AS numeric)),
            round(CAST(r_result.shared_blks_written AS numeric)),
            round(CAST(r_result.local_blks_written AS numeric)),
            round(CAST(r_result.temp_blks_written AS numeric)),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.calls
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_kcache_statements
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_kcache_statements(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, datid oid, dbname name, userid oid, queryid bigint, exec_user_time double precision, user_time_pct double precision, exec_system_time double precision, system_time_pct double precision, exec_minflts bigint, exec_majflts bigint, exec_nswaps bigint, exec_reads bigint, exec_writes bigint, exec_msgsnds bigint, exec_msgrcvs bigint, exec_nsignals bigint, exec_nvcsws bigint, exec_nivcsws bigint, reads_total_pct double precision, writes_total_pct double precision, plan_user_time double precision, plan_system_time double precision, plan_minflts bigint, plan_majflts bigint, plan_nswaps bigint, plan_reads bigint, plan_writes bigint, plan_msgsnds bigint, plan_msgrcvs bigint, plan_nsignals bigint, plan_nvcsws bigint, plan_nivcsws bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  WITH tot AS (
        SELECT
            COALESCE(sum(exec_user_time), 0.0) + COALESCE(sum(plan_user_time), 0.0) AS user_time,
            COALESCE(sum(exec_system_time), 0.0) + COALESCE(sum(plan_system_time), 0.0)  AS system_time,
            COALESCE(sum(exec_reads), 0) + COALESCE(sum(plan_reads), 0) AS reads,
            COALESCE(sum(exec_writes), 0) + COALESCE(sum(plan_writes), 0) AS writes
        FROM sample_kcache_total
        WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id)
    SELECT
        kc.server_id as server_id,
        kc.datid as datid,
        sample_db.datname as dbname,
        kc.userid as userid,
        kc.queryid as queryid,
        sum(kc.exec_user_time) as exec_user_time,
        ((COALESCE(sum(kc.exec_user_time), 0.0) + COALESCE(sum(kc.plan_user_time), 0.0))
          *100/NULLIF(min(tot.user_time),0.0))::float AS user_time_pct,
        sum(kc.exec_system_time) as exec_system_time,
        ((COALESCE(sum(kc.exec_system_time), 0.0) + COALESCE(sum(kc.plan_system_time), 0.0))
          *100/NULLIF(min(tot.system_time), 0.0))::float AS system_time_pct,
        sum(kc.exec_minflts)::bigint as exec_minflts,
        sum(kc.exec_majflts)::bigint as exec_majflts,
        sum(kc.exec_nswaps)::bigint as exec_nswaps,
        sum(kc.exec_reads)::bigint as exec_reads,
        sum(kc.exec_writes)::bigint as exec_writes,
        sum(kc.exec_msgsnds)::bigint as exec_msgsnds,
        sum(kc.exec_msgrcvs)::bigint as exec_msgrcvs,
        sum(kc.exec_nsignals)::bigint as exec_nsignals,
        sum(kc.exec_nvcsws)::bigint as exec_nvcsws,
        sum(kc.exec_nivcsws)::bigint as exec_nivcsws,
        ((COALESCE(sum(kc.exec_reads), 0) + COALESCE(sum(kc.plan_reads), 0))
          *100/NULLIF(min(tot.reads),0))::float AS reads_total_pct,
        ((COALESCE(sum(kc.exec_writes), 0) + COALESCE(sum(kc.plan_writes), 0))
          *100/NULLIF(min(tot.writes),0))::float AS writes_total_pct,
        sum(kc.plan_user_time) as plan_user_time,
        sum(kc.plan_system_time) as plan_system_time,
        sum(kc.plan_minflts)::bigint as plan_minflts,
        sum(kc.plan_majflts)::bigint as plan_majflts,
        sum(kc.plan_nswaps)::bigint as plan_nswaps,
        sum(kc.plan_reads)::bigint as plan_reads,
        sum(kc.plan_writes)::bigint as plan_writes,
        sum(kc.plan_msgsnds)::bigint as plan_msgsnds,
        sum(kc.plan_msgrcvs)::bigint as plan_msgrcvs,
        sum(kc.plan_nsignals)::bigint as plan_nsignals,
        sum(kc.plan_nvcsws)::bigint as plan_nvcsws,
        sum(kc.plan_nivcsws)::bigint as plan_nivcsws
   FROM sample_kcache kc
        -- Database name
        JOIN sample_stat_database sample_db
        ON (kc.server_id=sample_db.server_id AND kc.sample_id=sample_db.sample_id AND kc.datid=sample_db.datid)
        -- Total stats
        CROSS JOIN tot
    WHERE kc.server_id = sserver_id AND kc.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY kc.server_id,kc.datid,sample_db.datname,kc.userid,kc.queryid
$function$;

-- Function: top_plan_time_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_plan_time_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.plans, 0) as plans1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.total_plan_time, 0.0) as total_plan_time1,
        NULLIF(st1.plan_time_pct, 0.0) as plan_time_pct1,
        NULLIF(st1.min_plan_time, 0.0) as min_plan_time1,
        NULLIF(st1.max_plan_time, 0.0) as max_plan_time1,
        NULLIF(st1.mean_plan_time, 0.0) as mean_plan_time1,
        NULLIF(st1.stddev_plan_time, 0.0) as stddev_plan_time1,
        NULLIF(st2.plans, 0) as plans2,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.total_plan_time, 0.0) as total_plan_time2,
        NULLIF(st2.plan_time_pct, 0.0) as plan_time_pct2,
        NULLIF(st2.min_plan_time, 0.0) as min_plan_time2,
        NULLIF(st2.max_plan_time, 0.0) as max_plan_time2,
        NULLIF(st2.mean_plan_time, 0.0) as mean_plan_time2,
        NULLIF(st2.stddev_plan_time, 0.0) as stddev_plan_time2,
        row_number() over (ORDER BY st1.total_plan_time DESC NULLS LAST) as rn_time1,
        row_number() over (ORDER BY st2.total_plan_time DESC NULLS LAST) as rn_time2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    ORDER BY COALESCE(st1.total_plan_time,0) + COALESCE(st2.total_plan_time,0) DESC,
      COALESCE(st1.total_exec_time,0) + COALESCE(st2.total_exec_time,0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_time1,
        rn_time2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Time spent planning statement">Plan elapsed (s)</th>'
            '<th rowspan="2" title="Plan elapsed as a percentage of statement elapsed time">%Elapsed</th>'
            '<th colspan="4" title="Planning time statistics">Plan times (ms)</th>'
            '<th rowspan="2" title="Number of times the statement was planned">Plans</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th>Mean</th>'
            '<th>Min</th>'
            '<th>Max</th>'
            '<th>StdErr</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
          '<td {value}>%17$s</td>'
          '<td {value}>%18$s</td>'
          '<td {value}>%19$s</td>'
          '<td {value}>%20$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.total_plan_time1 AS numeric),2),
            round(CAST(r_result.plan_time_pct1 AS numeric),2),
            round(CAST(r_result.mean_plan_time1 AS numeric),3),
            round(CAST(r_result.min_plan_time1 AS numeric),3),
            round(CAST(r_result.max_plan_time1 AS numeric),3),
            round(CAST(r_result.stddev_plan_time1 AS numeric),3),
            r_result.plans1,
            r_result.calls1,
            round(CAST(r_result.total_plan_time2 AS numeric),2),
            round(CAST(r_result.plan_time_pct2 AS numeric),2),
            round(CAST(r_result.mean_plan_time2 AS numeric),3),
            round(CAST(r_result.min_plan_time2 AS numeric),3),
            round(CAST(r_result.max_plan_time2 AS numeric),3),
            round(CAST(r_result.stddev_plan_time2 AS numeric),3),
            r_result.plans2,
            r_result.calls2
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_plan_time_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_plan_time_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for queries ordered by planning time
    c_elapsed_time CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.plans, 0) as plans,
        NULLIF(st.calls, 0) as calls,
        NULLIF(st.total_plan_time, 0.0) as total_plan_time,
        NULLIF(st.plan_time_pct, 0.0) as plan_time_pct,
        NULLIF(st.min_plan_time, 0.0) as min_plan_time,
        NULLIF(st.max_plan_time, 0.0) as max_plan_time,
        NULLIF(st.mean_plan_time, 0.0) as mean_plan_time,
        NULLIF(st.stddev_plan_time, 0.0) as stddev_plan_time
    FROM top_statements st
    ORDER BY st.total_plan_time DESC,
      st.total_exec_time DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when planning timing is available
    IF NOT jsonb_extract_path_text(jreportset, 'report_features', 'planning_times')::boolean THEN
      RETURN '';
    END IF;

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2" title="Time spent planning statement">Plan elapsed (s)</th>'
            '<th rowspan="2" title="Plan elapsed as a percentage of statement elapsed time">%Elapsed</th>'
            '<th colspan="4" title="Planning time statistics">Plan times (ms)</th>'
            '<th rowspan="2" title="Number of times the statement was planned">Plans</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th>Mean</th>'
            '<th>Min</th>'
            '<th>Max</th>'
            '<th>StdErr</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%4$s</td>'
          '<td {value}>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
        '</tr>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            round(CAST(r_result.total_plan_time AS numeric),2),
            round(CAST(r_result.plan_time_pct AS numeric),2),
            round(CAST(r_result.mean_plan_time AS numeric),3),
            round(CAST(r_result.min_plan_time AS numeric),3),
            round(CAST(r_result.max_plan_time AS numeric),3),
            round(CAST(r_result.stddev_plan_time AS numeric),3),
            r_result.plans,
            r_result.calls
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_scan_tables_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_scan_tables_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(tbl1.dbname,tbl2.dbname) AS dbname,
        COALESCE(tbl1.tablespacename,tbl2.tablespacename) AS tablespacename,
        COALESCE(tbl1.schemaname,tbl2.schemaname) AS schemaname,
        COALESCE(tbl1.relname,tbl2.relname) AS relname,
        NULLIF(tbl1.seq_scan, 0) AS seq_scan1,
        tbl1_seq_scan.approximated AS seq_scan_bytes_approximated1,
        NULLIF(tbl1_seq_scan.seq_scan_bytes, 0) AS seq_scan_bytes1,
        NULLIF(tbl1.idx_scan, 0) AS idx_scan1,
        NULLIF(tbl1.idx_tup_fetch, 0) AS idx_tup_fetch1,
        NULLIF(tbl1.toastseq_scan, 0) AS toastseq_scan1,
        toast1_seq_scan.approximated AS toastseq_scan_bytes_approximated1,
        NULLIF(toast1_seq_scan.seq_scan_bytes, 0) AS toastseq_scan_bytes1,
        NULLIF(tbl1.toastidx_scan, 0) AS toastidx_scan1,
        NULLIF(tbl1.toastidx_tup_fetch, 0) AS toastidx_tup_fetch1,
        NULLIF(tbl2.seq_scan, 0) AS seq_scan2,
        tbl2_seq_scan.approximated AS seq_scan_bytes_approximated2,
        NULLIF(tbl2_seq_scan.seq_scan_bytes, 0) AS seq_scan_bytes2,
        NULLIF(tbl2.idx_scan, 0) AS idx_scan2,
        NULLIF(tbl2.idx_tup_fetch, 0) AS idx_tup_fetch2,
        NULLIF(tbl2.toastseq_scan, 0) AS toastseq_scan2,
        toast2_seq_scan.approximated AS toastseq_scan_bytes_approximated2,
        NULLIF(toast2_seq_scan.seq_scan_bytes, 0) AS toastseq_scan_bytes2,
        NULLIF(tbl2.toastidx_scan, 0) AS toastidx_scan2,
        NULLIF(tbl2.toastidx_tup_fetch, 0) AS toastidx_tup_fetch2,
        row_number() over (ORDER BY
          COALESCE(tbl1_seq_scan.seq_scan_bytes, 0) + COALESCE(toast1_seq_scan.seq_scan_bytes, 0)
          DESC NULLS LAST) AS rn_seqpg1,
        row_number() over (ORDER BY
          COALESCE(tbl2_seq_scan.seq_scan_bytes, 0) + COALESCE(toast2_seq_scan.seq_scan_bytes, 0)
          DESC NULLS LAST) AS rn_seqpg2
    FROM top_tables1 tbl1
        FULL OUTER JOIN top_tables2 tbl2 USING (server_id, datid, relid)
    LEFT OUTER JOIN (
      SELECT
        server_id,
        datid,
        relid,
        round(sum(seq_scan * relsize))::bigint as seq_scan_bytes,
        count(nullif(relsize, 0)) != count(nullif(seq_scan, 0)) as approximated
      FROM sample_stat_tables
      WHERE server_id = sserver_id AND sample_id BETWEEN start1_id + 1 AND end1_id
      GROUP BY
        server_id,
        datid,
        relid
    ) tbl1_seq_scan ON (tbl1.server_id,tbl1.datid,tbl1.relid) =
      (tbl1_seq_scan.server_id,tbl1_seq_scan.datid,tbl1_seq_scan.relid)
    LEFT OUTER JOIN (
      SELECT
        server_id,
        datid,
        relid,
        round(sum(seq_scan * relsize))::bigint as seq_scan_bytes,
        count(nullif(relsize, 0)) != count(nullif(seq_scan, 0)) as approximated
      FROM sample_stat_tables
      WHERE server_id = sserver_id AND sample_id BETWEEN start1_id + 1 AND end1_id
      GROUP BY
        server_id,
        datid,
        relid
    ) toast1_seq_scan ON (tbl1.server_id,tbl1.datid,tbl1.reltoastrelid) =
      (toast1_seq_scan.server_id,toast1_seq_scan.datid,toast1_seq_scan.relid)
    LEFT OUTER JOIN (
      SELECT
        server_id,
        datid,
        relid,
        round(sum(seq_scan * relsize))::bigint as seq_scan_bytes,
        count(nullif(relsize, 0)) != count(nullif(seq_scan, 0)) as approximated
      FROM sample_stat_tables
      WHERE server_id = sserver_id AND sample_id BETWEEN start2_id + 1 AND end2_id
      GROUP BY
        server_id,
        datid,
        relid
    ) tbl2_seq_scan ON (tbl2.server_id,tbl2.datid,tbl2.relid) =
      (tbl2_seq_scan.server_id,tbl2_seq_scan.datid,tbl2_seq_scan.relid)
    LEFT OUTER JOIN (
      SELECT
        server_id,
        datid,
        relid,
        round(sum(seq_scan * relsize))::bigint as seq_scan_bytes,
        count(nullif(relsize, 0)) != count(nullif(seq_scan, 0)) as approximated
      FROM sample_stat_tables
      WHERE server_id = sserver_id AND sample_id BETWEEN start2_id + 1 AND end2_id
      GROUP BY
        server_id,
        datid,
        relid
    ) toast2_seq_scan ON (tbl2.server_id,tbl2.datid,tbl2.reltoastrelid) =
      (toast2_seq_scan.server_id,toast2_seq_scan.datid,toast2_seq_scan.relid)
    WHERE COALESCE(tbl1_seq_scan.seq_scan_bytes, 0) +
      COALESCE(toast1_seq_scan.seq_scan_bytes, 0) +
      COALESCE(tbl2_seq_scan.seq_scan_bytes, 0) +
      COALESCE(toast2_seq_scan.seq_scan_bytes, 0) > 0
    ORDER BY
      COALESCE(tbl1_seq_scan.seq_scan_bytes, 0) +
      COALESCE(toast1_seq_scan.seq_scan_bytes, 0) +
      COALESCE(tbl2_seq_scan.seq_scan_bytes, 0) +
      COALESCE(toast2_seq_scan.seq_scan_bytes, 0) DESC,
      COALESCE(tbl1.datid,tbl2.datid) ASC,
      COALESCE(tbl1.relid,tbl2.relid) ASC
    ) t1
    WHERE least(
        rn_seqpg1,
        rn_seqpg2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">DB</th>'
            '<th rowspan="2">Tablespace</th>'
            '<th rowspan="2">Schema</th>'
            '<th rowspan="2">Table</th>'
            '<th rowspan="2">I</th>'
            '<th colspan="4">Table</th>'
            '<th colspan="4">TOAST</th>'
          '</tr>'
          '<tr>'
            '<th title="Estimated number of blocks, fetched by sequential scans">~SeqBytes</th>'
            '<th title="Number of sequential scans initiated on this table">SeqScan</th>'
            '<th title="Number of index scans initiated on this table">IxScan</th>'
            '<th title="Number of live rows fetched by index scans">IxFet</th>'
            '<th title="Estimated number of blocks, fetched by sequential scans">~SeqBytes</th>'
            '<th title="Number of sequential scans initiated on this table">SeqScan</th>'
            '<th title="Number of index scans initiated on this table">IxScan</th>'
            '<th title="Number of live rows fetched by index scans">IxFet</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            CASE WHEN r_result.seq_scan_bytes_approximated1 THEN '~'
              ELSE ''
            END||pg_size_pretty(r_result.seq_scan_bytes1),
            r_result.seq_scan1,
            r_result.idx_scan1,
            r_result.idx_tup_fetch1,
            CASE WHEN r_result.toastseq_scan_bytes_approximated1 THEN '~'
              ELSE ''
            END||pg_size_pretty(r_result.toastseq_scan_bytes1),
            r_result.toastseq_scan1,
            r_result.toastidx_scan1,
            r_result.toastidx_tup_fetch1,
            CASE WHEN r_result.seq_scan_bytes_approximated2 THEN '~'
              ELSE ''
            END||pg_size_pretty(r_result.seq_scan_bytes2),
            r_result.seq_scan2,
            r_result.idx_scan2,
            r_result.idx_tup_fetch2,
            CASE WHEN r_result.toastseq_scan_bytes_approximated2 THEN '~'
              ELSE ''
            END||pg_size_pretty(r_result.toastseq_scan_bytes2),
            r_result.toastseq_scan2,
            r_result.toastidx_scan2,
            r_result.toastidx_tup_fetch2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN report;
END;
$function$;

-- Function: top_scan_tables_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_scan_tables_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        tablespacename,
        schemaname,
        relname,
        reltoastrelid,
        NULLIF(seq_scan, 0) as seq_scan,
        NULLIF(tbl_seq_scan.seq_scan_bytes, 0) as seq_scan_bytes,
        tbl_seq_scan.approximated as seq_scan_approximated,
        NULLIF(idx_scan, 0) as idx_scan,
        NULLIF(idx_tup_fetch, 0) as idx_tup_fetch,
        NULLIF(n_tup_ins, 0) as n_tup_ins,
        NULLIF(n_tup_upd, 0) as n_tup_upd,
        NULLIF(n_tup_del, 0) as n_tup_del,
        NULLIF(n_tup_hot_upd, 0) as n_tup_hot_upd,
        NULLIF(toastseq_scan, 0) as toastseq_scan,
        NULLIF(toast_seq_scan.seq_scan_bytes, 0) as toast_seq_scan_bytes,
        toast_seq_scan.approximated as toast_seq_scan_approximated,
        NULLIF(toastidx_scan, 0) as toastidx_scan,
        NULLIF(toastidx_tup_fetch, 0) as toastidx_tup_fetch,
        NULLIF(toastn_tup_ins, 0) as toastn_tup_ins,
        NULLIF(toastn_tup_upd, 0) as toastn_tup_upd,
        NULLIF(toastn_tup_del, 0) as toastn_tup_del,
        NULLIF(toastn_tup_hot_upd, 0) as toastn_tup_hot_upd
    FROM top_tables tt
    LEFT OUTER JOIN (
      SELECT
        server_id,
        datid,
        relid,
        round(sum(seq_scan * relsize))::bigint as seq_scan_bytes,
        count(nullif(relsize, 0)) != count(nullif(seq_scan, 0)) as approximated
      FROM sample_stat_tables
      WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id
      GROUP BY
        server_id,
        datid,
        relid
    ) tbl_seq_scan ON (tt.server_id,tt.datid,tt.relid) =
      (tbl_seq_scan.server_id,tbl_seq_scan.datid,tbl_seq_scan.relid)
    LEFT OUTER JOIN (
      SELECT
        server_id,
        datid,
        relid,
        round(sum(seq_scan * relsize))::bigint as seq_scan_bytes,
        count(nullif(relsize, 0)) != count(nullif(seq_scan, 0)) as approximated
      FROM sample_stat_tables
      WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id
      GROUP BY
        server_id,
        datid,
        relid
    ) toast_seq_scan ON (tt.server_id,tt.datid,tt.reltoastrelid) =
      (toast_seq_scan.server_id,toast_seq_scan.datid,toast_seq_scan.relid)
    WHERE
      COALESCE(tbl_seq_scan.seq_scan_bytes, 0) + COALESCE(toast_seq_scan.seq_scan_bytes, 0) > 0
    ORDER BY
      COALESCE(tbl_seq_scan.seq_scan_bytes, 0) + COALESCE(toast_seq_scan.seq_scan_bytes, 0) DESC,
      tt.datid ASC,
      tt.relid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN

    --- Populate templates
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th title="Estimated number of bytes, fetched by sequential scans">~SeqBytes</th>'
            '<th title="Number of sequential scans initiated on this table">SeqScan</th>'
            '<th title="Number of index scans initiated on this table">IxScan</th>'
            '<th title="Number of live rows fetched by index scans">IxFet</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'rel_tpl',
        '<tr {reltr}>'
          '<td {reltdhdr}>%s</td>'
          '<td {reltdhdr}>%s</td>'
          '<td {reltdhdr}>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'rel_wtoast_tpl',
        '<tr {reltr}>'
          '<td {reltdspanhdr}>%s</td>'
          '<td {reltdspanhdr}>%s</td>'
          '<td {reltdspanhdr}>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {toasttr}>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);


    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
        IF r_result.reltoastrelid IS NULL THEN
          report := report||format(
              jtab_tpl #>> ARRAY['rel_tpl'],
              r_result.dbname,
              r_result.tablespacename,
              r_result.schemaname,
              r_result.relname,
              CASE WHEN r_result.seq_scan_approximated THEN '~'
                ELSE ''
              END||pg_size_pretty(r_result.seq_scan_bytes),
              r_result.seq_scan,
              r_result.idx_scan,
              r_result.idx_tup_fetch,
              r_result.n_tup_ins,
              r_result.n_tup_upd,
              r_result.n_tup_del,
              r_result.n_tup_hot_upd
          );
        ELSE
          report := report||format(
              jtab_tpl #>> ARRAY['rel_wtoast_tpl'],
              r_result.dbname,
              r_result.tablespacename,
              r_result.schemaname,
              r_result.relname,
              CASE WHEN r_result.seq_scan_approximated THEN '~'
                ELSE ''
              END||pg_size_pretty(r_result.seq_scan_bytes),
              r_result.seq_scan,
              r_result.idx_scan,
              r_result.idx_tup_fetch,
              r_result.n_tup_ins,
              r_result.n_tup_upd,
              r_result.n_tup_del,
              r_result.n_tup_hot_upd,
              r_result.relname||'(TOAST)',
              CASE WHEN r_result.toast_seq_scan_approximated THEN '~'
                ELSE ''
              END||pg_size_pretty(r_result.toast_seq_scan_bytes),
              r_result.toastseq_scan,
              r_result.toastidx_scan,
              r_result.toastidx_tup_fetch,
              r_result.toastn_tup_ins,
              r_result.toastn_tup_upd,
              r_result.toastn_tup_del,
              r_result.toastn_tup_hot_upd
          );
        END IF;
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN report;
END;
$function$;

-- Function: top_shared_blks_fetched_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_shared_blks_fetched_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by shared_blks_fetched
    c_shared_blks_fetched CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.shared_blks_fetched, 0) as shared_blks_fetched1,
        NULLIF(st1.shared_blks_fetched_pct, 0.0) as shared_blks_fetched_pct1,
        NULLIF(st1.shared_hit_pct, 0.0) as shared_hit_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.shared_blks_fetched, 0) as shared_blks_fetched2,
        NULLIF(st2.shared_blks_fetched_pct, 0.0) as shared_blks_fetched_pct2,
        NULLIF(st2.shared_hit_pct, 0.0) as shared_hit_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY st1.shared_blks_fetched DESC NULLS LAST) as rn_shared_blks_fetched1,
        row_number() over (ORDER BY st2.shared_blks_fetched DESC NULLS LAST) as rn_shared_blks_fetched2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(st1.shared_blks_fetched, 0) + COALESCE(st2.shared_blks_fetched, 0) > 0
    ORDER BY COALESCE(st1.shared_blks_fetched, 0) + COALESCE(st2.shared_blks_fetched, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_shared_blks_fetched1,
        rn_shared_blks_fetched2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Fetched (blk) sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>I</th>'
            '<th title="Shared blocks fetched (read and hit) by the statement">blks fetched</th>'
            '<th title="Shared blocks fetched by this statement as a percentage of all shared blocks fetched in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by shared_blks_fetched
    FOR r_result IN c_shared_blks_fetched LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.shared_blks_fetched1,
            round(CAST(r_result.shared_blks_fetched_pct1 AS numeric),2),
            round(CAST(r_result.shared_hit_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.shared_blks_fetched2,
            round(CAST(r_result.shared_blks_fetched_pct2 AS numeric),2),
            round(CAST(r_result.shared_hit_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_shared_blks_fetched_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_shared_blks_fetched_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by shared_blks_fetched
    c_shared_blks_fetched CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.shared_blks_fetched, 0) as shared_blks_fetched,
        NULLIF(st.shared_blks_fetched_pct, 0.0) as shared_blks_fetched_pct,
        NULLIF(st.shared_hit_pct, 0.0) as shared_hit_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements st
    WHERE shared_blks_fetched > 0
    ORDER BY st.shared_blks_fetched DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th title="Shared blocks fetched (read and hit) by the statement">blks fetched</th>'
            '<th title="Shared blocks fetched by this statement as a percentage of all shared blocks fetched in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by shared_blks_fetched
    FOR r_result IN c_shared_blks_fetched LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.shared_blks_fetched,
            round(CAST(r_result.shared_blks_fetched_pct AS numeric),2),
            round(CAST(r_result.shared_hit_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_shared_dirtied_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_shared_dirtied_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by shared dirtied
    c_sh_dirt CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.shared_blks_dirtied, 0) as shared_blks_dirtied1,
        NULLIF(st1.dirtied_pct, 0.0) as dirtied_pct1,
        NULLIF(st1.shared_hit_pct, 0.0) as shared_hit_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.shared_blks_dirtied, 0) as shared_blks_dirtied2,
        NULLIF(st2.dirtied_pct, 0.0) as dirtied_pct2,
        NULLIF(st2.shared_hit_pct, 0.0) as shared_hit_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY st1.shared_blks_dirtied DESC NULLS LAST) as rn_dirtied1,
        row_number() over (ORDER BY st2.shared_blks_dirtied DESC NULLS LAST) as rn_dirtied2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(st1.shared_blks_dirtied, 0) + COALESCE(st2.shared_blks_dirtied, 0) > 0
    ORDER BY COALESCE(st1.shared_blks_dirtied, 0) + COALESCE(st2.shared_blks_dirtied, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_dirtied1,
        rn_dirtied2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Dirtied sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>I</th>'
            '<th title="Total number of shared blocks dirtied by the statement">Dirtied</th>'
            '<th title="Shared blocks dirtied by this statement as a percentage of all shared blocks dirtied in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by shared dirtied
    FOR r_result IN c_sh_dirt LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.shared_blks_dirtied1,
            round(CAST(r_result.dirtied_pct1 AS numeric),2),
            round(CAST(r_result.shared_hit_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.shared_blks_dirtied2,
            round(CAST(r_result.dirtied_pct2 AS numeric),2),
            round(CAST(r_result.shared_hit_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_shared_dirtied_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_shared_dirtied_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by shared dirtied
    c_sh_dirt CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.shared_blks_dirtied, 0) as shared_blks_dirtied,
        NULLIF(st.dirtied_pct, 0.0) as dirtied_pct,
        NULLIF(st.shared_hit_pct, 0.0) as shared_hit_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements st
    WHERE st.shared_blks_dirtied > 0
    ORDER BY st.shared_blks_dirtied DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th title="Total number of shared blocks dirtied by the statement">Dirtied</th>'
            '<th title="Shared blocks dirtied by this statement as a percentage of all shared blocks dirtied in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by shared dirtied
    FOR r_result IN c_sh_dirt LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.shared_blks_dirtied,
            round(CAST(r_result.dirtied_pct AS numeric),2),
            round(CAST(r_result.shared_hit_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_shared_reads_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_shared_reads_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by reads
    c_sh_reads CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.shared_blks_read, 0.0) as shared_blks_read1,
        NULLIF(st1.read_pct, 0.0) as read_pct1,
        NULLIF(st1.shared_hit_pct, 0.0) as shared_hit_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.shared_blks_read, 0) as shared_blks_read2,
        NULLIF(st2.read_pct, 0.0) as read_pct2,
        NULLIF(st2.shared_hit_pct, 0.0) as shared_hit_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY st1.shared_blks_read DESC NULLS LAST) as rn_reads1,
        row_number() over (ORDER BY st2.shared_blks_read DESC NULLS LAST) as rn_reads2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(st1.shared_blks_read, 0) + COALESCE(st2.shared_blks_read, 0) > 0
    ORDER BY COALESCE(st1.shared_blks_read, 0) + COALESCE(st2.shared_blks_read, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_reads1,
        rn_reads2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Reads sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>I</th>'
            '<th title="Total number of shared blocks read by the statement">Reads</th>'
            '<th title="Shared blocks read by this statement as a percentage of all shared blocks read in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by reads
    FOR r_result IN c_sh_reads LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.shared_blks_read1,
            round(CAST(r_result.read_pct1 AS numeric),2),
            round(CAST(r_result.shared_hit_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.shared_blks_read2,
            round(CAST(r_result.read_pct2 AS numeric),2),
            round(CAST(r_result.shared_hit_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_shared_reads_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_shared_reads_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by reads
    c_sh_reads CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.shared_blks_read, 0) as shared_blks_read,
        NULLIF(st.read_pct, 0.0) as read_pct,
        NULLIF(st.shared_hit_pct, 0.0) as shared_hit_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements st
    WHERE st.shared_blks_read > 0
    ORDER BY st.shared_blks_read DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th title="Total number of shared blocks read by the statement">Reads</th>'
            '<th title="Shared blocks read by this statement as a percentage of all shared blocks read in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by reads
    FOR r_result IN c_sh_reads LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.shared_blks_read,
            round(CAST(r_result.read_pct AS numeric),2),
            round(CAST(r_result.shared_hit_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_shared_written_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_shared_written_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by shared written
    c_sh_wr CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.shared_blks_written, 0) as shared_blks_written1,
        NULLIF(st1.tot_written_pct, 0.0) as tot_written_pct1,
        NULLIF(st1.backend_written_pct, 0.0) as backend_written_pct1,
        NULLIF(st1.shared_hit_pct, 0.0) as shared_hit_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.shared_blks_written, 0) as shared_blks_written2,
        NULLIF(st2.tot_written_pct, 0.0) as tot_written_pct2,
        NULLIF(st2.backend_written_pct, 0.0) as backend_written_pct2,
        NULLIF(st2.shared_hit_pct, 0.0) as shared_hit_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY st1.shared_blks_written DESC NULLS LAST) as rn_written1,
        row_number() over (ORDER BY st2.shared_blks_written DESC NULLS LAST) as rn_written2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(st1.shared_blks_written, 0) + COALESCE(st2.shared_blks_written, 0) > 0
    ORDER BY COALESCE(st1.shared_blks_written, 0) + COALESCE(st2.shared_blks_written, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_written1,
        rn_written2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Shared written sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>I</th>'
            '<th title="Total number of shared blocks written by the statement">Written</th>'
            '<th title="Shared blocks written by this statement as a percentage of all shared blocks written in a cluster (sum of pg_stat_bgwriter fields buffers_checkpoint, buffers_clean and buffers_backend)">%Total</th>'
            '<th title="Shared blocks written by this statement as a percentage total buffers written directly by a backends (buffers_backend field of pg_stat_bgwriter view)">%BackendW</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by shared written
    FOR r_result IN c_sh_wr LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.shared_blks_written1,
            round(CAST(r_result.tot_written_pct1 AS numeric),2),
            round(CAST(r_result.backend_written_pct1 AS numeric),2),
            round(CAST(r_result.shared_hit_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.shared_blks_written2,
            round(CAST(r_result.tot_written_pct2 AS numeric),2),
            round(CAST(r_result.backend_written_pct2 AS numeric),2),
            round(CAST(r_result.shared_hit_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_shared_written_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_shared_written_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by shared written
    c_sh_wr CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.shared_blks_written, 0) as shared_blks_written,
        NULLIF(st.tot_written_pct, 0.0) as tot_written_pct,
        NULLIF(st.backend_written_pct, 0.0) as backend_written_pct,
        NULLIF(st.shared_hit_pct, 0.0) as shared_hit_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements st
    WHERE st.shared_blks_written > 0
    ORDER BY st.shared_blks_written DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th title="Total number of shared blocks written by the statement">Written</th>'
            '<th title="Shared blocks written by this statement as a percentage of all shared blocks written in a cluster (sum of pg_stat_bgwriter fields buffers_checkpoint, buffers_clean and buffers_backend)">%Total</th>'
            '<th title="Shared blocks written by this statement as a percentage total buffers written directly by a backends (buffers_backend of pg_stat_bgwriter view)">%BackendW</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by shared written
    FOR r_result IN c_sh_wr LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.shared_blks_written,
            round(CAST(r_result.tot_written_pct AS numeric),2),
            round(CAST(r_result.backend_written_pct AS numeric),2),
            round(CAST(r_result.shared_hit_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_statements
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_statements(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, datid oid, dbname name, userid oid, queryid bigint, plans bigint, plans_pct double precision, calls bigint, calls_pct double precision, total_time double precision, total_time_pct double precision, total_plan_time double precision, plan_time_pct double precision, total_exec_time double precision, total_exec_time_pct double precision, exec_time_pct double precision, min_exec_time double precision, max_exec_time double precision, mean_exec_time double precision, stddev_exec_time double precision, min_plan_time double precision, max_plan_time double precision, mean_plan_time double precision, stddev_plan_time double precision, rows bigint, shared_blks_hit bigint, shared_hit_pct double precision, shared_blks_read bigint, read_pct double precision, shared_blks_fetched bigint, shared_blks_fetched_pct double precision, shared_blks_dirtied bigint, dirtied_pct double precision, shared_blks_written bigint, tot_written_pct double precision, backend_written_pct double precision, local_blks_hit bigint, local_hit_pct double precision, local_blks_read bigint, local_blks_fetched bigint, local_blks_dirtied bigint, local_blks_written bigint, temp_blks_read bigint, temp_blks_written bigint, blk_read_time double precision, blk_write_time double precision, io_time double precision, io_time_pct double precision, temp_read_total_pct double precision, temp_write_total_pct double precision, local_read_total_pct double precision, local_write_total_pct double precision, wal_records bigint, wal_fpi bigint, wal_bytes numeric, wal_bytes_pct double precision, user_time double precision, system_time double precision, reads bigint, writes bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    WITH
      tot AS (
        SELECT
            COALESCE(sum(total_plan_time), 0.0) + sum(total_exec_time) AS total_time,
            sum(blk_read_time) AS blk_read_time,
            sum(blk_write_time) AS blk_write_time,
            sum(shared_blks_hit) AS shared_blks_hit,
            sum(shared_blks_read) AS shared_blks_read,
            sum(shared_blks_dirtied) AS shared_blks_dirtied,
            sum(temp_blks_read) AS temp_blks_read,
            sum(temp_blks_written) AS temp_blks_written,
            sum(local_blks_read) AS local_blks_read,
            sum(local_blks_written) AS local_blks_written,
            sum(calls) AS calls,
            sum(plans) AS plans
        FROM sample_statements_total st
        WHERE st.server_id = sserver_id AND st.sample_id BETWEEN start_id + 1 AND end_id
      ),
      totbgwr AS (
        SELECT
          sum(buffers_checkpoint) + sum(buffers_clean) + sum(buffers_backend) AS written,
          sum(buffers_backend) AS buffers_backend,
          sum(wal_size) AS wal_size
        FROM sample_stat_cluster
        WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id
      )
    SELECT
        st.server_id as server_id,
        st.datid as datid,
        sample_db.datname as dbname,
        st.userid as userid,
        st.queryid as queryid,
        sum(st.plans)::bigint as plans,
        (sum(st.plans)*100/NULLIF(min(tot.plans), 0))::float as plans_pct,
        sum(st.calls)::bigint as calls,
        (sum(st.calls)*100/NULLIF(min(tot.calls), 0))::float as calls_pct,
        (sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0))/1000 as total_time,
        (sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0))*100/NULLIF(min(tot.total_time), 0) as total_time_pct,
        sum(st.total_plan_time)/1000 as total_plan_time,
        sum(st.total_plan_time)*100/NULLIF(sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0), 0) as plan_time_pct,
        sum(st.total_exec_time)/1000 as total_exec_time,
        sum(st.total_exec_time)*100/NULLIF(min(tot.total_time), 0) as total_exec_time_pct,
        sum(st.total_exec_time)*100/NULLIF(sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0), 0) as exec_time_pct,
        min(st.min_exec_time) as min_exec_time,
        max(st.max_exec_time) as max_exec_time,
        sum(st.mean_exec_time*st.calls)/NULLIF(sum(st.calls), 0) as mean_exec_time,
        sqrt(sum((power(st.stddev_exec_time,2)+power(st.mean_exec_time,2))*st.calls)/NULLIF(sum(st.calls),0)-power(sum(st.mean_exec_time*st.calls)/NULLIF(sum(st.calls),0),2)) as stddev_exec_time,
        min(st.min_plan_time) as min_plan_time,
        max(st.max_plan_time) as max_plan_time,
        sum(st.mean_plan_time*st.plans)/NULLIF(sum(st.plans),0) as mean_plan_time,
        sqrt(sum((power(st.stddev_plan_time,2)+power(st.mean_plan_time,2))*st.plans)/NULLIF(sum(st.plans),0)-power(sum(st.mean_plan_time*st.plans)/NULLIF(sum(st.plans),0),2)) as stddev_plan_time,
        sum(st.rows)::bigint as rows,
        sum(st.shared_blks_hit)::bigint as shared_blks_hit,
        (sum(st.shared_blks_hit) * 100 / NULLIF(sum(st.shared_blks_hit) + sum(st.shared_blks_read), 0))::float as shared_hit_pct,
        sum(st.shared_blks_read)::bigint as shared_blks_read,
        (sum(st.shared_blks_read) * 100 / NULLIF(min(tot.shared_blks_read), 0))::float as read_pct,
        (sum(st.shared_blks_hit) + sum(st.shared_blks_read))::bigint as shared_blks_fetched,
        ((sum(st.shared_blks_hit) + sum(st.shared_blks_read)) * 100 / NULLIF(min(tot.shared_blks_hit) + min(tot.shared_blks_read), 0))::float as shared_blks_fetched_pct,
        sum(st.shared_blks_dirtied)::bigint as shared_blks_dirtied,
        (sum(st.shared_blks_dirtied) * 100 / NULLIF(min(tot.shared_blks_dirtied), 0))::float as dirtied_pct,
        sum(st.shared_blks_written)::bigint as shared_blks_written,
        (sum(st.shared_blks_written) * 100 / NULLIF(min(totbgwr.written), 0))::float as tot_written_pct,
        (sum(st.shared_blks_written) * 100 / NULLIF(min(totbgwr.buffers_backend), 0))::float as backend_written_pct,
        sum(st.local_blks_hit)::bigint as local_blks_hit,
        (sum(st.local_blks_hit) * 100 / NULLIF(sum(st.local_blks_hit) + sum(st.local_blks_read),0))::float as local_hit_pct,
        sum(st.local_blks_read)::bigint as local_blks_read,
        (sum(st.local_blks_hit) + sum(st.local_blks_read))::bigint as local_blks_fetched,
        sum(st.local_blks_dirtied)::bigint as local_blks_dirtied,
        sum(st.local_blks_written)::bigint as local_blks_written,
        sum(st.temp_blks_read)::bigint as temp_blks_read,
        sum(st.temp_blks_written)::bigint as temp_blks_written,
        sum(st.blk_read_time)/1000 as blk_read_time,
        sum(st.blk_write_time)/1000 as blk_write_time,
        (sum(st.blk_read_time) + sum(st.blk_write_time))/1000 as io_time,
        (sum(st.blk_read_time) + sum(st.blk_write_time)) * 100 / NULLIF(min(tot.blk_read_time) + min(tot.blk_write_time),0) as io_time_pct,
        (sum(st.temp_blks_read) * 100 / NULLIF(min(tot.temp_blks_read), 0))::float as temp_read_total_pct,
        (sum(st.temp_blks_written) * 100 / NULLIF(min(tot.temp_blks_written), 0))::float as temp_write_total_pct,
        (sum(st.local_blks_read) * 100 / NULLIF(min(tot.local_blks_read), 0))::float as local_read_total_pct,
        (sum(st.local_blks_written) * 100 / NULLIF(min(tot.local_blks_written), 0))::float as local_write_total_pct,
        sum(st.wal_records)::bigint as wal_records,
        sum(st.wal_fpi)::bigint as wal_fpi,
        sum(st.wal_bytes) as wal_bytes,
        (sum(st.wal_bytes) * 100 / NULLIF(min(totbgwr.wal_size), 0))::float wal_bytes_pct,
        -- kcache stats
        COALESCE(sum(kc.exec_user_time), 0.0) + COALESCE(sum(kc.plan_user_time), 0.0) as user_time,
        COALESCE(sum(kc.exec_system_time), 0.0) + COALESCE(sum(kc.plan_system_time), 0.0) as system_time,
        (COALESCE(sum(kc.exec_reads), 0) + COALESCE(sum(kc.plan_reads), 0))::bigint as reads,
        (COALESCE(sum(kc.exec_writes), 0) + COALESCE(sum(kc.plan_writes), 0))::bigint as writes
    FROM sample_statements st
        -- kcache join
        LEFT OUTER JOIN sample_kcache kc USING(server_id, sample_id, userid, datid, queryid)
        -- Database name
        JOIN sample_stat_database sample_db
        ON (st.server_id=sample_db.server_id AND st.sample_id=sample_db.sample_id AND st.datid=sample_db.datid)
        -- Total stats
        CROSS JOIN tot CROSS JOIN totbgwr
    WHERE st.server_id = sserver_id AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id,st.datid,sample_db.datname,st.userid,st.queryid
$function$;

-- Function: top_tables
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_tables(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, datid oid, relid oid, reltoastrelid oid, dbname name, tablespacename name, schemaname name, relname name, seq_scan bigint, seq_tup_read bigint, idx_scan bigint, idx_tup_fetch bigint, n_tup_ins bigint, n_tup_upd bigint, n_tup_del bigint, n_tup_hot_upd bigint, vacuum_count bigint, autovacuum_count bigint, analyze_count bigint, autoanalyze_count bigint, growth bigint, toastseq_scan bigint, toastseq_tup_read bigint, toastidx_scan bigint, toastidx_tup_fetch bigint, toastn_tup_ins bigint, toastn_tup_upd bigint, toastn_tup_del bigint, toastn_tup_hot_upd bigint, toastvacuum_count bigint, toastautovacuum_count bigint, toastanalyze_count bigint, toastautoanalyze_count bigint, toastgrowth bigint)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        st.server_id,
        st.datid,
        st.relid,
        st.reltoastrelid,
        sample_db.datname AS dbname,
        tl.tablespacename,
        st.schemaname,
        st.relname,
        sum(st.seq_scan)::bigint AS seq_scan,
        sum(st.seq_tup_read)::bigint AS seq_tup_read,
        sum(st.idx_scan)::bigint AS idx_scan,
        sum(st.idx_tup_fetch)::bigint AS idx_tup_fetch,
        sum(st.n_tup_ins)::bigint AS n_tup_ins,
        sum(st.n_tup_upd)::bigint AS n_tup_upd,
        sum(st.n_tup_del)::bigint AS n_tup_del,
        sum(st.n_tup_hot_upd)::bigint AS n_tup_hot_upd,
        sum(st.vacuum_count)::bigint AS vacuum_count,
        sum(st.autovacuum_count)::bigint AS autovacuum_count,
        sum(st.analyze_count)::bigint AS analyze_count,
        sum(st.autoanalyze_count)::bigint AS autoanalyze_count,
        sum(st.relsize_diff)::bigint AS growth,
        sum(stt.seq_scan)::bigint AS toastseq_scan,
        sum(stt.seq_tup_read)::bigint AS toastseq_tup_read,
        sum(stt.idx_scan)::bigint AS toastidx_scan,
        sum(stt.idx_tup_fetch)::bigint AS toastidx_tup_fetch,
        sum(stt.n_tup_ins)::bigint AS toastn_tup_ins,
        sum(stt.n_tup_upd)::bigint AS toastn_tup_upd,
        sum(stt.n_tup_del)::bigint AS toastn_tup_del,
        sum(stt.n_tup_hot_upd)::bigint AS toastn_tup_hot_upd,
        sum(stt.vacuum_count)::bigint AS toastvacuum_count,
        sum(stt.autovacuum_count)::bigint AS toastautovacuum_count,
        sum(stt.analyze_count)::bigint AS toastanalyze_count,
        sum(stt.autoanalyze_count)::bigint AS toastautoanalyze_count,
        sum(stt.relsize_diff)::bigint AS toastgrowth
    FROM v_sample_stat_tables st
        -- Database name
        JOIN sample_stat_database sample_db
          USING (server_id, sample_id, datid)
        JOIN tablespaces_list tl USING (server_id, tablespaceid)
        LEFT OUTER JOIN v_sample_stat_tables stt -- TOAST stats
        ON (st.server_id=stt.server_id AND st.sample_id=stt.sample_id AND st.datid=stt.datid AND st.reltoastrelid=stt.relid)
    WHERE st.server_id = sserver_id AND st.relkind IN ('r','m') AND NOT sample_db.datistemplate
      AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id,st.datid,st.relid,st.reltoastrelid,sample_db.datname,tl.tablespacename,st.schemaname,st.relname
$function$;

-- Function: top_temp_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_temp_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) querues ordered by temp usage
    c_temp CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.local_blks_fetched, 0) as local_blks_fetched1,
        NULLIF(st1.local_hit_pct, 0.0) as local_hit_pct1,
        NULLIF(st1.temp_blks_written, 0) as temp_blks_written1,
        NULLIF(st1.temp_write_total_pct, 0.0) as temp_write_total_pct1,
        NULLIF(st1.temp_blks_read, 0) as temp_blks_read1,
        NULLIF(st1.temp_read_total_pct, 0.0) as temp_read_total_pct1,
        NULLIF(st1.local_blks_written, 0) as local_blks_written1,
        NULLIF(st1.local_write_total_pct, 0.0) as local_write_total_pct1,
        NULLIF(st1.local_blks_read, 0) as local_blks_read1,
        NULLIF(st1.local_read_total_pct, 0.0) as local_read_total_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.local_blks_fetched, 0) as local_blks_fetched2,
        NULLIF(st2.local_hit_pct, 0.0) as local_hit_pct2,
        NULLIF(st2.temp_blks_written, 0) as temp_blks_written2,
        NULLIF(st2.temp_write_total_pct, 0.0) as temp_write_total_pct2,
        NULLIF(st2.temp_blks_read, 0) as temp_blks_read2,
        NULLIF(st2.temp_read_total_pct, 0.0) as temp_read_total_pct2,
        NULLIF(st2.local_blks_written, 0) as local_blks_written2,
        NULLIF(st2.local_write_total_pct, 0.0) as local_write_total_pct2,
        NULLIF(st2.local_blks_read, 0) as local_blks_read2,
        NULLIF(st2.local_read_total_pct, 0.0) as local_read_total_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY COALESCE(st1.temp_blks_read, 0)+ COALESCE(st1.temp_blks_written, 0)+
          COALESCE(st1.local_blks_read, 0)+ COALESCE(st1.local_blks_written, 0)DESC NULLS LAST) as rn_temp1,
        row_number() over (ORDER BY COALESCE(st2.temp_blks_read, 0)+ COALESCE(st2.temp_blks_written, 0)+
          COALESCE(st2.local_blks_read, 0)+ COALESCE(st2.local_blks_written, 0)DESC NULLS LAST) as rn_temp2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(st1.temp_blks_read, 0) + COALESCE(st1.temp_blks_written, 0) +
        COALESCE(st1.local_blks_read, 0) + COALESCE(st1.local_blks_written, 0) +
        COALESCE(st2.temp_blks_read, 0) + COALESCE(st2.temp_blks_written, 0) +
        COALESCE(st2.local_blks_read, 0) + COALESCE(st2.local_blks_written, 0) > 0
    ORDER BY COALESCE(st1.temp_blks_read, 0) + COALESCE(st1.temp_blks_written, 0) +
        COALESCE(st1.local_blks_read, 0) + COALESCE(st1.local_blks_written, 0) +
        COALESCE(st2.temp_blks_read, 0) + COALESCE(st2.temp_blks_written, 0) +
        COALESCE(st2.local_blks_read, 0) + COALESCE(st2.local_blks_written, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_temp1,
        rn_temp2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Temp usage sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Number of local blocks fetched (hit + read)">Local fetched</th>'
            '<th rowspan="2" title="Local blocks hit percentage">Hits(%)</th>'
            '<th colspan="4" title="Number of blocks, used for temporary tables">Local (blk)</th>'
            '<th colspan="4" title="Number of blocks, used in operations (like sorts and joins)">Temp (blk)</th>'
            '<th rowspan="2" title="Time spent by the statement">Elapsed(s)</th>'
            '<th rowspan="2" title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of written local blocks">Write</th>'
            '<th title="Percentage of all local blocks written">%Total</th>'
            '<th title="Number of read local blocks">Read</th>'
            '<th title="Percentage of all local blocks read">%Total</th>'
            '<th title="Number of written temp blocks">Write</th>'
            '<th title="Percentage of all temp blocks written">%Total</th>'
            '<th title="Number of read temp blocks">Read</th>'
            '<th title="Percentage of all temp blocks read">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by temp usage
    FOR r_result IN c_temp LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.local_blks_fetched1,
            round(CAST(r_result.local_hit_pct1 AS numeric),2),
            r_result.local_blks_written1,
            round(CAST(r_result.local_write_total_pct1 AS numeric),2),
            r_result.local_blks_read1,
            round(CAST(r_result.local_read_total_pct1 AS numeric),2),
            r_result.temp_blks_written1,
            round(CAST(r_result.temp_write_total_pct1 AS numeric),2),
            r_result.temp_blks_read1,
            round(CAST(r_result.temp_read_total_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.local_blks_fetched2,
            round(CAST(r_result.local_hit_pct2 AS numeric),2),
            r_result.local_blks_written2,
            round(CAST(r_result.local_write_total_pct2 AS numeric),2),
            r_result.local_blks_read2,
            round(CAST(r_result.local_read_total_pct2 AS numeric),2),
            r_result.temp_blks_written2,
            round(CAST(r_result.temp_write_total_pct2 AS numeric),2),
            r_result.temp_blks_read2,
            round(CAST(r_result.temp_read_total_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_temp_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_temp_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) querues ordered by temp usage
    c_temp CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.local_blks_fetched, 0) as local_blks_fetched,
        NULLIF(st.local_hit_pct, 0.0) as local_hit_pct,
        NULLIF(st.temp_blks_written, 0) as temp_blks_written,
        NULLIF(st.temp_write_total_pct, 0.0) as temp_write_total_pct,
        NULLIF(st.temp_blks_read, 0) as temp_blks_read,
        NULLIF(st.temp_read_total_pct, 0.0) as temp_read_total_pct,
        NULLIF(st.local_blks_written, 0) as local_blks_written,
        NULLIF(st.local_write_total_pct, 0.0) as local_write_total_pct,
        NULLIF(st.local_blks_read, 0) as local_blks_read,
        NULLIF(st.local_read_total_pct, 0.0) as local_read_total_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements st
    WHERE COALESCE(st.temp_blks_read, 0) + COALESCE(st.temp_blks_written, 0) +
        COALESCE(st.local_blks_read, 0) + COALESCE(st.local_blks_written, 0) > 0
    ORDER BY COALESCE(st.temp_blks_read, 0) + COALESCE(st.temp_blks_written, 0) +
        COALESCE(st.local_blks_read, 0) + COALESCE(st.local_blks_written, 0) DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2" title="Number of local blocks fetched (hit + read)">Local fetched</th>'
            '<th rowspan="2" title="Local blocks hit percentage">Hits(%)</th>'
            '<th colspan="4" title="Number of blocks, used for temporary tables">Local (blk)</th>'
            '<th colspan="4" title="Number of blocks, used in operations (like sorts and joins)">Temp (blk)</th>'
            '<th rowspan="2" title="Time spent by the statement">Elapsed(s)</th>'
            '<th rowspan="2" title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of written local blocks">Write</th>'
            '<th title="Percentage of all local blocks written">%Total</th>'
            '<th title="Number of read local blocks">Read</th>'
            '<th title="Percentage of all local blocks read">%Total</th>'
            '<th title="Number of written temp blocks">Write</th>'
            '<th title="Percentage of all temp blocks written">%Total</th>'
            '<th title="Number of read temp blocks">Read</th>'
            '<th title="Percentage of all temp blocks read">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting on top queries by temp usage
    FOR r_result IN c_temp LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            r_result.local_blks_fetched,
            round(CAST(r_result.local_hit_pct AS numeric),2),
            r_result.local_blks_written,
            round(CAST(r_result.local_write_total_pct AS numeric),2),
            r_result.local_blks_read,
            round(CAST(r_result.local_read_total_pct AS numeric),2),
            r_result.temp_blks_written,
            round(CAST(r_result.temp_write_total_pct AS numeric),2),
            r_result.temp_blks_read,
            round(CAST(r_result.temp_read_total_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_upd_vac_tables_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_upd_vac_tables_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(tbl1.dbname,tbl2.dbname) as dbname,
        COALESCE(tbl1.tablespacename,tbl2.tablespacename) AS tablespacename,
        COALESCE(tbl1.schemaname,tbl2.schemaname) as schemaname,
        COALESCE(tbl1.relname,tbl2.relname) as relname,
        NULLIF(tbl1.n_tup_upd, 0) as n_tup_upd1,
        NULLIF(tbl1.n_tup_del, 0) as n_tup_del1,
        NULLIF(tbl1.n_tup_hot_upd, 0) as n_tup_hot_upd1,
        NULLIF(tbl1.vacuum_count, 0) as vacuum_count1,
        NULLIF(tbl1.autovacuum_count, 0) as autovacuum_count1,
        NULLIF(tbl1.analyze_count, 0) as analyze_count1,
        NULLIF(tbl1.autoanalyze_count, 0) as autoanalyze_count1,
        NULLIF(tbl2.n_tup_upd, 0) as n_tup_upd2,
        NULLIF(tbl2.n_tup_del, 0) as n_tup_del2,
        NULLIF(tbl2.n_tup_hot_upd, 0) as n_tup_hot_upd2,
        NULLIF(tbl2.vacuum_count, 0) as vacuum_count2,
        NULLIF(tbl2.autovacuum_count, 0) as autovacuum_count2,
        NULLIF(tbl2.analyze_count, 0) as analyze_count2,
        NULLIF(tbl2.autoanalyze_count, 0) as autoanalyze_count2,
        row_number() OVER (ORDER BY COALESCE(tbl1.n_tup_upd, 0) + COALESCE(tbl1.n_tup_del, 0) DESC NULLS LAST) as rn_vactpl1,
        row_number() OVER (ORDER BY COALESCE(tbl2.n_tup_upd, 0) + COALESCE(tbl2.n_tup_del, 0) DESC NULLS LAST) as rn_vactpl2
    FROM top_tables1 tbl1
        FULL OUTER JOIN top_tables2 tbl2 USING (server_id, datid, relid)
    WHERE COALESCE(tbl1.n_tup_upd, 0) + COALESCE(tbl1.n_tup_del, 0) +
          COALESCE(tbl2.n_tup_upd, 0) + COALESCE(tbl2.n_tup_del, 0) > 0
    ORDER BY COALESCE(tbl1.n_tup_upd, 0) + COALESCE(tbl1.n_tup_del, 0) +
          COALESCE(tbl2.n_tup_upd, 0) + COALESCE(tbl2.n_tup_del, 0) DESC,
      COALESCE(tbl1.datid,tbl2.datid) ASC,
      COALESCE(tbl1.relid,tbl2.relid) ASC
    ) t1
    WHERE least(
        rn_vactpl1,
        rn_vactpl2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th>I</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of times this table has been manually vacuumed (not counting VACUUM FULL)">Vacuum</th>'
            '<th title="Number of times this table has been vacuumed by the autovacuum daemon">AutoVacuum</th>'
            '<th title="Number of times this table has been manually analyzed">Analyze</th>'
            '<th title="Number of times this table has been analyzed by the autovacuum daemon">AutoAnalyze</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.n_tup_upd1,
            r_result.n_tup_hot_upd1,
            r_result.n_tup_del1,
            r_result.vacuum_count1,
            r_result.autovacuum_count1,
            r_result.analyze_count1,
            r_result.autoanalyze_count1,
            r_result.n_tup_upd2,
            r_result.n_tup_hot_upd2,
            r_result.n_tup_del2,
            r_result.vacuum_count2,
            r_result.autovacuum_count2,
            r_result.analyze_count2,
            r_result.autoanalyze_count2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_upd_vac_tables_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_upd_vac_tables_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        tablespacename,
        schemaname,
        relname,
        reltoastrelid,
        NULLIF(n_tup_upd, 0) as n_tup_upd,
        NULLIF(n_tup_del, 0) as n_tup_del,
        NULLIF(n_tup_hot_upd, 0) as n_tup_hot_upd,
        NULLIF(vacuum_count, 0) as vacuum_count,
        NULLIF(autovacuum_count, 0) as autovacuum_count,
        NULLIF(analyze_count, 0) as analyze_count,
        NULLIF(autoanalyze_count, 0) as autoanalyze_count,
        NULLIF(toastn_tup_upd, 0) as toastn_tup_upd,
        NULLIF(toastn_tup_del, 0) as toastn_tup_del,
        NULLIF(toastn_tup_hot_upd, 0) as toastn_tup_hot_upd,
        NULLIF(toastvacuum_count, 0) as toastvacuum_count,
        NULLIF(toastautovacuum_count, 0) as toastautovacuum_count,
        NULLIF(toastanalyze_count, 0) as toastanalyze_count,
        NULLIF(toastautoanalyze_count, 0) as toastautoanalyze_count
    FROM top_tables
    WHERE COALESCE(n_tup_upd, 0) + COALESCE(n_tup_del, 0) +
      COALESCE(toastn_tup_upd, 0) + COALESCE(toastn_tup_del, 0) > 0
    ORDER BY COALESCE(n_tup_upd, 0) + COALESCE(n_tup_del, 0) +
      COALESCE(toastn_tup_upd, 0) + COALESCE(toastn_tup_del, 0) DESC,
      datid ASC,
      relid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    -- Populate templates
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of times this table has been manually vacuumed (not counting VACUUM FULL)">Vacuum</th>'
            '<th title="Number of times this table has been vacuumed by the autovacuum daemon">AutoVacuum</th>'
            '<th title="Number of times this table has been manually analyzed">Analyze</th>'
            '<th title="Number of times this table has been analyzed by the autovacuum daemon">AutoAnalyze</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'rel_tpl',
        '<tr {reltr}>'
          '<td {reltdhdr}>%s</td>'
          '<td {reltdhdr}>%s</td>'
          '<td {reltdhdr}>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'rel_wtoast_tpl',
        '<tr {reltr}>'
          '<td {reltdspanhdr}>%s</td>'
          '<td {reltdspanhdr}>%s</td>'
          '<td {reltdspanhdr}>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {toasttr}>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
        IF r_result.reltoastrelid IS NULL THEN
          report := report||format(
              jtab_tpl #>> ARRAY['rel_tpl'],
              r_result.dbname,
              r_result.tablespacename,
              r_result.schemaname,
              r_result.relname,
              r_result.n_tup_upd,
              r_result.n_tup_hot_upd,
              r_result.n_tup_del,
              r_result.vacuum_count,
              r_result.autovacuum_count,
              r_result.analyze_count,
              r_result.autoanalyze_count
          );
        ELSE
          report := report||format(
              jtab_tpl #>> ARRAY['rel_wtoast_tpl'],
              r_result.dbname,
              r_result.tablespacename,
              r_result.schemaname,
              r_result.relname,
              r_result.n_tup_upd,
              r_result.n_tup_hot_upd,
              r_result.n_tup_del,
              r_result.vacuum_count,
              r_result.autovacuum_count,
              r_result.analyze_count,
              r_result.autoanalyze_count,
              r_result.relname||'(TOAST)',
              r_result.toastn_tup_upd,
              r_result.toastn_tup_hot_upd,
              r_result.toastn_tup_del,
              r_result.toastvacuum_count,
              r_result.toastautovacuum_count,
              r_result.toastanalyze_count,
              r_result.toastautoanalyze_count
          );
        END IF;
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_vacuumed_indexes_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_vacuumed_indexes_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for indexes stats
    c_ix_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(ix1.dbname,ix2.dbname) as dbname,
        COALESCE(ix1.tablespacename,ix2.tablespacename) as tablespacename,
        COALESCE(ix1.schemaname,ix2.schemaname) as schemaname,
        COALESCE(ix1.relname,ix2.relname) as relname,
        COALESCE(ix1.indexrelname,ix2.indexrelname) as indexrelname,
        NULLIF(vac1.vacuum_count, 0) as vacuum_count1,
        NULLIF(vac1.autovacuum_count, 0) as autovacuum_count1,
        NULLIF(vac1.vacuum_bytes, 0) as vacuum_bytes1,
        NULLIF(vac1.avg_indexrelsize, 0) as avg_ix_relsize1,
        NULLIF(vac1.avg_relsize, 0) as avg_relsize1,
        NULLIF(vac2.vacuum_count, 0) as vacuum_count2,
        NULLIF(vac2.autovacuum_count, 0) as autovacuum_count2,
        NULLIF(vac2.vacuum_bytes, 0) as vacuum_bytes2,
        NULLIF(vac2.avg_indexrelsize, 0) as avg_ix_relsize2,
        NULLIF(vac2.avg_relsize, 0) as avg_relsize2,
        row_number() over (ORDER BY vac1.vacuum_bytes DESC NULLS LAST) as rn_vacuum_bytes1,
        row_number() over (ORDER BY vac2.vacuum_bytes DESC NULLS LAST) as rn_vacuum_bytes2
    FROM top_indexes1 ix1
        FULL OUTER JOIN top_indexes2 ix2 USING (server_id, datid, indexrelid)
        -- Join interpolated data of interval 1
        LEFT OUTER JOIN (
			SELECT
				server_id,
				datid,
				indexrelid,
				sum(vacuum_count) as vacuum_count,
				sum(autovacuum_count) as autovacuum_count,
				round(sum(i.relsize
					* (COALESCE(vacuum_count,0) + COALESCE(autovacuum_count,0))))::bigint as vacuum_bytes,
				round(avg(i.relsize))::bigint as avg_indexrelsize,
				round(avg(t.relsize))::bigint as avg_relsize
			FROM sample_stat_indexes i
				JOIN indexes_list il USING (server_id,datid,indexrelid)
				JOIN sample_stat_tables t USING
					(server_id, sample_id, datid, relid)
			WHERE
				server_id = sserver_id AND
				sample_id BETWEEN start1_id + 1 AND end1_id
			GROUP BY
				server_id, datid, indexrelid
        ) vac1 USING (server_id, datid, indexrelid)
        -- Join interpolated data of interval 2
        LEFT OUTER JOIN (
			SELECT
				server_id,
				datid,
				indexrelid,
				sum(vacuum_count) as vacuum_count,
				sum(autovacuum_count) as autovacuum_count,
				round(sum(i.relsize
					* (COALESCE(vacuum_count,0) + COALESCE(autovacuum_count,0))))::bigint as vacuum_bytes,
				round(avg(i.relsize))::bigint as avg_indexrelsize,
				round(avg(t.relsize))::bigint as avg_relsize
			FROM sample_stat_indexes i
				JOIN indexes_list il USING (server_id,datid,indexrelid)
				JOIN sample_stat_tables t USING
					(server_id, sample_id, datid, relid)
			WHERE
				server_id = sserver_id AND
				sample_id BETWEEN start2_id + 1 AND end2_id
			GROUP BY
				server_id, datid, indexrelid
        ) vac2 USING (server_id, datid, indexrelid)
    WHERE COALESCE(vac1.vacuum_bytes, 0) + COALESCE(vac2.vacuum_bytes, 0) > 0
    ORDER BY
      COALESCE(vac1.vacuum_bytes, 0) + COALESCE(vac2.vacuum_bytes, 0) DESC,
      COALESCE(ix1.datid,ix2.datid) ASC,
      COALESCE(ix1.relid,ix2.relid) ASC,
      COALESCE(ix1.indexrelid,ix2.indexrelid) ASC
    ) t1
    WHERE least(
        rn_vacuum_bytes1,
        rn_vacuum_bytes2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th>Index</th>'
            '<th>I</th>'
            '<th title="Estimated implicit vacuum load caused by table indexes">~Vacuum bytes</th>'
            '<th title="Vacuum count on underlying table">Vacuum cnt</th>'
            '<th title="Autovacuum count on underlying table">Autovacuum cnt</th>'
            '<th title="Average index size during report interval">IX size</th>'
            '<th title="Average relation size during report interval">Relsize</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting table stats
    FOR r_result IN c_ix_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.indexrelname,
            pg_size_pretty(r_result.vacuum_bytes1),
            r_result.vacuum_count1,
            r_result.autovacuum_count1,
            pg_size_pretty(r_result.avg_ix_relsize1),
            pg_size_pretty(r_result.avg_relsize1),
            pg_size_pretty(r_result.vacuum_bytes2),
            r_result.vacuum_count2,
            r_result.autovacuum_count2,
            pg_size_pretty(r_result.avg_ix_relsize2),
            pg_size_pretty(r_result.avg_relsize2)
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_vacuumed_indexes_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_vacuumed_indexes_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Indexes stats template
    jtab_tpl    jsonb;

    --Cursor for indexes stats
    c_ix_stats CURSOR FOR
    SELECT
        st.dbname,
        st.tablespacename,
        st.schemaname,
        st.relname,
        st.indexrelname,
        NULLIF(vac.vacuum_count, 0) as vacuum_count,
        NULLIF(vac.autovacuum_count, 0) as autovacuum_count,
        NULLIF(vac.vacuum_bytes, 0) as vacuum_bytes,
        NULLIF(vac.avg_indexrelsize, 0) as avg_ix_relsize,
        NULLIF(vac.avg_relsize, 0) as avg_relsize
    FROM top_indexes st
      JOIN (
        SELECT
          server_id,
          datid,
          indexrelid,
          sum(vacuum_count) as vacuum_count,
          sum(autovacuum_count) as autovacuum_count,
          round(sum(i.relsize
			* (COALESCE(vacuum_count,0) + COALESCE(autovacuum_count,0))))::bigint as vacuum_bytes,
          round(avg(i.relsize))::bigint as avg_indexrelsize,
          round(avg(t.relsize))::bigint as avg_relsize
        FROM sample_stat_indexes i
			JOIN indexes_list il USING (server_id,datid,indexrelid)
			JOIN sample_stat_tables t USING
				(server_id, sample_id, datid, relid)
        WHERE
          server_id = sserver_id AND
          sample_id BETWEEN start_id + 1 AND end_id
        GROUP BY
          server_id, datid, indexrelid
      ) vac USING (server_id, datid, indexrelid)
    WHERE vac.vacuum_bytes > 0
    ORDER BY
      vacuum_bytes DESC,
      st.datid ASC,
      st.relid ASC,
      st.indexrelid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th>Index</th>'
            '<th title="Estimated implicit vacuum load caused by table indexes">~Vacuum bytes</th>'
            '<th title="Vacuum count on underlying table">Vacuum cnt</th>'
            '<th title="Autovacuum count on underlying table">Autovacuum cnt</th>'
            '<th title="Average index size during report interval">IX size</th>'
            '<th title="Average relation size during report interval">Relsize</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting table stats
    FOR r_result IN c_ix_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.indexrelname,
            pg_size_pretty(r_result.vacuum_bytes),
            r_result.vacuum_count,
            r_result.autovacuum_count,
            pg_size_pretty(r_result.avg_ix_relsize),
            pg_size_pretty(r_result.avg_relsize)
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_vacuumed_tables_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_vacuumed_tables_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    -- Table elements template collection
    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(tbl1.dbname,tbl2.dbname) as dbname,
        COALESCE(tbl1.tablespacename,tbl2.tablespacename) AS tablespacename,
        COALESCE(tbl1.schemaname,tbl2.schemaname) as schemaname,
        COALESCE(tbl1.relname,tbl2.relname) as relname,
        NULLIF(tbl1.vacuum_count, 0) as vacuum_count1,
        NULLIF(tbl1.autovacuum_count, 0) as autovacuum_count1,
        NULLIF(tbl1.n_tup_ins, 0) as n_tup_ins1,
        NULLIF(tbl1.n_tup_upd, 0) as n_tup_upd1,
        NULLIF(tbl1.n_tup_del, 0) as n_tup_del1,
        NULLIF(tbl1.n_tup_hot_upd, 0) as n_tup_hot_upd1,
        NULLIF(tbl2.vacuum_count, 0) as vacuum_count2,
        NULLIF(tbl2.autovacuum_count, 0) as autovacuum_count2,
        NULLIF(tbl2.n_tup_ins, 0) as n_tup_ins2,
        NULLIF(tbl2.n_tup_upd, 0) as n_tup_upd2,
        NULLIF(tbl2.n_tup_del, 0) as n_tup_del2,
        NULLIF(tbl2.n_tup_hot_upd, 0) as n_tup_hot_upd2,
        row_number() OVER (ORDER BY COALESCE(tbl1.vacuum_count, 0) + COALESCE(tbl1.autovacuum_count, 0) DESC) as rn_vacuum1,
        row_number() OVER (ORDER BY COALESCE(tbl2.vacuum_count, 0) + COALESCE(tbl2.autovacuum_count, 0) DESC) as rn_vacuum2
    FROM top_tables1 tbl1
        FULL OUTER JOIN top_tables2 tbl2 USING (server_id,datid,relid)
    WHERE COALESCE(tbl1.vacuum_count, 0) + COALESCE(tbl1.autovacuum_count, 0) +
          COALESCE(tbl2.vacuum_count, 0) + COALESCE(tbl2.autovacuum_count, 0) > 0
    ORDER BY COALESCE(tbl1.vacuum_count, 0) + COALESCE(tbl1.autovacuum_count, 0) +
          COALESCE(tbl2.vacuum_count, 0) + COALESCE(tbl2.autovacuum_count, 0) DESC,
      COALESCE(tbl1.datid,tbl2.datid) ASC,
      COALESCE(tbl1.relid,tbl2.relid) ASC
    ) t1
    WHERE least(
        rn_vacuum1,
        rn_vacuum2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Tables stats template
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th>I</th>'
            '<th title="Number of times this table has been manually vacuumed (not counting VACUUM FULL)">Vacuum count</th>'
            '<th title="Number of times this table has been vacuumed by the autovacuum daemon">Autovacuum count</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'row_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['row_tpl'],
            r_result.dbname,
            r_result.tablespacename,
            r_result.schemaname,
            r_result.relname,
            r_result.vacuum_count1,
            r_result.autovacuum_count1,
            r_result.n_tup_ins1,
            r_result.n_tup_upd1,
            r_result.n_tup_del1,
            r_result.n_tup_hot_upd1,
            r_result.vacuum_count2,
            r_result.autovacuum_count2,
            r_result.n_tup_ins2,
            r_result.n_tup_upd2,
            r_result.n_tup_del2,
            r_result.n_tup_hot_upd2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_vacuumed_tables_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_vacuumed_tables_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';

    jtab_tpl    jsonb;

    --Cursor for tables stats
    c_tbl_stats CURSOR FOR
    SELECT
        dbname,
        top.tablespacename,
        top.schemaname,
        top.relname,
        NULLIF(top.vacuum_count, 0) as vacuum_count,
        NULLIF(top.autovacuum_count, 0) as autovacuum_count,
        NULLIF(top.n_tup_ins, 0) as n_tup_ins,
        NULLIF(top.n_tup_upd, 0) as n_tup_upd,
        NULLIF(top.n_tup_del, 0) as n_tup_del,
        NULLIF(top.n_tup_hot_upd, 0) as n_tup_hot_upd
    FROM top_tables top
    WHERE COALESCE(top.vacuum_count, 0) + COALESCE(top.autovacuum_count, 0) > 0
    ORDER BY COALESCE(top.vacuum_count, 0) + COALESCE(top.autovacuum_count, 0) DESC,
      top.datid ASC,
      top.relid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN

    -- Populate templates
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>DB</th>'
            '<th>Tablespace</th>'
            '<th>Schema</th>'
            '<th>Table</th>'
            '<th title="Number of times this table has been manually vacuumed (not counting VACUUM FULL)">Vacuum count</th>'
            '<th title="Number of times this table has been vacuumed by the autovacuum daemon">Autovacuum count</th>'
            '<th title="Number of rows inserted">Ins</th>'
            '<th title="Number of rows updated (includes HOT updated rows)">Upd</th>'
            '<th title="Number of rows deleted">Del</th>'
            '<th title="Number of rows HOT updated (i.e., with no separate index update required)">Upd(HOT)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'rel_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
    );

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
      report := report||format(
          jtab_tpl #>> ARRAY['rel_tpl'],
          r_result.dbname,
          r_result.tablespacename,
          r_result.schemaname,
          r_result.relname,
          r_result.vacuum_count,
          r_result.autovacuum_count,
          r_result.n_tup_ins,
          r_result.n_tup_upd,
          r_result.n_tup_del,
          r_result.n_tup_hot_upd
      );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: top_wal_size_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_wal_size_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by WAL bytes
    c_wal_size CURSOR FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        NULLIF(st1.wal_bytes, 0) as wal_bytes1,
        NULLIF(st1.wal_bytes_pct, 0.0) as wal_bytes_pct1,
        NULLIF(st1.shared_blks_dirtied, 0) as shared_blks_dirtied1,
        NULLIF(st1.wal_fpi, 0) as wal_fpi1,
        NULLIF(st1.wal_records, 0) as wal_records1,
        NULLIF(st2.wal_bytes, 0) as wal_bytes2,
        NULLIF(st2.wal_bytes_pct, 0.0) as wal_bytes_pct2,
        NULLIF(st2.shared_blks_dirtied, 0) as shared_blks_dirtied2,
        NULLIF(st2.wal_fpi, 0) as wal_fpi2,
        NULLIF(st2.wal_records, 0) as wal_records2,
        row_number() over (ORDER BY st1.wal_bytes DESC NULLS LAST) as rn_wal1,
        row_number() over (ORDER BY st2.wal_bytes DESC NULLS LAST) as rn_wal2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(st1.wal_bytes, 0) + COALESCE(st2.wal_bytes, 0) > 0
    ORDER BY COALESCE(st1.wal_bytes, 0) + COALESCE(st2.wal_bytes, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC
    ) t1
    WHERE least(
        rn_wal1,
        rn_wal2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when WAL stats is available
    IF NOT jsonb_extract_path_text(jreportset, 'report_features', 'statement_wal_bytes')::boolean THEN
      RETURN '';
    END IF;

    -- WAL sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>I</th>'
            '<th title="Total amount of WAL bytes generated by the statement">WAL</th>'
            '<th title="WAL bytes of this statement as a percentage of total WAL bytes generated by a cluster">%Total</th>'
            '<th title="Total number of shared blocks dirtied by the statement">Dirtied</th>'
            '<th title="Total number of WAL full page images generated by the statement">WAL FPI</th>'
            '<th title="Total number of WAL records generated by the statement">WAL records</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by shared_blks_fetched
    FOR r_result IN c_wal_size LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            pg_size_pretty(r_result.wal_bytes1),
            round(CAST(r_result.wal_bytes_pct1 AS numeric),2),
            r_result.shared_blks_dirtied1,
            r_result.wal_fpi1,
            r_result.wal_records1,
            pg_size_pretty(r_result.wal_bytes2),
            round(CAST(r_result.wal_bytes_pct2 AS numeric),2),
            r_result.shared_blks_dirtied2,
            r_result.wal_fpi2,
            r_result.wal_records2
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: top_wal_size_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.top_wal_size_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer, topn integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for queries ordered by WAL bytes
    c_wal_size CURSOR FOR
    SELECT
        st.datid,
        st.userid,
        st.queryid,
        st.dbname,
        NULLIF(st.wal_bytes, 0) as wal_bytes,
        NULLIF(st.wal_bytes_pct, 0.0) as wal_bytes_pct,
        NULLIF(st.shared_blks_dirtied, 0) as shared_blks_dirtied,
        NULLIF(st.wal_fpi, 0) as wal_fpi,
        NULLIF(st.wal_records, 0) as wal_records
    FROM top_statements st
    WHERE st.wal_bytes > 0
    ORDER BY st.wal_bytes DESC,
      st.queryid ASC,
      st.datid ASC,
      st.userid ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when WAL stats is available
    IF NOT jsonb_extract_path_text(jreportset, 'report_features', 'statement_wal_bytes')::boolean THEN
      RETURN '';
    END IF;

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th title="Total amount of WAL bytes generated by the statement">WAL</th>'
            '<th title="WAL bytes of this statement as a percentage of total WAL bytes generated by a cluster">%Total</th>'
            '<th title="Total number of shared blocks dirtied by the statement">Dirtied</th>'
            '<th title="Total number of WAL full page images generated by the statement">WAL FPI</th>'
            '<th title="Total number of WAL records generated by the statement">WAL records</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small></p></td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_wal_size LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            NULL, --reserved
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            to_hex(r_result.queryid),
            r_result.dbname,
            pg_size_pretty(r_result.wal_bytes),
            round(CAST(r_result.wal_bytes_pct AS numeric),2),
            r_result.shared_blks_dirtied,
            r_result.wal_fpi,
            r_result.wal_records
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$function$;

-- Function: wal_stats
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.wal_stats(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(server_id integer, wal_records bigint, wal_fpi bigint, wal_bytes numeric, wal_buffers_full bigint, wal_write bigint, wal_sync bigint, wal_write_time double precision, wal_sync_time double precision)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
    SELECT
        st.server_id as server_id,
        sum(wal_records)::bigint as wal_records,
        sum(wal_fpi)::bigint as wal_fpi,
        sum(wal_bytes)::numeric as wal_bytes,
        sum(wal_buffers_full)::bigint as wal_buffers_full,
        sum(wal_write)::bigint as wal_write,
        sum(wal_sync)::bigint as wal_sync,
        sum(wal_write_time)::double precision as wal_write_time,
        sum(wal_sync_time)::double precision as wal_sync_time
    FROM sample_stat_wal st
    WHERE st.server_id = sserver_id AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY st.server_id
$function$;

-- Function: wal_stats_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.wal_stats_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    report1_duration float = (jreportset #> ARRAY['report_properties','interval1_duration_sec'])::float;
    report2_duration float = (jreportset #> ARRAY['report_properties','interval2_duration_sec'])::float;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        NULLIF(stat1.wal_records, 0) as wal_records1,
        NULLIF(stat1.wal_fpi, 0) as wal_fpi1,
        NULLIF(stat1.wal_bytes, 0) as wal_bytes1,
        NULLIF(stat1.wal_buffers_full, 0) as wal_buffers_full1,
        NULLIF(stat1.wal_write, 0) as wal_write1,
        NULLIF(stat1.wal_sync, 0) as wal_sync1,
        NULLIF(stat1.wal_write_time, 0.0) as wal_write_time1,
        NULLIF(stat1.wal_sync_time, 0.0) as wal_sync_time1,
        NULLIF(stat2.wal_records, 0) as wal_records2,
        NULLIF(stat2.wal_fpi, 0) as wal_fpi2,
        NULLIF(stat2.wal_bytes, 0) as wal_bytes2,
        NULLIF(stat2.wal_buffers_full, 0) as wal_buffers_full2,
        NULLIF(stat2.wal_write, 0) as wal_write2,
        NULLIF(stat2.wal_sync, 0) as wal_sync2,
        NULLIF(stat2.wal_write_time, 0.0) as wal_write_time2,
        NULLIF(stat2.wal_sync_time, 0.0) as wal_sync_time2
    FROM wal_stats(sserver_id,start1_id,end1_id) stat1
        FULL OUTER JOIN wal_stats(sserver_id,start2_id,end2_id) stat2 USING (server_id);

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Metric</th>'
            '<th {title1}>Value (1)</th>'
            '<th {title2}>Value (2)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'val_tpl',
        '<tr>'
          '<td title="%s">%s</td>'
          '<td {interval1}><div {value}>%s</div></td>'
          '<td {interval2}><div {value}>%s</div></td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting summary bgwriter stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total amount of WAL generated', 'WAL generated',
          pg_size_pretty(r_result.wal_bytes1), pg_size_pretty(r_result.wal_bytes2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Average amount of WAL generated per second', 'WAL per second',
          pg_size_pretty(
            round(
              r_result.wal_bytes1/report1_duration
            )::bigint
          ),
          pg_size_pretty(
            round(
              r_result.wal_bytes2/report2_duration
            )::bigint
          ));

        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total number of WAL records generated', 'WAL records', r_result.wal_records1, r_result.wal_records2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total number of WAL full page images generated', 'WAL FPI', r_result.wal_fpi1, r_result.wal_fpi2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Number of times WAL data was written to disk because WAL buffers became full', 'WAL buffers full', r_result.wal_buffers_full1, r_result.wal_buffers_full2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Number of times WAL buffers were written out to disk via XLogWrite request', 'WAL writes',
          r_result.wal_write1, r_result.wal_write2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Average number of times WAL buffers were written out to disk via XLogWrite request per second',
          'WAL writes per second',
          round((r_result.wal_write1/report1_duration)::numeric,2),
          round((r_result.wal_write2/report2_duration)::numeric,2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Number of times WAL files were synced to disk via issue_xlog_fsync request (if fsync is on and wal_sync_method is either fdatasync, fsync or fsync_writethrough, otherwise zero)',
          'WAL sync', r_result.wal_sync1, r_result.wal_sync2);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Average number of times WAL files were synced to disk via issue_xlog_fsync request per second',
          'WAL syncs per second',
          round((r_result.wal_sync1/report1_duration)::numeric,2),
          round((r_result.wal_sync2/report2_duration)::numeric,2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total amount of time spent writing WAL buffers to disk via XLogWrite request, in milliseconds (if track_wal_io_timing is enabled, otherwise zero). This includes the sync time when wal_sync_method is either open_datasync or open_sync',
          'WAL write time (s)',
          round(cast(r_result.wal_write_time1/1000 as numeric),2),
          round(cast(r_result.wal_write_time2/1000 as numeric),2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'WAL write time as a percentage of the report duration time',
          'WAL write duty',
          round((r_result.wal_write_time1/10/report1_duration)::numeric,2) || '%',
          round((r_result.wal_write_time2/10/report2_duration)::numeric,2) || '%');
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total amount of time spent syncing WAL files to disk via issue_xlog_fsync request, in milliseconds (if track_wal_io_timing is enabled, fsync is on, and wal_sync_method is either fdatasync, fsync or fsync_writethrough, otherwise zero)',
          'WAL sync time (s)',
          round(cast(r_result.wal_sync_time1/1000 as numeric),2),
          round(cast(r_result.wal_sync_time2/1000 as numeric),2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'WAL sync time as a percentage of the report duration time',
          'WAL sync duty',
          round((r_result.wal_sync_time1/10/report1_duration)::numeric,2) || '%',
          round((r_result.wal_sync_time2/10/report2_duration)::numeric,2) || '%');
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: wal_stats_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.wal_stats_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    report_duration float = (jreportset #> ARRAY['report_properties','interval_duration_sec'])::float;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        NULLIF(wal_records, 0) as wal_records,
        NULLIF(wal_fpi, 0) as wal_fpi,
        NULLIF(wal_bytes, 0) as wal_bytes,
        NULLIF(wal_buffers_full, 0) as wal_buffers_full,
        NULLIF(wal_write, 0) as wal_write,
        NULLIF(wal_sync, 0) as wal_sync,
        NULLIF(wal_write_time, 0.0) as wal_write_time,
        NULLIF(wal_sync_time, 0.0) as wal_sync_time
    FROM wal_stats(sserver_id,start_id,end_id);

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Metric</th>'
            '<th>Value</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'val_tpl',
        '<tr>'
          '<td title="%s">%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);
    -- Reporting summary bgwriter stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total amount of WAL generated', 'WAL generated', pg_size_pretty(r_result.wal_bytes));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Average amount of WAL generated per second', 'WAL per second',
          pg_size_pretty(
            round(
              r_result.wal_bytes/report_duration
            )::bigint
          ));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total number of WAL records generated', 'WAL records', r_result.wal_records);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total number of WAL full page images generated', 'WAL FPI', r_result.wal_fpi);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Number of times WAL data was written to disk because WAL buffers became full',
          'WAL buffers full', r_result.wal_buffers_full);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Number of times WAL buffers were written out to disk via XLogWrite request',
          'WAL writes', r_result.wal_write);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Average number of times WAL buffers were written out to disk via XLogWrite request per second',
          'WAL writes per second',
          round((r_result.wal_write/report_duration)::numeric,2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Number of times WAL files were synced to disk via issue_xlog_fsync request (if fsync is on and wal_sync_method is either fdatasync, fsync or fsync_writethrough, otherwise zero)',
          'WAL sync', r_result.wal_sync);
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Average number of times WAL files were synced to disk via issue_xlog_fsync request per second',
          'WAL syncs per second',
          round((r_result.wal_sync/report_duration)::numeric,2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total amount of time spent writing WAL buffers to disk via XLogWrite request, in milliseconds (if track_wal_io_timing is enabled, otherwise zero). This includes the sync time when wal_sync_method is either open_datasync or open_sync',
          'WAL write time (s)',
          round(cast(r_result.wal_write_time/1000 as numeric),2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'WAL write time as a percentage of the report duration time',
          'WAL write duty',
          round((r_result.wal_write_time/10/report_duration)::numeric,2) || '%');
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'Total amount of time spent syncing WAL files to disk via issue_xlog_fsync request, in milliseconds (if track_wal_io_timing is enabled, fsync is on, and wal_sync_method is either fdatasync, fsync or fsync_writethrough, otherwise zero)',
          'WAL sync time (s)',
          round(cast(r_result.wal_sync_time/1000 as numeric),2));
        report := report||format(jtab_tpl #>> ARRAY['val_tpl'],
          'WAL sync time as a percentage of the report duration time',
          'WAL sync duty',
          round((r_result.wal_sync_time/10/report_duration)::numeric,2) || '%');
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: wal_stats_reset
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.wal_stats_reset(sserver_id integer, start_id integer, end_id integer)
 RETURNS TABLE(sample_id integer, wal_stats_reset timestamp with time zone)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT
      ws1.sample_id as sample_id,
      nullif(ws1.stats_reset,ws0.stats_reset)
  FROM sample_stat_wal ws1
      JOIN sample_stat_wal ws0 ON (ws1.server_id = ws0.server_id AND ws1.sample_id = ws0.sample_id + 1)
  WHERE ws1.server_id = sserver_id AND ws1.sample_id BETWEEN start_id + 1 AND end_id
    AND
      nullif(ws1.stats_reset,ws0.stats_reset) IS NOT NULL
  ORDER BY ws1.sample_id ASC
$function$;

-- Function: wal_stats_reset_diff_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.wal_stats_reset_diff_htbl(jreportset jsonb, sserver_id integer, start1_id integer, end1_id integer, start2_id integer, end2_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        interval_num,
        sample_id,
        wal_stats_reset
    FROM
      (SELECT 1 AS interval_num, sample_id, wal_stats_reset
        FROM wal_stats_reset(sserver_id,start1_id,end1_id)
      UNION ALL
      SELECT 2 AS interval_num, sample_id, wal_stats_reset
        FROM wal_stats_reset(sserver_id,start2_id,end2_id)) AS samples
    ORDER BY interval_num, wal_stats_reset ASC;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>I</th>'
            '<th>Sample</th>'
            '<th>WAL stats reset time</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'sample_tpl1',
        '<tr {interval1}>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'sample_tpl2',
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
      CASE r_result.interval_num
        WHEN 1 THEN
          report := report||format(
              jtab_tpl #>> ARRAY['sample_tpl1'],
              r_result.sample_id,
              r_result.wal_stats_reset
          );
        WHEN 2 THEN
          report := report||format(
              jtab_tpl #>> ARRAY['sample_tpl2'],
              r_result.sample_id,
              r_result.wal_stats_reset
          );
        END CASE;
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: wal_stats_reset_htbl
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.wal_stats_reset_htbl(jreportset jsonb, sserver_id integer, start_id integer, end_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for db stats
    c_dbstats CURSOR FOR
    SELECT
        sample_id,
        wal_stats_reset
    FROM wal_stats_reset(sserver_id,start_id,end_id)
    ORDER BY wal_stats_reset ASC;

    r_result RECORD;
BEGIN
    -- Database stats TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Sample</th>'
            '<th>WAL stats reset time</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'sample_tpl',
        '<tr>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');
    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_dbstats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['sample_tpl'],
            r_result.sample_id,
            r_result.wal_stats_reset
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;

    RETURN  report;
END;
$function$;

-- Function: word_similarity
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity$function$;

-- Function: word_similarity_commutator_op
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_commutator_op$function$;

-- Function: word_similarity_dist_commutator_op
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_commutator_op$function$;

-- Function: word_similarity_dist_op
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_op$function$;

-- Function: word_similarity_op
CREATE OR REPLACE CREATE OR REPLACE FUNCTION public.word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_op$function$;


-- ============================================================
-- PERMISSIONS
-- ============================================================

-- Tablespace grants: REQUIRED so DAR_PORTAL_USER can create tables
-- in the awrparser and awrparser_idx tablespaces.
-- Without these grants CREATE TABLE ... TABLESPACE awrparser returns:
--   ERROR: permission denied for tablespace awrparser
GRANT CREATE ON TABLESPACE awrparser     TO DAR_PORTAL_USER;
GRANT CREATE ON TABLESPACE awrparser_idx TO DAR_PORTAL_USER;

-- Table, sequence and MV object grants:
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
END $$;

-- ============================================================
-- END OF SCHEMA SCRIPT
-- Tables:              80
-- Views:               2
-- Materialized Views:  12
-- Indexes:             61
-- Functions:           248
-- Generated:           2026-08-04 11:30:30
-- ============================================================
