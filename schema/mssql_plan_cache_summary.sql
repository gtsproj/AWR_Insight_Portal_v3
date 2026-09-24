-- ============================================================
-- mssql_plan_cache_summary -- one row per snapshot, accurate
-- full-plan-cache aggregate counts for single-use/ad-hoc plan bloat.
--
-- The existing mssql_plan_cache_stats only keeps the TOP 200 plans
-- by usecounts (deliberately bounded, per that collector's own
-- comment, since the cache can hold tens of thousands of entries) --
-- which biases toward highly-reused plans and would UNDERCOUNT
-- single-use plans in any busy, ad-hoc-query-heavy environment where
-- more than 200 distinct plans exist. Rather than build a "single-use
-- plan bloat" report section from data that's structurally biased
-- against showing single-use plans, this is a small, separate,
-- lightweight aggregate query against the FULL cache (COUNT/SUM only,
-- not storing every individual plan) -- accurate regardless of how
-- many total plans exist.
-- ============================================================

CREATE TABLE IF NOT EXISTS mssql_plan_cache_summary (
    id                             SERIAL,
    snapshot_id                    INTEGER NOT NULL,
    total_plan_count               BIGINT,
    total_plan_size_mb             NUMERIC,
    single_use_plan_count          BIGINT,     -- usecounts = 1, across the ENTIRE cache
    single_use_plan_size_mb        NUMERIC,
    adhoc_plan_count                BIGINT,     -- objtype = 'Adhoc', across the ENTIRE cache
    adhoc_plan_size_mb              NUMERIC,
    CONSTRAINT mssql_plan_cache_summary_pkey PRIMARY KEY (id) USING INDEX TABLESPACE mssqlparser_idx,
    CONSTRAINT fk_mssql_pcs_summary_snapshot FOREIGN KEY (snapshot_id) REFERENCES mssql_dmv_snapshot(snapshot_id),
    CONSTRAINT uq_mssql_plan_cache_summary UNIQUE (snapshot_id) USING INDEX TABLESPACE mssqlparser_idx
) TABLESPACE mssqlparser;
COMMENT ON TABLE mssql_plan_cache_summary IS 'Accurate, full-plan-cache aggregate counts (single-use/ad-hoc bloat) -- unlike mssql_plan_cache_stats, not limited to the top 200 by usecounts.';

\echo 'mssql_plan_cache_summary created.'
