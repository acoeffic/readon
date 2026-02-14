-- RPC: Count user AI messages for the current calendar month
CREATE OR REPLACE FUNCTION get_ai_monthly_message_count()
RETURNS int
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT count(*)::int
  FROM ai_messages m
  JOIN ai_conversations c ON c.id = m.conversation_id
  WHERE c.user_id = auth.uid()
    AND m.role = 'user'
    AND m.created_at >= date_trunc('month', now());
$$;
