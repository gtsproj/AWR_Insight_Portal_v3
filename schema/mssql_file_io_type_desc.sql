-- ============================================================
-- Add file_type_desc to mssql_file_io_delta -- unblocks two
-- previously-deferred requests (log-specific Load Profile metrics,
-- datafile-vs-logfile I/O stalls) that both needed the same missing
-- piece: reliable data-vs-log file classification. File naming
-- (e.g. "TESTDB_log") is not a safe signal on its own -- some DBAs
-- name files differently -- so this uses sys.master_files.type_desc
-- directly ('ROWS', 'LOG', 'FILESTREAM', 'FULLTEXT'), the same
-- column the file-I/O collector already joins against for
-- logical_file_name, now captured alongside it rather than a second
-- lookup.
-- ============================================================

ALTER TABLE mssql_file_io_delta ADD COLUMN IF NOT EXISTS file_type_desc TEXT;

\echo 'mssql_file_io_delta.file_type_desc added.'
