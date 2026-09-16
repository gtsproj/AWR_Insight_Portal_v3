-- ============================================================
-- Migration: add table/index/statement-text columns to
-- mssql_blocking_snapshot
-- ============================================================
-- For Ganesh's existing table (created before this enhancement).
-- Run once. Existing rows will have NULL for all three new columns
-- -- only future collector runs will populate them, same reasoning
-- as the earlier RCSI-columns migration on the deadlock table.
-- ============================================================

ALTER TABLE mssql_blocking_snapshot ADD COLUMN IF NOT EXISTS blocked_object_name TEXT;
ALTER TABLE mssql_blocking_snapshot ADD COLUMN IF NOT EXISTS blocked_index_name TEXT;
ALTER TABLE mssql_blocking_snapshot ADD COLUMN IF NOT EXISTS blocked_statement_text TEXT;

\echo 'mssql_blocking_snapshot: blocked_object_name/blocked_index_name/blocked_statement_text columns added'
