-- ============================================================
-- DAR Portal v3 — Exadata AWR Wave 2 Tables
-- Top Databases, Cell IO Statistics, IO Reasons,
-- Flash Cache Space, Cell Server Statistics
-- ============================================================
SET client_min_messages = WARNING;
SET search_path = public;

-- ── awr_exadata_top_db ────────────────────────────────────
CREATE TABLE IF NOT EXISTS awr_exadata_top_db (
    id                  SERIAL,
    dbname              TEXT        NOT NULL,
    instance            TEXT        NOT NULL,
    begin_snap          INTEGER,
    snap_time           TIMESTAMP   WITHOUT TIME ZONE,
    target_dbname       TEXT        NOT NULL,  -- database being reported (Global AWR: could differ)
    flash_req_pct       NUMERIC,               -- % IO requests from Flash Cache
    disk_req_pct        NUMERIC,               -- % IO requests from Hard Disk
    small_avg_lat_ms    NUMERIC,               -- avg latency for small IOs (ms)
    large_avg_lat_ms    NUMERIC,               -- avg latency for large IOs (ms)
    iorm_queue_ms       NUMERIC,               -- IORM queue time for large IOs (ms)
    total_req           BIGINT,                -- total IO request count
    flash_mb_pct        NUMERIC,               -- % IO MB from Flash
    disk_mb_pct         NUMERIC,               -- % IO MB from Disk
    row_hash            CHAR(32)    NOT NULL,
    created_at          TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_top_db_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_top_db UNIQUE (dbname, begin_snap, target_dbname, row_hash)
) TABLESPACE awrparser;

COMMENT ON TABLE awr_exadata_top_db IS
'Top Databases by IO Requests from Exadata AWR. Shows per-database IO distribution across '
'Flash Cache and Hard Disk, with average latencies and IORM queue times. '
'High iorm_queue_ms (>5ms) on large IOs indicates IORM resource contention.';

CREATE INDEX IF NOT EXISTS idx_exadata_top_db_snap
    ON awr_exadata_top_db (dbname, begin_snap) TABLESPACE awrparser_idx;
CREATE INDEX IF NOT EXISTS idx_exadata_top_db_iorm
    ON awr_exadata_top_db (dbname, begin_snap, iorm_queue_ms DESC) TABLESPACE awrparser_idx;


-- ── awr_exadata_cell_iostat ───────────────────────────────
CREATE TABLE IF NOT EXISTS awr_exadata_cell_iostat (
    id                  SERIAL,
    dbname              TEXT        NOT NULL,
    instance            TEXT        NOT NULL,
    begin_snap          INTEGER,
    snap_time           TIMESTAMP   WITHOUT TIME ZONE,
    cell_name           TEXT        NOT NULL,
    device_type         TEXT,                  -- 'Flash' or 'HardDisk' (with size suffix)
    iops                NUMERIC,               -- IO operations per second
    throughput_mbps     NUMERIC,               -- MB/s throughput
    util_pct            NUMERIC,               -- utilization %
    service_ms          NUMERIC,               -- average service time (ms)
    queue_ms            NUMERIC,               -- average queue time (ms)
    is_outlier          BOOLEAN DEFAULT false, -- marked as IO outlier vs peers
    at_max_capacity     BOOLEAN DEFAULT false, -- at maximum device capacity
    row_hash            CHAR(32)    NOT NULL,
    created_at          TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_cell_iostat_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_cell_iostat UNIQUE (dbname, begin_snap, cell_name, device_type, row_hash)
) TABLESPACE awrparser;

COMMENT ON TABLE awr_exadata_cell_iostat IS
'OS IO Statistics for Exadata storage cells from AWR Outlier Cells section. '
'is_outlier=TRUE means this cell is performing significantly more IO than its peers. '
'at_max_capacity=TRUE is a HIGH alert — the cell is throttling IOs.';

CREATE INDEX IF NOT EXISTS idx_exadata_cell_iostat_snap
    ON awr_exadata_cell_iostat (dbname, begin_snap) TABLESPACE awrparser_idx;
	
CREATE INDEX IF NOT EXISTS idx_exadata_cell_iostat_outlier
    ON awr_exadata_cell_iostat (dbname, is_outlier)  TABLESPACE awrparser_idx
    WHERE is_outlier = true;
CREATE INDEX IF NOT EXISTS idx_exadata_cell_iostat_maxcap
    ON awr_exadata_cell_iostat (dbname, at_max_capacity)  TABLESPACE awrparser_idx
    WHERE at_max_capacity = truec;


-- ── awr_exadata_io_reasons ────────────────────────────────
CREATE TABLE IF NOT EXISTS awr_exadata_io_reasons (
    id                  SERIAL,
    dbname              TEXT        NOT NULL,
    instance            TEXT        NOT NULL,
    begin_snap          INTEGER,
    snap_time           TIMESTAMP   WITHOUT TIME ZONE,
    cell_name           TEXT        NOT NULL,  -- 'All' for system aggregate
    reason              TEXT        NOT NULL,  -- Smart Scan | Redo | DBWR | Scrub | Internal IO | etc.
    small_req           BIGINT,                -- small IO request count
    large_req           BIGINT,                -- large IO request count
    total_req           BIGINT,                -- total requests
    small_mb            NUMERIC,               -- MB from small IOs
    large_mb            NUMERIC,               -- MB from large IOs
    total_mb            NUMERIC,               -- total MB
    pct_of_total_req    NUMERIC,               -- % of all cell requests
    row_hash            CHAR(32)    NOT NULL,
    created_at          TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_io_reasons_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_io_reasons UNIQUE (dbname, begin_snap, cell_name, reason, row_hash)
) TABLESPACE awrparser;

