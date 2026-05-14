-- Add isbn and google_id to trending books and community sessions materialized views
-- so the Flutter app can construct Google Books fallback cover URLs.

-- 1. Recreate mv_trending_books with isbn and google_id
DROP MATERIALIZED VIEW IF EXISTS mv_trending_books CASCADE;
CREATE MATERIALIZED VIEW mv_trending_books AS
SELECT
  b.id          AS book_id,
  b.title       AS book_title,
  b.author      AS book_author,
  b.cover_url   AS book_cover,
  b.isbn        AS book_isbn,
  b.google_id   AS book_google_id,
  COUNT(DISTINCT rs.id)      AS session_count,
  COUNT(DISTINCT rs.user_id) AS reader_count
FROM books b
JOIN reading_sessions rs ON rs.book_id = b.id::text
WHERE rs.created_at > NOW() - INTERVAL '7 days'
  AND rs.end_time IS NOT NULL
GROUP BY b.id, b.title, b.author, b.cover_url, b.isbn, b.google_id
ORDER BY session_count DESC
LIMIT 20
WITH DATA;

CREATE UNIQUE INDEX idx_mv_trending_books_id ON mv_trending_books(book_id);

-- 2. Recreate mv_community_sessions with isbn and google_id
DROP MATERIALIZED VIEW IF EXISTS mv_community_sessions CASCADE;
CREATE MATERIALIZED VIEW mv_community_sessions AS
SELECT
  rs.id::text   AS session_id,
  rs.start_page,
  rs.end_page,
  rs.start_time,
  rs.end_time,
  rs.created_at AS session_created_at,
  p.display_name,
  p.avatar_url,
  p.id          AS user_id,
  b.title       AS book_title,
  b.author      AS book_author,
  b.cover_url   AS book_cover,
  b.isbn        AS book_isbn,
  b.google_id   AS book_google_id
FROM reading_sessions rs
JOIN profiles p ON p.id = rs.user_id
JOIN books b ON b.id::text = rs.book_id
WHERE COALESCE(p.is_profile_private, FALSE) = FALSE
  AND rs.end_time IS NOT NULL
  AND rs.created_at > NOW() - INTERVAL '24 hours'
ORDER BY rs.created_at DESC
LIMIT 50
WITH DATA;

CREATE UNIQUE INDEX idx_mv_community_sessions_id ON mv_community_sessions(session_id);

-- 3. Update RPCs to include new columns (DROP first — return type changed)

DROP FUNCTION IF EXISTS get_trending_books_by_sessions(INTEGER);
CREATE OR REPLACE FUNCTION get_trending_books_by_sessions(
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
  book_id BIGINT,
  book_title TEXT,
  book_author TEXT,
  book_cover TEXT,
  book_isbn TEXT,
  book_google_id TEXT,
  session_count BIGINT,
  reader_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    mv.book_id,
    mv.book_title,
    mv.book_author,
    mv.book_cover,
    mv.book_isbn,
    mv.book_google_id,
    mv.session_count,
    mv.reader_count
  FROM mv_trending_books mv
  ORDER BY mv.session_count DESC
  LIMIT p_limit;
END;
$$;

DROP FUNCTION IF EXISTS get_community_sessions(INTEGER);
CREATE OR REPLACE FUNCTION get_community_sessions(
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  session_id TEXT,
  start_page INTEGER,
  end_page INTEGER,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  session_created_at TIMESTAMPTZ,
  display_name TEXT,
  avatar_url TEXT,
  user_id UUID,
  book_title TEXT,
  book_author TEXT,
  book_cover TEXT,
  book_isbn TEXT,
  book_google_id TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    mv.session_id,
    mv.start_page,
    mv.end_page,
    mv.start_time,
    mv.end_time,
    mv.session_created_at,
    mv.display_name,
    mv.avatar_url,
    mv.user_id,
    mv.book_title,
    mv.book_author,
    mv.book_cover,
    mv.book_isbn,
    mv.book_google_id
  FROM mv_community_sessions mv
  WHERE mv.user_id != auth.uid()
  ORDER BY mv.session_created_at DESC
  LIMIT p_limit;
END;
$$;
