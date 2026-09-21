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
