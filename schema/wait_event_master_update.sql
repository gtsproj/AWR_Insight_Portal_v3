-- ============================================================
-- awr_wait_event_master — add guidance columns
-- Run once. Safe to re-run (ADD COLUMN IF NOT EXISTS).
-- ============================================================

ALTER TABLE awr_wait_event_master
  ADD COLUMN IF NOT EXISTS corr_type         TEXT,
  ADD COLUMN IF NOT EXISTS seg_filter        TEXT,
  ADD COLUMN IF NOT EXISTS has_specific_rule BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS guidance_text     TEXT;

-- corr_type values:
--   io_read      → join segments by physical_reads
--   io_write     → join segments by physical_writes
--   buffer_busy  → join segments by buffer_busy_waits
--   row_lock     → join segments by row_lock_waits
--   gc_cluster   → join segments by gc_buffer_busy
--   none         → no segment correlation is valid
--
-- seg_filter values:
--   all          → all segment types
--   index_only   → INDEX family only (single-block reads are index-driven)
--   table_only   → TABLE / LOB / CLUSTER only (multi-block / direct-path reads)
--   none         → no segment shown (corr_type=none)

-- ═══════════════════════════════════════════════════════════════
-- USER I/O — events with segment correlation
-- ═══════════════════════════════════════════════════════════════

