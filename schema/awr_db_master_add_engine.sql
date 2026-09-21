-- ============================================================
-- Add db_engine to awr_db_master -- the licensing table has no
-- way to distinguish which database engine a row represents
-- (db_type here means Oracle Standalone/RAC architecture, not
-- vendor). Needed so MS SQL Server databases can be registered
-- in the SAME licensing pool as Oracle (the license key's own
-- db_limit is already a single, generic counter -- not split per
-- engine -- so this is additive to the existing model, not a new
-- one) while still being distinguishable in the UI and enforceable
-- per-engine where needed (e.g. the SAR/NMON OS-utility exclusivity
-- check, which is engine-independent and unaffected by this).
--
-- Defaults every EXISTING row to 'ORACLE' -- every row already in
-- this table today came from the Oracle AWR pipeline, so this
-- preserves their correct classification without needing a
-- per-row backfill.
-- ============================================================

ALTER TABLE awr_db_master ADD COLUMN IF NOT EXISTS db_engine TEXT NOT NULL DEFAULT 'ORACLE';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_db_master_engine'
    ) THEN
        ALTER TABLE awr_db_master ADD CONSTRAINT chk_db_master_engine
            CHECK (db_engine = ANY (ARRAY['ORACLE'::text, 'MSSQL'::text, 'POSTGRESQL'::text,
                                            'MYSQL'::text, 'MARIADB'::text, 'CASSANDRA'::text]));
    END IF;
END $$;

\echo 'awr_db_master.db_engine added, all existing rows classified as ORACLE.'
SELECT db_engine, count(*) FROM awr_db_master GROUP BY db_engine;
