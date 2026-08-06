-- ============================================================
-- awr_db_master — add OS type and OS utility columns
-- Run once on existing installations.
-- ============================================================

ALTER TABLE awr_db_master
    ADD COLUMN IF NOT EXISTS os_type    TEXT DEFAULT 'Linux'
        CHECK (os_type IN ('Linux', 'IBM AIX', 'Other')),
    ADD COLUMN IF NOT EXISTS os_utility TEXT DEFAULT 'SAR'
        CHECK (os_utility IN ('SAR', 'NMON', 'None'));

COMMENT ON COLUMN awr_db_master.os_type    IS 'Linux → SAR, IBM AIX → NMON';
COMMENT ON COLUMN awr_db_master.os_utility IS 'OS monitoring utility for this host — SAR or NMON (mutually exclusive per hostname)';

-- Enforce: same hostname cannot have both SAR and NMON registered
-- Uses a partial unique index — only one utility type allowed per active host
CREATE UNIQUE INDEX IF NOT EXISTS uq_awr_db_master_host_utility
    ON awr_db_master (host_name, os_utility)
    WHERE active = TRUE AND host_name IS NOT NULL AND host_name != '';

-- Auto-populate existing rows based on OS type if possible
-- (safe to run; defaults are already set above)
UPDATE awr_db_master SET os_type = 'Linux',   os_utility = 'SAR'  WHERE os_type IS NULL;
