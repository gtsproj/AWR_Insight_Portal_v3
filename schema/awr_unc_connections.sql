-- ============================================================
-- AWR UNC Connections — per-database network/UNC path config
-- for AWR source type = 'network'
--
-- Replaces the single global awr_network_path setting with a
-- multi-database connection manager, mirroring the pattern used
-- by sar_ssh_connections (SAR SSH pull) and awr_oracle_connections
-- (Direct Oracle DB AWR generation).
-- ============================================================

CREATE TABLE IF NOT EXISTS awr_unc_connections (
    id              SERIAL PRIMARY KEY,
    db_name         TEXT NOT NULL,             -- matches awr_db_master.db_name
    display_name    TEXT,                      -- friendly label shown in UI
    unc_path        TEXT NOT NULL,             -- e.g. \\server\share\awr_reports\ORCL
    username        TEXT,                      -- optional — for net use / mapped drive auth
    password_enc    TEXT,                      -- base64-obfuscated (if username supplied)
    pull_interval_hrs NUMERIC(4,1) DEFAULT 1,  -- copy new files every N hours (0=manual)
    enabled         BOOLEAN DEFAULT TRUE,
    last_pull_at    TIMESTAMP,                 -- datetime of last successful pull
    added_at        TIMESTAMP DEFAULT NOW(),
    added_by        TEXT DEFAULT 'admin',
    CONSTRAINT uq_awr_unc_db_name UNIQUE (db_name)
);

COMMENT ON TABLE awr_unc_connections IS
    'Per-database network/UNC path config for AWR source type = network. '
    'One row per Oracle database. Each row points at its own UNC folder — '
    'no shared root path or DB-name subfolder convention required. '
    'Files are copied to awr_reports\<db_name>\ and picked up by the queue processor.';

CREATE INDEX IF NOT EXISTS idx_awr_unc_enabled
    ON awr_unc_connections (enabled, db_name);
