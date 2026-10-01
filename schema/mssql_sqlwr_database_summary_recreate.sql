-- schema/mssql_sqlwr_database_summary_recreate.sql
--
-- *** DESTRUCTIVE FOR AN EXISTING mssql_sqlwr_database_summary TABLE ***
--
-- Drops and recreates mssql_sqlwr_database_summary with the new, slimmer
-- column set (per spec: database identity facts moved out to the new
-- mssql_db_info table -- see schema/mssql_db_info.sql -- so this table
-- keeps only the per-report fields). Any rows already parsed into the
-- OLD (richer) shape of this table are lost by running this file.
--
-- That loss is recoverable, not permanent: every row this table ever
-- had came from parsing a SQLWR report file, and those report files
-- still exist on disk (in sqlwr_reports/<db>/ or, once archived,
-- sqlwr_archive/<db>/) -- re-running the master parser
-- (mssql_master_parser.py) against them regenerates this table's rows
-- (and populates the new mssql_db_info table) from the same source
-- files. Nothing else is touched: the other 26 mssql_sqlwr_* tables
-- are unaffected by this file.
--
-- Run this ONCE, after schema/mssql_db_info.sql (or a fresh install,
-- which already has both in their final shape and does not need this
-- file at all).

DROP TABLE IF EXISTS mssql_sqlwr_database_summary CASCADE;

CREATE TABLE mssql_sqlwr_database_summary (
    id                  SERIAL,
    database_name       TEXT NOT NULL,
    snapshot_time       TIMESTAMP WITHOUT TIME ZONE,
    startup_time        TIMESTAMP WITHOUT TIME ZONE,
    begin_snap_id       INTEGER,
    begin_snapshot_id   INTEGER NOT NULL,
    end_snap_id         INTEGER,
    end_snap_time       TIMESTAMP WITHOUT TIME ZONE,
    begin_sessions      INTEGER,
    end_sessions        INTEGER,
    cursors_per_sessions NUMERIC,
    elapsed_minutes     NUMERIC,
    db_time_minutes     NUMERIC,
    row_hash            CHAR(32) NOT NULL,
    created_at          TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_sqlwr_db_summary_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT uq_sqlwr_db_summary UNIQUE (database_name, begin_snapshot_id, row_hash)
        USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_sqlwr_database_summary IS 'RECREATED (slimmer) per spec: parsed data for the SQLWR report''s per-report summary fields only, one row per report -- database_name is carried for convenience/filtering, not as a join key (there is no instance_id column here; join back to mssql_dmv_snapshot on begin_snap_id/end_snap_id if the instance is ever needed). Database/host/instance IDENTITY facts (edition, release, host_name, platform, cpu/cores/sockets, memory, database_id, unique_name, role, instance_id, inst_num) moved OUT of this table and into mssql_db_info, which captures them once per database rather than repeating them on every report row -- see that table''s own comment. Two intentional redundancies kept because the column list was specified explicitly: begin_snap_id and begin_snapshot_id hold the SAME value (begin_snap_id for symmetry with end_snap_id; begin_snapshot_id for consistency with the report-key convention every other mssql_sqlwr_* table uses); end_snap_time and snapshot_time likewise both hold the end snapshot''s time. cursors_per_sessions is always NULL: SQL Server exposes no per-session open-cursor count via these DMVs, so it is not filled rather than approximated. See Documentation/MSSQL_SQLWR_Parsed_Tables_Conventions.md.';
