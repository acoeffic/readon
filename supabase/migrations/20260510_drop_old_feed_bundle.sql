-- Drop the old get_feed_bundle overload that used BIGINT cursor.
-- PostgREST cannot resolve overloaded functions (PGRST203),
-- so we keep only the TIMESTAMPTZ version (from 20260509).
DROP FUNCTION IF EXISTS get_feed_bundle(INT, BIGINT, INT, INT, INT, INT, INT, INT[]);
