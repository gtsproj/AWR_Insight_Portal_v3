-- Migration: extend awr_undo_statistics with STO/OOS and unexpired/
-- expired stolen/released/reused block columns, and add the new
-- awr_undo_segment_summary table for the previously-unparsed Undo
-- Segment Summary section.
--
-- Safe to run against your existing DB -- purely additive, existing
-- rows/columns are untouched, new columns default to NULL for
-- historical rows (only newly-parsed files will populate them).

ALTER TABLE awr_undo_statistics
    ADD COLUMN IF NOT EXISTS tun_ret_mins   NUMERIC,
    ADD COLUMN IF NOT EXISTS sto_count      INTEGER,
    ADD COLUMN IF NOT EXISTS oos_count      INTEGER,
    ADD COLUMN IF NOT EXISTS us_stolen      BIGINT,
    ADD COLUMN IF NOT EXISTS ur_released    BIGINT,
    ADD COLUMN IF NOT EXISTS uu_reused      BIGINT,
    ADD COLUMN IF NOT EXISTS es_stolen      BIGINT,
    ADD COLUMN IF NOT EXISTS er_released    BIGINT,
    ADD COLUMN IF NOT EXISTS eu_reused      BIGINT;

CREATE TABLE IF NOT EXISTS awr_undo_segment_summary (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    instnum                        INTEGER,
    snap_time                      TIMESTAMP WITHOUT TIME ZONE,
    undo_ts_num                    INTEGER,
    num_undo_blocks_k              NUMERIC,
    number_of_transactions         BIGINT,
    max_qry_len_s                  NUMERIC,
    max_tx_concurrency              NUMERIC,
    min_tr_mins                    NUMERIC,
    max_tr_mins                    NUMERIC,
    sto_count                      INTEGER,
    oos_count                      INTEGER,
    us_stolen                      BIGINT,
    ur_released                    BIGINT,
    uu_reused                      BIGINT,
    es_stolen                      BIGINT,
    er_released                    BIGINT,
    eu_reused                      BIGINT,
    begin_snap                     INTEGER,
    row_hash                       CHAR(32) NOT NULL,
    created_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    pdb_name                       TEXT,
    CONSTRAINT awr_undo_segment_summary_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_undo_seg_summary UNIQUE (dbname, instance, begin_snap, row_hash)
) TABLESPACE awrparser;
