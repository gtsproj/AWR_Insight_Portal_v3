-- ============================================================
-- DAR Portal — MS SQL Server Support
-- SQLWR Report Section Tables (parsed-data layer)
-- Avekshaa Technologies
-- ============================================================
-- One table per SQLWR report section, mirroring the Oracle side's
-- awr_* table conventions exactly (checked directly against
-- install_fresh.sql, not assumed): each row is keyed by
-- begin_snapshot_id -- the same value Ganesh specified represents
-- the ENTIRE SQLWR report (the begin/end snapshot PAIR, not the
-- begin snapshot in isolation) -- with a row_hash-based unique
-- constraint so re-parsing the same report is idempotent, the same
-- as every awr_* table's own uq_* constraint.
--
-- This is the PARSED-DATA layer the forthcoming SQLWR parser will
-- populate by reading each generated SQLWR HTML report -- these
-- tables are intentionally separate from the raw DMV/Query Store
-- collector tables (mssql_wait_stats_delta, mssql_qs_runtime_stats,
-- etc.) the report generator itself reads from. Once the parser
-- exists and populates these, the three materialized views built
-- earlier (mssql_wait_summary_mv, mssql_sql_summary_mv,
-- mssql_segment_summary_mv) will be re-pointed to source from these
-- parsed tables instead of the raw collector tables they currently
-- read from -- not done in this file, a deliberate, separate step
-- once real parsed data exists to rebuild them against.
--
-- Column convention, adapted from the Oracle pattern (not copied
-- verbatim -- MSSQL has no RAC/PDB concepts, so instnum/pdb_name are
-- dropped in favor of the instance_id foreign key this project's
-- other MSSQL tables already use):
--   database_name   TEXT NOT NULL   (Oracle: dbname)
--   instance_id     INTEGER NOT NULL REFERENCES mssql_instance_master
--                                   (Oracle: instance/instnum as text/int)
--   snapshot_time   TIMESTAMP       (Oracle: snap_time -- the END
--                                    snapshot's time, matching what
--                                    the SQLWR report's own Snapshot
--                                    Summary section already shows)
--   [section-specific columns]
--   begin_snapshot_id INTEGER NOT NULL (Oracle: begin_snap -- represents
--                                    the whole report, per Ganesh)
--   row_hash        CHAR(32) NOT NULL
--   created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- ============================================================

\echo 'Creating SQLWR report section tables...'

