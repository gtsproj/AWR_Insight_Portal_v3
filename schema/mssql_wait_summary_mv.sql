-- ============================================================
-- mssql_wait_summary_mv -- MSSQL analog to the Oracle side's
-- awr_wait_summary_mv. One row per (instance, snapshot, wait_type),
-- with a severity_score for fast "what's hurting this instance
-- right now" dashboard queries -- mirrors the naming, granularity,
-- and severity-scoring approach of the Oracle MV it's modeled on.
--
-- The one real architectural difference from the Oracle version,
-- not papered over: awr_wait_summary_mv sources from ALREADY-DELTA'D
-- parsed report tables (Oracle's AWR snapshot mechanism computes
-- deltas at collection time). mssql_wait_stats_delta instead stores
-- CUMULATIVE counters at each snapshot (sys.dm_os_wait_stats is
-- cumulative since SQL Server startup, not reset per interval) --
-- so this MV computes the delta itself, between each snapshot and
-- the one immediately before it for the same instance/wait_type,
-- via LAG() -- not an arbitrary snapshot pair the way a single SQLWR
-- report is scoped to, but a genuine time series suitable for
-- Grafana trending.
--
-- No foreground/background split (unlike several of the Oracle-side
-- wait MVs) -- sys.dm_os_wait_stats has no equivalent distinction;
-- this deliberately mirrors awr_wait_summary_mv (the unified,
-- non-split one) rather than the four FG/BG-specific Oracle MVs,
-- which have no honest MSSQL equivalent.
--
-- Benign wait types (SLEEP_*, idle/broker waits, etc.) excluded via
-- mssql_wait_event_master.is_benign -- the same, single source of
-- truth rule_engine.py's BENIGN_WAIT_TYPES already seeds that column
-- from, not a second, separately-maintained list.
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS mssql_wait_summary_mv;

CREATE MATERIALIZED VIEW mssql_wait_summary_mv
TABLESPACE mssqlparser
AS
WITH deltas AS (
    SELECT
        s.instance_id,
        w.snapshot_id,
        s.snapshot_time,
        w.wait_type,
        COALESCE(m.wait_class, 'Other/Uncategorized') AS wait_class,
        w.waiting_tasks_count - LAG(w.waiting_tasks_count)
            OVER (PARTITION BY s.instance_id, w.wait_type ORDER BY w.snapshot_id) AS d_tasks,
        w.wait_time_ms - LAG(w.wait_time_ms)
            OVER (PARTITION BY s.instance_id, w.wait_type ORDER BY w.snapshot_id) AS d_wait_ms,
        w.signal_wait_time_ms - LAG(w.signal_wait_time_ms)
            OVER (PARTITION BY s.instance_id, w.wait_type ORDER BY w.snapshot_id) AS d_signal_ms
    FROM mssql_wait_stats_delta w
    JOIN mssql_dmv_snapshot s ON s.snapshot_id = w.snapshot_id
    LEFT JOIN mssql_wait_event_master m
           ON m.tier = 'wait_type' AND m.event_name = w.wait_type
    WHERE COALESCE(m.is_benign, false) = false
),
-- LAG() returns NULL for each wait_type's first-ever snapshot per
-- instance (nothing to delta against) -- those rows are correctly
-- excluded here, not shown as zero activity.
positive AS (
    SELECT instance_id, snapshot_id, snapshot_time, wait_class, wait_type,
           GREATEST(d_tasks, 0) AS waiting_tasks,
           GREATEST(d_wait_ms, 0) AS wait_time_ms,
           GREATEST(d_signal_ms, 0) AS signal_wait_time_ms
    FROM deltas
    WHERE d_wait_ms IS NOT NULL
)
SELECT
    instance_id, snapshot_id, snapshot_time, wait_class, wait_type,
    waiting_tasks, wait_time_ms, signal_wait_time_ms,
    ROUND(wait_time_ms / 1000.0, 2) AS wait_time_s,
    CASE WHEN waiting_tasks > 0
         THEN ROUND(wait_time_ms::numeric / waiting_tasks, 2)
         ELSE 0 END AS avg_wait_ms,
    ROUND(100.0 * wait_time_ms
          / NULLIF(SUM(wait_time_ms) OVER (PARTITION BY instance_id, snapshot_id), 0), 2)
        AS pct_of_snapshot_wait,
    -- Same weighting shape as Oracle's awr_wait_summary_mv:
    -- 70% share-of-snapshot-wait-time, 20% total wait time (scaled),
    -- 10% average wait per task (scaled) -- reusing that project's
    -- own established weighting rather than inventing a new one.
    ROUND(
        (COALESCE(100.0 * wait_time_ms
             / NULLIF(SUM(wait_time_ms) OVER (PARTITION BY instance_id, snapshot_id), 0), 0) * 0.7)
        + ((wait_time_ms / 1000.0) * 0.2)
        + ((CASE WHEN waiting_tasks > 0 THEN wait_time_ms::numeric / waiting_tasks ELSE 0 END
            / 10.0) * 0.1)
    , 2) AS severity_score,
    ROW_NUMBER() OVER () AS mv_id
FROM positive
WHERE wait_time_ms > 0
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mssql_wait_summary_mv_id
    ON mssql_wait_summary_mv (mv_id) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_wait_summary_mv_inst_snap
    ON mssql_wait_summary_mv (instance_id, snapshot_id) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_wait_summary_mv_severity
    ON mssql_wait_summary_mv (instance_id, snapshot_id, severity_score DESC) TABLESPACE mssqlparser_idx;

\echo 'mssql_wait_summary_mv created.'
