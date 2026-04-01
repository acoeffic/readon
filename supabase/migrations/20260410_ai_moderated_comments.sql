-- Migration: AI-moderated comments
-- Adds status column, RLS policies, updates view & RPCs for comment moderation

-- =============================================================================
-- 1. Add status column to existing comments table
-- =============================================================================

ALTER TABLE comments
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';

-- Add CHECK constraint separately (IF NOT EXISTS not supported for constraints)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_comments_status'
  ) THEN
    ALTER TABLE comments
      ADD CONSTRAINT chk_comments_status CHECK (status IN ('pending', 'approved', 'rejected'));
  END IF;
END;
$$;

-- Mark all existing comments as approved (they predate moderation)
UPDATE comments SET status = 'approved' WHERE status = 'pending';

-- Indexes for status-aware queries
CREATE INDEX IF NOT EXISTS idx_comments_status
  ON comments(status);

CREATE INDEX IF NOT EXISTS idx_comments_activity_status_created
  ON comments(activity_id, status, created_at DESC);

-- =============================================================================
-- 2. RLS policies on comments
-- =============================================================================

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- SELECT: own comments (any status) + approved comments from friend activities
DROP POLICY IF EXISTS "read_comments" ON comments;
CREATE POLICY "read_comments"
  ON comments FOR SELECT TO authenticated
  USING (
    auth.uid() = author_id
    OR (
      status = 'approved'
      AND EXISTS (
        SELECT 1 FROM activities a
        WHERE a.id = comments.activity_id
        AND (
          a.author_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM friends f
            WHERE f.status = 'accepted'
            AND (
              (f.requester_id = auth.uid() AND f.addressee_id = a.author_id)
              OR (f.requester_id = a.author_id AND f.addressee_id = auth.uid())
            )
          )
        )
      )
    )
  );

-- INSERT: only own comments
DROP POLICY IF EXISTS "insert_comments" ON comments;
CREATE POLICY "insert_comments"
  ON comments FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = author_id);

-- UPDATE: only own comments
DROP POLICY IF EXISTS "update_comments" ON comments;
CREATE POLICY "update_comments"
  ON comments FOR UPDATE TO authenticated
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- DELETE: only own comments
DROP POLICY IF EXISTS "delete_comments" ON comments;
CREATE POLICY "delete_comments"
  ON comments FOR DELETE TO authenticated
  USING (auth.uid() = author_id);

-- =============================================================================
-- 3. Update comments_with_user view to include status
-- =============================================================================

DROP VIEW IF EXISTS comments_with_user;
CREATE VIEW comments_with_user AS
SELECT
  c.id,
  c.activity_id,
  c.author_id,
  c.content,
  c.status,
  c.created_at,
  c.updated_at,
  p.display_name AS author_name,
  p.email AS author_email,
  p.avatar_url AS author_avatar
FROM comments c
JOIN profiles p ON p.id = c.author_id;

-- =============================================================================
-- 4. Update get_activity_comments RPC (status-aware)
-- =============================================================================

DROP FUNCTION IF EXISTS get_activity_comments(BIGINT);
CREATE FUNCTION get_activity_comments(p_activity_id BIGINT)
RETURNS TABLE (
  id UUID,
  activity_id BIGINT,
  author_id UUID,
  content TEXT,
  status TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  author_name TEXT,
  author_email TEXT,
  author_avatar TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.activity_id,
    c.author_id,
    c.content,
    c.status,
    c.created_at,
    c.updated_at,
    p.display_name AS author_name,
    p.email AS author_email,
    p.avatar_url AS author_avatar
  FROM comments c
  JOIN profiles p ON p.id = c.author_id
  WHERE c.activity_id = p_activity_id
    AND (c.status = 'approved' OR c.author_id = auth.uid())
  ORDER BY c.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_activity_comments(BIGINT) TO authenticated;

-- =============================================================================
-- 5. New RPC: get approved comment count for an activity
-- =============================================================================

CREATE OR REPLACE FUNCTION get_comment_count(p_activity_id BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM comments
  WHERE activity_id = p_activity_id
    AND status = 'approved';
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION get_comment_count(BIGINT) TO authenticated;
