-- New table for modules/init_parameters_parser.py. Purely additive,
-- safe to run against your existing DB.
--
-- Deduplicated CURRENT-STATE key-value store, not a per-snapshot log:
-- only parameter changes (rows with a populated End Value in the AWR
-- Modified Parameters section) are recorded, upserted by
-- (dbname, instance, parameter_name).

CREATE TABLE IF NOT EXISTS awr_init_parameters (
    id                             SERIAL,
    dbname                         TEXT NOT NULL,
    instance                       TEXT NOT NULL,
    parameter_name                 TEXT NOT NULL,
    value                          TEXT,
    last_changed_begin_snap        INTEGER,
    updated_at                     TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT awr_init_parameters_pkey PRIMARY KEY (id),
    CONSTRAINT uq_awr_init_params UNIQUE (dbname, instance, parameter_name)
) TABLESPACE awrparser;

