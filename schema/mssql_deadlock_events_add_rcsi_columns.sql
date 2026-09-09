-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Migration: add database_name/rcsi_enabled to mssql_deadlock_events
-- Avekshaa Technologies
-- ============================================================
-- Run this if mssql_deadlock_events already exists with real data
-- (i.e. you already tested the deadlock collector before this
-- change) -- CREATE TABLE IF NOT EXISTS in mssql_deadlock_table.sql
-- won't retroactively add new columns to an existing table, only a
-- genuine ALTER TABLE will.
--
-- Safe to run on a fresh install too (IF NOT EXISTS guards) -- if
-- you haven't installed the deadlock tables at all yet, just run
-- mssql_deadlock_table.sql directly instead, it already includes
-- these columns.
-- ============================================================

\echo 'Adding database_name/rcsi_enabled to mssql_deadlock_events...'

ALTER TABLE mssql_deadlock_events ADD COLUMN IF NOT EXISTS database_name TEXT;
ALTER TABLE mssql_deadlock_events ADD COLUMN IF NOT EXISTS rcsi_enabled BOOLEAN;

\echo '  Migration complete -- existing rows will have NULL for both new columns'
\echo '  (the database/RCSI status wasnt captured for events collected before this change)'
