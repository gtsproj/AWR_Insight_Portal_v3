-- ============================================================
-- Extend mssql_index_usage_delta with additional
-- sys.dm_db_index_operational_stats columns, plus current size --
-- prompted by reference queries Ganesh shared for a richer Segment
-- Statistics breakdown (separate "Segments by..." views matching
-- Oracle AWR's own multi-section structure: logical reads, physical
-- reads, writes, table scans, row lock waits, buffer busy waits).
--
-- range_scan_count/singleton_lookup_count: a more granular read
-- breakdown than user_seeks/scans/lookups alone (range vs point
-- lookups specifically, from the operational stats DMV rather than
-- the usage-stats DMV).
-- page_lock_wait_count/page_lock_wait_in_ms: row/page-level LOCK
-- waits -- distinct from page_latch_wait_* (in-memory latching, no
-- lock manager involved) already collected.
-- leaf_page_merge_count: page-merge operations from leaf-level
-- deletes, a B-tree maintenance signal.
-- row_count/size_mb: current size at the END snapshot -- unlike
-- every other column here, this is NOT delta'd (it's "how big is
-- this object right now", not an activity count), captured directly
-- from sys.dm_db_partition_stats rather than computed from two
-- snapshots' difference.
-- ============================================================

ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS range_scan_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS singleton_lookup_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS page_lock_wait_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS page_lock_wait_in_ms BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS leaf_page_merge_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS row_count BIGINT;
ALTER TABLE mssql_index_usage_delta ADD COLUMN IF NOT EXISTS size_mb NUMERIC;

\echo 'mssql_index_usage_delta extended with additional operational-stats columns and current size.'
