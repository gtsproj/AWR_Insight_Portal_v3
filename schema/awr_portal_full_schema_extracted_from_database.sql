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

- ============================================================
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

CREATE TABLE IF NOT EXISTS awr_unc_connections (
    id              SERIAL PRIMARY KEY,
    db_name         TEXT NOT NULL,             -- matches awr_db_master.db_name
    display_name    TEXT,                      -- friendly label shown in UI
    unc_path        TEXT NOT NULL,             -- e.g. \\server\share\awr_reports\ORCL
    username        TEXT,                      -- optional — for net use / mapped drive auth
    password_enc    TEXT,                      -- base64-obfuscated (if username supplied)
    pull_interval_hrs NUMERIC(4,1) DEFAULT 1,  -- copy new files every N hours (0=manual)
    enabled         BOOLEAN DEFAULT TRUE,
    last_pull_at    TIMESTAMP,                 -- datetime of last successful pull
    added_at        TIMESTAMP DEFAULT NOW(),
    added_by        TEXT DEFAULT 'admin',
    CONSTRAINT uq_awr_unc_db_name UNIQUE (db_name)
) tablespace awrparser;

COMMENT ON TABLE awr_unc_connections IS
    'Per-database network/UNC path config for AWR source type = network. '
    'One row per Oracle database. Each row points at its own UNC folder — '
    'no shared root path or DB-name subfolder convention required. '
    'Files are copied to awr_reports\<db_name>\ and picked up by the queue processor.';


CREATE TABLE IF NOT EXISTS awr_remote_servers (
    id                 SERIAL PRIMARY KEY,
    display_name       TEXT NOT NULL,             -- friendly label shown in UI
    connection_type    TEXT NOT NULL DEFAULT 'unc'
                            CHECK (connection_type IN ('unc', 'ssh')),
    host                TEXT NOT NULL,             -- IP/hostname (UNC share host, or SSH host)
    root_path           TEXT NOT NULL,             -- UNC: \\host\share\awr_reports
                                                    -- SSH: /remote/path/awr_reports
    ssh_port            INTEGER DEFAULT 22,        -- SSH only
    ssh_key_path        TEXT,                      -- SSH only — path to private key on portal server
    username             TEXT,                     -- UNC: share credential (optional).
                                                    -- SSH: required unless ssh_key_path set
    password_enc        TEXT,                      -- base64-obfuscated (not true encryption)
    auto_discover       BOOLEAN DEFAULT TRUE,       -- scan root_path's subfolders as databases
    pull_interval_hrs   NUMERIC(4,1) DEFAULT 1,     -- used when auto_discover=TRUE (0=manual)
    enabled             BOOLEAN DEFAULT TRUE,
    last_pull_at        TIMESTAMP,                  -- used when auto_discover=TRUE
    added_at            TIMESTAMP DEFAULT NOW(),
    added_by            TEXT DEFAULT 'admin',
    CONSTRAINT uq_awr_remote_server UNIQUE (display_name)
) tablespace awrparser;

COMMENT ON TABLE awr_remote_servers IS
    'Remote server config for AWR network sources. One row per server, one login. '
    'connection_type=unc uses Windows net use with root_path as a UNC prefix. '
    'connection_type=ssh uses paramiko SFTP with root_path as a remote directory. '
    'When auto_discover=TRUE, every immediate subfolder under root_path is treated '
    'as a database automatically — no per-database configuration required.';

CREATE TABLE IF NOT EXISTS awr_remote_db_paths (
    id                 SERIAL PRIMARY KEY,
    server_id          INTEGER NOT NULL REFERENCES awr_remote_servers(id) ON DELETE CASCADE,
    db_name            TEXT NOT NULL,          -- matches awr_db_master.db_name
    display_name       TEXT,
    remote_subpath     TEXT NOT NULL,          -- subfolder under the server's root_path, e.g. 'ORCL'
    pull_interval_hrs  NUMERIC(4,1) DEFAULT 1, -- pull every N hours (0=manual)
    enabled            BOOLEAN DEFAULT TRUE,
    last_pull_at       TIMESTAMP,
    added_at           TIMESTAMP DEFAULT NOW(),
    added_by           TEXT DEFAULT 'admin',
    CONSTRAINT uq_awr_remote_db_per_server UNIQUE (server_id, db_name)
) tablespace awrparser;

COMMENT ON TABLE awr_remote_db_paths IS
    'OPTIONAL per-database override for a server. Only needed to rename a folder, '
    'give one database its own interval, or list databases explicitly when a '
    'server has auto_discover=FALSE. Full remote location = '
    'server.root_path + / + remote_subpath. Files are copied to '
    'awr_reports/<db_name>/ and picked up by the queue processor.';

CREATE INDEX IF NOT EXISTS idx_awr_remote_db_enabled
    ON awr_remote_db_paths (enabled, server_id) tablespace awrparser_idx;


-- ============================================================
-- INDEXES (61 indexes)
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

CREATE INDEX IF NOT EXISTS idx_awr_unc_enabled  ON awr_unc_connections (enabled, db_name);

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
-- END OF SCHEMA SCRIPT
-- Tables:              80
-- Views:               2
-- Materialized Views:  12
-- Indexes:             61
-- Generated:           2026-08-04 11:30:30
-- ============================================================
