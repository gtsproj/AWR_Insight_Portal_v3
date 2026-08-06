-- ============================================================
-- NMON Stats — table structure mirroring the sar_*_stats pattern
-- (hostname, snap_time, metric columns, row_hash for idempotency)
--
-- Covers the four sections needed for AWR correlation and
-- dashboards: CPU, Memory, Disk I/O, Network. Additional NMON
-- sections (JFS filesystem, TOP process, paging) can be added the
-- same way once these four are validated.
-- ============================================================

CREATE TABLE IF NOT EXISTS nmon_cpu_stats (
    id          SERIAL PRIMARY KEY,
    hostname    TEXT NOT NULL,
    snap_time   TIMESTAMP NOT NULL,
    cpu         TEXT NOT NULL DEFAULT 'ALL',   -- 'ALL' for CPU_ALL, or per-core id for CPUnn
    user_pct    NUMERIC,
    sys_pct     NUMERIC,
    wait_pct    NUMERIC,                        -- I/O wait — closest analogue to SAR %iowait
    idle_pct    NUMERIC,
    busy_pct    NUMERIC,
    cpu_count   INTEGER,
    row_hash    CHAR(32) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_nmon_cpu UNIQUE (hostname, snap_time, cpu, row_hash)
) TABLESPACE awrparser;
CREATE INDEX IF NOT EXISTS idx_nmon_cpu_host_time ON nmon_cpu_stats (hostname, snap_time) tablespace awrparser_idx;
CREATE INDEX IF NOT EXISTS idx_nmon_cpu_wait       ON nmon_cpu_stats (hostname, wait_pct DESC) tablespace awrparser_idx;;

