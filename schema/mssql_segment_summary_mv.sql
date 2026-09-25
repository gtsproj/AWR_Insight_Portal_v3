-- ============================================================
-- mssql_segment_summary_mv -- MSSQL analog to Oracle's
-- awr_segment_summary_mv. One row per (instance, snapshot, database,
-- object, index), combining read/write/latch/lock activity into a
-- single row -- mirrors that Oracle MV's shape (severity-scored
-- per-object activity, ready for "top objects across time" Grafana
-- panels) and reuses the metric selection already established in the
-- SQLWR report's own "Top Objects by..." sections (Segment
-- Statistics work), just restructured for the MV's per-snapshot
-- time-series shape instead of an arbitrary-snapshot-pair report.
--
-- Same architectural note as mssql_wait_summary_mv: every counter in
-- mssql_index_usage_delta (seeks, scans, leaf_insert_count,
-- page_io_latch_wait_in_ms, etc.) is CUMULATIVE since the index's
-- metadata entered SQL Server's cache, not a per-snapshot value --
-- this MV computes deltas itself via LAG(), between each snapshot and
-- the one immediately before it for the same instance/object/index.
--
-- GREATEST(delta, 0) per metric, same reasoning as the SQLWR report's
-- own Segment Statistics section: sys.dm_db_index_operational_stats'
-- own documented behavior is that these counters reset to zero when
-- an index's metadata cycles out of and back into the cache -- a
-- negative delta there is a real reset, not activity.
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS mssql_segment_summary_mv;

CREATE MATERIALIZED VIEW mssql_segment_summary_mv
TABLESPACE mssqlparser
AS
WITH deltas AS (
    SELECT
        s.instance_id,
        e.snapshot_id,
        s.snapshot_time,
        e.database_name,
        e.schema_name,
        e.object_name,
        e.index_name,
        e.index_id,
        CASE WHEN e.index_id = 0 THEN 'Heap'
             WHEN e.index_id = 1 THEN 'Clustered Index'
             ELSE 'Nonclustered Index' END AS segment_type,
        e.user_seeks - LAG(e.user_seeks)
            OVER (PARTITION BY s.instance_id, e.database_name, e.object_name, e.index_id
                  ORDER BY e.snapshot_id) AS d_seeks,
        e.user_scans - LAG(e.user_scans)
            OVER (PARTITION BY s.instance_id, e.database_name, e.object_name, e.index_id
                  ORDER BY e.snapshot_id) AS d_scans,
        e.user_lookups - LAG(e.user_lookups)
            OVER (PARTITION BY s.instance_id, e.database_name, e.object_name, e.index_id
                  ORDER BY e.snapshot_id) AS d_lookups,
        e.leaf_insert_count - LAG(e.leaf_insert_count)
            OVER (PARTITION BY s.instance_id, e.database_name, e.object_name, e.index_id
                  ORDER BY e.snapshot_id) AS d_inserts,
        e.leaf_delete_count - LAG(e.leaf_delete_count)
            OVER (PARTITION BY s.instance_id, e.database_name, e.object_name, e.index_id
                  ORDER BY e.snapshot_id) AS d_deletes,
        e.leaf_update_count - LAG(e.leaf_update_count)
            OVER (PARTITION BY s.instance_id, e.database_name, e.object_name, e.index_id
                  ORDER BY e.snapshot_id) AS d_updates,
        e.page_io_latch_wait_in_ms - LAG(e.page_io_latch_wait_in_ms)
            OVER (PARTITION BY s.instance_id, e.database_name, e.object_name, e.index_id
                  ORDER BY e.snapshot_id) AS d_io_latch_ms,
        e.page_latch_wait_in_ms - LAG(e.page_latch_wait_in_ms)
            OVER (PARTITION BY s.instance_id, e.database_name, e.object_name, e.index_id
                  ORDER BY e.snapshot_id) AS d_latch_ms,
        e.row_lock_wait_in_ms - LAG(e.row_lock_wait_in_ms)
            OVER (PARTITION BY s.instance_id, e.database_name, e.object_name, e.index_id
                  ORDER BY e.snapshot_id) AS d_row_lock_ms,
        e.row_count,
        e.size_mb
    FROM mssql_index_usage_delta e
    JOIN mssql_dmv_snapshot s ON s.snapshot_id = e.snapshot_id
),
positive AS (
    SELECT instance_id, snapshot_id, snapshot_time, database_name, schema_name,
           object_name, index_name, segment_type,
           GREATEST(d_seeks, 0) AS seeks,
           GREATEST(d_scans, 0) AS scans,
           GREATEST(d_lookups, 0) AS lookups,
           GREATEST(d_inserts, 0) AS inserts,
           GREATEST(d_deletes, 0) AS deletes,
           GREATEST(d_updates, 0) AS updates,
           GREATEST(d_io_latch_ms, 0) AS io_latch_ms,
           GREATEST(d_latch_ms, 0) AS latch_ms,
           GREATEST(d_row_lock_ms, 0) AS row_lock_ms,
           row_count, size_mb
    FROM deltas
    -- LAG() returns NULL for each object/index's first-ever snapshot per
    -- instance -- excluded here (nothing to delta against), not shown as
    -- zero activity.
    WHERE d_seeks IS NOT NULL
)
SELECT
    instance_id, snapshot_id, snapshot_time, database_name,
    CASE WHEN schema_name IS NOT NULL THEN schema_name || '.' || object_name ELSE object_name END AS object_name,
    index_name, segment_type,
    seeks, scans, lookups, inserts, deletes, updates,
    (seeks + scans + lookups) AS read_operations,
    (inserts + deletes + updates) AS write_operations,
    io_latch_ms, latch_ms, row_lock_ms,
    row_count, size_mb,
    -- Same three-factor-weighted-sum shape as the other two MVs' severity
    -- scores: read+write operation volume dominates (60%), physical I/O
    -- wait next (30%), lock contention last (10%) -- matching the ranking
    -- priority the SQLWR report's own Segment Statistics sections already
    -- established (Logical/Physical Reads and Writes ranked ahead of Row
    -- Lock Waits and Buffer Busy Waits in that report's own section order).
    ROUND(
        ((seeks + scans + lookups + inserts + deletes + updates)::numeric / 100.0) * 0.6
        + (io_latch_ms / 1000.0) * 0.3
        + (row_lock_ms / 1000.0) * 0.1
    , 2) AS severity_score,
    ROW_NUMBER() OVER () AS mv_id
FROM positive
WHERE (seeks + scans + lookups + inserts + deletes + updates + io_latch_ms + latch_ms + row_lock_ms) > 0
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mssql_segment_summary_mv_id
    ON mssql_segment_summary_mv (mv_id) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_segment_summary_mv_inst_snap
    ON mssql_segment_summary_mv (instance_id, snapshot_id) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_segment_summary_mv_severity
    ON mssql_segment_summary_mv (instance_id, snapshot_id, severity_score DESC) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_segment_summary_mv_object
    ON mssql_segment_summary_mv (instance_id, database_name, object_name) TABLESPACE mssqlparser_idx;

\echo 'mssql_segment_summary_mv created.'