-- ── Load Profile ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_load_profile (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    metric              TEXT NOT NULL,
    metric_value        NUMERIC,
    begin_snapshot_id   INTEGER NOT NULL,
    row_hash            CHAR(32) NOT NULL,
    created_at          TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_load_profile_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_load_profile_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_load_profile UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_load_profile IS 'Parsed data for the SQLWR report Load Profile section -- per-second rate metrics (Batch Requests, SQL Compilations, Log IOPS, Throughput, Datafile/Logfile IO Wait, Total DB Time, etc.), one row per metric per report.';


-- ── CPU Utilization ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_cpu_utilization (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    metric              TEXT NOT NULL,          -- 'SQL Server (Used)' / 'Free (Idle)' / 'Other Processes'
    min_pct             NUMERIC,
    max_pct             NUMERIC,
    avg_pct             NUMERIC,
    sample_count        INTEGER,
    begin_snapshot_id   INTEGER NOT NULL,
    row_hash            CHAR(32) NOT NULL,
    created_at          TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_cpu_util_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_cpu_util_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_cpu_util UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_cpu_utilization IS 'Parsed data for the SQLWR report CPU Utilization section -- SQL Server/Free/Other Processes CPU percentages (min/max/avg across the sys.dm_os_ring_buffers samples in the snapshot window), one row per metric per report.';


-- ── Instance Efficiency Percentages ──────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_instance_efficiency (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    metric              TEXT NOT NULL,
    metric_value        NUMERIC,
    begin_snapshot_id   INTEGER NOT NULL,
    row_hash            CHAR(32) NOT NULL,
    created_at          TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_inst_eff_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_inst_eff_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_inst_eff UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_instance_efficiency IS 'Parsed data for the SQLWR report Instance Efficiency Percentages section -- Buffer Cache Hit Ratio, Page Life Expectancy, Memory Grants Pending, one row per metric per report.';


-- ── Wait Classes by Total Wait Time ──────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_wait_classes (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    wait_class          TEXT NOT NULL,
    total_wait_time_s   NUMERIC,
    pct_of_total        NUMERIC,
    begin_snapshot_id   INTEGER NOT NULL,
    row_hash            CHAR(32) NOT NULL,
    created_at          TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_wait_classes_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_wait_classes_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_wait_classes UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_wait_classes IS 'Parsed data for the SQLWR report Wait Classes by Total Wait Time section -- wait time aggregated by wait_class, one row per class per report.';


-- ── Top Wait Types by Total Wait Time ────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_wait_events (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    wait_type            TEXT NOT NULL,
    wait_class            TEXT,
    total_wait_time_s      NUMERIC,
    pct_of_total             NUMERIC,
    begin_snapshot_id         INTEGER NOT NULL,
    row_hash                  CHAR(32) NOT NULL,
    created_at                 TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_wait_events_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_wait_events_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_wait_events UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_wait_events IS 'Parsed data for the SQLWR report Top 15 Wait Types by Total Wait Time section -- one row per individual wait_type per report.';


-- ── Wait Events by Stored Procedure (MSSQL-specific; no Oracle
--    equivalent -- Query Store's per-query wait-category attribution
--    has no AWR analog) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_wait_by_procedure (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    procedure_name      TEXT,
    executions          NUMERIC,
    wait_category         TEXT NOT NULL,
    wait_time_s             NUMERIC,
    begin_snapshot_id        INTEGER NOT NULL,
    row_hash                 CHAR(32) NOT NULL,
    created_at                TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_wait_by_proc_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_wait_by_proc_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_wait_by_proc UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_wait_by_procedure IS 'Parsed data for the SQLWR report Wait Events by Stored Procedure section -- Query Store''s own per-query wait-category attribution, one row per procedure/wait-category pair per report. MSSQL-specific; no Oracle AWR equivalent.';


-- ── Memory Statistics ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_memory_stats (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    metric              TEXT NOT NULL,
    value_mb            NUMERIC,
    begin_snapshot_id   INTEGER NOT NULL,
    row_hash            CHAR(32) NOT NULL,
    created_at          TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_memory_stats_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_memory_stats_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_memory_stats UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_memory_stats IS 'Parsed data for the SQLWR report Memory Statistics section -- host physical memory, memory allocated/used by SQL Server, one row per metric per report.';


-- ── IO Profile ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_io_profile (
    id                     SERIAL,
    database_name          TEXT NOT NULL,
    instance_id            INTEGER NOT NULL,
    snapshot_time          TIMESTAMP WITHOUT TIME ZONE,
    io_database_name       TEXT,          -- the database column IN the report row (may differ
                                           -- from `database_name` above, which is the SQLWR
                                           -- report's own owning database)
    file_name                TEXT,
    reads_per_sec              NUMERIC,
    writes_per_sec               NUMERIC,
    mb_read                        NUMERIC,
    mb_written                       NUMERIC,
    avg_read_latency_ms                NUMERIC,
    avg_write_latency_ms                 NUMERIC,
    begin_snapshot_id                      INTEGER NOT NULL,
    row_hash                               CHAR(32) NOT NULL,
    created_at                              TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_io_profile_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_io_profile_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_io_profile UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_io_profile IS 'Parsed data for the SQLWR report IO Profile section -- per-file read/write throughput and latency, one row per database file per report.';


-- ── IO Stalls by File Type ────────────────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_io_stalls_by_filetype (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    file_type             TEXT NOT NULL,       -- 'Datafile' / 'Logfile'
    read_stall_ms           NUMERIC,
    write_stall_ms             NUMERIC,
    avg_read_stall_ms            NUMERIC,
    avg_write_stall_ms             NUMERIC,
    begin_snapshot_id                INTEGER NOT NULL,
    row_hash                         CHAR(32) NOT NULL,
    created_at                        TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_io_stalls_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_io_stalls_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_io_stalls UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_io_stalls_by_filetype IS 'Parsed data for the SQLWR report IO Stalls by File Type section -- read/write stall time aggregated by Datafile vs Logfile, one row per file type per report.';


-- ── Top Objects by ... (6 sections, mirroring the Oracle side's
--    per-metric awr_seg_* split, one table per Top-Objects-by section
--    rather than one per raw underlying metric -- matching THIS
--    project's own 6-section report structure) ──────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_seg_logical_reads (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    seg_database_name   TEXT,
    object_name           TEXT,
    index_name              TEXT,
    segment_type              TEXT,
    read_operations              NUMERIC,
    seeks                          NUMERIC,
    scans                            NUMERIC,
    lookups                            NUMERIC,
    row_count                            NUMERIC,
    size_mb                                NUMERIC,
    begin_snapshot_id                        INTEGER NOT NULL,
    row_hash                                 CHAR(32) NOT NULL,
    created_at                                TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_seg_logical_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_seg_logical_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_seg_logical UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_seg_logical_reads IS 'Parsed data for the SQLWR report Top Objects by Logical Reads section -- seeks+scans+lookups per index/table, one row per object per report.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_seg_physical_reads (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    seg_database_name   TEXT,
    object_name           TEXT,
    index_name              TEXT,
    segment_type              TEXT,
    physical_read_requests      NUMERIC,
    io_wait_ms                     NUMERIC,
    begin_snapshot_id                INTEGER NOT NULL,
    row_hash                         CHAR(32) NOT NULL,
    created_at                        TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_seg_phys_reads_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_seg_phys_reads_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_seg_phys_reads UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_seg_physical_reads IS 'Parsed data for the SQLWR report Top Objects by Physical Reads section -- page_io_latch_wait-based physical I/O per index/table, one row per object per report.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_seg_physical_writes (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    seg_database_name   TEXT,
    object_name           TEXT,
    index_name              TEXT,
    segment_type              TEXT,
    total_changes                NUMERIC,
    inserts                        NUMERIC,
    deletes                          NUMERIC,
    updates                            NUMERIC,
    begin_snapshot_id                    INTEGER NOT NULL,
    row_hash                             CHAR(32) NOT NULL,
    created_at                            TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_seg_phys_writes_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_seg_phys_writes_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_seg_phys_writes UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_seg_physical_writes IS 'Parsed data for the SQLWR report Top Objects by Write Activity section -- insert/delete/update counts per index/table, one row per object per report.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_seg_table_scans (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    seg_database_name   TEXT,
    object_name           TEXT,
    index_name              TEXT,
    segment_type              TEXT,
    table_scans                  NUMERIC,
    begin_snapshot_id              INTEGER NOT NULL,
    row_hash                       CHAR(32) NOT NULL,
    created_at                      TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_seg_scans_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_seg_scans_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_seg_scans UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_seg_table_scans IS 'Parsed data for the SQLWR report Top Objects by Table Scans section -- full-scan counts per index/table, one row per object per report.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_seg_row_lock_waits (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    seg_database_name   TEXT,
    object_name           TEXT,
    index_name              TEXT,
    segment_type              TEXT,
    row_lock_waits                NUMERIC,
    row_lock_wait_ms                NUMERIC,
    begin_snapshot_id                 INTEGER NOT NULL,
    row_hash                          CHAR(32) NOT NULL,
    created_at                         TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_seg_rowlock_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_seg_rowlock_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_seg_rowlock UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_seg_row_lock_waits IS 'Parsed data for the SQLWR report Top Objects by Row Lock Waits section -- row lock wait counts/time per index/table, one row per object per report.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_seg_buffer_busy_waits (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    seg_database_name   TEXT,
    object_name           TEXT,
    index_name              TEXT,
    segment_type              TEXT,
    page_latch_waits              NUMERIC,
    page_latch_wait_ms              NUMERIC,
    page_io_latch_waits               NUMERIC,
    page_io_latch_wait_ms               NUMERIC,
    begin_snapshot_id                     INTEGER NOT NULL,
    row_hash                              CHAR(32) NOT NULL,
    created_at                             TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_seg_latch_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_seg_latch_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_seg_latch UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_seg_buffer_busy_waits IS 'Parsed data for the SQLWR report Top Objects by Page Latch Waits section -- page latch and page IO latch wait counts/time per index/table, one row per object per report.';


-- ── SQL ordered by ... (4 sections, mirroring Oracle's
--    awr_sql_elapsed_time / awr_sql_cpu_time / awr_sql_gets /
--    awr_sql_executions split exactly) ─────────────────────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_sql_elapsed_time (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    sql_id                TEXT,
    sql_module              TEXT,
    stored_procedure          TEXT,
    executions                  NUMERIC,
    elapsed_time_s                 NUMERIC,
    elapsed_time_per_exec_s          NUMERIC,
    pct_total                          NUMERIC,
    pct_cpu                              NUMERIC,
    pct_io                                  NUMERIC,
    begin_snapshot_id                         INTEGER NOT NULL,
    row_hash                                  CHAR(32) NOT NULL,
    created_at                                 TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_sql_elapsed_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_sql_elapsed_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_sql_elapsed UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_sql_elapsed_time IS 'Parsed data for the SQLWR report SQL ordered by Elapsed Time section -- one row per query per report.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_sql_cpu_time (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    sql_id                TEXT,
    sql_module              TEXT,
    stored_procedure          TEXT,
    executions                  NUMERIC,
    cpu_time_s                     NUMERIC,
    cpu_per_exec_s                    NUMERIC,
    elapsed_time_s                       NUMERIC,
    pct_total                              NUMERIC,
    pct_cpu                                  NUMERIC,
    pct_io                                      NUMERIC,
    begin_snapshot_id                             INTEGER NOT NULL,
    row_hash                                      CHAR(32) NOT NULL,
    created_at                                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_sql_cpu_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_sql_cpu_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_sql_cpu UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_sql_cpu_time IS 'Parsed data for the SQLWR report SQL ordered by CPU Time section -- one row per query per report.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_sql_gets (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    sql_id                TEXT,
    sql_module              TEXT,
    stored_procedure          TEXT,
    buffer_gets                  NUMERIC,
    executions                     NUMERIC,
    gets_per_exec                     NUMERIC,
    pct_total                           NUMERIC,
    elapsed_time_s                        NUMERIC,
    pct_cpu                                 NUMERIC,
    pct_io                                     NUMERIC,
    begin_snapshot_id                            INTEGER NOT NULL,
    row_hash                                     CHAR(32) NOT NULL,
    created_at                                    TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_sql_gets_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_sql_gets_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_sql_gets UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_sql_gets IS 'Parsed data for the SQLWR report SQL ordered by Gets section -- buffer gets per query, one row per query per report.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_sql_executions (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    sql_id                TEXT,
    sql_module              TEXT,
    stored_procedure          TEXT,
    executions                  NUMERIC,
    elapsed_time_s                 NUMERIC,
    pct_cpu                          NUMERIC,
    pct_io                             NUMERIC,
    rows_processed                       NUMERIC,
    rows_per_exec                          NUMERIC,
    begin_snapshot_id                        INTEGER NOT NULL,
    row_hash                                 CHAR(32) NOT NULL,
    created_at                                TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_sql_execs_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_sql_execs_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_sql_execs UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_sql_executions IS 'Parsed data for the SQLWR report SQL ordered by Executions section -- one row per query per report.';


-- ── Complete List of SQL Text (mirrors awr_sql_text) ─────────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_sql_text (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    sql_id                TEXT NOT NULL,
    sql_text                TEXT,
    begin_snapshot_id         INTEGER NOT NULL,
    row_hash                  CHAR(32) NOT NULL,
    created_at                  TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_sql_text_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_sql_text_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_sql_text UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_sql_text IS 'Parsed data for the SQLWR report Complete List of SQL Text section -- full SQL text for every sql_id referenced elsewhere in the report, one row per query per report.';


-- ── Blocking Summary (MSSQL-specific; no Oracle equivalent) ──
CREATE TABLE IF NOT EXISTS mssql_sqlwr_blocking_summary (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    session_id             INTEGER,
    blocked_by                INTEGER,
    wait_type                    TEXT,
    wait_time_s                     NUMERIC,
    resource_type                     TEXT,
    blocked_object                       TEXT,
    blocked_database_name                  TEXT,
    begin_snapshot_id                        INTEGER NOT NULL,
    row_hash                                 CHAR(32) NOT NULL,
    created_at                                TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_blocking_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_blocking_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_blocking UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_blocking_summary IS 'Parsed data for the SQLWR report Blocking Summary section -- blocking sessions observed at the end snapshot, one row per blocked session per report. MSSQL-specific; no Oracle AWR equivalent.';


-- ── Deadlock Summary (MSSQL-specific; no Oracle equivalent) ──
CREATE TABLE IF NOT EXISTS mssql_sqlwr_deadlock_summary (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    deadlock_time         TIMESTAMP WITHOUT TIME ZONE,
    deadlock_database_name  TEXT,
    contested_table            TEXT,
    contested_index               TEXT,
    deadlock_cause                   TEXT,
    process_count                       INTEGER,
    victim_app                             TEXT,
    victim_login                             TEXT,
    victim_proc_or_statement                    TEXT,
    begin_snapshot_id                             INTEGER NOT NULL,
    row_hash                                      CHAR(32) NOT NULL,
    created_at                                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_deadlock_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_deadlock_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_deadlock UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_deadlock_summary IS 'Parsed data for the SQLWR report Deadlock Summary section -- deadlocks recorded during the snapshot window with victim context, one row per deadlock per report. MSSQL-specific; no Oracle AWR equivalent.';


-- ── Plan Cache Health (MSSQL-specific; no Oracle equivalent) ──
CREATE TABLE IF NOT EXISTS mssql_sqlwr_plan_cache_summary (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    metric              TEXT NOT NULL,     -- 'Total Cached Plans' / 'Single-Use Plans' / 'Ad Hoc Plans'
    plan_count           NUMERIC,
    pct_of_total            NUMERIC,
    memory_mb                 NUMERIC,
    begin_snapshot_id           INTEGER NOT NULL,
    row_hash                     CHAR(32) NOT NULL,
    created_at                    TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_pc_summary_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_pc_summary_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_pc_summary UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_plan_cache_summary IS 'Parsed data for the SQLWR report Plan Cache Health section (summary part) -- total/single-use/ad hoc plan counts and memory, one row per metric per report. MSSQL-specific; no Oracle AWR equivalent.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_plan_cache_detail (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    query_hash             TEXT,
    plan_type                 TEXT,
    use_count                    NUMERIC,
    size_kb                        NUMERIC,
    executions                       NUMERIC,
    cpu_time_s                          NUMERIC,
    logical_reads                          NUMERIC,
    begin_snapshot_id                        INTEGER NOT NULL,
    row_hash                                 CHAR(32) NOT NULL,
    created_at                                TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_pc_detail_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_pc_detail_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_pc_detail UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_plan_cache_detail IS 'Parsed data for the SQLWR report Plan Cache Health section (detail part) -- top cached plans by reuse count, one row per plan per report. MSSQL-specific; no Oracle AWR equivalent.';


-- ── TempDB Usage (MSSQL-specific; no Oracle equivalent) ──────
CREATE TABLE IF NOT EXISTS mssql_sqlwr_tempdb_sessions (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    session_id             INTEGER,
    login_name                TEXT,
    user_objects_mb              NUMERIC,
    internal_objects_mb            NUMERIC,
    begin_snapshot_id                 INTEGER NOT NULL,
    row_hash                          CHAR(32) NOT NULL,
    created_at                         TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_tempdb_sess_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_tempdb_sess_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_tempdb_sess UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_tempdb_sessions IS 'Parsed data for the SQLWR report TempDB Usage section (sessions part) -- top sessions by cumulative TempDB space, one row per session per report. MSSQL-specific; no Oracle AWR equivalent.';


CREATE TABLE IF NOT EXISTS mssql_sqlwr_tempdb_tasks (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    instance_id         INTEGER NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    session_id             INTEGER,
    request_id                INTEGER,
    allocated_mb                  NUMERIC,
    deallocated_mb                   NUMERIC,
    begin_snapshot_id                    INTEGER NOT NULL,
    row_hash                             CHAR(32) NOT NULL,
    created_at                            TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_tempdb_task_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_sqlwr_tempdb_task_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_sqlwr_tempdb_task UNIQUE (database_name, instance_id, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_tempdb_tasks IS 'Parsed data for the SQLWR report TempDB Usage section (tasks part) -- currently-executing tasks allocating TempDB space, one row per task per report. MSSQL-specific; no Oracle AWR equivalent.';


\echo ''
\echo '============================================================'
\echo 'SQLWR report section tables created -- 26 tables covering all'
\echo '26 SQLWR report sections (Database/Snapshot Summary use'
\echo 'existing mssql_dmv_snapshot/mssql_sqlwr_report metadata rather'
\echo 'than a dedicated parsed table each).'
\echo '============================================================'
