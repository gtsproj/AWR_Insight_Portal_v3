-- ============================================================
-- Drop uq_awr_db_master_host_utility -- a real bug surfaced by
-- adding db_engine support: this index's own comment states the
-- intent as "same hostname cannot have both SAR and NMON registered,"
-- but the actual implementation (UNIQUE on (host_name, os_utility)
-- WHERE active) enforces something stricter -- only ONE active row
-- per (host_name, os_utility) combination, period. That accidentally
-- blocks two entirely DIFFERENT databases on the same host (e.g. an
-- Oracle instance and an MS SQL Server instance on the same dev/test
-- machine) once they share the same os_utility -- which is the
-- common case for 'NONE' (Windows hosts have no SAR/NMON equivalent,
-- so every database on a Windows host gets os_utility='NONE').
--
-- The actual intended rule (no mixing SAR and NMON on one host) is
-- already correctly enforced at the application level in
-- api_db_master_add (portal/app.py) -- it explicitly checks for an
-- OPPOSITE utility (SAR vs NMON) on the same host, and only fires
-- when os_utility IN ('SAR', 'NMON') -- never for 'NONE'. That check
-- is sufficient on its own; this DB-level index was an unintentionally
-- stricter backstop, not a necessary one.
-- ============================================================

DROP INDEX IF EXISTS uq_awr_db_master_host_utility;

\echo 'uq_awr_db_master_host_utility dropped -- multiple databases (any engine) can now share a host.'
\echo 'SAR/NMON mutual exclusivity per host is still enforced at the application level (portal/app.py).'
