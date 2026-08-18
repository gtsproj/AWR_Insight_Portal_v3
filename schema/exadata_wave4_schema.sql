-- =============================================================
-- exadata_wave4_schema.sql
-- Wave 4 Exadata tables — sections visible in real AWR reports
-- Missing from Waves 1-3 based on screenshot analysis
-- =============================================================

-- ── HIGH PRIORITY — dashboard time-series tables ─────────────

-- exadata8: OS I/O Summary (by disk type: F/6.2T flash, H/20.0T HDD)
CREATE TABLE IF NOT EXISTS awr_exadata_os_io_summary (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    instance        TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    disk_type       TEXT NOT NULL,   -- 'F/6.2T', 'H/20.0T', etc.
    n_cells         INTEGER,
    n_disks         INTEGER,
    total_iops      NUMERIC(18,2),   -- Total IOPs all disks
    iops_per_cell   NUMERIC(18,2),   -- Average IOPs per cell
    total_mbps      NUMERIC(12,2),
    mbps_per_cell   NUMERIC(12,2),
    service_time_ms NUMERIC(10,4),   -- Avg service time ms
    wait_time_ms    NUMERIC(10,4),   -- Avg wait time ms
    pct_disk_util   NUMERIC(8,2),    -- % disk utilisation
    row_hash        TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, instance, begin_snap, disk_type)
) tablespace awrparser;
CREATE INDEX IF NOT EXISTS idx_exa_os_io_snap ON awr_exadata_os_io_summary(dbname, begin_snap) tablespace awrparser_idx;

-- exadata8: Cell I/O Summary (small/large reads/writes breakdown per disk type)
CREATE TABLE IF NOT EXISTS awr_exadata_cell_io_summary (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    instance        TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    disk_type       TEXT NOT NULL,
    n_cells         INTEGER,
    n_disks         INTEGER,
    total_iops      NUMERIC(18,2),
    avg_iops_per_cell NUMERIC(18,2),
    small_reads_ps  NUMERIC(14,2),   -- Small read IOPs (OLTP)
    small_writes_ps NUMERIC(14,2),
    large_reads_ps  NUMERIC(14,2),   -- Large read IOPs (scans)
    large_writes_ps NUMERIC(14,2),
    total_mbps      NUMERIC(12,2),
    avg_mbps_per_cell NUMERIC(12,2),
    row_hash        TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, instance, begin_snap, disk_type)
) tablespace awrparser;
CREATE INDEX IF NOT EXISTS idx_exa_cell_io_snap ON awr_exadata_cell_io_summary(dbname, begin_snap) tablespace awrparser_idx;

-- exadata10: Single Block Reads (DB IOs, Flash/Disk/XRMEM distribution)
CREATE TABLE IF NOT EXISTS awr_exadata_single_block_reads (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    instance        TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    -- Database IOs section
    phys_read_total_io     INTEGER,   -- physical read total IO requests
    phys_read_io_reqs      INTEGER,   -- physical read IO requests
    fc_read_hits           INTEGER,   -- cell flash cache read hits
    xrmem_cache_hits       INTEGER,   -- cell xrmem cache read hits
    cell_rdma_reads        INTEGER,   -- cell RDMA reads
    phys_read_total_ps     NUMERIC(12,2),
    phys_read_io_reqs_ps   NUMERIC(12,2),
    fc_read_hits_ps        NUMERIC(12,2),
    xrmem_hits_ps          NUMERIC(12,2),
    rdma_reads_ps          NUMERIC(12,2),
    -- Small Reads Distribution
    pct_flash              NUMERIC(6,2),
    pct_disk               NUMERIC(6,2),
    pct_xrmem              NUMERIC(6,2),
    small_reads_flash_ps   NUMERIC(14,2),
    small_reads_disk_ps    NUMERIC(14,2),
    small_reads_xrmem_ps   NUMERIC(14,2),
    row_hash               TEXT,
    created_at             TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, instance, begin_snap)
) tablespace awrparser;
CREATE INDEX IF NOT EXISTS idx_exa_sbr_snap ON awr_exadata_single_block_reads(dbname, begin_snap) tablespace awrparser_idx;

