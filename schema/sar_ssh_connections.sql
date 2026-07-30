-- ============================================================
-- SAR SSH Connections — per-server SSH config for SAR pull
-- Delta extraction: SSH exec sar -A -s/-e on remote server,
-- download text output, no binary/WSL needed.
-- ============================================================

CREATE TABLE IF NOT EXISTS sar_ssh_connections (
    id                SERIAL PRIMARY KEY,
    hostname          TEXT NOT NULL,             -- Linux server hostname (sar_drop subfolder name)
    display_name      TEXT,                      -- friendly label shown in UI
    ssh_host          TEXT NOT NULL,             -- SSH hostname or IP
    ssh_port          INTEGER DEFAULT 22,
    ssh_user          TEXT NOT NULL,             -- SSH username
    ssh_key_path      TEXT,                      -- path to private key on portal server
    password_enc      TEXT,                      -- base64-obfuscated password (if no key)
    remote_sar_path   TEXT DEFAULT '/var/log/sa', -- SA file location on Linux server
    pull_interval_hrs NUMERIC(4,1) DEFAULT 1,   -- extract delta every N hours (0=manual)
    enabled           BOOLEAN DEFAULT TRUE,
    last_pull_at      TIMESTAMP,                 -- datetime of last successful pull
    last_pull_time    TIME,                      -- HH:MM:SS of last extracted interval end
    last_pull_date    DATE,                      -- date of last extracted SA file (to know saDD)
    added_at          TIMESTAMP DEFAULT NOW(),
    added_by          TEXT DEFAULT 'admin',
    CONSTRAINT uq_sar_ssh_hostname UNIQUE (hostname)
);

COMMENT ON TABLE sar_ssh_connections IS
    'SSH connection config for SAR delta extraction from Linux servers. '
    'One row per server. Delta extracted via: sar -A -s HH:MM -e HH:MM -f saDD '
    'then downloaded as text — no binary pull, no WSL conversion needed.';

CREATE INDEX IF NOT EXISTS idx_sar_ssh_enabled
    ON sar_ssh_connections (enabled, hostname);
