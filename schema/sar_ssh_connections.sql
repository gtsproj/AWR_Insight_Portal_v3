-- ============================================================
-- SAR SSH Connections — per-server SSH config for SAR pull
-- Mirrors awr_oracle_connections for multi-server support.
-- ============================================================

CREATE TABLE IF NOT EXISTS sar_ssh_connections (
    id              SERIAL PRIMARY KEY,
    hostname        TEXT NOT NULL,           -- Linux server hostname (used as sar_drop sub-folder name)
    display_name    TEXT,                    -- friendly label shown in UI
    ssh_host        TEXT NOT NULL,           -- SSH hostname or IP to connect to
    ssh_port        INTEGER DEFAULT 22,
    ssh_user        TEXT NOT NULL,           -- SSH username (e.g. oracle, root, saruser)
    ssh_key_path    TEXT,                    -- path to private key file on portal server
    password_enc    TEXT,                    -- base64-obfuscated password (used if no key)
    remote_sar_path TEXT DEFAULT '/var/log/sa', -- path to SA files on Linux server
    pull_interval_hrs NUMERIC(4,1) DEFAULT 24,  -- pull every N hours (0 = manual only)
    enabled         BOOLEAN DEFAULT TRUE,
    last_pull_at    TIMESTAMP,
    added_at        TIMESTAMP DEFAULT NOW(),
    added_by        TEXT DEFAULT 'admin',
    CONSTRAINT uq_sar_ssh_hostname UNIQUE (hostname)
);

COMMENT ON TABLE sar_ssh_connections IS
    'SSH connection config for pulling SAR files from Linux servers. '
    'One row per Linux server. Files pulled to sar_drop/<hostname>/.';

CREATE INDEX IF NOT EXISTS idx_sar_ssh_enabled
    ON sar_ssh_connections (enabled, hostname);
