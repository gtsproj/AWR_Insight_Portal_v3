-- Migration: add `instance` to awr_recommendations, fix the unique
-- constraint to include it.
--
-- Bug: the constraint was (dbname, begin_snap, end_snap, rule_id) with
-- no instance column at all. On a RAC database, snap IDs are shared
-- cluster-wide, so if the same rule_id fired on both instance 1 and
-- instance 2 in the same snapshot window, the second instance's
-- ON CONFLICT ... DO UPDATE silently overwrote the first instance's
-- row instead of creating a separate one -- real data loss, not a
-- cosmetic issue. Standalone (non-RAC) databases were never affected,
-- since there's only ever one instance per dbname there.
--
-- Safe to run against your existing DB -- existing rows get
-- instance = '' (matches the new column's DEFAULT), which is
-- harmless for standalone databases and simply means any
-- historically-stored RAC recommendations predating this fix won't
-- retroactively be split by instance. New recommendation runs will
-- populate instance correctly per the recommendation_engine.py and
-- dashboard changes made alongside this migration.

ALTER TABLE awr_recommendations
    ADD COLUMN IF NOT EXISTS instance TEXT NOT NULL DEFAULT '';

ALTER TABLE awr_recommendations
    DROP CONSTRAINT IF EXISTS uq_awr_rec;

ALTER TABLE awr_recommendations
    ADD CONSTRAINT uq_awr_rec UNIQUE (dbname, instance, begin_snap, end_snap, rule_id);
