-- ============================================================================
-- MIGRATION: Performance Indexes for Pagination and Common Queries
-- Date: 2026-02-05
-- ============================================================================
-- This migration adds indexes to optimize:
-- - Paginated lists (sessions, user books, feed activities)
-- - Common lookups (active sessions, friend relations)
-- ============================================================================

-- ============================================================================
-- 1. READING_SESSIONS TABLE INDEXES
-- ============================================================================

-- Index for paginated user sessions (ordered by start_time DESC)
CREATE INDEX IF NOT EXISTS idx_reading_sessions_user_start_time
  ON reading_sessions(user_id, start_time DESC);

-- Index for active session lookup (end_page IS NULL)
CREATE INDEX IF NOT EXISTS idx_reading_sessions_active
  ON reading_sessions(user_id, book_id)
  WHERE end_page IS NULL;

-- Index for book sessions history
CREATE INDEX IF NOT EXISTS idx_reading_sessions_book_user
  ON reading_sessions(book_id, user_id, start_time DESC);

-- ============================================================================
-- 2. USER_BOOKS TABLE INDEXES
-- ============================================================================

-- Index for user's books with status (for paginated library)
CREATE INDEX IF NOT EXISTS idx_user_books_user_status
  ON user_books(user_id, status);

-- Composite index for user book lookup
CREATE INDEX IF NOT EXISTS idx_user_books_user_book
  ON user_books(user_id, book_id);

-- Index for "reading" status books (current reading)
CREATE INDEX IF NOT EXISTS idx_user_books_reading
  ON user_books(user_id, created_at DESC)
  WHERE status IN ('reading', 'to_read');

-- ============================================================================
-- 3. FRIENDS TABLE INDEXES
-- ============================================================================

-- Index for friend lookups by requester
CREATE INDEX IF NOT EXISTS idx_friends_requester_status
  ON friends(requester_id, status);

-- Index for friend lookups by addressee
CREATE INDEX IF NOT EXISTS idx_friends_addressee_status
  ON friends(addressee_id, status);

-- Index for accepted friends (used in feed queries)
CREATE INDEX IF NOT EXISTS idx_friends_accepted
  ON friends(requester_id, addressee_id)
  WHERE status = 'accepted';

-- ============================================================================
-- 4. BOOKS TABLE INDEXES
-- ============================================================================

-- Index for book search by title (case-insensitive)
CREATE INDEX IF NOT EXISTS idx_books_title_lower
  ON books(LOWER(title));

-- Index for ISBN lookup
CREATE INDEX IF NOT EXISTS idx_books_isbn
  ON books(isbn)
  WHERE isbn IS NOT NULL;

-- ============================================================================
-- 5. PROFILES TABLE INDEXES
-- ============================================================================

-- Index for user search by display_name
CREATE INDEX IF NOT EXISTS idx_profiles_display_name_lower
  ON profiles(LOWER(display_name))
  WHERE display_name IS NOT NULL;

-- ============================================================================
-- 6. NOTIFICATIONS TABLE INDEXES (if exists)
-- ============================================================================

-- Index for user notifications (paginated)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
    CREATE INDEX IF NOT EXISTS idx_notifications_user_created
      ON notifications(user_id, created_at DESC);
  END IF;
END $$;

-- ============================================================================
-- 7. READING_STREAKS TABLE INDEXES (if exists)
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'reading_streaks') THEN
    CREATE INDEX IF NOT EXISTS idx_reading_streaks_user
      ON reading_streaks(user_id);
  END IF;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- List all created indexes for the relevant tables
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename IN ('reading_sessions', 'user_books', 'friends', 'books', 'profiles', 'notifications', 'reading_streaks')
  AND schemaname = 'public'
ORDER BY tablename, indexname;
