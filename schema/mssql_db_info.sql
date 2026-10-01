-- schema/mssql_db_info.sql
--
-- Standalone migration for an EXISTING database: adds mssql_db_info
-- (CREATE TABLE IF NOT EXISTS -- safe to re-run, does nothing if the
-- table already exists from a fresh install via mssql_fresh_install.sql
-- or mssql_core_tables.sql, which already define it identically).
--
-- See schema/mssql_core_tables.sql for the full column-by-column
-- rationale; this file exists only so the table can be added to a
-- database that was set up before this table existed, without
-- re-running the whole core-tables script.

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
COMMENT ON TABLE mssql_db_info IS 'Per-database identity registry, one row per (instance, database), inserted once from the first SQLWR report parsed for that database and never updated afterward -- mirrors awr_db_info''s role for Oracle, with a stricter one-row-ever dedup rule (unique on instance_id+database_name, not row_hash) per spec. inst_num/unique_name/role are Oracle-flavoured concepts with no reliable SQL Server equivalent outside an Availability Group and are NULL until AG collection exists.';
