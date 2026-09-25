-- ============================================================
-- mssql_sql_summary_mv -- MSSQL analog to Oracle's awr_sql_summary_mv.
-- One row per (instance, database, Query Store interval, query),
-- combining executions/elapsed/CPU/logical-reads/physical-reads into
-- a single row -- mirrors that Oracle MV's shape and intent (a
-- per-query, per-time-slice performance summary for fast dashboard
-- queries) without needing a separate elapsed/cpu/gets/reads MV each
-- the way the Oracle side's four separate source tables required.
--
-- Keyed by Query Store's own qs_interval_id, NOT mssql_dmv_snapshot's
-- snapshot_id -- a deliberate difference from mssql_wait_summary_mv,
-- not an inconsistency. Query Store's intervals run on their own
-- independent clock (INTERVAL_LENGTH_MINUTES, set per-database, not
-- synchronized to the DMV collector's snapshot schedule at all) --
-- forcing this into snapshot_id terms would mean picking one
-- arbitrary DMV snapshot to attribute each interval to, which is
-- both inaccurate and unnecessary: start_time/end_time here are
-- already a genuine, honest time reference Grafana can plot directly.
--
-- Unlike mssql_wait_stats_delta, mssql_qs_runtime_stats is already
-- PER-INTERVAL, not a cumulative counter -- Query Store computes and
-- resets these itself each interval, so this MV aggregates directly
-- rather than needing the LAG()-based delta computation
-- mssql_wait_summary_mv required.
--
-- No Oracle-style sql_object_map/sql_text_norm MVs needed here --
-- object_name comes directly from mssql_qs_query (Query Store's own,
-- native object linkage), not regex-inferred from SQL text the way
-- Oracle's equivalent had to.
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS mssql_sql_summary_mv;

CREATE MATERIALIZED VIEW mssql_sql_summary_mv
TABLESPACE mssqlparser
AS
SELECT
    q.instance_id,
    rs.database_name,
    iv.qs_interval_id,
    iv.start_time,
    iv.end_time,
    q.qs_query_id AS sql_id,
    q.object_name,
    qt.query_sql_text,
    SUM(rs.count_executions) AS executions,
    SUM(rs.avg_duration_us * rs.count_executions) / 1000000.0 AS total_elapsed_time_s,
    SUM(rs.avg_cpu_time_us * rs.count_executions) / 1000000.0 AS total_cpu_time_s,
    SUM(rs.avg_logical_io_reads * rs.count_executions) AS total_logical_reads,
    SUM(rs.avg_physical_io_reads * rs.count_executions) AS total_physical_reads,
    SUM(rs.avg_rowcount * rs.count_executions) AS total_rows,
    CASE WHEN SUM(rs.count_executions) > 0
         THEN ROUND((SUM(rs.avg_duration_us * rs.count_executions) / 1000000.0)
                     / SUM(rs.count_executions), 4)
         ELSE 0 END AS elapsed_time_per_exec_s,
    -- Severity: total elapsed time in the interval dominates (queries that
    -- collectively burn the most wall-clock time matter most for RCA), with
    -- total CPU and total logical reads as secondary signals -- same three-
    -- factor-weighted-sum shape as mssql_wait_summary_mv's severity_score,
    -- scaled for SQL-level rather than wait-level magnitudes.
    ROUND(
        (SUM(rs.avg_duration_us * rs.count_executions) / 1000000.0) * 0.6
        + (SUM(rs.avg_cpu_time_us * rs.count_executions) / 1000000.0) * 0.3
        + (SUM(rs.avg_logical_io_reads * rs.count_executions) / 100000.0) * 0.1
    , 2) AS severity_score,
    ROW_NUMBER() OVER () AS mv_id
FROM mssql_qs_runtime_stats rs
JOIN mssql_qs_plan p
  ON rs.instance_id = p.instance_id AND rs.database_name = p.database_name
 AND rs.qs_plan_id = p.qs_plan_id
JOIN mssql_qs_query q
  ON p.instance_id = q.instance_id AND p.database_name = q.database_name
 AND p.qs_query_id = q.qs_query_id
JOIN mssql_qs_query_text qt
  ON q.instance_id = qt.instance_id AND q.database_name = qt.database_name
 AND q.qs_query_text_id = qt.qs_query_text_id
JOIN mssql_qs_interval iv
  ON rs.instance_id = iv.instance_id AND rs.database_name = iv.database_name
 AND rs.qs_interval_id = iv.qs_interval_id
GROUP BY q.instance_id, rs.database_name, iv.qs_interval_id, iv.start_time, iv.end_time,
         q.qs_query_id, q.object_name, qt.query_sql_text
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mssql_sql_summary_mv_id
    ON mssql_sql_summary_mv (mv_id) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_sql_summary_mv_inst_iv
    ON mssql_sql_summary_mv (instance_id, qs_interval_id) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_sql_summary_mv_severity
    ON mssql_sql_summary_mv (instance_id, qs_interval_id, severity_score DESC) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_sql_summary_mv_sqlid
    ON mssql_sql_summary_mv (instance_id, sql_id) TABLESPACE mssqlparser_idx;

\echo 'mssql_sql_summary_mv created.'
