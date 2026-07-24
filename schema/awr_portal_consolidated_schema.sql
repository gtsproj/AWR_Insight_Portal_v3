-- ============================================================
-- AWR Insight Portal v3 — Consolidated Installation Schema
-- ============================================================
-- Single script for complete fresh installation.
-- Consolidates all schema files in correct dependency order.
--
-- Prerequisites:
--   1. Run awr_portal_schema_owner.sql first (creates awr_owner role)
--   2. Create tablespace directories on disk:
--        Windows: mkdir C:\PostgreSQL\tablespaces\awrparser
--                 mkdir C:\PostgreSQL\tablespaces\awrparser_idx
--   3. Register tablespaces in PostgreSQL:
--        CREATE TABLESPACE awrparser     LOCATION 'C:/PostgreSQL/tablespaces/awrparser';
--        CREATE TABLESPACE awrparser_idx LOCATION 'C:/PostgreSQL/tablespaces/awrparser_idx';
--
-- Usage:
--   Windows:
--     psql -U awr_owner -d postgres -f schema/awr_portal_consolidated_schema.sql
--
--   Linux:
--     psql -U awr_owner -d postgres -f schema/awr_portal_consolidated_schema.sql
--
-- Order of execution:
--   1. Core AWR parser tables      (awr_master_schema_v2 (4).sql)
--   2. Object metadata tables      (awr_object_metadata_schema.sql)
--   3. Execution plan tables       (execution_plans.sql)
--   4. Recommendations tables      (recommendations_and_comparison.sql)
--   5. SAR extension tables        (sar_hugepage_socket_tables.sql)
--   6. SAR new tables              (sar_new_tables_and_cdb_additions.sql)
--   7. Remote fetch schema         (remote_fetch_schema.sql)
--   8. License schema              (awr_license_schema.sql)
--   9. DB master schema            (awr_db_master_schema (1).sql)
--  10. Index creation              (awr_parser_index_creation.sql)
--  11. Wait event master seed      (wait_event_master_update.sql)
-- ============================================================

SET client_min_messages = WARNING;
SET search_path = public;

\echo '============================================================'
\echo 'AWR Insight Portal v3 — Consolidated Schema Installation'
\echo '============================================================'

-- ── Part 1: Core AWR parser tables ───────────────────────────────────────────
\echo ''
\echo '[1/11] Creating core AWR parser tables...'
\i schema/awr_master_schema_v2 (4).sql

-- ── Part 2: Object metadata ───────────────────────────────────────────────────
\echo ''
\echo '[2/11] Creating object metadata tables...'
\i schema/awr_object_metadata_schema.sql

-- ── Part 3: Execution plans ───────────────────────────────────────────────────
\echo ''
\echo '[3/11] Creating execution plan tables...'
\i schema/execution_plans.sql

-- ── Part 4: Recommendations and comparison ────────────────────────────────────
\echo ''
\echo '[4/11] Creating recommendations and comparison tables...'
\i schema/recommendations_and_comparison.sql

-- ── Part 5: SAR extension tables ─────────────────────────────────────────────
\echo ''
\echo '[5/11] Creating SAR extension tables (hugepage, socket)...'
\i schema/sar_hugepage_socket_tables.sql

-- ── Part 6: SAR new tables ───────────────────────────────────────────────────
\echo ''
\echo '[6/11] Creating SAR new tables and CDB additions...'
\i schema/sar_new_tables_and_cdb_additions.sql

-- ── Part 7: Remote fetch schema ──────────────────────────────────────────────
\echo ''
\echo '[7/11] Creating remote fetch schema...'
\i schema/remote_fetch_schema.sql

-- ── Part 8: License schema ───────────────────────────────────────────────────
\echo ''
\echo '[8/11] Creating license schema...'
\i schema/awr_license_schema.sql

-- ── Part 9: DB master schema ─────────────────────────────────────────────────
\echo ''
\echo '[9/11] Creating DB master schema...'
\i schema/awr_db_master_schema (1).sql

-- ── Part 10: Indexes ─────────────────────────────────────────────────────────
\echo ''
\echo '[10/11] Creating indexes...'
\i schema/awr_parser_index_creation.sql

-- ── Part 11: Wait event master seed data ─────────────────────────────────────
\echo ''
\echo '[11/11] Seeding wait event master data...'
\i schema/wait_event_master_update.sql

\echo ''
\echo '============================================================'
\echo 'Schema installation complete.'
\echo 'All tables, views, indexes, and seed data created.'
\echo ''
\echo 'Next steps:'
\echo '  1. Update config/settings.yaml with DB credentials'
\echo '  2. Run install_services.bat to register Windows services'
\echo '  3. Run py patch_grafana_urls.py --dir portal/static'
\echo '  4. Start services: py start_all.py (or use NSSM)'
\echo '============================================================'
