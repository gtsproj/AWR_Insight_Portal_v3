-- schema/mssql_config_snapshot_host_extend.sql
--
-- Adds the columns the enriched "Database Summary" section needs that
-- mssql_config_snapshot didn't carry: the database's own database_id, and
-- host-level socket/core/platform facts. Safe to re-run (IF NOT EXISTS).
--
-- Sources (all long-stable, safe on SQL Server 2022):
--   database_id                sys.databases.database_id
--   socket_count, cores_per_socket   sys.dm_os_sys_info (added SQL Server 2016)
--   host_platform, host_distribution sys.dm_os_host_info (added SQL Server 2017)

ALTER TABLE mssql_config_snapshot ADD COLUMN IF NOT EXISTS database_id        INTEGER;
ALTER TABLE mssql_config_snapshot ADD COLUMN IF NOT EXISTS socket_count       INTEGER;
ALTER TABLE mssql_config_snapshot ADD COLUMN IF NOT EXISTS cores_per_socket   INTEGER;
ALTER TABLE mssql_config_snapshot ADD COLUMN IF NOT EXISTS host_platform      TEXT;
ALTER TABLE mssql_config_snapshot ADD COLUMN IF NOT EXISTS host_distribution  TEXT;

COMMENT ON COLUMN mssql_config_snapshot.database_id       IS 'sys.databases.database_id for this row''s database_name.';
COMMENT ON COLUMN mssql_config_snapshot.socket_count       IS 'sys.dm_os_sys_info.socket_count -- host-wide, repeats on every database row for the same snapshot.';
COMMENT ON COLUMN mssql_config_snapshot.cores_per_socket   IS 'sys.dm_os_sys_info.cores_per_socket -- host-wide, repeats on every database row for the same snapshot.';
COMMENT ON COLUMN mssql_config_snapshot.host_platform      IS 'sys.dm_os_host_info.host_platform (''Windows'' or ''Linux'') -- host-wide.';
COMMENT ON COLUMN mssql_config_snapshot.host_distribution  IS 'sys.dm_os_host_info.host_distribution -- blank on Windows, e.g. an Ubuntu/RHEL name on Linux -- host-wide.';
