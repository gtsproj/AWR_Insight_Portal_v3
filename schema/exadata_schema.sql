-- ============================================================
-- DAR Portal v3 — Exadata AWR Statistics Tables
-- Wave 1: Flash Cache Config, Performance Summary,
--         Smart IO, Flash Cache User Reads
-- ============================================================
--
-- Run AFTER install_fresh.sql (depends on awrparser tablespace).
-- Safe to re-run: all statements use IF NOT EXISTS / DO NOTHING.
--
-- Applies to:
--   Oracle Database on Exadata X-Series hardware (on-premises,
--   ExaDB-D, or ExaDB-C@C).
--   Sections are present in AWR Instance and AWR Global reports
--   (HTML/Active-HTML format only).  They are absent in:
--   • text-format AWR reports
--   • PDB-level AWR reports
--   Non-Exadata AWR reports simply produce 0 rows here.
-- ============================================================

SET client_min_messages = WARNING;
SET search_path = public;


-- ============================================================
-- Table: awr_exadata_fc_config
-- Source : Flash Cache Configuration section of Exadata AWR
-- Purpose: Per-storage-cell Flash Cache status.
--          CRITICAL signal: is_flushing = TRUE means that cell's
--          Flash Cache is not serving client IOs — all reads are
--          redirected to hard disk.
-- ============================================================
CREATE TABLE IF NOT EXISTS awr_exadata_fc_config (
    id              SERIAL,
    dbname          TEXT        NOT NULL,
    instance        TEXT        NOT NULL,
    begin_snap      INTEGER,
    snap_time       TIMESTAMP   WITHOUT TIME ZONE,
    cell_name       TEXT        NOT NULL,   -- e.g. celadm01 or 'All'
    fc_status       TEXT,                  -- normal | normal-flushing | etc.
    fc_size_gb      NUMERIC,               -- Flash Cache size in GB
    fl_size_mb      NUMERIC,               -- Flash Log size in MB (NULL = no FL)
    is_flushing     BOOLEAN     DEFAULT false,  -- derived: 'flushing' in status
    row_hash        CHAR(32)    NOT NULL,
    created_at      TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_fc_config_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_fc_config
        UNIQUE (dbname, begin_snap, cell_name, row_hash)
) TABLESPACE awrparser;

COMMENT ON TABLE awr_exadata_fc_config IS
'Per-cell Exadata Flash Cache configuration and status from AWR reports. '
'is_flushing=TRUE is a CRITICAL condition: Flash Cache is actively flushing '
'to disk and IOs on that cell are redirected to hard disk, causing severe latency.';

CREATE INDEX IF NOT EXISTS idx_exadata_fc_config_snap
    ON awr_exadata_fc_config (dbname, begin_snap) TABLESPACE awrparser_idx;

CREATE INDEX IF NOT EXISTS idx_exadata_fc_config_flushing
    ON awr_exadata_fc_config (dbname, is_flushing) TABLESPACE awrparser_idx
    WHERE is_flushing = true ;


-- ============================================================
-- Table: awr_exadata_perf_summary
-- Source : Exadata Performance Summary section (Cache Savings
--          sub-section and Disk Activity sub-section)
-- Purpose: System-level cache efficiency metrics.
--          One row per snap = system-wide aggregate.
-- ============================================================
CREATE TABLE IF NOT EXISTS awr_exadata_perf_summary (
    id                      SERIAL,
    dbname                  TEXT        NOT NULL,
    instance                TEXT        NOT NULL,
    begin_snap              INTEGER,
    snap_time               TIMESTAMP   WITHOUT TIME ZONE,
    -- Cache Savings
    fc_pct_of_db_ios        NUMERIC,   -- % DB IOs from Flash Cache
    xrmem_pct_of_db_ios     NUMERIC,   -- % DB IOs from XRMEM Cache
    rdma_pct_of_db_ios      NUMERIC,   -- % DB IOs via RDMA (subset of XRMEM)
    fc_hit_oltp_pct         NUMERIC,   -- Flash Cache hit% for OLTP reads
    fc_hit_scan_pct         NUMERIC,   -- Flash Cache hit% for Scan reads
    -- Disk Activity
    fc_read_skip_count      BIGINT,    -- Flash Cache read skips (reads bypassing FC)
    fc_write_skip_count     BIGINT,    -- Flash Cache write skips
    scrub_io_mbps           NUMERIC,   -- Disk scrub IO MB/s (expected on idle disk)
    fc_read_miss_count      BIGINT,    -- Flash Cache read misses (went to disk)
    row_hash                CHAR(32)   NOT NULL,
    created_at              TIMESTAMP  WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_perf_summary_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_perf_summary
        UNIQUE (dbname, begin_snap, row_hash)
) TABLESPACE awrparser;

COMMENT ON TABLE awr_exadata_perf_summary IS
'System-level Exadata cache efficiency from AWR Performance Summary section. '
'fc_pct_of_db_ios + xrmem_pct_of_db_ios describe where DB IOs are served from. '
'Low hit% or high skip counts indicate cache pressure or misconfiguration.';

