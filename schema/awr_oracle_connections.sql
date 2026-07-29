-- ============================================================
-- AWR Oracle Connections — per-database Oracle connection config
-- for Direct Oracle DB AWR generation
-- ============================================================

CREATE TABLE IF NOT EXISTS awr_oracle_connections (
    id              SERIAL PRIMARY KEY,
    db_name         TEXT NOT NULL,           -- matches awr_db_master.db_name
    display_name    TEXT,                    -- friendly label shown in UI
    host            TEXT NOT NULL,           -- DB server hostname or RAC SCAN hostname (not IP)
    port            INTEGER DEFAULT 1521,
    service_name    TEXT NOT NULL,           -- Oracle service name (not SID)
    username        TEXT NOT NULL,
    password_enc    TEXT NOT NULL,           -- base64 obfuscated (not true encryption)
    snap_interval_hrs NUMERIC(4,1) DEFAULT 1,  -- generate every N hours (0=manual, 0.5=30min)
    enabled         BOOLEAN DEFAULT TRUE,
    last_run_at     TIMESTAMP,
    last_snap_id    INTEGER,                 -- last begin_snap processed
    added_at        TIMESTAMP DEFAULT NOW(),
    added_by        TEXT DEFAULT 'admin',
    CONSTRAINT uq_oracle_conn_db UNIQUE (db_name)
);

COMMENT ON TABLE awr_oracle_connections IS
    'Oracle DB connection config for direct AWR report generation. '
    'One row per Oracle database. Used by the Direct Oracle DB AWR fetcher.';

CREATE INDEX IF NOT EXISTS idx_oracle_conn_enabled
    ON awr_oracle_connections (enabled, db_name);

-- ============================================================
-- Failed snap pairs — retry queue for AWR generation failures
-- ============================================================
CREATE TABLE IF NOT EXISTS awr_oracle_failed_snaps (
    id              SERIAL PRIMARY KEY,
    conn_id         INTEGER NOT NULL REFERENCES awr_oracle_connections(id) ON DELETE CASCADE,
    db_name         TEXT NOT NULL,
    snap_date       DATE NOT NULL,
    begin_snap      INTEGER NOT NULL,
    end_snap        INTEGER NOT NULL,
    dbid            BIGINT,
    instance_number INTEGER,
    error_msg       TEXT,
    retry_count     INTEGER DEFAULT 0,
    max_retries     INTEGER DEFAULT 3,
    first_failed_at TIMESTAMP DEFAULT NOW(),
    last_tried_at   TIMESTAMP DEFAULT NOW(),
    resolved        BOOLEAN DEFAULT FALSE,
    CONSTRAINT uq_failed_snap UNIQUE (conn_id, begin_snap, end_snap)
);

COMMENT ON TABLE awr_oracle_failed_snaps IS
    'Retry queue for AWR report generation failures. '
    'Scheduler retries each failed pair up to max_retries times. '
    'Resolved = TRUE once successfully generated or max retries exceeded.';

CREATE INDEX IF NOT EXISTS idx_failed_snaps_pending
    ON awr_oracle_failed_snaps (conn_id, resolved, retry_count)
    WHERE resolved = FALSE;
