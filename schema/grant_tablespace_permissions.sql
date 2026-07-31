-- ============================================================
-- grant_tablespace_permissions.sql
-- DAR Portal — Fix: permission denied for tablespace awrparser
-- ============================================================
--
-- Run this as the PostgreSQL superuser (postgres) if you see:
--   ERROR: permission denied for tablespace awrparser
-- when connecting as DAR_PORTAL_USER and creating tables.
--
-- This happens because GRANT CREATE ON TABLESPACE is a separate
-- privilege in PostgreSQL — it is NOT included in the schema
-- GRANT CREATE or GRANT ALL.  It must be granted explicitly
-- by a superuser on each tablespace.
--
-- Run as: psql -U postgres -d postgres -f schema\grant_tablespace_permissions.sql
-- ============================================================

\echo 'Granting tablespace permissions to DAR_PORTAL_USER...'

-- Allow DAR_PORTAL_USER to create objects in the DAR Portal tablespaces
GRANT CREATE ON TABLESPACE awrparser     TO DAR_PORTAL_USER;
GRANT CREATE ON TABLESPACE awrparser_idx TO DAR_PORTAL_USER;

\echo 'Done. DAR_PORTAL_USER can now CREATE TABLE ... TABLESPACE awrparser.'

-- Verify
SELECT
    t.spcname            AS tablespace,
    r.rolname            AS role,
    has_tablespace_privilege(r.rolname, t.spcname, 'CREATE') AS can_create
FROM pg_tablespace t
CROSS JOIN pg_roles r
WHERE t.spcname IN ('awrparser','awrparser_idx')
  AND r.rolname = 'DAR_PORTAL_USER';
