-- ============================================================
-- Fix mssql_dmv_snapshot.snapshot_time's default -- a real,
-- significant bug this exposed: plain now() returns the value in
-- whatever timezone the Postgres SESSION is configured with, not
-- necessarily UTC. Every Query Store timestamp this column gets
-- compared against (mssql_qs_interval.start_time/end_time, via
-- sqlwr_report_generator.py's snapshot-window overlap query) is
-- EXPLICITLY normalized to naive UTC first (connection.py's
-- to_naive_utc(), used specifically because DATETIMEOFFSET carries
-- an unambiguous UTC offset and every downstream comparison needs a
-- single, consistent time reference). If snapshot_time was actually
-- being stored in local server time (IST, UTC+5:30, in the specific
-- case this was found from) while being compared directly against
-- UTC interval timestamps as if they were the same reference, that
-- mismatch alone explains an apparent "5+ hour gap" in Query Store
-- activity that never actually existed -- Query Store itself was
-- working completely normally the whole time.
--
-- (now() AT TIME ZONE 'utc') converts the current instant to an
-- explicit UTC wall-clock value regardless of the session's own
-- timezone setting -- correct and safe no matter what Postgres
-- happens to be configured with, not dependent on guessing or
-- confirming the exact prior misconfiguration first.
-- ============================================================

ALTER TABLE mssql_dmv_snapshot ALTER COLUMN snapshot_time SET DEFAULT (now() AT TIME ZONE 'utc');

\echo 'mssql_dmv_snapshot.snapshot_time default fixed to explicit UTC.'
\echo 'Existing rows are UNCHANGED by this -- their snapshot_time values were captured under the'
\echo 'old, timezone-dependent default and are not retroactively corrected. Only snapshots taken'
\echo 'from this point forward will be correctly comparable against Query Store''s UTC timestamps.'