-- exadata9: Flash Activity (I/O per second)
CREATE TABLE IF NOT EXISTS awr_exadata_flash_activity (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    instance        TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    -- All values are I/O per second (total across cells)
    flash_log_writes_ps    NUMERIC(14,2),
    flash_log_writes_total NUMERIC(18,2),   -- total count
    flash_log_writes_per_cell NUMERIC(14,2),
    fc_oltp_reads_ps       NUMERIC(14,2),   -- Flash Cache OLTP reads
    fc_oltp_reads_total    NUMERIC(18,2),
    fc_scan_reads_ps       NUMERIC(14,2),   -- Flash Cache scan reads
    fc_scan_reads_total    NUMERIC(18,2),
    columnar_reads_ps      NUMERIC(14,2),   -- Columnar Cache reads
    columnar_reads_total   NUMERIC(18,2),
    fc_user_writes_ps      NUMERIC(14,2),   -- Flash Cache user writes
    fc_user_writes_total   NUMERIC(18,2),
    disk_writer_reads_ps   NUMERIC(14,2),   -- Disk writer reads
    population_writes_ps   NUMERIC(14,2),   -- Population (cache fill) writes
    metadata_writes_ps     NUMERIC(14,2),
    row_hash               TEXT,
    created_at             TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, instance, begin_snap)
) tablespace awrparser;
CREATE INDEX IF NOT EXISTS idx_exa_fa_snap ON awr_exadata_flash_activity(dbname, begin_snap) tablespace awrparser_idx;

-- exadata9: Disk Activity (I/O per second — disk-destined IOs)
CREATE TABLE IF NOT EXISTS awr_exadata_disk_activity (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    instance        TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    redo_writes_ps         NUMERIC(14,2),   -- Redo log writes to disk
    redo_writes_total      NUMERIC(18,2),
    fc_miss_oltp_ps        NUMERIC(14,2),   -- Flash Cache misses (OLTP)
    fc_read_skips_ps       NUMERIC(14,2),   -- Flash Cache read skips
    fc_write_skips_ps      NUMERIC(14,2),   -- Flash Cache write skips
    fc_lw_rejections_ps    NUMERIC(14,2),   -- Large Write rejections (total)
    disk_writer_writes_ps  NUMERIC(14,2),   -- Disk writer writes
    scrub_io_ps            NUMERIC(14,2),   -- Scrub IO
    row_hash               TEXT,
    created_at             TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, instance, begin_snap)
) tablespace awrparser;
CREATE INDEX IF NOT EXISTS idx_exa_da_snap ON awr_exadata_disk_activity(dbname, begin_snap) tablespace awrparser_idx;

-- exadata11: Database IO Summary (per database row)
CREATE TABLE IF NOT EXISTS awr_exadata_db_io_summary (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    instance        TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    db_name_consumer TEXT NOT NULL,  -- The consumer DB name (may differ from dbname)
    small_io_reqs_ps    NUMERIC(14,2),
    pct_flash           NUMERIC(6,2),
    pct_disk            NUMERIC(6,2),
    flash_latency_us    NUMERIC(12,2),
    disk_latency_us     NUMERIC(12,2),
    flash_queue_time_us NUMERIC(12,2),
    disk_queue_time_us  NUMERIC(12,2),
    latency_per_sec_us  NUMERIC(12,2),
    row_hash            TEXT,
    created_at          TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, instance, begin_snap, db_name_consumer)
) tablespace awrparser;
CREATE INDEX IF NOT EXISTS idx_exa_dbio_snap ON awr_exadata_db_io_summary(dbname, begin_snap) tablespace awrparser_idx;

