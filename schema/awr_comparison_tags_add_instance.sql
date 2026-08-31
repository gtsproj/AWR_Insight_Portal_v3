-- Migration: fix awr_comparison_tags so RAC instances don't collide.
--
-- Bug: the unique constraint was (dbname, tag_name, tag_type) with no
-- instance column in it, even though the table has an instance column
-- and the tag-creation form requires it. Creating a same-named tag
-- (e.g. "before_fix") for two different instances of the same RAC
-- database silently overwrote the first instance's tag (snap range,
-- notes, everything) via ON CONFLICT, instead of creating a second,
-- separate tag row. On top of that, the comparison dashboards' queries
-- didn't filter by instance at all, so even correctly-stored tags
-- would have their wait/SQL/load-profile data pooled across every
-- instance sharing that dbname -- both issues are fixed together here
-- (this migration) and in the two dashboard JSON files.
--
-- Safe to run against your existing DB: existing rows get
-- instance = '' if the column doesn't already have a value (matches
-- the column's own DEFAULT), which is harmless for standalone
-- databases -- there's only ever one instance per dbname there.

ALTER TABLE awr_comparison_tags
    ALTER COLUMN instance SET DEFAULT '';

UPDATE awr_comparison_tags SET instance = '' WHERE instance IS NULL;

ALTER TABLE awr_comparison_tags
    ALTER COLUMN instance SET NOT NULL;

ALTER TABLE awr_comparison_tags
    DROP CONSTRAINT IF EXISTS uq_awr_tag;

ALTER TABLE awr_comparison_tags
    ADD CONSTRAINT uq_awr_tag UNIQUE (dbname, instance, tag_name, tag_type);
