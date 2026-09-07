-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Tablespace Setup and Grants
-- Avekshaa Technologies
-- ============================================================
--
-- Confirmed tablespace names (per Ganesh, MS SQL Analysis Model
-- design doc v1.2/v1.3 Section 5): mssqlparser / mssqlparser_idx --
-- mirrors the existing awrparser/awrparser_idx split exactly. Same
-- PostgreSQL database as the Oracle schema, separate tablespace only.
--
-- Run this ONCE, before any of the mssql_*_tables.sql scripts, on
-- either a fresh install or an existing installation being extended
-- to MS SQL Server support. Safe to re-run (IF NOT EXISTS guards
-- throughout, matching every other schema script in this project).
-- ============================================================

\echo 'Creating MS SQL Server tablespaces...'

-- NOTE: PostgreSQL's CREATE TABLESPACE has no IF NOT EXISTS clause
-- (confirmed against PostgreSQL 16's own \h CREATE TABLESPACE output),
-- AND cannot run inside a DO block/function at all (tested directly --
-- "CREATE TABLESPACE cannot be executed from a function"). The \gexec
-- pattern below is PostgreSQL's standard, correct way to make DDL like
-- this idempotent when IF NOT EXISTS isn't available -- verified with
-- two consecutive runs, second run produces zero errors and creates
-- nothing.
--
-- Worth knowing: install_fresh.sql's existing
-- "CREATE TABLESPACE IF NOT EXISTS awrparser" has the same invalid
-- syntax -- it would only surface as an error if someone re-runs that
-- installer on a system where the tablespace already exists, which
-- the file's own header describes as safe to do. Not fixed here since
-- it's out of scope for MS SQL schema work and touches the existing
-- Oracle install script -- flagging for you to decide whether/when to
-- address separately.
SELECT 'CREATE TABLESPACE mssqlparser OWNER postgres LOCATION ''C:\PostgreSQL\tablespaces\mssqlparser'''
WHERE NOT EXISTS (SELECT 1 FROM pg_tablespace WHERE spcname = 'mssqlparser')
\gexec
-- ^^^ EDIT THIS PATH before running

SELECT 'CREATE TABLESPACE mssqlparser_idx OWNER postgres LOCATION ''C:\PostgreSQL\tablespaces\mssqlparser_idx'''
WHERE NOT EXISTS (SELECT 1 FROM pg_tablespace WHERE spcname = 'mssqlparser_idx')
\gexec
-- ^^^ EDIT THIS PATH before running

\echo '  MS SQL tablespaces: done'

-- DAR_PORTAL_USER already exists and already owns the Oracle schema --
-- its own comment in install_fresh.sql already anticipates this
-- ("Designed to own objects across multiple DB platform modules:
-- Oracle AWR, MS SQL Server, PostgreSQL, MySQL, MariaDB, etc.") --
-- so no new role is needed, only the tablespace-level grant, exactly
-- mirroring grant_tablespace_permissions.sql's existing pattern for
-- awrparser/awrparser_idx.
\echo 'Granting DAR_PORTAL_USER access to MS SQL tablespaces...'

GRANT CREATE ON TABLESPACE mssqlparser     TO DAR_PORTAL_USER;
GRANT CREATE ON TABLESPACE mssqlparser_idx TO DAR_PORTAL_USER;

\echo '  Grants: done'
\echo ''
\echo 'Next: run mssql_core_tables.sql, then mssql_qs_tables.sql,'
\echo 'then mssql_dmv_tables.sql, then mssql_deadlock_table.sql.'
