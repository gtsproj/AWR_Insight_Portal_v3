-- ============================================================
-- Fix and refresh awr_segment_summary_mv
-- Safe approach — works even when dependent objects exist
-- ============================================================
-- The MV had a bug: 16 CTEs (physical_reads, table_scans etc.)
-- were missing owner/object_name in GROUP BY, causing all objects
-- to show identical values. AVG() was used instead of SUM().
--
-- This script fixes it WITHOUT dropping the MV:
--   1. Find dependent objects (indexes, other MVs, views)
--   2. Save their definitions
--   3. Drop dependents first
--   4. Drop and recreate the MV
--   5. Recreate dependents
--
-- Usage:
--   psql -U awr_owner -d postgres -f schema/refresh_segment_mv.sql
-- ============================================================

SET client_min_messages = WARNING;

\echo '============================================================'
\echo 'Step 1: Check dependent objects'
\echo '============================================================'

SELECT
    dependent.relname AS dependent_object,
    dependent.relkind AS kind,
    pg_get_viewdef(dependent.oid) AS definition
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class dependent ON dependent.oid = r.ev_class
JOIN pg_class source ON source.oid = d.refobjid
WHERE source.relname = 'awr_segment_summary_mv'
  AND dependent.relname != 'awr_segment_summary_mv'
  AND d.deptype = 'n';

\echo ''
\echo '============================================================'
\echo 'Step 2: Save dependent MV/view definitions to temp table'
\echo '============================================================'

CREATE TEMP TABLE _dep_defs AS
SELECT
    dependent.relname AS obj_name,
    dependent.relkind AS obj_kind,
    pg_get_viewdef(dependent.oid) AS obj_def,
    t.spcname AS tablespace_name
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class dependent ON dependent.oid = r.ev_class
JOIN pg_namespace n ON n.oid = dependent.relnamespace
JOIN pg_class source ON source.oid = d.refobjid
LEFT JOIN pg_tablespace t ON t.oid = dependent.reltablespace
WHERE source.relname = 'awr_segment_summary_mv'
  AND dependent.relname != 'awr_segment_summary_mv'
  AND n.nspname = 'public';

SELECT obj_name, obj_kind FROM _dep_defs;

\echo ''
\echo '============================================================'
\echo 'Step 3: Drop dependent objects'
\echo '============================================================'

DO $$
DECLARE
    obj RECORD;
BEGIN
    FOR obj IN SELECT obj_name, obj_kind FROM _dep_defs LOOP
        IF obj.obj_kind = 'm' THEN
            EXECUTE 'DROP MATERIALIZED VIEW IF EXISTS ' || obj.obj_name || ' CASCADE';
            RAISE NOTICE 'Dropped MV: %', obj.obj_name;
        ELSIF obj.obj_kind = 'v' THEN
            EXECUTE 'DROP VIEW IF EXISTS ' || obj.obj_name || ' CASCADE';
            RAISE NOTICE 'Dropped view: %', obj.obj_name;
        END IF;
    END LOOP;
END $$;

\echo ''
\echo '============================================================'
\echo 'Step 4: Drop and recreate awr_segment_summary_mv'
\echo '============================================================'

DROP MATERIALIZED VIEW IF EXISTS awr_segment_summary_mv;