COMMENT ON TABLE awr_exadata_io_reasons IS
'IO Reasons breakdown from Exadata AWR — why IOs occur on storage cells. '
'reason = Smart Scan is the most valuable (Exadata value adds). '
'High Redo% = log-write intensive; High Internal IO% = maintenance activity.';

CREATE INDEX IF NOT EXISTS idx_exadata_io_reasons_snap
    ON awr_exadata_io_reasons (dbname, begin_snap) TABLESPACE awrparser_idx;
CREATE INDEX IF NOT EXISTS idx_exadata_io_reasons_reason
    ON awr_exadata_io_reasons (dbname, begin_snap, reason) TABLESPACE awrparser_idx;


-- ── awr_exadata_fc_space ──────────────────────────────────
CREATE TABLE IF NOT EXISTS awr_exadata_fc_space (
    id                  SERIAL,
    dbname              TEXT        NOT NULL,
    instance            TEXT        NOT NULL,
    begin_snap          INTEGER,
    snap_time           TIMESTAMP   WITHOUT TIME ZONE,
    cell_name           TEXT        NOT NULL,  -- 'All' or cell hostname
    total_fc_mb         NUMERIC,               -- total Flash Cache size (MB)
    oltp_used_mb        NUMERIC,               -- MB used for OLTP reads
    scan_used_mb        NUMERIC,               -- MB used for Smart Scan reads
    large_write_mb      NUMERIC,               -- MB used for Large Writes (temp/direct)
    large_write_pct     NUMERIC,               -- large_write_mb / total_fc_mb * 100
    free_mb             NUMERIC,               -- free Flash Cache space
    row_hash            CHAR(32)    NOT NULL,
    created_at          TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_fc_space_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_fc_space UNIQUE (dbname, begin_snap, cell_name, row_hash)
) TABLESPACE awrparser;

COMMENT ON TABLE awr_exadata_fc_space IS
'Flash Cache space usage per cell from Exadata AWR. '
'large_write_pct > 15% = Global Limit pressure; > 20% = HIGH alert. '
'Large writes come from PGA spills (temp), direct-path inserts, and DBWR. '
'When large_write_pct is high, OLTP and Scan data are being evicted.';

CREATE INDEX IF NOT EXISTS idx_exadata_fc_space_snap
    ON awr_exadata_fc_space (dbname, begin_snap) TABLESPACE awrparser_idx;
CREATE INDEX IF NOT EXISTS idx_exadata_fc_space_lw
    ON awr_exadata_fc_space (dbname, begin_snap, large_write_pct DESC) TABLESPACE awrparser_idx;


-- ── awr_exadata_cell_server ───────────────────────────────
CREATE TABLE IF NOT EXISTS awr_exadata_cell_server (
    id                  SERIAL,
    dbname              TEXT        NOT NULL,
    instance            TEXT        NOT NULL,
    begin_snap          INTEGER,
    snap_time           TIMESTAMP   WITHOUT TIME ZONE,
    cell_name           TEXT        NOT NULL,
    small_read_iops     NUMERIC,               -- small read IO/s
    small_write_iops    NUMERIC,               -- small write IO/s
    large_read_iops     NUMERIC,               -- large read IO/s
    large_write_iops    NUMERIC,               -- large write IO/s
    small_read_mbps     NUMERIC,               -- small read MB/s
    small_write_mbps    NUMERIC,               -- small write MB/s
    large_read_mbps     NUMERIC,               -- large read MB/s
    large_write_mbps    NUMERIC,               -- large write MB/s
    total_iops          NUMERIC,               -- derived: sum of all iops
    large_write_pct_iops NUMERIC,              -- large_write_iops/total_iops*100
    row_hash            CHAR(32)    NOT NULL,
    created_at          TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_cell_server_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_cell_server UNIQUE (dbname, begin_snap, cell_name, row_hash)
) TABLESPACE awrparser;

COMMENT ON TABLE awr_exadata_cell_server IS
'Cell Server IO statistics per cell from Exadata AWR. '
'Breaks down IO into small/large read/write for each cell. '
'High large_write_pct_iops signals temp spill pressure or checkpoint storm. '
'Cross-cell imbalance (one cell doing 2x others) indicates uneven data distribution.';

CREATE INDEX IF NOT EXISTS idx_exadata_cell_server_snap
    ON awr_exadata_cell_server (dbname, begin_snap) TABLESPACE awrparser_idx;

\echo 'Exadata Wave 2 schema: awr_exadata_top_db, awr_exadata_cell_iostat, awr_exadata_io_reasons, awr_exadata_fc_space, awr_exadata_cell_server'

