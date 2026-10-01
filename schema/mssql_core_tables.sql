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


-- ── mssql_db_info ───────────────────────────────────────────────
-- Per-database identity registry, modeled on the Oracle side's
-- awr_db_info (db_info_parser.py): one row per (instance, database),
-- captured ONCE -- from the FIRST SQLWR report ever parsed for that
-- database -- and never updated afterward by this parser. Unlike
-- awr_db_info's own dedup rule (UNIQUE on db_name+instance+row_hash,
-- which allows a NEW row when the content changes), this table's
-- uniqueness is on (instance_id, database_name) alone: a database
-- already present is always skipped, even if its edition, host,
-- core count etc. would now parse differently. row_hash is still
-- stored (project-wide convention, and useful for audit) but is
-- NOT part of what makes a row unique here.
--
-- inst_num, unique_name, and role are genuinely Oracle concepts
-- (RAC instance number; Data Guard-style unique database name;
-- replica role) with no reliable SQL Server equivalent outside an
-- Availability Group -- NULL unless/until AG collection exists (see
-- mssql_instance_master.ag_name/ag_replica_role, currently
-- unpopulated -- AG support is explicitly out of scope for now).
CREATE TABLE IF NOT EXISTS mssql_db_info (
    id                             SERIAL,
    instance_name                  TEXT,
    instance_id                    INTEGER,
    inst_num                       INTEGER,
    database_name                  TEXT NOT NULL,
    database_id                    INTEGER,
    unique_name                    TEXT,
    role                           TEXT,
    edition                        TEXT,
    release                        TEXT,
    host_name                      TEXT,
    platform                       TEXT,
    cpu_count                      INTEGER,
    cores                          INTEGER,
    socket                         INTEGER,
    memory_gb                      NUMERIC,
    row_hash                       CHAR(32) NOT NULL,
    source_type                    TEXT DEFAULT 'local_file'::text,
    repo_path                      TEXT,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_db_info_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_db_info_inst FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_db_info UNIQUE (instance_id, database_name) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_db_info IS 'Per-database identity registry, one row per (instance, database), inserted once from the first SQLWR report parsed for that database and never updated afterward -- mirrors awr_db_info''s role for Oracle, with a stricter one-row-ever dedup rule (unique on instance_id+database_name, not row_hash) per spec. inst_num/unique_name/role are Oracle-flavoured concepts with no reliable SQL Server equivalent outside an Availability Group and are NULL until AG collection exists.'


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
