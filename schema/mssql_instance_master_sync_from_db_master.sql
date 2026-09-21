-- ============================================================
-- 1. Missing unique constraint on mssql_instance_master -- found
--    while fixing the licensing-sync gap below. Without this,
--    (host_name, instance_name) has no uniqueness guarantee at all,
--    and ON CONFLICT (needed for the sync upsert below) has nothing
--    to match against. A genuine data-integrity gap independent of
--    the sync work, worth closing while already here.
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_mssql_instance_host_inst'
    ) THEN
        ALTER TABLE mssql_instance_master
            ADD CONSTRAINT uq_mssql_instance_host_inst UNIQUE (host_name, instance_name);
    END IF;
END $$;

-- ============================================================
-- 2. One-time sync: every awr_db_master row already registered with
--    db_engine='MSSQL' gets a matching, active mssql_instance_master
--    row. Real gap found from a real failure: Ganesh registered a
--    connection in mssql_connections (Step: "DB Connection > MS SQL")
--    AND registered the database in the Licensed Databases tab
--    (awr_db_master, db_engine='MSSQL') -- but these are two
--    completely separate tables that were never wired together.
--    mssql_instance_master (the collector's own licensing gate,
--    resolve_instance_id()) stayed empty regardless, so collection
--    correctly, loudly refused to run for an instance that was, from
--    Ganesh's own perspective, already fully registered twice over.
--
--    This is a one-time catch-up for whatever's already registered;
--    portal/app.py's api_db_master_add is updated separately (not in
--    this file) to keep doing this automatically for every future
--    MSSQL registration, so this manual step should not be needed
--    again going forward.
-- ============================================================

INSERT INTO mssql_instance_master (host_name, instance_name, active, added_by)
SELECT DISTINCT host_name, COALESCE(NULLIF(instance_name, ''), 'MSSQLSERVER'), TRUE, 'db_master_sync'
FROM awr_db_master
WHERE db_engine = 'MSSQL' AND active = TRUE AND host_name IS NOT NULL AND host_name != ''
ON CONFLICT (host_name, instance_name) DO UPDATE SET active = TRUE;

\echo 'mssql_instance_master synced from every active MSSQL row in awr_db_master.'
SELECT host_name, instance_name, active FROM mssql_instance_master;
