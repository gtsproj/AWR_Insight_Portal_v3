-- ============================================================
-- AWR Insight Portal v3 — Schema Owner and Access Control Setup
-- ============================================================
-- Purpose:
--   1. Create a dedicated schema owner (awr_owner) that owns all
--      AWR Insight Portal database objects
--   2. Create a read-only user (awr_readonly) for reporting/viewing
--   3. Grant appropriate privileges
--
-- Run as: postgres superuser
-- Usage:  psql -U postgres -d postgres -f schema/awr_portal_schema_owner.sql
--
-- IMPORTANT: Run this script BEFORE the main schema script.
--            The main schema should be run AS awr_owner (or with
--            SET ROLE awr_owner) so all objects are owned by awr_owner.
-- ============================================================

-- ── Step 1: Create the schema owner role ─────────────────────────────────────
-- awr_owner: owns all tables, views, functions, sequences.
-- Has full DDL and DML privileges on all portal objects.
-- No superuser — principle of least privilege.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'awr_owner') THEN
        CREATE ROLE awr_owner
            LOGIN
            PASSWORD 'AWROwner@2024!'   -- CHANGE THIS before production
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            INHERIT
            CONNECTION LIMIT -1;
        RAISE NOTICE 'Role awr_owner created.';
    ELSE
        RAISE NOTICE 'Role awr_owner already exists — skipping creation.';
    END IF;
END $$;

-- ── Step 2: Create the read-only role ────────────────────────────────────────
-- awr_readonly: can SELECT from all portal tables/views.
-- Cannot INSERT, UPDATE, DELETE, or modify any schema objects.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'awr_readonly') THEN
        CREATE ROLE awr_readonly
            LOGIN
            PASSWORD 'AWRRead@2024!'    -- CHANGE THIS before production
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            INHERIT
            CONNECTION LIMIT 10;
        RAISE NOTICE 'Role awr_readonly created.';
    ELSE
        RAISE NOTICE 'Role awr_readonly already exists — skipping creation.';
    END IF;
END $$;

-- ── Step 3: Grant database access ────────────────────────────────────────────
GRANT CONNECT ON DATABASE postgres TO awr_owner;
GRANT CONNECT ON DATABASE postgres TO awr_readonly;

-- ── Step 4: Schema privileges ────────────────────────────────────────────────
-- awr_owner: full control of the public schema
GRANT USAGE, CREATE ON SCHEMA public TO awr_owner;

-- awr_readonly: can see objects in public schema but not create
GRANT USAGE ON SCHEMA public TO awr_readonly;

-- ── Step 5: Tablespace grants (if using custom tablespaces) ──────────────────
-- Only grant if tablespaces exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tablespace WHERE spcname = 'awrparser') THEN
        EXECUTE 'GRANT CREATE ON TABLESPACE awrparser TO awr_owner';
        RAISE NOTICE 'Tablespace awrparser granted to awr_owner.';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_tablespace WHERE spcname = 'awrparser_idx') THEN
        EXECUTE 'GRANT CREATE ON TABLESPACE awrparser_idx TO awr_owner';
        RAISE NOTICE 'Tablespace awrparser_idx granted to awr_owner.';
    END IF;
END $$;

-- ── Step 6: Grant awr_owner full privileges on all existing objects ───────────
-- This covers objects already created in the public schema

-- Tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO awr_owner;
-- Sequences (for SERIAL/IDENTITY columns)
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO awr_owner;
-- Functions
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO awr_owner;

-- ── Step 7: Read-only grants for awr_readonly ─────────────────────────────────
GRANT SELECT ON ALL TABLES IN SCHEMA public TO awr_readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO awr_readonly;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO awr_readonly;

-- ── Step 8: Default privileges — automatically apply to future objects ─────────
-- When awr_owner creates a new table/sequence/function, awr_readonly
-- automatically gets SELECT/EXECUTE — no manual re-grant needed.

ALTER DEFAULT PRIVILEGES FOR ROLE awr_owner IN SCHEMA public
    GRANT SELECT ON TABLES TO awr_readonly;

ALTER DEFAULT PRIVILEGES FOR ROLE awr_owner IN SCHEMA public
    GRANT SELECT ON SEQUENCES TO awr_readonly;

ALTER DEFAULT PRIVILEGES FOR ROLE awr_owner IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO awr_readonly;

-- awr_owner's own default: owns everything it creates
ALTER DEFAULT PRIVILEGES FOR ROLE awr_owner IN SCHEMA public
    GRANT ALL ON TABLES TO awr_owner;

ALTER DEFAULT PRIVILEGES FOR ROLE awr_owner IN SCHEMA public
    GRANT ALL ON SEQUENCES TO awr_owner;

-- ── Step 9: Allow awr_owner to manage indexes on its own tables ───────────────
-- (Covered by table ownership — no separate grant needed)

-- ── Step 10: Materialised view refresh privilege ──────────────────────────────
-- awr_owner can refresh MVs; awr_readonly can only SELECT them
-- (MV ownership covers this — no extra grant needed)

-- ── Step 11: Verify setup ─────────────────────────────────────────────────────
SELECT
    r.rolname,
    r.rolsuper,
    r.rolcreatedb,
    r.rolcreaterole,
    r.rolcanlogin,
    r.rolconnlimit
FROM pg_roles r
WHERE r.rolname IN ('awr_owner', 'awr_readonly')
ORDER BY r.rolname;

-- ── Step 12: How to run the main schema as awr_owner ─────────────────────────
-- After running this script, run the main schema script as awr_owner:
--
--   Option A (recommended): Run psql as awr_owner
--     psql -U awr_owner -d postgres -f schema/awr_master_schema_v2\ \(4\).sql
--
--   Option B: Use SET ROLE in the same session
--     SET ROLE awr_owner;
--     \i schema/awr_master_schema_v2\ (4).sql
--
-- ── Step 13: Update config/settings.yaml to use awr_owner credentials ────────
-- In config/settings.yaml (or however your DB connection is configured):
--
--   database:
--     host: localhost
--     port: 5432
--     dbname: postgres
--     user: awr_owner          # <-- schema owner for the portal service
--     password: AWROwner@2024! # <-- change to your password
--
-- The portal service (AWRPortal) must connect as awr_owner so it can
-- INSERT, UPDATE, DELETE, and refresh materialised views.
-- The awr_readonly user is for external reporting tools only.

\echo ''
\echo 'Schema owner setup complete.'
\echo 'awr_owner  : full DDL+DML on all portal objects'
\echo 'awr_readonly: SELECT on all portal objects'
\echo ''
\echo 'Next: run the main schema script as awr_owner.'
\echo 'Then update config/settings.yaml with awr_owner credentials.'
