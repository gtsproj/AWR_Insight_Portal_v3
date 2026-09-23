-- ============================================================
-- mssql_cpu_utilization_history -- SQL Server process/idle/other CPU
-- utilization over time, from sys.dm_os_ring_buffers'
-- RING_BUFFER_SCHEDULER_MONITOR -- the standard, well-documented
-- source for this (Glenn Berry's/Brent Ozar's diagnostic query
-- pattern), holding up to ~256 historical samples at roughly
-- 1-minute intervals, independent of this project's own snapshot
-- schedule. One row per distinct SQL Server sample, not per
-- collection cycle -- repeated collection naturally re-sees the same
-- samples (the ~10-minute collection cadence is coarser than the
-- ring buffer's own ~1-minute sampling), deduplicated by
-- (instance_id, event_time).
--
-- event_time is stored as UTC explicitly (the collector uses
-- SYSUTCDATETIME(), not GETDATE(), specifically to avoid the exact
-- local-vs-UTC mismatch that mssql_dmv_snapshot.snapshot_time hit
-- earlier in this project) -- safe to compare directly against
-- snapshot_time for a report's time-window filtering.
-- ============================================================

CREATE TABLE IF NOT EXISTS mssql_cpu_utilization_history (
    id                             SERIAL,
    instance_id                    INTEGER NOT NULL,
    event_time                     TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    sql_process_pct                SMALLINT,
    system_idle_pct                SMALLINT,
    other_process_pct              SMALLINT,
    collected_at_snapshot_id       INTEGER,
    CONSTRAINT mssql_cpu_util_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT uq_mssql_cpu_util UNIQUE (instance_id, event_time) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_cpu_util_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id)
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_cpu_utilization_history IS 'SQL Server CPU utilization over time from sys.dm_os_ring_buffers (RING_BUFFER_SCHEDULER_MONITOR). sql_process_pct = used by SQL Server, system_idle_pct = free, other_process_pct = used by other processes on the host.';

CREATE INDEX IF NOT EXISTS idx_mssql_cpu_util_inst_time
    ON public.mssql_cpu_utilization_history USING btree (instance_id, event_time) TABLESPACE mssqlparser_idx;

\echo 'mssql_cpu_utilization_history created.'
