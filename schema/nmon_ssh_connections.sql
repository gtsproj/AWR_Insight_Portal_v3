-- ============================================================
-- nmon_ssh_connections — SSH pull config for NMON files from
-- IBM AIX servers. Mirrors sar_ssh_connections exactly, with
-- remote_nmon_path replacing remote_sar_path.
-- ============================================================

CREATE TABLE IF NOT EXISTS nmon_ssh_connections (
    id                SERIAL PRIMARY KEY,
    hostname          TEXT NOT NULL UNIQUE,         -- matches awr_db_master.host_name
    display_name      TEXT,
    ssh_host          TEXT NOT NULL,                -- IP or FQDN of the AIX server
    ssh_port          INTEGER DEFAULT 22,
    ssh_user          TEXT NOT NULL,
    ssh_key_path      TEXT,                         -- path to private key on portal server
    password_enc      TEXT,                         -- base64-obfuscated
    remote_nmon_path  TEXT DEFAULT '/home/oracle/nmon',  -- remote directory holding .nmon files
    pull_interval_hrs NUMERIC(4,1) DEFAULT 1,
    enabled           BOOLEAN DEFAULT TRUE,
    last_pull_at      TIMESTAMP,
    added_at          TIMESTAMP DEFAULT NOW(),
    added_by          TEXT DEFAULT 'admin'
) TABLESPACE awrparser;

CREATE INDEX IF NOT EXISTS idx_nmon_ssh_enabled
    ON nmon_ssh_connections (enabled, hostname);

COMMENT ON TABLE nmon_ssh_connections IS
    'SSH pull configuration for NMON files from IBM AIX servers. '
    'Mirrors sar_ssh_connections. Files pulled via SFTP and deposited '
    'under nmon_drop/<hostname>/ for the NMONWatcher service to pick up.';
