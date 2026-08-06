CREATE TABLE IF NOT EXISTS nmon_anomalies (
    id              SERIAL PRIMARY KEY,
    hostname        TEXT        NOT NULL,
    snap_time       TIMESTAMP   NOT NULL,
    metric_source   TEXT        NOT NULL,
    metric_name     TEXT        NOT NULL,
    object_name     TEXT,
    metric_value    NUMERIC,
    baseline_mean   NUMERIC,
    baseline_stddev NUMERIC,
    z_score         NUMERIC,
    severity        TEXT,
    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_nmon_anomaly
        UNIQUE (hostname, snap_time, metric_source, metric_name, object_name)
) tablespace awrparser;