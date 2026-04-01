-- Migration: Add join request system for reading groups
-- Description: Allows users to request to join a group; admins approve/reject

-- =====================================================
-- 1. GROUP_JOIN_REQUESTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS group_join_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES reading_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  UNIQUE(group_id, user_id),
  CONSTRAINT valid_request_status CHECK (status IN ('pending', 'accepted', 'rejected')),
  CONSTRAINT message_max_length CHECK (char_length(message) <= 300)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_group_join_requests_group ON group_join_requests(group_id);
CREATE INDEX IF NOT EXISTS idx_group_join_requests_user ON group_join_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_group_join_requests_status ON group_join_requests(status);

-- Timestamp trigger
DROP TRIGGER IF EXISTS update_group_join_requests_updated_at ON group_join_requests;
CREATE TRIGGER update_group_join_requests_updated_at
  BEFORE UPDATE ON group_join_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 2. RLS POLICIES
-- =====================================================
ALTER TABLE group_join_requests ENABLE ROW LEVEL SECURITY;

-- SELECT: Admins can see requests for their groups; users can see their own requests
DROP POLICY IF EXISTS "View join requests" ON group_join_requests;
CREATE POLICY "View join requests"
  ON group_join_requests FOR SELECT
  USING (
    user_id = auth.uid()
    OR is_group_admin(group_id, auth.uid())
  );

-- INSERT: Any authenticated user can request to join (if not already a member)
DROP POLICY IF EXISTS "Users can request to join" ON group_join_requests;
CREATE POLICY "Users can request to join"
  ON group_join_requests FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND NOT is_group_member(group_id, auth.uid())
  );

-- UPDATE: Only admins can update request status (accept/reject)
DROP POLICY IF EXISTS "Admins can respond to join requests" ON group_join_requests;
CREATE POLICY "Admins can respond to join requests"
  ON group_join_requests FOR UPDATE
  USING (
    is_group_admin(group_id, auth.uid())
  );

-- DELETE: Users can cancel their own pending request
DROP POLICY IF EXISTS "Users can cancel their own requests" ON group_join_requests;
CREATE POLICY "Users can cancel their own requests"
  ON group_join_requests FOR DELETE
  USING (
    user_id = auth.uid()
    AND status = 'pending'
  );

-- =====================================================
-- 3. FUNCTION - Respond to join request
-- =====================================================
CREATE OR REPLACE FUNCTION respond_to_join_request(
  p_request_id UUID,
  p_accept BOOLEAN
)
RETURNS BOOLEAN AS $$
DECLARE
  v_group_id UUID;
  v_user_id UUID;
  v_status TEXT;
BEGIN
  -- Get request details and verify caller is admin
  SELECT group_id, user_id, status INTO v_group_id, v_user_id, v_status
  FROM group_join_requests
  WHERE id = p_request_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Join request not found';
  END IF;

  IF v_status != 'pending' THEN
    RAISE EXCEPTION 'Request has already been processed';
  END IF;

  -- Verify caller is admin
  IF NOT is_group_admin(v_group_id, auth.uid()) THEN
    RAISE EXCEPTION 'Only admins can respond to join requests';
  END IF;

  -- Update request status
  UPDATE group_join_requests
  SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END,
      updated_at = now()
  WHERE id = p_request_id;

  -- If accepted, add user to group
  IF p_accept THEN
    INSERT INTO group_members (group_id, user_id, role)
    VALUES (v_group_id, v_user_id, 'member')
    ON CONFLICT (group_id, user_id) DO NOTHING;

    -- Create join activity
    INSERT INTO group_activities (group_id, user_id, activity_type, payload)
    VALUES (v_group_id, v_user_id, 'joined', jsonb_build_object('action', 'joined'));
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. FUNCTION - Get pending join requests for a group
-- =====================================================
DROP FUNCTION IF EXISTS get_group_join_requests(UUID) CASCADE;
CREATE OR REPLACE FUNCTION get_group_join_requests(p_group_id UUID)
RETURNS TABLE (
  id UUID,
  group_id UUID,
  user_id UUID,
  user_name TEXT,
  user_avatar TEXT,
  message TEXT,
  status TEXT,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  -- Verify caller is admin
  IF NOT is_group_admin(p_group_id, auth.uid()) THEN
    RAISE EXCEPTION 'Only admins can view join requests';
  END IF;

  RETURN QUERY
  SELECT
    gjr.id,
    gjr.group_id,
    gjr.user_id,
    p.display_name AS user_name,
    p.avatar_url AS user_avatar,
    gjr.message,
    gjr.status,
    gjr.created_at
  FROM group_join_requests gjr
  LEFT JOIN profiles p ON gjr.user_id = p.id
  WHERE gjr.group_id = p_group_id
  AND gjr.status = 'pending'
  ORDER BY gjr.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. FUNCTION - Check if user has pending join request
-- =====================================================
CREATE OR REPLACE FUNCTION has_pending_join_request(p_group_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM group_join_requests
    WHERE group_id = p_group_id
    AND user_id = p_user_id
    AND status = 'pending'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
