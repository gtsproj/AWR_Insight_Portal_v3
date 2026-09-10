-- ============================================================
-- DAR Portal — MS SQL Server Support
-- Recommendation Engine + Ground-Truth Feedback Tables
-- Avekshaa Technologies
-- ============================================================
-- Two tables, deliberately separate: mssql_recommendations holds
-- what was generated (a fact -- this recommendation was produced at
-- this time from this evidence), mssql_recommendation_feedback holds
-- a human's review of it (mutable -- can be updated as understanding
-- of a given recommendation changes, without touching the original
-- generated record).
--
-- The feedback table is the actual ground-truth mechanism: without
-- it, "80-90% accuracy" is an assertion, not a number. Once enough
-- recommendations have been reviewed, accuracy = confirmed_real /
-- (confirmed_real + false_positive) is a real, computable metric,
-- not a guess.
-- ============================================================

\echo 'Creating MS SQL recommendation + feedback tables...'

CREATE TABLE IF NOT EXISTS mssql_recommendations (
    id                      SERIAL,
    instance_id             INTEGER NOT NULL,
    generated_at            TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    category                TEXT NOT NULL,       -- 'wait_analysis' for now; extensible
                                                  -- ('blocking', 'deadlock', 'index', ...)
                                                  -- as more rule categories are built
    severity                TEXT NOT NULL,        -- highest severity among contributing findings
    title                   TEXT NOT NULL,
    summary                 TEXT,                 -- human-readable synthesis across every
                                                   -- finding that contributed to this recommendation
    contributing_rule_ids   TEXT,                 -- comma-separated (e.g. "MSSQL_WAIT_002,MSSQL_WAIT_006")
                                                   -- -- which rules' findings were correlated together
    correlated              BOOLEAN DEFAULT false, -- true if 2+ independent findings (e.g. a
                                                    -- wait_type AND a wait_category finding for the
                                                    -- same underlying issue) corroborated each other --
                                                    -- a stronger signal than a single finding alone
    evidence_json           TEXT,                  -- structured JSON of the raw finding(s) that
                                                    -- contributed, for full traceability back to
                                                    -- the actual metrics that triggered this
    database_name           TEXT,
    affected_object          TEXT,                 -- table/wait_type/wait_category/query, whichever
                                                    -- is most specific for this recommendation
    row_hash                CHAR(32) NOT NULL,     -- dedups against re-generating the same
                                                    -- recommendation on every run while the
                                                    -- underlying condition persists
    created_at               TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_recommendations_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_recommendations_instance FOREIGN KEY (instance_id) REFERENCES mssql_instance_master(id),
    CONSTRAINT uq_mssql_recommendations UNIQUE (instance_id, row_hash) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_recommendations IS 'Orchestrated, correlated recommendations synthesized from one or more rule-engine findings -- the output of recommendation_engine.py, not raw per-metric findings (those live only transiently in the rule engine''s own evaluation).';

CREATE INDEX IF NOT EXISTS idx_mssql_recommendations_instance ON public.mssql_recommendations USING btree (instance_id, generated_at DESC) TABLESPACE mssqlparser_idx;
CREATE INDEX IF NOT EXISTS idx_mssql_recommendations_category ON public.mssql_recommendations USING btree (category) TABLESPACE mssqlparser_idx;


CREATE TABLE IF NOT EXISTS mssql_recommendation_feedback (
    id                      SERIAL,
    recommendation_id       INTEGER NOT NULL,
    feedback_status         TEXT NOT NULL DEFAULT 'UNREVIEWED',
                                                  -- UNREVIEWED, CONFIRMED_REAL, FALSE_POSITIVE,
                                                  -- NEEDS_INVESTIGATION
    reviewed_by             TEXT,
    reviewed_at             TIMESTAMP WITHOUT TIME ZONE,
    notes                   TEXT,
    created_at               TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mssql_recommendation_feedback_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_feedback_recommendation FOREIGN KEY (recommendation_id) REFERENCES mssql_recommendations(id),
    CONSTRAINT uq_mssql_feedback_recommendation UNIQUE (recommendation_id) USING INDEX TABLESPACE mssqlparser_idx
    -- One feedback row per recommendation, updatable -- not a history
    -- table. If a fuller audit trail (who changed status when, more
    -- than once) turns out to matter later, that's a genuine schema
    -- change worth making deliberately then, not speculatively now.
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_recommendation_feedback IS 'The actual ground-truth mechanism: a DBA''s review of whether a generated recommendation was a real issue or a false positive. Once populated at meaningful volume, accuracy = confirmed_real / (confirmed_real + false_positive) is a computable number, not an assertion.';

CREATE INDEX IF NOT EXISTS idx_mssql_feedback_status ON public.mssql_recommendation_feedback USING btree (feedback_status) TABLESPACE mssqlparser_idx;

\echo '  Recommendation + feedback tables: done'
