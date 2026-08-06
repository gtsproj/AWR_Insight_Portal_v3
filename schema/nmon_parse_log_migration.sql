-- ============================================================
-- nmon_parse_log migration — add incremental parse state columns
-- Run once on existing installations that already have nmon_parse_log.
-- Safe to run multiple times (IF NOT EXISTS / DO NOTHING).
-- ============================================================

ALTER TABLE nmon_parse_log
    ADD COLUMN IF NOT EXISTS last_token_seq INTEGER  DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_snap_time TIMESTAMP;

-- Status now includes 'partial' (incremental, more tokens expected)
-- Existing status constraint (if any) is not changed — 'partial' is
-- just a new value; no CHECK constraint was applied previously.

COMMENT ON COLUMN nmon_parse_log.last_token_seq IS
    'Last Txxxx sequence number fully processed (e.g. 288 for T0288). '
    'Incremental parse resumes from last_token_seq + 1 on next pull.';

COMMENT ON COLUMN nmon_parse_log.last_snap_time IS
    'Timestamp of the last snapshot processed — used for anomaly detection range.';
