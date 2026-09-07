-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Deadlock Capture Table
-- Avekshaa Technologies
-- ============================================================
--
-- Run AFTER mssql_core_tables.sql. Sourced from the system_health
-- Extended Events session, which runs by default on every SQL Server
-- instance (2008+) with no setup needed -- the collector's job is
-- periodic extraction (querying sys.dm_xe_session_targets for the
-- ring_buffer/file target, parsing the XML deadlock graph), not
-- standing up new capture infrastructure (Analysis Model doc
-- Section 9.1.4).
--
-- One row per captured deadlock EVENT, not a delta/snapshot table --
-- uses row_hash for dedup since the same deadlock event could
-- theoretically be re-extracted if the collector polls faster than
-- the XE ring buffer rotates, the same protection pattern used for
-- Oracle's time-series parser tables.
-- ============================================================

\echo 'Creating MS SQL deadlock capture table...'

CREATE TABLE IF NOT EXISTS mssql_deadlock_events (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    deadlock_time                  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    victim_session_id              INTEGER,
    deadlock_graph_xml             TEXT,
    process_count                  INTEGER,
    resource_summary                TEXT,          -- short human-readable summary derived at
                                                    -- collection time (e.g. "2 processes, KEY lock
                                                    -- on dbo.Orders") -- avoids needing to parse the
                                                    -- full XML just to render a findings list
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_deadlock_events_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_deadlock_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_deadlock_events UNIQUE (instance_id, row_hash) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_deadlock_events IS 'Deadlock graphs extracted from the system_health Extended Events session (always running by default, no setup needed). row_hash dedups against re-extracting the same event if the collector polls faster than the XE ring buffer rotates.';

CREATE INDEX IF NOT EXISTS idx_mssql_deadlock_time ON public.mssql_deadlock_events USING btree (instance_id, deadlock_time DESC) TABLESPACE mssqlparser_idx;

\echo '  Deadlock table: done'
\echo ''
\echo '============================================================'
\echo 'MS SQL Server Phase 1 schema install complete.'
\echo '22 tables total: 3 core + 5 Query Store + 13 cumulative-DMV + 1 deadlock'
\echo '============================================================'