-- exadata11: Temp IO and Large Writes Summary
CREATE TABLE IF NOT EXISTS awr_exadata_temp_io_lw (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    instance        TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    large_writes_total_ps   NUMERIC(14,2),
    lw_temp_spill_ps        NUMERIC(14,2),
    lw_data_temp_ps         NUMERIC(14,2),
    lw_write_only_ps        NUMERIC(14,2),
    db_temp_io_hit_pct      NUMERIC(6,2),   -- Database Flash Cache Temp Write Hit%
    fc_lw_for_temp_total    NUMERIC(18,0),  -- Cell FC Large Writes for Temp total
    fc_lw_for_temp_ps       NUMERIC(14,2),
    row_hash                TEXT,
    created_at              TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, instance, begin_snap)
) tablespace awrparser;
CREATE INDEX IF NOT EXISTS idx_exa_tilw_snap ON awr_exadata_temp_io_lw(dbname, begin_snap) tablespace awrparser_idx;

-- ── MEDIUM PRIORITY — configuration / health tables ──────────

-- exadata5: Exadata Storage Information (summary per group of cells)
CREATE TABLE IF NOT EXISTS awr_exadata_storage_info (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    n_cells         INTEGER,
    flash_cache_gb  NUMERIC(12,2),
    xrmem_cache_gb  NUMERIC(12,2),
    flash_log_gb    NUMERIC(10,2),
    n_hard_disk     INTEGER,
    n_flash_disk    INTEGER,
    n_griddisks     INTEGER,
    n_celldisks     INTEGER,
    cell_list       TEXT,            -- comma-separated cell names
    row_hash        TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, begin_snap, n_cells)
) tablespace awrparser;

-- exadata6: ASM Diskgroups (capacity + state)
CREATE TABLE IF NOT EXISTS awr_exadata_asm_diskgroups (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    disk_group      TEXT NOT NULL,
    size_gb         NUMERIC(14,2),
    used_gb         NUMERIC(14,2),
    pct_used        NUMERIC(6,2),
    n_griddisks     INTEGER,
    redundancy      TEXT,            -- HIGH, NORMAL, EXTERNAL
    state           TEXT,            -- CONNECTED, DISMOUNTING, etc.
    row_hash        TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, begin_snap, disk_group)
) tablespace awrparser;
CREATE INDEX IF NOT EXISTS idx_exa_asm_snap ON awr_exadata_asm_diskgroups(dbname, begin_snap) tablespace awrparser_idx;

-- exadata6: IORM Objective (plan setting at begin/end of snapshot)
CREATE TABLE IF NOT EXISTS awr_exadata_iorm_objective (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    iorm_begin      TEXT,            -- auto, basic, high_throughput, manual
    iorm_end        TEXT,
    cells           TEXT,            -- 'All (N)'
    row_hash        TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, begin_snap)
) tablespace awrparser;

-- exadata6: Exadata Alerts Summary
CREATE TABLE IF NOT EXISTS awr_exadata_alerts (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    alert_count     INTEGER DEFAULT 0,
    has_open_alerts BOOLEAN DEFAULT FALSE,
    alert_text      TEXT,            -- full alert text or 'No open alerts.'
    row_hash        TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, begin_snap)
) tablespace awrparser;

-- exadata5: Exadata Griddisks (caching policy, disk types)
CREATE TABLE IF NOT EXISTS awr_exadata_griddisks (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    griddisk_prefix TEXT NOT NULL,
    caching_policy  TEXT,            -- default, none
    n_griddisks     INTEGER,
    n_cached_by     INTEGER,
    griddisk_size_gb NUMERIC(12,2),
    cell_total_gb   NUMERIC(14,2),
    system_total_gb NUMERIC(14,2),
    disk_type       TEXT,            -- H/20.0T, F/6.2T, etc.
    cells           TEXT,
    row_hash        TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, begin_snap, griddisk_prefix)
) tablespace awrparser;

-- exadata6: Exadata Celldisks (flash vs HDD summary)
CREATE TABLE IF NOT EXISTS awr_exadata_celldisks (
    id              SERIAL PRIMARY KEY,
    dbname          TEXT NOT NULL,
    begin_snap      INTEGER NOT NULL,
    snap_time       TIMESTAMP,
    disk_type       TEXT NOT NULL,   -- F/6.2T, H/20.0T, M-XRMEM
    celldisk_size_gb NUMERIC(12,2),
    n_celldisks     INTEGER,
    cells           TEXT,
    row_hash        TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(dbname, begin_snap, disk_type)
) tablespace awrparser;