CREATE INDEX IF NOT EXISTS idx_exadata_perf_summary_snap
    ON awr_exadata_perf_summary (dbname, begin_snap) TABLESPACE awrparser_idx;


-- ============================================================
-- Table: awr_exadata_smart_io
-- Source : Exadata Smart IO section of AWR
-- Purpose: Per-cell Smart Scan efficiency.
--          Flash vs disk split, Storage Index savings,
--          passthru rate, columnar cache usage.
--          cell_name = 'All' is the system aggregate row.
-- ============================================================
CREATE TABLE IF NOT EXISTS awr_exadata_smart_io (
    id                  SERIAL,
    dbname              TEXT        NOT NULL,
    instance            TEXT        NOT NULL,
    begin_snap          INTEGER,
    snap_time           TIMESTAMP   WITHOUT TIME ZONE,
    cell_name           TEXT        NOT NULL,   -- 'All' or cell hostname
    eligible_mbps       NUMERIC,    -- MB/s eligible for Smart Scan offload
    si_savings_mbps     NUMERIC,    -- MB/s saved by Storage Index elimination
    flash_read_mbps     NUMERIC,    -- MB/s satisfied from Flash Cache (Smart Scan)
    disk_read_mbps      NUMERIC,    -- MB/s read from hard disk (Smart Scan)
    passthru_mbps       NUMERIC,    -- MB/s in passthru (not offloaded)
    col_cache_mbps      NUMERIC,    -- MB/s from Columnar Cache
    reverse_offload_mbps NUMERIC,   -- MB/s in reverse offload mode
    passthru_pct        NUMERIC,    -- passthru_mbps / eligible_mbps * 100
    disk_pct            NUMERIC,    -- disk_read_mbps / eligible_mbps * 100
    row_hash            CHAR(32)    NOT NULL,
    created_at          TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_smart_io_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_smart_io
        UNIQUE (dbname, begin_snap, cell_name, row_hash)
) TABLESPACE awrparser;

COMMENT ON TABLE awr_exadata_smart_io IS
'Per-cell Exadata Smart IO statistics from AWR. '
'passthru_pct > 15% is a HIGH alert — smart scans are not offloading. '
'disk_pct > 40% means most scans are hitting hard disk, not Flash Cache. '
'Outlier cells (diff from peers) indicate cell-level Flash Cache issues.';

CREATE INDEX IF NOT EXISTS idx_exadata_smart_io_snap
    ON awr_exadata_smart_io (dbname, begin_snap) TABLESPACE awrparser_idx;

CREATE INDEX IF NOT EXISTS idx_exadata_smart_io_passthru
    ON awr_exadata_smart_io (dbname, begin_snap, passthru_pct DESC) TABLESPACE awrparser_idx
    WHERE passthru_pct IS NOT NULL ;


-- ============================================================
-- Table: awr_exadata_fc_reads
-- Source : Flash Cache User Reads Per Second +
--          Flash Cache User Reads Efficiency sections of AWR
-- Purpose: Per-cell Flash Cache read performance.
--          io_type = 'OLTP' or 'Scan' (or 'Total' for aggregated).
-- ============================================================
CREATE TABLE IF NOT EXISTS awr_exadata_fc_reads (
    id              SERIAL,
    dbname          TEXT        NOT NULL,
    instance        TEXT        NOT NULL,
    begin_snap      INTEGER,
    snap_time       TIMESTAMP   WITHOUT TIME ZONE,
    cell_name       TEXT        NOT NULL,   -- cell hostname or 'All'
    io_type         TEXT        NOT NULL,   -- OLTP | Scan | Total
    req_per_sec     NUMERIC,    -- read requests per second to Flash Cache
    miss_per_sec    NUMERIC,    -- cache miss rate (requests going to disk/XRMEM)
    hit_pct         NUMERIC,    -- Flash Cache hit percentage
    skip_count      BIGINT,     -- reads that bypassed Flash Cache entirely
    row_hash        CHAR(32)    NOT NULL,
    created_at      TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_fc_reads_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_fc_reads
        UNIQUE (dbname, begin_snap, cell_name, io_type, row_hash)
) TABLESPACE awrparser;

COMMENT ON TABLE awr_exadata_fc_reads IS
'Per-cell Exadata Flash Cache read performance from AWR. '
'hit_pct < 80% for OLTP or < 70% for Scan = HIGH alert. '
'Cells with lower hit_pct than peers indicate Flash Cache flushing or '
'size/configuration differences across cells.';

CREATE INDEX IF NOT EXISTS idx_exadata_fc_reads_snap
    ON awr_exadata_fc_reads (dbname, begin_snap) TABLESPACE awrparser_idx;

CREATE INDEX IF NOT EXISTS idx_exadata_fc_reads_hit
    ON awr_exadata_fc_reads (dbname, begin_snap, io_type, hit_pct) TABLESPACE awrparser_idx;


-- ============================================================
-- END OF FILE
-- ============================================================
\echo 'Exadata Wave 1 schema created: awr_exadata_fc_config, awr_exadata_perf_summary, awr_exadata_smart_io, awr_exadata_fc_reads'
