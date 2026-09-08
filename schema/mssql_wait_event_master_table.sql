-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Wait Event Master Table
-- Avekshaa Technologies
-- ============================================================
-- Mirrors awr_wait_event_master's role for Oracle: a broad reference
-- table used to ground AI narrative generation (Analysis Model doc
-- Section 10.4's equivalent for MS SQL, once built) and to give the
-- portal UI/rules engine a single source of truth for which events
-- have dedicated rules versus which are catalogued but not yet
-- individually covered.
--
-- Two tiers in one table (tier column), not two separate tables --
-- MS SQL genuinely has two distinct wait namespaces that don't
-- overlap: wait_type (sys.dm_os_wait_stats, ~1,300+ raw values) and
-- wait_category (sys.query_store_wait_stats, a fixed 24-value enum).
-- Both need guidance text and rule-coverage tracking, so both live
-- here rather than inventing a second master table.
--
-- Same honest scope as Oracle's own master table: broad NAME and
-- wait_class coverage across the full catalog, but only a SUBSET
-- (the ones this project has actually researched -- rule-covered
-- events plus the confirmed-benign list) get real, sourced
-- guidance_text. The rest have wait_class classification (derived
-- from naming convention, reasonable confidence) but NULL guidance --
-- left honestly blank rather than filled with unverified text.
-- ============================================================

\echo 'Creating mssql_wait_event_master...'

CREATE TABLE IF NOT EXISTS mssql_wait_event_master (
    id                  SERIAL,
    tier                TEXT NOT NULL,      -- 'wait_type' or 'wait_category'
    event_name          TEXT NOT NULL,
    wait_class          TEXT,               -- broad grouping (I/O, Lock, CPU, Memory,
                                             -- Parallelism, Transaction Log, Network,
                                             -- Preemptive, Internal, etc.) -- classified
                                             -- from naming convention where guidance_text
                                             -- research hasn't been done individually
    is_benign           BOOLEAN DEFAULT false,   -- matches BENIGN_WAIT_TYPES in rule_engine.py
                                                  -- for tier='wait_type'; NULL/false otherwise
    has_specific_rule   BOOLEAN DEFAULT false,   -- true if a rule in
                                                  -- recommendation_rules_mssql_v1.json
                                                  -- targets this event_name
    rule_ids            TEXT,               -- comma-separated rule_id(s) covering this
                                             -- event, if has_specific_rule is true
    guidance_text       TEXT,               -- populated only where actually researched
                                             -- this project -- NULL is honest, not a gap
                                             -- to silently paper over
    source              TEXT,               -- where guidance_text's claims came from,
                                             -- for traceability (e.g. a URL or "Paul
                                             -- Randal, sqlskills.com") -- NULL where
                                             -- guidance_text itself is NULL
    CONSTRAINT mssql_wait_event_master_pkey PRIMARY KEY (tier, event_name) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_wait_event_master IS 'Wait event reference catalog covering both sys.dm_os_wait_stats (tier=wait_type) and sys.query_store_wait_stats (tier=wait_category). Mirrors awr_wait_event_master''s role -- broad name/class coverage, guidance_text populated only where actually researched.';

CREATE INDEX IF NOT EXISTS idx_mssql_wait_event_master_class ON public.mssql_wait_event_master USING btree (wait_class) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_wait_event_master_has_rule ON public.mssql_wait_event_master USING btree (has_specific_rule) TABLESPACE mssqlparser_idx;

\echo '  mssql_wait_event_master: done'