-- Single-block reads: INDEX and UNDO segments only.
-- Tables are never the direct cause of this wait; index leaf/branch
-- blocks and ROWID lookups via an index are. Do NOT show tables here.
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file sequential read','User I/O','io_read','index_only',true,
'Single-block I/O — index leaf/branch reads or ROWID table access after an index lookup. Root cause: deep B-tree (high BLEVEL), poor clustering factor, or buffer cache miss on hot index blocks. (1) Check BLEVEL of hot indexes — rebuild if BLEVEL > 4. (2) Check clustering_factor vs num_rows — if ratio > 0.5, consider reorganising the table. (3) Increase DB_CACHE_SIZE or assign hot indexes to the KEEP buffer pool.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Multi-block / direct-path reads: TABLE and LOB segments only.
-- These bypass the buffer cache and target table extents / LOB segments,
-- never index blocks. Do NOT show indexes here.
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('direct path read','User I/O','io_read','table_only',true,
'Multi-block read bypassing buffer cache — full table scan, parallel query, or large LOB read. Root cause: missing partition pruning, missing selective index, or intentional analytics scan. (1) Check for missing indexes on high-selectivity filter columns. (2) For analytics: validate partition pruning is active and parallel degree is appropriate. (3) For LOB reads: consider SecureFile LOB with CACHE option.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file scattered read','User I/O','io_read','table_only',true,
'Multi-block scattered read — full table or fast full index scan in non-parallel context. Root cause: missing indexes or large range scans. (1) Identify the full-scan SQL in Top SQL dashboard. (2) Set DB_FILE_MULTIBLOCK_READ_COUNT appropriately (128 for SSD). (3) Consider parallel query to shift reads to direct path for large analytics.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Exadata smart scan variants: map to same segment filters as their equivalents
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell smart table scan','User I/O','io_read','table_only',false,
'Exadata smart scan of a table — full segment scan offloaded to storage cell. Root cause: missing partition pruning or large analytics scan. (1) Enable storage index via partition pruning. (2) Check cell offload eligibility. (3) Review predicate pushdown to storage cells.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell smart index scan','User I/O','io_read','index_only',false,
'Exadata smart scan of an index — index read offloaded to storage cell. Root cause: deep B-tree or large index range scan. (1) Check BLEVEL of hot indexes. (2) Ensure cell offload is enabled for index scans. (3) Review index selectivity.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell single block physical read','User I/O','io_read','index_only',false,
'Exadata single-block physical read — equivalent to db file sequential read on Exadata. Root cause: index block read or ROWID lookup. (1) Check BLEVEL and clustering factor of hot indexes. (2) Review buffer cache hit ratio. (3) Assign hot indexes to the KEEP buffer pool.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell single block read request','User I/O','io_read','index_only',false,
'Exadata single-block read request — index or ROWID read submitted to storage cell. Root cause same as db file sequential read. (1) Check hot indexes for high BLEVEL. (2) Review buffer cache sizing. (3) Check storage cell response times.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell multiblock physical read','User I/O','io_read','table_only',false,
'Exadata multiblock physical read — full table or LOB scan on storage cells. (1) Review partition pruning on scanned tables. (2) Validate storage cell offload efficiency. (3) Check if parallel query is appropriate for the scan pattern.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell multiblock read request','User I/O','io_read','table_only',false,
'Exadata multiblock read request — storage cell multiblock read for table/LOB scans. (1) Review partition pruning. (2) Check cell offload eligibility. (3) Validate parallel degree for large scans.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell list of blocks physical read','User I/O','io_read','all',false,
'Exadata list-of-blocks physical read — targeted block read from storage cells. Can involve any segment type. (1) Identify the SQL driving this read pattern. (2) Review execution plan for the targeted segment. (3) Check storage cell performance.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cell list of blocks read request','User I/O','io_read','all',false,
'Exadata list-of-blocks read request — targeted block list read submitted to cells. Can involve any segment type. (1) Identify the SQL driving this. (2) Review execution plan. (3) Check storage cell response times.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Parallel read: can involve any segment type (parallel recovery, parallel query)
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file parallel read','User I/O','io_read','all',false,
'Parallel block read — used during parallel recovery or parallel prefetch. All segment types may be involved. (1) If during normal operations: check for parallel query prefetch activity. (2) If during recovery: normal and expected. (3) Review storage I/O throughput on SAR dashboard.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Write waits: io_write
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('local write wait','User I/O','io_write','all',false,
'Session waiting for a local write to complete — typically a dirty buffer being written before it can be reused. Root cause: slow storage or DBWn contention. (1) Check data file storage latency on SAR dashboard. (2) Review DB_WRITER_PROCESSES. (3) Enable async I/O.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file single write','User I/O','io_write','all',false,
'Single-block write — file header update or single block flush. Root cause: slow storage on file header device or checkpoint activity. (1) Check file header I/O latency. (2) Review checkpoint frequency. (3) Verify all datafile paths have adequate I/O performance.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- SecureFile reads: LOB/TABLE only
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('securefile direct-read completion','User I/O','io_read','table_only',false,
'SecureFile LOB direct read completion — reading LOB data outside the buffer cache. Root cause: LOB NOCACHE or large LOB access frequency. (1) Convert to SecureFile LOBs with CACHE option. (2) Consider LOB compression for large objects. (3) Review whether LOB data should be externalised for very large files.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('securefile direct-write completion','User I/O','io_write','table_only',false,
'SecureFile LOB direct write completion — writing LOB data directly to storage. Root cause: high-frequency LOB writes. (1) Review LOB write frequency in application. (2) Consider SecureFile with compression. (3) Ensure LOB tablespace is on fast storage.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Buffer read retry: concurrency variant of buffer read
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('read by other session','User I/O','buffer_busy','all',true,
'Session waiting for another session to finish loading a block from disk. Root cause: buffer cache too small causing repeated cold reads of hot blocks. (1) Increase DB_CACHE_SIZE to retain hot blocks. (2) Assign critical lookup tables to KEEP buffer pool. (3) Reduce full scans that evict hot blocks from cache.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('buffer read retry','User I/O','buffer_busy','all',false,
'Block read retry — block being read was found to be invalid or in flux, requiring a retry. Root cause: hot block being concurrently modified. (1) Check for buffer busy waits on the same segments. (2) Increase INITRANS on hot tables/indexes. (3) Review concurrent DML patterns on hot objects.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Direct path write: io_write for non-temp (bulk loads, CTAS)
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('direct path write','User I/O','io_write','all',true,
'Direct path write — bulk load (CTAS, INSERT APPEND) bypassing buffer cache, or sort/hash spill to temp. (1) Check PGA usage — increase PGA_AGGREGATE_TARGET to reduce sort/hash spills. (2) For bulk loads: ensure NOLOGGING is used where applicable. (3) Validate temp tablespace I/O throughput on SAR dashboard.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- ═══════════════════════════════════════════════════════════════
-- USER I/O — events with NO segment correlation
-- (infrastructure I/O, not associated with specific user segments)
-- ═══════════════════════════════════════════════════════════════

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('direct path read temp','User I/O','none','none',false,
'Temp tablespace read — sort/hash workarea spilling to temp. No user segment involved. (1) Increase PGA_AGGREGATE_TARGET. (2) Identify spilling SQL via V$SQL_WORKAREA_ACTIVE. (3) Ensure temp tablespace is on fast SSD storage.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('direct path write temp','User I/O','none','none',false,
'Temp tablespace write — sort/hash workarea spilling to temp. No user segment involved. (1) Increase PGA_AGGREGATE_TARGET. (2) Review execution plans for large sort/hash joins. (3) Add sort-elimination indexes where ORDER BY is frequent.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Infrastructure User I/O — these are all operating on Oracle internals, not user segments
DO $$ DECLARE events TEXT[] := ARRAY[
  'Parameter File I/O','Disk file I/O Calibration','Disk file Mirror Read',
  'Disk file Mirror/Media Repair Write','Disk file operations I/O',
  'Data file init write','Log file init write','File Copy',
  'Pluggable Database file copy','Shared IO Pool IO Completion',
  'Datapump dump file I/O','dbms_file_transfer I/O',
  'DG Broker configuration file I/O','dbverify reads',
  'BFILE read','utl_file I/O','TEXT: File System I/O',
  'DNFS disp IO slave completion','external table read','external table write',
  'external table open','external table seek','external table misc IO',
  'ASM sync cache disk read','ASM IO for non-blocking poll',
  'ASM Fixed Package I/O','ASM Staleness File I/O','ASM File Group Sync',
  'Archive Manager file transfer I/O','flashback log file sync',
  'direct path sync','cell smart file creation','cell statistics gather',
  'cell external table smart scan','cell physical read no I/O',
  'db flash cache single block physical read','db flash cache multiblock physical read',
  'db flash cache write'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e, (SELECT wait_class FROM awr_wait_event_master WHERE lower(event)=lower(e) LIMIT 1),
            'none','none',false,
            'Infrastructure I/O — this event operates on Oracle internal files (parameter files, flashback logs, external tables, ASM, flash cache, etc.), not on user data segments. (1) Check SAR I/O dashboard for storage device latency. (2) Review the specific subsystem involved (ASM, Datapump, external tables, etc.). (3) See Oracle documentation for this event class.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- SYSTEM I/O — all background-process I/O
-- ═══════════════════════════════════════════════════════════════

-- DBWR and slave writes: io_write (only ones with segment correlation)
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('db file parallel write','System I/O','io_write','all',true,
'DBWR writing dirty buffers to datafiles. Root cause: data file device latency, insufficient DBWn processes, or checkpoint storms. (1) Check data file storage latency on SAR I/O dashboard. (2) Increase DB_WRITER_PROCESSES. (3) Enable async I/O (FILESYSTEMIO_OPTIONS=SETALL or use ASM).')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('DBWR slave I/O','System I/O','io_write','all',false,
'DBWR slave process writing dirty buffers — same root cause as db file parallel write. (1) Check data file storage latency on SAR I/O dashboard. (2) Increase DB_WRITER_PROCESSES if this slave is bottlenecked. (3) Enable async I/O.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Control file operations: no segment correlation
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('control file sequential read','System I/O','none','none',true,
'Control file read by background process (ARCn, RMAN, CKPT). No user segment involved. (1) Ensure all control file copies are on fast storage. (2) Reduce log switch frequency by increasing redo log file size. (3) Review RMAN backup schedule — frequent backups update the control file repeatedly.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('control file parallel write','System I/O','none','none',true,
'Control file write by background process (log switches, checkpoints, RMAN). No user segment involved. (1) Ensure all control file copies are on fast storage (avoid NFS-mounted paths). (2) Reduce log switch frequency. (3) Review RMAN backup frequency during peak hours.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('control file single write','System I/O','none','none',false,
'Control file single-block write — usually a file header or checkpoint record update. No user segment involved. (1) Ensure control file copies are on fast storage. (2) This is typically low-frequency and benign unless it dominates wait time. (3) Correlate with log switch frequency if elevated.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Redo log writes: no segment correlation
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('log file parallel write','System I/O','none','none',true,
'LGWR writing redo to redo log files — redo storage latency. No segment involved. (1) Move redo logs to dedicated SSD. (2) Enable write-back cache on the redo log storage device. (3) Verify redo log multiplexing does not include slow members.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- All remaining System I/O events: background process I/O, no segment correlation
DO $$ DECLARE events TEXT[] := ARRAY[
  'Standby redo I/O','Network file transfer','File Repopulation Write',
  'PBR logfile IO','PBR logfile block write','recovery read',
  'RFS sequential i/o','RFS random i/o','RFS write',
  'log file sequential read','log file single write',
  'log file pmem persist write','log file pmem persist read',
  'db file async I/O submit','flashback log file write','flashback log file read',
  'cell smart incremental backup','cell smart restore from backup',
  'ASM sync relocation I/O','ASM async relocation I/O','kfk: async disk IO',
  'iowp io','cell manager opening cell','cell manager closing cell',
  'RMAN lost write reread','RMAN backup & recovery I/O','Log archive I/O',
  'Clonedb bitmap file write','Archiver slave I/O','LGWR slave I/O',
  'RMAN Tape slave I/O','RMAN Disk slave I/O',
  'cell manager discovering disks','io done'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'System I/O','none','none',false,
            'Background process I/O — this event involves Oracle infrastructure I/O (redo logs, archiver, RMAN, standby, ASM) performed by background processes. No user segment is involved. (1) Check SAR I/O dashboard for storage device latency on the relevant devices. (2) Review the background process health (alert log). (3) Schedule heavy background I/O (RMAN, archiving) during off-peak hours where possible.')
    ON CONFLICT (event) DO UPDATE SET
      corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,
      has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- COMMIT — redo/commit waits, no segment correlation
-- ═══════════════════════════════════════════════════════════════

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('log file sync','Commit','none','none',true,
'Session waiting for LGWR to flush redo on commit. No segment involved — this is redo I/O latency. (1) Move redo logs to dedicated fast storage (SSDs). (2) Batch application commits to reduce flush frequency. (3) Increase LOG_BUFFER to 256MB–1GB.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

DO $$ DECLARE events TEXT[] := ARRAY[
  'remote log force - commit','nologging standby txn commit',
  'Nologging standby progress','enq: BB - 2PC across RAC instances'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Commit','none','none',false,
            'Commit/redo synchronisation wait — no user segment involved. Root cause: redo I/O latency or distributed transaction coordination overhead. (1) Check redo log storage latency on SAR dashboard. (2) Review distributed transaction (dblink) commit frequency. (3) Batch commits where possible to reduce LGWR flush overhead.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION — redo/log/segment space events
-- ═══════════════════════════════════════════════════════════════

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('free buffer waits','Configuration','buffer_busy','all',true,
'Server process cannot find a free buffer — DBWn not writing dirty buffers fast enough. (1) Check data file I/O latency on SAR dashboard. (2) Increase DB_WRITER_PROCESSES. (3) Increase DB_CACHE_SIZE if memory allows.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('write complete waits','Configuration','buffer_busy','all',false,
'Session waiting for a buffer write to complete before it can be modified. Root cause: slow storage causing write-side buffer contention. (1) Check data file storage latency. (2) Review DB_WRITER_PROCESSES count. (3) Enable async I/O if not already enabled.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('write complete waits: flash cache','Configuration','buffer_busy','all',false,
'Session waiting for a flash cache write to complete. Root cause: flash cache device latency or saturation. (1) Check flash cache device health and performance. (2) Review flash cache sizing (DB_FLASH_CACHE_SIZE). (3) Consider disabling flash cache if device is consistently bottlenecked.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- ITL wait: buffer_busy variant — specific to segment blocks
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('enq: TX - allocate ITL entry','Configuration','buffer_busy','all',false,
'Insufficient ITL (Interested Transaction List) entries in a block — concurrent transactions cannot fit their ITL entries. (1) Increase INITRANS on the hot table or index. (2) Increase PCTFREE to leave more space for ITL expansion. (3) Review concurrent DML patterns on the affected object.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Undo/segment space events: no user segment
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('undo segment extension','Configuration','none','none',false,
'Undo segment needing to extend — undo tablespace space or extent allocation delay. No user data segment involved. (1) Increase undo tablespace size. (2) Increase UNDO_RETENTION to reduce premature undo reuse. (3) Enable RETENTION GUARANTEE on the undo tablespace.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('undo segment tx slot','Configuration','none','none',false,
'No free transaction slot available in the undo segment header. Root cause: undo segment too small or too many concurrent transactions. (1) Ensure UNDO_MANAGEMENT=AUTO and undo tablespace is adequately sized. (2) Increase number of undo segments (or ensure auto-undo is not constrained). (3) Review concurrent transaction count.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Redo/log configuration events: no segment
DO $$ DECLARE events TEXT[] := ARRAY[
  'log buffer space','log file switch (checkpoint incomplete)',
  'log file switch (archiving needed)',
  'log file switch (private strand flush incomplete)','log file switch completion',
  'latch: redo copy','latch: redo writing'
];
DECLARE e TEXT; DECLARE msgs TEXT[] := ARRAY[
  'Redo log buffer exhausted — sessions cannot write redo fast enough. (1) Increase LOG_BUFFER to 256MB–1GB. (2) Check LGWR latency (log file parallel write). (3) Reduce unnecessary redo — use NOLOGGING for bulk loads.',
  'Log switch blocked — checkpoint for reuse group not yet complete. (1) Increase redo log file size (min 500MB, target 1–4GB). (2) Add more redo log groups. (3) Increase DB_WRITER_PROCESSES.',
  'URGENT — Log switch blocked; ARCn cannot archive fast enough. (1) Check archive destination space immediately. (2) Increase LOG_ARCHIVE_MAX_PROCESSES to 4–8. (3) Increase redo log file size as immediate relief.',
  'Log switch blocked — private strand flush not yet complete. (1) Increase redo log file size. (2) Review private strand flush settings. (3) Add more redo log groups.',
  'Waiting for log file switch to complete. (1) Increase redo log file size. (2) Add more log groups. (3) Check LGWR I/O performance.',
  'Redo copy latch contention — very high redo generation rate. (1) Increase LOG_BUFFER. (2) Batch DML to reduce redo allocation. (3) Use NOLOGGING for bulk operations.',
  'Redo write latch contention — LGWR I/O serialisation. (1) Move redo logs to dedicated SSDs. (2) Increase LOG_BUFFER. (3) Ensure async I/O is enabled for redo.'
];
DECLARE i INT := 1;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,(SELECT wait_class FROM awr_wait_event_master WHERE lower(event)=lower(e) LIMIT 1),
            'none','none',
            (e IN ('log buffer space','log file switch (checkpoint incomplete)','log file switch (archiving needed)')),
            msgs[i])
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
    i := i + 1;
  END LOOP;
END $$;

-- Sort/HW/space configuration events: no segment
DO $$ DECLARE events TEXT[] := ARRAY[
  'enq: HW - contention','enq: ST - contention','sort segment request',
  'enq: SQ - contention','enq: SS - contention','enq: SV - contention',
  'checkpoint completed','memoptimize write buffer get',
  'SecureFile log buffer','nologging range consumption list',
  'statement suspended wait error to be cleared',
  'Global transaction acquire instance locks','flashback buf free by RVWR',
  'wait for EMON to process ntfns','REPL Apply: commit'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Configuration','none','none',false,
            'Configuration or space management wait — no direct user segment correlation. Root cause is typically space allocation, segment extension, or instance configuration constraints. (1) Check tablespace free space and extent sizing. (2) Review relevant Oracle parameters (NEXT extent, PCTINCREASE). (3) Check alert log for related errors.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- CONCURRENCY — block-level (valid segment correlation)
-- ═══════════════════════════════════════════════════════════════

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('buffer busy waits','Concurrency','buffer_busy','all',true,
'Multiple sessions competing for the same buffer block. Root cause: hot segment blocks — frequently updated index leaf blocks or hot table rows. (1) Increase INITRANS on hot tables/indexes. (2) For index leaf contention: consider reverse-key index or hash partitioning. (3) For sequence inserts: use sequence cache to reduce monotonic clustering.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- enq: TX - index contention: ITL/index block split contention — buffer_busy
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('enq: TX - index contention','Concurrency','buffer_busy','index_only',false,
'Index block split contention — a session is waiting for another to complete an index block split. Root cause: right-side index block splits on monotonically increasing keys (sequences, timestamps). (1) Consider reverse-key index for sequence-generated keys. (2) Use hash partitioning to distribute inserts. (3) Increase index INITRANS to reduce split frequency.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- In-memory buffer busy: buffer_busy
DO $$ DECLARE events TEXT[] := ARRAY[
  'IM buffer busy','IM buffer busy TXN','IM buffer busy SHR'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Concurrency','buffer_busy','table_only',false,
            'In-Memory buffer contention — concurrent access to an In-Memory Column Store (IMCS) buffer for a table. Root cause: high concurrent read/write on an In-Memory populated table. (1) Review IMCS population status and compression. (2) Check for concurrent DML invalidating IMCS buffers. (3) Review INMEMORY_MAX_POPULATE_SERVERS setting.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- CONCURRENCY — latch/mutex/library cache (NO segment correlation)
-- ═══════════════════════════════════════════════════════════════

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('latch: cache buffers chains','Concurrency','none','none',true,
'Hot block contention at the latch level — a buffer block is accessed by so many concurrent sessions that the latch serialises access. (1) Identify the hot block using X$BH (addr, obj, tch columns). (2) For sequence inserts: enable sequence caching, consider reverse-key index. (3) Hash partition the hot segment to spread block access.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('latch: shared pool','Concurrency','none','none',true,
'Shared pool latch contention — heavy parse activity or fragmentation. (1) Enforce bind variable usage across all application SQL. (2) Increase SHARED_POOL_SIZE. (3) Pin critical packages with DBMS_SHARED_POOL.KEEP.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('latch: row cache objects','Concurrency','none','none',true,
'Data dictionary (row cache) latch contention. (1) Avoid DDL during peak hours. (2) Increase SHARED_POOL_SIZE. (3) Reduce metadata-intensive operations.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('cursor: pin S wait on X','Concurrency','none','none',true,
'Cursor pin contention — a session holds an exclusive cursor pin while others wait for shared. (1) Enforce bind variable usage to reduce hard parse rate. (2) Avoid DDL on hot objects during peak. (3) Review CURSOR_INVALIDATION parameter (12.2+).')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('library cache lock','Concurrency','none','none',true,
'Library cache object lock contention — DDL on a hot object or procedure recompilation. (1) Avoid DDL on hot procedures/packages during peak hours. (2) Check DBA_OBJECTS for INVALID objects auto-recompiling. (3) Review dependency chains — compilations cascade to dependents.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('library cache load lock','Concurrency','none','none',true,
'Library cache load contention — multiple sessions loading the same object simultaneously. (1) Pin critical packages with DBMS_SHARED_POOL.KEEP. (2) Pre-warm library cache after startup. (3) Reduce invalidation frequency.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('library cache: mutex X','Concurrency','none','none',true,
'Library cache mutex contention — high parse rate. (1) Enforce bind variable usage. (2) Review CURSOR_SHARING parameter. (3) Tune SESSION_CACHED_CURSORS and OPEN_CURSORS.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- All remaining Concurrency latch/mutex/cursor/library variants: no segment correlation
DO $$ DECLARE events TEXT[] := ARRAY[
  'cursor: mutex X','cursor: mutex S','cursor: pin X','cursor: pin S',
  'library cache pin','library cache: bucket mutex X',
  'library cache: dependency mutex X','library cache: mutex S',
  'latch: MGA shared context root latch','latch: MGA shared context latch',
  'latch: MGA heap latch','latch: MGA pid alloc latch','latch: MGA asr alloc latch',
  'latch: Undo Hint Latch','latch: In memory undo latch','latch: MQL Tracking Latch',
  'log file sync: SCN ordering','logout restrictor','pipe put',
  'resmgr:internal state change','resmgr:sessions to exit',
  'result cache lock wait','row cache lock','row cache mutex','row cache read',
  'Shared IO Pool Memory','Unpin a recreatable chunk','LCK0 row cache object free',
  'libcache interrupt action by LCK','db flash cache invalidate wait',
  'enq: IV - cross instance invalidation','enq: CB - role operation',
  'enq: RI - Reader Farm SQL Isolation','enq: TG - IMCDT global resource',
  'enq: TI - IMCDT object HT','enq: KV - IMA key vector access',
  'enq: BE - Critical Block Allocation','enq: HV - contention',
  'enq: WG - lock fso','securefile chain update','SecureFile mutex',
  'Cube Build Master Wait for Jobs','REPL Apply: dependency',
  'Inmemory Populate: get loadscn'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Concurrency','none','none',false,
            'Memory structure contention (latch, mutex, cursor, or library cache wait) — no user segment correlation. These waits reflect in-memory structure contention. (1) Enforce bind variable usage to reduce hard parsing. (2) Increase SHARED_POOL_SIZE. (3) Pin critical PL/SQL packages with DBMS_SHARED_POOL.KEEP.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- APPLICATION — lock and enqueue events
-- ═══════════════════════════════════════════════════════════════

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('enq: TX - row lock contention','Application','row_lock','all',true,
'Row-level lock contention — sessions blocking each other on the same rows. (1) Identify blocking sessions from AWR Active Session History. (2) Ensure frequent commits in high-DML batch processes. (3) Review INITRANS on hot tables — increase to allow more concurrent row-level modifications.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('enq: TM - contention','Application','row_lock','all',true,
'Table-level lock contention — most commonly caused by DML on a parent table with an unindexed foreign key on the child. (1) Identify unindexed FK columns: query DBA_CONSTRAINTS joined to DBA_IND_COLUMNS. (2) Create indexes on all FK columns in child tables. (3) Avoid concurrent DDL on high-DML tables.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('Wait for Table Lock','Application','row_lock','table_only',false,
'Waiting for a table-level lock held by another session. Root cause: DDL-DML contention or explicit LOCK TABLE statement. (1) Identify the blocking session and its lock type from V$LOCK and V$SESSION. (2) Avoid DDL (ALTER, DROP, TRUNCATE) on tables with concurrent DML during peak hours. (3) Review application for unnecessary LOCK TABLE statements.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- Other Application events: no segment correlation
DO $$ DECLARE events TEXT[] := ARRAY[
  'SQL*Net break/reset to client','SQL*Net break/reset to dblink',
  'External Procedure initial connection','External Procedure call',
  'OLAP DML Sleep','REPL Apply: apply DDL','REPL Capture: filter callback ruleset',
  'WCR: replay lock order','enq: UL - contention',
  'enq: KO - fast object checkpoint','enq: PW - flush prewarm buffers',
  'enq: RC - Result Cache: Contention','enq: RO - contention',
  'enq: RO - fast object reuse'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Application','none','none',false,
            'Application-level wait — this event reflects application behaviour or inter-process coordination rather than segment I/O contention. (1) Check the Oracle documentation for the specific enqueue or application mechanism involved. (2) Review the application for the specific operation causing this wait. (3) See the Active Recommendations panel if a rule covers this event.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- CLUSTER — RAC events
-- ═══════════════════════════════════════════════════════════════

-- Block-transfer events: gc_cluster correlation
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('gc buffer busy acquire','Cluster','gc_cluster','all',true,
'RAC global cache block contention — hot blocks being transferred between instances. (1) Configure service affinity to route related transactions to the same instance. (2) Partition hot tables and pin partitions to specific instances. (3) Review interconnect bandwidth on SAR network dashboard.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('gc buffer busy release','Cluster','gc_cluster','all',true,
'RAC global cache block release wait. (1) Configure service affinity. (2) Review interconnect latency — target < 1ms. (3) Check for unindexed FK columns causing cross-instance TM lock shipping.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('gc cr request','Cluster','gc_cluster','all',true,
'RAC consistent-read block transfer — instance requesting a CR copy from another instance. (1) Configure read workload affinity per service. (2) Increase buffer cache size to reduce cross-instance reads. (3) Verify interconnect latency < 1ms on SAR dashboard.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('gc current request','Cluster','gc_cluster','all',true,
'RAC current block transfer — requesting writable copy from another instance. (1) Route DML transactions to a single primary instance via services. (2) Hash partition high-DML tables with partition-wise service routing. (3) Check for unindexed FK columns.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- All gc cr/current block/grant variants: gc_cluster correlation
DO $$ DECLARE events TEXT[] := ARRAY[
  'gc cr block 2-way','gc cr block 3-way','gc cr block busy','gc cr block congested',
  'gc cr block lost','gc cr block remote read','gc cr failure',
  'gc cr grant 2-way','gc cr grant 3-way','gc cr grant busy','gc cr grant congested',
  'gc cr grant ka','gc cr grant read-mostly invalidation',
  'gc cr grant read-only instance invalidation','gc cr grant cluster flash cache read',
  'gc cr cluster flash cache read','gc cr disk read','gc cr disk request',
  'gc cr flash cache copy','gc cr multi block request','gc cr multi block mixed',
  'gc cr multi block grant','gc cr cancel','gc cr disk request',
  'gc current block 2-way','gc current block 3-way','gc current block busy',
  'gc current block congested','gc current block lost','gc current retry',
  'gc current split','gc current cancel','gc current grant 2-way',
  'gc current grant 3-way','gc current grant busy','gc current grant congested',
  'gc current grant ka','gc current grant cluster flash cache read',
  'gc current grant read-mostly invalidation','gc current grant read-only instance invalidation',
  'gc current multi block request','gc current index split',
  'gc block recovery request','gc imc multi block request','gc imc multi block quiesce',
  'gc flushed buffer','gc index operation'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Cluster','gc_cluster','all',false,
            'RAC global cache block transfer event — blocks being shipped between instances. (1) Configure service-based workload routing to reduce cross-instance block requests. (2) Check interconnect latency and bandwidth on SAR network dashboard. (3) Review partition strategy for hot segments.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- RAC admin/infrastructure cluster events: no segment correlation
DO $$ DECLARE events TEXT[] := ARRAY[
  'ASM PST query : wait for [PM][grp][0] grant','lock remastering',
  'gc transaction table','gc freelist','gc remaster','gc quiesce',
  'gc recovery','gc flushed buffer','gc send complete','gc assume',
  'gc domain validation','gc recovery free','gc recovery quiesce',
  'gc claim','gc cancel retry','Service operation completion',
  'service monitor: inst recovery completion','retry contact SCN lock master',
  'pi renounce write complete','remote log force - buffer update',
  'remote log force - buffer read','remote log force - SCN range',
  'remote log force - session cleanout','remote log force - log switch/recovery'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Cluster','none','none',false,
            'RAC cluster management or infrastructure event — no user segment correlation. This event relates to RAC instance coordination, lock mastering, or infrastructure messaging. (1) Check interconnect health and latency on SAR network dashboard. (2) Review GCS/GES background process health in the alert log. (3) Investigate only if this event dominates alongside other RAC performance issues.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- NETWORK — no segment correlation
-- ═══════════════════════════════════════════════════════════════

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('SQL*Net message from client','Idle','none','none',true,
'Idle wait — session waiting for the next request from the client. Not a database bottleneck. (1) If this dominates DB time, focus on the non-idle waits. (2) Review connection pool min/max sizing. (3) Implement idle session timeout to release unused connections.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('SQL*Net more data to client','Network','none','none',true,
'Large resultset transfer to client — network or fetch bottleneck. (1) Implement result pagination (ROWNUM/ROW_NUMBER). (2) Avoid SELECT * on wide tables. (3) Increase SDU for batch/reporting connections.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('SQL*Net message from dblink','Network','none','none',false,
'Session waiting for a response from a remote database over a database link. No local segment involved. (1) Check network latency between local and remote DB. (2) Review the query using the dblink — avoid fetching large result sets row-by-row. (3) Consider materialising frequently-accessed remote data locally.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- All other Network events: no segment correlation
DO $$ DECLARE events TEXT[] := ARRAY[
  'remote db operation','ASM remote SQL','remote db file write','remote db file read',
  'IPC group service call','Data Guard network buffer stall reap',
  'ARCH wait for net re-connect','ARCH wait for netserver start',
  'LNS wait on LGWR','LGWR wait on LNS','ARCH wait for netserver init 2',
  'ARCH wait for flow-control','ARCH wait for netserver detach',
  'TCP Socket (KGAS)','virtual circuit wait','dispatcher listen timer',
  'dedicated server timer','connection broker handoff',
  'SQL*Net message to client','SQL*Net message to dblink',
  'SQL*Net more data to dblink','SQL*Net more data from client',
  'SQL*Net more data from dblink','SQL*Net vector data to client',
  'SQL*Net vector data from client','SQL*Net vector data to dblink',
  'SQL*Net vector data from dblink','TEXT: URL_DATASTORE network wait'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,(SELECT wait_class FROM awr_wait_event_master WHERE lower(event)=lower(e) LIMIT 1),
            'none','none',false,
            'Network or inter-process communication wait — no user segment involved. This event reflects session, network, or cross-database communication latency. (1) Check network latency between DB and application tier. (2) Review connection pool settings and idle session timeout. (3) For Data Guard / dblink events: check remote DB performance and network bandwidth.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- SCHEDULER — Resource Manager and PX scheduling
-- ═══════════════════════════════════════════════════════════════

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('resmgr:cpu quantum','Scheduler','none','none',true,
'Sessions throttled by Oracle Resource Manager — CPU quantum exhausted. (1) Review Resource Manager plan and consumer group CPU allocations. (2) Identify which sessions/users are being throttled. (3) Increase CPU allocation for critical consumer groups or adjust SWITCH_TIME thresholds.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

DO $$ DECLARE events TEXT[] := ARRAY[
  'resmgr:become active','resmgr: I/O rate limit','resmgr:large I/O queued',
  'resmgr:pq queued','resmgr: redo throttle',
  'PX Queuing: statement queue','enq: JX - cleanup of queue',
  'enq: JX - SQL statement queue','acknowledge over PGA limit'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Scheduler','none','none',false,
            'Resource Manager or scheduler throttling — no segment correlation. (1) Review Resource Manager plan and consumer group allocations. (2) Check if runaway queries are causing throttling of legitimate workloads. (3) Review PX statement queue configuration if parallel query is involved.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- ADMINISTRATIVE — all infrastructure admin events
-- ═══════════════════════════════════════════════════════════════

DO $$ DECLARE events TEXT[] := ARRAY[
  'ASM COD rollback operation completion','ASM mount : wait for heartbeat',
  'JS kgl get object wait','JS kill job wait','JS coord start wait',
  'Backup: MML initialization','Backup: MML v1 open backup piece',
  'Backup: MML v1 read backup piece','Backup: MML v1 write backup piece',
  'Backup: MML v1 close backup piece','Backup: MML v1 query backup piece',
  'Backup: MML v1 delete backup piece','Backup: MML create a backup piece',
  'Backup: MML commit backup piece','Backup: MML command to channel',
  'Backup: MML shutdown','Backup: MML obtain textual error',
  'Backup: MML query backup piece','Backup: MML extended initialization',
  'Backup: MML read backup piece','Backup: MML delete backup piece',
  'Backup: MML restore backup piece','Backup: MML write backup piece',
  'Backup: MML proxy initialize backup','Backup: MML proxy cancel',
  'Backup: MML proxy commit backup piece','Backup: MML proxy session end',
  'Backup: MML datafile proxy backup?','Backup: MML datafile proxy restore?',
  'Backup: MML proxy initialize restore','Backup: MML proxy start data movement',
  'Backup: MML data movement done?','Backup: MML proxy prepare to start',
  'Backup: MML obtain a direct buffer','Backup: MML release a direct buffer',
  'Backup: MML get base address','Backup: MML query for direct buffers',
  'OFS operation completion','BA: Performance API',
  'control file backup creation','multiple dbwriter suspend/resume for file offline',
  'db flash cache dynamic disabling wait','switch logfile command',
  'enq: MV - datafile move','datafile pre-create',
  'wait for possible quiesce finish','concurrent I/O completion',
  'datafile copy range completion','switch undo - offline','alter rbs offline',
  'enq: TW - contention','index (re)build online start',
  'index (re)build online cleanup','index (re)build online merge',
  'index (re)build lock or pin object','alter system set dispatcher',
  'connection pool wait','enq: DB - contention','enq: ZG - contention'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Administrative','none','none',false,
            'Administrative wait — database management operation (backup, datafile management, index rebuild, control file, space management). No user segment correlation. (1) Schedule administrative operations (RMAN, index rebuilds, datafile moves) during off-peak hours. (2) Review the specific administrative operation from the alert log. (3) Check SAR I/O dashboard for storage impact during the operation.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- QUEUEING — Streams AQ / LogMiner flow control
-- ═══════════════════════════════════════════════════════════════

DO $$ DECLARE events TEXT[] := ARRAY[
  'LogMiner builder: DDL','LogMiner builder: memory','LogMiner preparer: memory',
  'LogMiner reader: buffer','REPL Capture/Apply: flow control',
  'REPL Capture/Apply: memory','REPL Capture: subscribers to catch up',
  'Streams AQ: enqueue blocked due to flow control',
  'Streams AQ: enqueue blocked on low memory'
];
DECLARE e TEXT;
BEGIN
  FOREACH e IN ARRAY events LOOP
    INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
    VALUES (e,'Queueing','none','none',false,
            'Streams AQ or LogMiner flow control / memory wait — no user segment correlation. Root cause: replication or capture process is falling behind or memory-constrained. (1) Increase Streams Pool size (STREAMS_POOL_SIZE). (2) Review downstream consumer throughput and lag. (3) Check alert log for capture/apply process errors.')
    ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- OTHER events — fix the two known events that were mismatched
-- ═══════════════════════════════════════════════════════════════

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('latch free','Other','none','none',true,
'Generic latch wait — a session is waiting for an unspecified latch. (1) Identify the specific latch from AWR Latch Activity section. (2) Correlate with other concurrent wait events for the primary driver. (3) Use the specific latch rule in the Recommendations panel if available.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('reliable message','Other','none','none',true,
'Background inter-process messaging wait. (1) Investigate only if this dominates alongside other symptoms. (2) Correlate with specific background process (AQ, XStream, Replication). (3) Check alert log for related background process errors.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('rdbms ipc reply','Other','none','none',true,
'Foreground session waiting for a background process to complete an operation. (1) Identify the background process from ASH (PROGRAM column). (2) If SMON: check for heavy coalescing or undo management. (3) If ARCn: check archivelog I/O and destination space.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('DFS lock handle','Other','none','none',true,
'RAC global lock manager (DLM) contention. (1) Identify the specific resource from ASH (P1/P2 values). (2) Review object partitioning and service affinity to reduce DLM contention. (3) Check GCS/GES background process activity and interconnect latency.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- PX events that were seeded with wrong event names
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('PX Deq Credit: send blkd','Idle','none','none',true,
'PX producer slave blocked — consumer slaves cannot process rows fast enough. (1) Identify the bottleneck operation in the parallel plan. (2) Review join methods — hash joins consume faster than nested loops. (3) Reduce DOP if consumer is overloaded.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- PX Deq Credit: execute reply — the correct name in this master table
INSERT INTO awr_wait_event_master (event, wait_class, corr_type, seg_filter, has_specific_rule, guidance_text)
VALUES ('PX Deq: Execute Reply','Idle','none','none',true,
'Parallel query coordinator waiting for slave replies. (1) Check for data distribution imbalance across partitions. (2) Review PARALLEL_MAX_SERVERS and available PX server pool. (3) Consider reducing degree of parallelism if server pool is saturated.')
ON CONFLICT (event) DO UPDATE SET corr_type=EXCLUDED.corr_type,seg_filter=EXCLUDED.seg_filter,has_specific_rule=EXCLUDED.has_specific_rule,guidance_text=EXCLUDED.guidance_text;

-- ═══════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════

SELECT
  wait_class,
  COUNT(*) AS total_events,
  COUNT(corr_type) AS seeded,
  COUNT(CASE WHEN corr_type <> 'none' THEN 1 END) AS with_segment_corr,
  COUNT(CASE WHEN corr_type = 'none' THEN 1 END) AS no_segment_corr,
  COUNT(*) - COUNT(corr_type) AS not_yet_seeded
FROM awr_wait_event_master
GROUP BY wait_class
ORDER BY total_events DESC;