CREATE MATERIALIZED VIEW IF NOT EXISTS awr_segment_summary_mv
TABLESPACE awrparser
AS
 WITH logical_reads AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                min(t.snap_time) AS snap_time,
                t.tablespace_name, t.obj_type, t.owner,
                t.object_name, t.subobject_name,
                sum(t.logical_reads) AS logical_reads
           FROM awr_seg_logical_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.tablespace_name, t.obj_type, t.owner,
                   t.object_name, t.subobject_name
        ),
        physical_reads AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.physical_reads) AS physical_reads
           FROM awr_seg_phy_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        physical_writes AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.physical_writes) AS physical_writes
           FROM awr_seg_phy_writes t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        direct_reads AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.direct_reads) AS direct_reads
           FROM awr_seg_direct_phy_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        direct_writes AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.direct_writes) AS direct_writes
           FROM awr_seg_direct_phy_writes t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        read_req AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.phys_read_requests) AS phys_read_requests
           FROM awr_seg_phy_read_req t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        write_req AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.phys_write_requests) AS phys_write_requests
           FROM awr_seg_phy_write_req t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        cr_blocks AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.cr_blocks_received) AS cr_blocks_received
           FROM awr_seg_cr_blk_rec t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        cur_blocks AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.current_blocks_received) AS current_blocks_received
           FROM awr_seg_cur_blk_rec t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        unopt_reads AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.unoptimized_reads) AS unoptimized_reads
           FROM awr_seg_unopt_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        opt_reads AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.optimized_reads) AS optimized_reads
           FROM awr_seg_opt_reads t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        table_scans AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.table_scans) AS table_scans
           FROM awr_seg_table_scan t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        db_block_changes AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.db_block_changes) AS db_block_changes
           FROM awr_seg_db_blk_chg t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        row_lock AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.row_lock_waits) AS row_lock_waits
           FROM awr_seg_row_lck_waits t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        itl AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.itl_waits) AS itl_waits
           FROM awr_seg_itl_waits t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        buff_busy AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.buffer_busy_waits) AS buffer_busy_waits
           FROM awr_seg_buff_busy_waits t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        ),
        gc_busy AS (
         SELECT t.dbname, t.instance, t.begin_snap,
                t.owner, t.object_name, t.subobject_name, t.obj_type,
                sum(t.gc_buffer_busy) AS gc_buffer_busy
           FROM awr_seg_gbl_cache_buff_busy t
          GROUP BY t.dbname, t.instance, t.begin_snap,
                   t.owner, t.object_name, t.subobject_name, t.obj_type
        )
 SELECT l.dbname, l.instance, l.begin_snap, l.snap_time,
        l.tablespace_name, l.owner, l.obj_type, l.object_name, l.subobject_name,
        l.logical_reads,
        pr.physical_reads, pw.physical_writes,
        dr.direct_reads, dw.direct_writes,
        rr.phys_read_requests, wr.phys_write_requests,
        cb.cr_blocks_received, cur.current_blocks_received,
        un.unoptimized_reads, opt.optimized_reads,
        ts.table_scans, dbc.db_block_changes,
        rl.row_lock_waits, it.itl_waits, bb.buffer_busy_waits,
        gc.gc_buffer_busy,
        (COALESCE(pr.physical_reads,      0::numeric) * 0.15
       + (COALESCE(dr.direct_reads,       0::numeric)
        + COALESCE(dw.direct_writes,      0::numeric)) * 0.10
       + COALESCE(l.logical_reads,        0::numeric) * 0.10
       + (COALESCE(cb.cr_blocks_received, 0::numeric)
        + COALESCE(cur.current_blocks_received, 0::numeric)) * 0.10
       + COALESCE(ts.table_scans,         0::numeric) * 0.05
       + COALESCE(un.unoptimized_reads,   0::numeric) * 0.05
       + (COALESCE(rr.phys_read_requests, 0::numeric)
        + COALESCE(wr.phys_write_requests,0::numeric)) * 0.03
       + COALESCE(opt.optimized_reads,    0::numeric) * 0.02
       + COALESCE(dbc.db_block_changes,   0::numeric) * 0.10
       + COALESCE(rl.row_lock_waits,      0::numeric) * 0.10
       + COALESCE(it.itl_waits,           0::numeric) * 0.05
       + COALESCE(bb.buffer_busy_waits,   0::numeric) * 0.10
       + COALESCE(gc.gc_buffer_busy,      0::numeric) * 0.05
        )::numeric(18,4) AS severity_score,
        row_number() OVER () AS mv_id
   FROM logical_reads l
     LEFT JOIN physical_reads   pr  ON pr.dbname=l.dbname  AND pr.instance=l.instance  AND pr.begin_snap=l.begin_snap  AND pr.owner=l.owner  AND pr.object_name=l.object_name  AND pr.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN physical_writes  pw  ON pw.dbname=l.dbname  AND pw.instance=l.instance  AND pw.begin_snap=l.begin_snap  AND pw.owner=l.owner  AND pw.object_name=l.object_name  AND pw.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN direct_reads     dr  ON dr.dbname=l.dbname  AND dr.instance=l.instance  AND dr.begin_snap=l.begin_snap  AND dr.owner=l.owner  AND dr.object_name=l.object_name  AND dr.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN direct_writes    dw  ON dw.dbname=l.dbname  AND dw.instance=l.instance  AND dw.begin_snap=l.begin_snap  AND dw.owner=l.owner  AND dw.object_name=l.object_name  AND dw.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN read_req         rr  ON rr.dbname=l.dbname  AND rr.instance=l.instance  AND rr.begin_snap=l.begin_snap  AND rr.owner=l.owner  AND rr.object_name=l.object_name  AND rr.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN write_req        wr  ON wr.dbname=l.dbname  AND wr.instance=l.instance  AND wr.begin_snap=l.begin_snap  AND wr.owner=l.owner  AND wr.object_name=l.object_name  AND wr.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN cr_blocks        cb  ON cb.dbname=l.dbname  AND cb.instance=l.instance  AND cb.begin_snap=l.begin_snap  AND cb.owner=l.owner  AND cb.object_name=l.object_name  AND cb.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN cur_blocks       cur ON cur.dbname=l.dbname AND cur.instance=l.instance AND cur.begin_snap=l.begin_snap AND cur.owner=l.owner AND cur.object_name=l.object_name AND cur.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN unopt_reads      un  ON un.dbname=l.dbname  AND un.instance=l.instance  AND un.begin_snap=l.begin_snap  AND un.owner=l.owner  AND un.object_name=l.object_name  AND un.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN opt_reads        opt ON opt.dbname=l.dbname AND opt.instance=l.instance AND opt.begin_snap=l.begin_snap AND opt.owner=l.owner AND opt.object_name=l.object_name AND opt.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN table_scans      ts  ON ts.dbname=l.dbname  AND ts.instance=l.instance  AND ts.begin_snap=l.begin_snap  AND ts.owner=l.owner  AND ts.object_name=l.object_name  AND ts.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN db_block_changes dbc ON dbc.dbname=l.dbname AND dbc.instance=l.instance AND dbc.begin_snap=l.begin_snap AND dbc.owner=l.owner AND dbc.object_name=l.object_name AND dbc.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN row_lock         rl  ON rl.dbname=l.dbname  AND rl.instance=l.instance  AND rl.begin_snap=l.begin_snap  AND rl.owner=l.owner  AND rl.object_name=l.object_name  AND rl.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN itl              it  ON it.dbname=l.dbname  AND it.instance=l.instance  AND it.begin_snap=l.begin_snap  AND it.owner=l.owner  AND it.object_name=l.object_name  AND it.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN buff_busy        bb  ON bb.dbname=l.dbname  AND bb.instance=l.instance  AND bb.begin_snap=l.begin_snap  AND bb.owner=l.owner  AND bb.object_name=l.object_name  AND bb.subobject_name IS NOT DISTINCT FROM l.subobject_name
     LEFT JOIN gc_busy          gc  ON gc.dbname=l.dbname  AND gc.instance=l.instance  AND gc.begin_snap=l.begin_snap  AND gc.owner=l.owner  AND gc.object_name=l.object_name  AND gc.subobject_name IS NOT DISTINCT FROM l.subobject_name
