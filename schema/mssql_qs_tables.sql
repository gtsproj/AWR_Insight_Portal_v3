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
