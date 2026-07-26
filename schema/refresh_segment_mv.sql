-- ============================================================
-- Refresh awr_segment_summary_mv after schema fix
-- ============================================================
-- The MV was rebuilt to fix a bug where all 16 CTEs (physical_reads,
-- table_scans, buffer_busy_waits, etc.) were missing owner/object_name/
-- subobject_name in their GROUP BY. This caused all objects to show
-- identical values (the AVG across ALL objects for that snap).
--
-- This script:
--   1. Drops the old MV
--   2. Recreates it with the correct object-level GROUP BY and SUM
--   3. Recreates its indexes
--
-- Run as: psql -U awr_owner -d postgres -f schema/refresh_segment_mv.sql
-- ============================================================

\echo 'Dropping old awr_segment_summary_mv...'
DROP MATERIALIZED VIEW IF EXISTS awr_segment_summary_mv CASCADE;

\echo 'Recreating awr_segment_summary_mv with object-level GROUP BY...'
\i schema/awr_master_schema_v2 (4).sql

\echo ''
\echo 'Done. Verifying row count:'
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT owner || '.' || object_name) AS distinct_objects,
       COUNT(DISTINCT dbname) AS databases
FROM awr_segment_summary_mv;

\echo ''
\echo 'Sample — verify different values per object for physical_reads:'
SELECT owner, object_name, obj_type, begin_snap,
       physical_reads, logical_reads, table_scans, buffer_busy_waits
FROM awr_segment_summary_mv
WHERE physical_reads > 0
ORDER BY physical_reads DESC
LIMIT 10;