WITH DATA;

-- Recreate indexes on the MV
CREATE INDEX IF NOT EXISTS idx_seg_summary_mv_dbname_snap
    ON awr_segment_summary_mv (dbname, instance, begin_snap) TABLESPACE awrparser_idx;

CREATE INDEX IF NOT EXISTS idx_seg_summary_mv_owner_object
    ON awr_segment_summary_mv (dbname, owner, object_name) TABLESPACE awrparser_idx;

CREATE INDEX IF NOT EXISTS idx_seg_summary_mv_severity
    ON awr_segment_summary_mv (dbname, instance, begin_snap, severity_score DESC) TABLESPACE awrparser_idx;

\echo ''
\echo '============================================================'
\echo 'Step 5: Recreate dependent objects'
\echo '============================================================'

DO $$
DECLARE
    obj RECORD;
    ts_clause TEXT;
BEGIN
    FOR obj IN SELECT obj_name, obj_kind, obj_def, tablespace_name
               FROM _dep_defs
               ORDER BY obj_kind DESC  -- views before MVs (in case of chained deps)
    LOOP
        ts_clause := CASE WHEN obj.tablespace_name IS NOT NULL
                          THEN E'\nTABLESPACE ' || obj.tablespace_name
                          ELSE '' END;
        IF obj.obj_kind = 'm' THEN
            EXECUTE 'CREATE MATERIALIZED VIEW IF NOT EXISTS ' || obj.obj_name
                 || ts_clause || E'\nAS\n' || obj.obj_def || E'\nWITH DATA';
            RAISE NOTICE 'Recreated MV: %', obj.obj_name;
        ELSIF obj.obj_kind = 'v' THEN
            EXECUTE 'CREATE OR REPLACE VIEW ' || obj.obj_name
                 || E'\nAS\n' || obj.obj_def;
            RAISE NOTICE 'Recreated view: %', obj.obj_name;
        END IF;
    END LOOP;
END $$;

\echo ''
\echo '============================================================'
\echo 'Step 6: Verify'
\echo '============================================================'

SELECT
  COUNT(*)                                        AS total_rows,
  COUNT(DISTINCT owner || '.' || object_name)     AS distinct_objects,
  COUNT(DISTINCT dbname)                          AS databases,
  COUNT(CASE WHEN physical_reads > 0 THEN 1 END)  AS rows_with_phys_reads,
  COUNT(CASE WHEN table_scans > 0 THEN 1 END)     AS rows_with_table_scans,
  COUNT(CASE WHEN buffer_busy_waits > 0 THEN 1 END) AS rows_with_buf_busy
FROM awr_segment_summary_mv;

\echo ''
\echo 'Sample — top 10 objects by physical_reads:'
SELECT owner, object_name, obj_type, begin_snap,
       physical_reads, logical_reads, table_scans,
       buffer_busy_waits, row_lock_waits, severity_score
FROM awr_segment_summary_mv
ORDER BY physical_reads DESC NULLS LAST
LIMIT 10;

\echo ''
\echo 'Done. awr_segment_summary_mv rebuilt with object-level GROUP BY.'
