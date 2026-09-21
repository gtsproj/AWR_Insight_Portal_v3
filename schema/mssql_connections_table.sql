-- ============================================================
-- mssql_connections -- credential/config storage for the QS and
-- DMV collectors, supporting multiple SQL Server instances, each
-- with multiple databases. Mirrors awr_oracle_connections' role
-- for Oracle, adapted for SQL Server's instance-vs-database
-- relationship: Oracle credentials are typically tied to one
-- service_name (one row per database there), but SQL Server
-- authentication is instance-level -- the same login authenticates
-- against every database on that instance -- so this is one row
-- per INSTANCE, with a list of which databases to collect on it.
-- ============================================================

CREATE TABLE IF NOT EXISTS mssql_connections (
    id                             SERIAL,
    host_name                      TEXT NOT NULL,
    instance_name                  TEXT NOT NULL DEFAULT 'MSSQLSERVER',
    display_name                   TEXT,
    port                           INTEGER,        -- NULL = default 1433, matches the
                                                     -- collectors' own --port "omit for default" convention
    auth_type                      TEXT NOT NULL DEFAULT 'trusted',  -- 'trusted' | 'sql'
    username                       TEXT,            -- required when auth_type='sql'
    password_enc                   TEXT,            -- required when auth_type='sql'; base64
                                                     -- obfuscation, NOT encryption -- same honest
                                                     -- framing as awr_oracle_connections.password_enc,
                                                     -- prevents plain-text storage, not a real secret store
    databases                      TEXT[],          -- NULL/empty = collect every online database on
                                                     -- this instance (matches dmv_delta_collector.py's
                                                     -- own "omit --database for all" convention);
                                                     -- non-empty = collect only these specific databases
    snap_interval_minutes          INTEGER NOT NULL DEFAULT 60,  -- must be one of SQL Server's own
                                                     -- valid QUERY_STORE INTERVAL_LENGTH_MINUTES values
    enabled                        BOOLEAN DEFAULT true,
    last_run_at                    TIMESTAMP WITHOUT TIME ZONE,
    last_dmv_snapshot_id           INTEGER,
    last_run_status                TEXT,            -- 'success' | 'failed' | 'skipped' | NULL (never run)
    last_run_error                 TEXT,
    added_at                       TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    added_by                       TEXT DEFAULT 'admin'::text,
    CONSTRAINT mssql_connections_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT uq_mssql_conn UNIQUE (host_name, instance_name) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT chk_mssql_conn_auth CHECK (
        (auth_type = 'trusted') OR
        (auth_type = 'sql' AND username IS NOT NULL AND password_enc IS NOT NULL)
    ),
    CONSTRAINT chk_mssql_conn_interval CHECK (snap_interval_minutes IN (1, 5, 10, 15, 30, 60, 1440))
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_connections IS 'SQL Server instance connection config for the QS/DMV collectors. One row per instance (not per database -- SQL Server auth is instance-level). Mirrors awr_oracle_connections'' role for Oracle. Read by mssql_collector_scheduler.py --from-config.';

CREATE INDEX IF NOT EXISTS idx_mssql_conn_enabled ON public.mssql_connections USING btree (enabled) TABLESPACE mssqlparser_idx;