CREATE TABLE IF NOT EXISTS nmon_memory_stats (
    id            SERIAL PRIMARY KEY,
    hostname      TEXT NOT NULL,
    snap_time     TIMESTAMP NOT NULL,
    mem_total_mb  NUMERIC,
    mem_free_mb   NUMERIC,
    mem_used_mb   NUMERIC,
    mem_used_pct  NUMERIC,
    buffers_mb    NUMERIC,
    cached_mb     NUMERIC,
    swap_total_mb NUMERIC,
    swap_free_mb  NUMERIC,
    swap_used_pct NUMERIC,
    row_hash      CHAR(32) NOT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_nmon_mem UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;
CREATE INDEX IF NOT EXISTS idx_nmon_mem_host_time ON nmon_memory_stats (hostname, snap_time) tablespace awrparser_idx;;

CREATE TABLE IF NOT EXISTS nmon_disk_stats (
    id           SERIAL PRIMARY KEY,
    hostname     TEXT NOT NULL,
    snap_time    TIMESTAMP NOT NULL,
    disk_name    TEXT NOT NULL,
    busy_pct     NUMERIC,
    read_kbs     NUMERIC,
    write_kbs    NUMERIC,
    xfers_per_sec NUMERIC,
    row_hash     CHAR(32) NOT NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_nmon_disk UNIQUE (hostname, snap_time, disk_name, row_hash)
) TABLESPACE awrparser;
CREATE INDEX IF NOT EXISTS idx_nmon_disk_host_time ON nmon_disk_stats (hostname, snap_time) tablespace awrparser_idx;;
CREATE INDEX IF NOT EXISTS idx_nmon_disk_busy       ON nmon_disk_stats (hostname, busy_pct DESC) tablespace awrparser_idx;;

CREATE TABLE IF NOT EXISTS nmon_network_stats (
    id            SERIAL PRIMARY KEY,
    hostname      TEXT NOT NULL,
    snap_time     TIMESTAMP NOT NULL,
    interface     TEXT NOT NULL,
    read_kbs      NUMERIC,
    write_kbs     NUMERIC,
    read_packets  NUMERIC,
    write_packets NUMERIC,
    row_hash      CHAR(32) NOT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_nmon_net UNIQUE (hostname, snap_time, interface, row_hash)
) TABLESPACE awrparser;
CREATE INDEX IF NOT EXISTS idx_nmon_net_host_time ON nmon_network_stats (hostname, snap_time) tablespace awrparser_idx;;

-- ============================================================
-- Run queue and context switches — from NMON's PROC section
-- (Runnable / pswitch fields). NMON has no exponential-decay load
-- average like SAR's ldavg-1/5/15 — run queue length is the closest
-- available signal for CPU saturation.
-- ============================================================
CREATE TABLE IF NOT EXISTS nmon_runqueue_stats (
    id          SERIAL PRIMARY KEY,
    hostname    TEXT NOT NULL,
    snap_time   TIMESTAMP NOT NULL,
    runq_sz     NUMERIC,     -- NMON 'Runnable' — processes waiting for CPU
    swapin_procs NUMERIC,    -- NMON 'Swap-in' — processes swapped in, if present
    row_hash    CHAR(32) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_nmon_runq UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;
CREATE INDEX IF NOT EXISTS idx_nmon_runq_host_time ON nmon_runqueue_stats (hostname, snap_time) tablespace awrparser_idx;;

CREATE TABLE IF NOT EXISTS nmon_ctxswitch_stats (
    id          SERIAL PRIMARY KEY,
    hostname    TEXT NOT NULL,
    snap_time   TIMESTAMP NOT NULL,
    cswch_persec NUMERIC,    -- NMON 'pswitch' — context switches/sec
    fork_persec  NUMERIC,    -- NMON 'fork', closest analogue to SAR's proc/s
    row_hash    CHAR(32) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_nmon_ctxsw UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;
CREATE INDEX IF NOT EXISTS idx_nmon_ctxsw_host_time ON nmon_ctxswitch_stats (hostname, snap_time) tablespace awrparser_idx;;

-- ============================================================
-- Paging — from NMON's PAGE section. Field names/availability vary
-- more across NMON builds than other sections; parser matches by
-- keyword rather than fixed position and leaves unavailable fields
-- NULL rather than guessing.
-- ============================================================
CREATE TABLE IF NOT EXISTS nmon_paging_stats (
    id            SERIAL PRIMARY KEY,
    hostname      TEXT NOT NULL,
    snap_time     TIMESTAMP NOT NULL,
    pgin_persec   NUMERIC,   -- page-ins from disk
    pgout_persec  NUMERIC,   -- page-outs to disk
    pgsin_persec  NUMERIC,   -- page-ins from swap specifically, if present
    pgsout_persec NUMERIC,   -- page-outs to swap specifically, if present
    fault_persec  NUMERIC,   -- page faults/sec
    row_hash      CHAR(32) NOT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_nmon_page UNIQUE (hostname, snap_time, row_hash)
) TABLESPACE awrparser;
CREATE INDEX IF NOT EXISTS idx_nmon_page_host_time ON nmon_paging_stats (hostname, snap_time); tablespace awrparser_idx;

-- ============================================================
-- NMON file/source tracking — mirrors sar_ssh_connections style
-- bookkeeping, used by the queue processor / watcher
-- ============================================================
CREATE TABLE IF NOT EXISTS nmon_parse_log (
    id           SERIAL PRIMARY KEY,
    hostname     TEXT NOT NULL,
    filename     TEXT NOT NULL,
    snap_date    DATE,
    rows_parsed  INTEGER DEFAULT 0,
    status       TEXT DEFAULT 'ok',    -- ok | error
    error_msg    TEXT,
    parsed_at    TIMESTAMP DEFAULT NOW(),
    CONSTRAINT uq_nmon_parse_log UNIQUE (hostname, filename)
) TABLESPACE awrparser;

COMMENT ON TABLE nmon_cpu_stats IS
    'NMON CPU_ALL section — mirrors sar_cpu_stats. wait_pct is NMON''s I/O wait, '
    'the closest analogue to SAR''s %iowait, used in AWR/NMON correlation.';
COMMENT ON TABLE nmon_disk_stats IS
    'NMON DISKBUSY/DISKREAD/DISKWRITE sections merged per disk per snapshot — mirrors sar_disk_stats.';
COMMENT ON TABLE nmon_network_stats IS
    'NMON NET section — mirrors sar_network_stats.';
