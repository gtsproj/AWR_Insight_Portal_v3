-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Deadlock Capture Tables
-- Avekshaa Technologies
-- ============================================================
--
-- Run AFTER mssql_core_tables.sql. Sourced from the system_health
-- Extended Events session's FILE TARGET, not the ring buffer --
-- confirmed against a real SQL Server 2022 source (our exact version
-- floor) that the ring buffer returns zero rows for
-- xml_deadlock_report events on 2022, even when the events are
-- genuinely captured and visible in the file target. Using the ring
-- buffer, as originally planned in the Analysis Model design doc
-- Section 9.1.4, would have silently produced empty results --
-- caught before writing the collector, not after.
--
-- Two tables, not one, adapted from Ganesh's own deadlock-extraction
-- scripts: an event has ONE contested resource but potentially MORE
-- THAN TWO participating processes (his third script explicitly
-- shreds every process via CROSS APPLY rather than assuming exactly
-- 2) -- cramming "process 1"/"process 2" columns into one row breaks
-- down for that case, so process-level detail gets its own table in
-- a natural one-to-many relationship with the event.
-- ============================================================

\echo 'Creating MS SQL deadlock capture tables...'

-- ── mssql_deadlock_events ──────────────────────────────────────
-- One row per captured deadlock EVENT -- the contested resource and
-- an overall root-cause classification (mirroring the deadlock_cause
-- CASE logic from Ganesh's own analysis script) live here.
CREATE TABLE IF NOT EXISTS mssql_deadlock_events (
    id                              SERIAL,
    instance_id                     INTEGER NOT NULL,
    deadlock_time                   TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    victim_process_id               TEXT,          -- the deadlock graph's own process id (e.g. "process861a...")
                                                    -- for the victim -- joins to mssql_deadlock_processes.process_id
    process_count                   INTEGER,
    contested_table                 TEXT,
    contested_index                 TEXT,
    lock_mode_1                     TEXT,
    lock_mode_2                     TEXT,
    deadlock_cause                  TEXT,          -- classified at collection time, same categories as
                                                    -- Ganesh's script: 'Update/Exclusive lock collision',
                                                    -- 'Read-Write conflict (RCSI not enabled?)',
                                                    -- 'Table-level lock (missing covering index)',
                                                    -- 'Cross-resource cyclic lock (tx order mismatch)'
    deadlock_graph_xml              TEXT,          -- full raw XML, for anything the structured columns don't capture
    row_hash                        CHAR(32) NOT NULL,
    created_at                      TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_deadlock_events_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_deadlock_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_deadlock_events UNIQUE (instance_id, row_hash) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_deadlock_events IS 'Deadlock graphs extracted from the system_health Extended Events session''s FILE target (not ring buffer -- confirmed unreliable on SQL Server 2022). row_hash dedups against re-extracting the same event across collector runs.';

CREATE INDEX IF NOT EXISTS idx_mssql_deadlock_time ON public.mssql_deadlock_events USING btree (instance_id, deadlock_time DESC) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_deadlock_cause ON public.mssql_deadlock_events USING btree (deadlock_cause) TABLESPACE mssqlparser_idx;

-- ── mssql_deadlock_processes ───────────────────────────────────
-- One row per PROCESS participating in a deadlock event -- mirrors
-- the process-level detail Ganesh's third script extracts (role,
-- session/login/app context, isolation level, and critically the
-- exact DML statement each process was executing at deadlock time).
CREATE TABLE IF NOT EXISTS mssql_deadlock_processes (
    id                              SERIAL,
    deadlock_event_id               INTEGER NOT NULL,
    process_id                      TEXT,          -- the deadlock graph's own process id string
    role                            TEXT,          -- 'VICTIM' or 'SURVIVOR'
    spid                            INTEGER,
    client_app                      TEXT,
    login_name                      TEXT,
    host_name                       TEXT,
    isolation_level                 TEXT,
    tran_count                      INTEGER,
    input_buffer                    TEXT,          -- outermost EXEC call or ad-hoc SQL
    executing_proc                  TEXT,          -- stored procedure name, if any, from the innermost execution frame
    executing_line                  INTEGER,
    exact_dml_statement              TEXT,          -- the actual statement text at the point of deadlock --
                                                    -- falls back to input_buffer if the execution frame's own
                                                    -- text wasn't captured, same fallback Ganesh's script uses
    caller_proc                     TEXT,          -- one level up the call stack, if the executing proc was
                                                    -- itself called from another procedure
    caller_line                     INTEGER,
    CONSTRAINT mssql_deadlock_processes_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_deadlock_process_event FOREIGN KEY (deadlock_event_id) REFERENCES mssql_deadlock_events(id)
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_deadlock_processes IS 'One row per process participating in a deadlock event -- role, session context, and the exact DML statement each was executing, mirroring Ganesh''s own deadlock-analysis script''s process-level extraction.';

CREATE INDEX IF NOT EXISTS idx_mssql_deadlock_processes_event ON public.mssql_deadlock_processes USING btree (deadlock_event_id) TABLESPACE mssqlparser_idx;

\echo '  Deadlock tables: done'
\echo ''
\echo '============================================================'
\echo 'MS SQL Server Phase 1 schema install complete.'
\echo '23 tables total: 3 core + 5 Query Store + 13 cumulative-DMV + 2 deadlock'
\echo '============================================================'
