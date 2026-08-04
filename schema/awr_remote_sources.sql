-- ============================================================
-- AWR Remote Sources — two-tier model for AWR source type = 'network'
--
-- Tier 1: awr_remote_servers   — one row per remote server. Holds
--         connection credentials (shared across all its databases).
--         connection_type = 'unc' (Windows share) or 'ssh' (Linux).
--
--         auto_discover = TRUE (default): log in once, the watcher
--         scans every immediate subfolder under root_path and treats
--         each subfolder name as a database — no manual per-DB setup
--         needed. This is the primary/simple mode.
--
-- Tier 2: awr_remote_db_paths  — OPTIONAL per-database override.
--         Only needed if a database's folder name should differ from
--         the auto-discovered db_name, if one database needs its own
--         pull interval, or if auto_discover is turned off for a
--         server and paths must be listed explicitly.
-- ============================================================

CREATE TABLE IF NOT EXISTS awr_remote_servers (
    id                 SERIAL PRIMARY KEY,
    display_name       TEXT NOT NULL,             -- friendly label shown in UI
    connection_type    TEXT NOT NULL DEFAULT 'unc'
                            CHECK (connection_type IN ('unc', 'ssh')),
    host                TEXT NOT NULL,             -- IP/hostname (UNC share host, or SSH host)
    root_path           TEXT NOT NULL,             -- UNC: \\host\share\awr_reports
                                                    -- SSH: /remote/path/awr_reports
    ssh_port            INTEGER DEFAULT 22,        -- SSH only
    ssh_key_path        TEXT,                      -- SSH only — path to private key on portal server
    username             TEXT,                     -- UNC: share credential (optional).
                                                    -- SSH: required unless ssh_key_path set
    password_enc        TEXT,                      -- base64-obfuscated (not true encryption)
    auto_discover       BOOLEAN DEFAULT TRUE,       -- scan root_path's subfolders as databases
    pull_interval_hrs   NUMERIC(4,1) DEFAULT 1,     -- used when auto_discover=TRUE (0=manual)
    enabled             BOOLEAN DEFAULT TRUE,
    last_pull_at        TIMESTAMP,                  -- used when auto_discover=TRUE
    added_at            TIMESTAMP DEFAULT NOW(),
    added_by            TEXT DEFAULT 'admin',
    CONSTRAINT uq_awr_remote_server UNIQUE (display_name)
);

COMMENT ON TABLE awr_remote_servers IS
    'Remote server config for AWR network sources. One row per server, one login. '
    'connection_type=unc uses Windows net use with root_path as a UNC prefix. '
    'connection_type=ssh uses paramiko SFTP with root_path as a remote directory. '
    'When auto_discover=TRUE, every immediate subfolder under root_path is treated '
    'as a database automatically — no per-database configuration required.';

CREATE TABLE IF NOT EXISTS awr_remote_db_paths (
    id                 SERIAL PRIMARY KEY,
    server_id          INTEGER NOT NULL REFERENCES awr_remote_servers(id) ON DELETE CASCADE,
    db_name            TEXT NOT NULL,          -- matches awr_db_master.db_name
    display_name       TEXT,
    remote_subpath     TEXT NOT NULL,          -- subfolder under the server's root_path, e.g. 'ORCL'
    pull_interval_hrs  NUMERIC(4,1) DEFAULT 1, -- pull every N hours (0=manual)
    enabled            BOOLEAN DEFAULT TRUE,
    last_pull_at       TIMESTAMP,
    added_at           TIMESTAMP DEFAULT NOW(),
    added_by           TEXT DEFAULT 'admin',
    CONSTRAINT uq_awr_remote_db_per_server UNIQUE (server_id, db_name)
);

COMMENT ON TABLE awr_remote_db_paths IS
    'OPTIONAL per-database override for a server. Only needed to rename a folder, '
    'give one database its own interval, or list databases explicitly when a '
    'server has auto_discover=FALSE. Full remote location = '
    'server.root_path + / + remote_subpath. Files are copied to '
    'awr_reports/<db_name>/ and picked up by the queue processor.';

CREATE INDEX IF NOT EXISTS idx_awr_remote_db_enabled
    ON awr_remote_db_paths (enabled, server_id);
