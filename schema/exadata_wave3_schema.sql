-- ============================================================
-- DAR Portal v3 — Exadata AWR Wave 3 Tables
-- FC Writes, FC Write Rejections, Exadata Config,
-- Disk IOStat, FC Internal Reads/Writes
-- ============================================================
SET client_min_messages = WARNING;
SET search_path = public;

-- awr_exadata_fc_writes
CREATE TABLE IF NOT EXISTS awr_exadata_fc_writes (
    id                SERIAL,
    dbname            TEXT        NOT NULL,
    instance          TEXT        NOT NULL,
    begin_snap        INTEGER,
    snap_time         TIMESTAMP   WITHOUT TIME ZONE,
    cell_name         TEXT        NOT NULL,
    write_section     TEXT        NOT NULL,
    total_write_reqs  BIGINT,
    partial_writes    BIGINT,
    absorbed_writes   BIGINT,
    rejected_writes   BIGINT,
    partial_write_pct NUMERIC,
    large_write_count BIGINT,
    large_write_type  TEXT,
    skip_count        BIGINT,
    skip_reason       TEXT,
    row_hash          CHAR(32)    NOT NULL,
    created_at        TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_fc_writes_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_fc_writes UNIQUE (dbname, begin_snap, cell_name, write_section, row_hash)
) TABLESPACE awrparser;
COMMENT ON TABLE awr_exadata_fc_writes IS 'Flash Cache User Write stats — normal writes, large writes (temp spills/direct path), write skips. High rejected_writes means Global Limit hit.';
CREATE INDEX IF NOT EXISTS idx_exadata_fc_writes_snap ON awr_exadata_fc_writes (dbname, begin_snap) TABLESPACE awrparser_idx;
CREATE INDEX IF NOT EXISTS idx_exadata_fc_writes_rejects ON awr_exadata_fc_writes (dbname, begin_snap, rejected_writes DESC) TABLESPACE awrparser_idx WHERE rejected_writes IS NOT NULL;

-- awr_exadata_fc_write_reject
CREATE TABLE IF NOT EXISTS awr_exadata_fc_write_reject (
    id               SERIAL,
    dbname           TEXT        NOT NULL,
    instance         TEXT        NOT NULL,
    begin_snap       INTEGER,
    snap_time        TIMESTAMP   WITHOUT TIME ZONE,
    cell_name        TEXT        NOT NULL,
    reason           TEXT        NOT NULL,
    rejection_count  BIGINT,
    rejection_pct    NUMERIC,
    row_hash         CHAR(32)    NOT NULL,
    created_at       TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_fc_write_reject_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_fc_write_reject UNIQUE (dbname, begin_snap, cell_name, reason, row_hash)
) TABLESPACE awrparser;
COMMENT ON TABLE awr_exadata_fc_write_reject IS 'Flash Cache Large Write Rejection reasons. reason=Global Limit means FC large-write space ceiling was hit — direct-path/temp writes go to disk.';
CREATE INDEX IF NOT EXISTS idx_exadata_fc_write_reject_snap ON awr_exadata_fc_write_reject (dbname, begin_snap) TABLESPACE awrparser_idx;

-- awr_exadata_config
CREATE TABLE IF NOT EXISTS awr_exadata_config (
    id               SERIAL,
    dbname           TEXT        NOT NULL,
    instance         TEXT        NOT NULL,
    begin_snap       INTEGER,
    snap_time        TIMESTAMP   WITHOUT TIME ZONE,
    cell_name        TEXT        NOT NULL,
    model            TEXT,
    storage_version  TEXT,
    flash_cache_mb   NUMERIC,
    flash_log_mb     NUMERIC,
    cell_disks       INTEGER,
    grid_disks       INTEGER,
    has_flash_log    BOOLEAN     DEFAULT false,
    row_hash         CHAR(32)    NOT NULL,
    created_at       TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_config_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_config UNIQUE (dbname, begin_snap, cell_name, row_hash)
) TABLESPACE awrparser;
COMMENT ON TABLE awr_exadata_config IS 'Exadata cell hardware config. Inconsistent flash_cache_mb or missing flash_log across cells is a MEDIUM alert.';
CREATE INDEX IF NOT EXISTS idx_exadata_config_snap ON awr_exadata_config (dbname, begin_snap) TABLESPACE awrparser_idx;

-- awr_exadata_disk_iostat
CREATE TABLE IF NOT EXISTS awr_exadata_disk_iostat (
    id               SERIAL,
    dbname           TEXT        NOT NULL,
    instance         TEXT        NOT NULL,
    begin_snap       INTEGER,
    snap_time        TIMESTAMP   WITHOUT TIME ZONE,
    cell_name        TEXT,
    disk_name        TEXT,
    device_type      TEXT,
    iops             NUMERIC,
    throughput_mbps  NUMERIC,
    util_pct         NUMERIC,
    service_ms       NUMERIC,
    is_outlier       BOOLEAN     DEFAULT false,
    row_hash         CHAR(32)    NOT NULL,
    created_at       TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_disk_iostat_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_disk_iostat UNIQUE (dbname, begin_snap, cell_name, device_type, row_hash)
) TABLESPACE awrparser;
COMMENT ON TABLE awr_exadata_disk_iostat IS 'Per-disk IO stats from Outlier Disks section. is_outlier within a healthy cell may indicate a degraded disk.';
CREATE INDEX IF NOT EXISTS idx_exadata_disk_iostat_snap ON awr_exadata_disk_iostat (dbname, begin_snap) TABLESPACE awrparser_idx;
CREATE INDEX IF NOT EXISTS idx_exadata_disk_iostat_outlier ON awr_exadata_disk_iostat (dbname, is_outlier) TABLESPACE awrparser_idx WHERE is_outlier = true;

-- awr_exadata_fc_internal
CREATE TABLE IF NOT EXISTS awr_exadata_fc_internal (
    id               SERIAL,
    dbname           TEXT        NOT NULL,
    instance         TEXT        NOT NULL,
    begin_snap       INTEGER,
    snap_time        TIMESTAMP   WITHOUT TIME ZONE,
    cell_name        TEXT        NOT NULL,
    io_direction     TEXT        NOT NULL,
    request_count    BIGINT,
    io_type          TEXT,
    row_hash         CHAR(32)    NOT NULL,
    created_at       TIMESTAMP   WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_exadata_fc_internal_pkey PRIMARY KEY (id),
    CONSTRAINT uq_exadata_fc_internal UNIQUE (dbname, begin_snap, cell_name, io_direction, io_type, row_hash)
) TABLESPACE awrparser;
COMMENT ON TABLE awr_exadata_fc_internal IS 'Flash Cache Internal Reads/Writes. Internal Reads spike during flushing. Absence of Internal Writes is also a flushing diagnostic.';
CREATE INDEX IF NOT EXISTS idx_exadata_fc_internal_snap ON awr_exadata_fc_internal (dbname, begin_snap) TABLESPACE awrparser_idx;

\echo 'Wave 3: awr_exadata_fc_writes, awr_exadata_fc_write_reject, awr_exadata_config, awr_exadata_disk_iostat, awr_exadata_fc_internal'
