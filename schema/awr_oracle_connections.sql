-- ============================================================
-- AWR Oracle Connections — per-database Oracle connection config
-- for Direct Oracle DB AWR generation
-- ============================================================

CREATE TABLE IF NOT EXISTS awr_oracle_connections (
    id              SERIAL PRIMARY KEY,
    db_name         TEXT NOT NULL,           -- matches awr_db_master.db_name
    display_name    TEXT,                    -- friendly label shown in UI
    host            TEXT NOT NULL,
    port            INTEGER DEFAULT 1521,
    service_name    TEXT NOT NULL,           -- Oracle service name (not SID)
    username        TEXT NOT NULL,
    password_enc    TEXT NOT NULL,           -- base64 obfuscated (not true encryption)
    snap_interval_hrs INTEGER DEFAULT 1,     -- generate report every N hours (0 = manual only)
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
