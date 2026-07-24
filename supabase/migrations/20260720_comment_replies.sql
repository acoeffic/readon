-- Migration : Réponses aux commentaires (threading) + notifications
-- 1. Ajoute comments.parent_id (réponse à un commentaire)
-- 2. Met à jour la vue comments_with_user et la RPC get_activity_comments
-- 3. Étend notify_activity_comment : notification 'comment_reply' à l'auteur
--    du commentaire parent (sans doubler la notif 'comment' de l'auteur de
--    l'activité quand c'est la même personne)
-- 4. Met à jour get_user_notifications pour enrichir le type 'comment_reply'
-- 5. Ajoute la branche push 'comment_reply' dans send_push_on_notification

-- ═══════════════════════════════════════════════════════════════
-- 1. Colonne parent_id sur comments
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE comments
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES comments(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_comments_parent_id
  ON comments(parent_id)
  WHERE parent_id IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════
-- 2. Vue comments_with_user + RPC get_activity_comments (exposent parent_id)
-- ═══════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS comments_with_user;
CREATE VIEW comments_with_user AS
SELECT
  c.id,
  c.activity_id,
  c.author_id,
  c.parent_id,
  c.content,
  c.status,
  c.created_at,
  c.updated_at,
  p.display_name AS author_name,
  p.email AS author_email,
  p.avatar_url AS author_avatar
FROM comments c
JOIN profiles p ON p.id = c.author_id;

DROP FUNCTION IF EXISTS get_activity_comments(BIGINT);
CREATE FUNCTION get_activity_comments(p_activity_id BIGINT)
RETURNS TABLE (
  id UUID,
  activity_id BIGINT,
  author_id UUID,
  parent_id UUID,
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
    c.parent_id,
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

-- ═══════════════════════════════════════════════════════════════
-- 3. Trigger notification : commentaire + réponse
--    (remplace notify_activity_comment ; le trigger existant
--    trigger_comment_notification sur comments reste inchangé)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION notify_activity_comment()
RETURNS TRIGGER AS $$
DECLARE
  v_activity_author UUID;
  v_parent_author UUID;
BEGIN
  -- Trouver l'auteur de l'activité
  SELECT author_id INTO v_activity_author
  FROM activities
  WHERE id = NEW.activity_id;

  -- Trouver l'auteur du commentaire parent (si réponse)
  IF NEW.parent_id IS NOT NULL THEN
    SELECT author_id INTO v_parent_author
    FROM comments
    WHERE id = NEW.parent_id;
  END IF;

  -- Notification 'comment_reply' à l'auteur du commentaire parent
  -- (pas de notification si on répond à son propre commentaire)
  IF v_parent_author IS NOT NULL AND v_parent_author != NEW.author_id THEN
    INSERT INTO notifications (user_id, from_user_id, type, activity_id, is_read, created_at)
    VALUES (v_parent_author, NEW.author_id, 'comment_reply', NEW.activity_id, false, NOW());
  END IF;

  -- Notification 'comment' à l'auteur de l'activité, sauf si :
  --  - il commente sa propre activité
  --  - il vient déjà de recevoir la notif 'comment_reply' (il est l'auteur du parent)
  IF v_activity_author IS NOT NULL
     AND v_activity_author != NEW.author_id
     AND (v_parent_author IS NULL OR v_parent_author != v_activity_author) THEN
    INSERT INTO notifications (user_id, from_user_id, type, activity_id, is_read, created_at)
    VALUES (v_activity_author, NEW.author_id, 'comment', NEW.activity_id, false, NOW());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════
-- 4. RPC get_user_notifications : gérer le type 'comment_reply'
--    (+ fix : le join comments prend désormais LE dernier commentaire
--    au lieu de potentiellement dupliquer les lignes ;
--    + fix : duration_minutes peut être décimal dans le payload,
--    le cast direct ::INT faisait planter toute la RPC)
-- ═══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS get_user_notifications(UUID, INT, INT);
CREATE FUNCTION get_user_notifications(p_user_id UUID, p_limit INT DEFAULT 20, p_offset INT DEFAULT 0)
RETURNS TABLE (
  id UUID,
  type TEXT,
  activity_id BIGINT,
  from_user_id UUID,
  from_user_name TEXT,
  from_user_avatar TEXT,
  activity_payload JSONB,
  comment_content TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    n.id,
    n.type,
    n.activity_id,
    n.from_user_id,
    COALESCE(p.display_name, 'Un utilisateur')::TEXT AS from_user_name,
    p.avatar_url::TEXT AS from_user_avatar,
    CASE
      WHEN n.type IN ('like', 'comment', 'comment_reply') AND a.id IS NOT NULL THEN
        jsonb_build_object(
          'book_title',      COALESCE(a.payload->>'book_title', b.title),
          'book_id',         COALESCE((a.payload->>'book_id')::TEXT, b.id::TEXT),
          'book_author',     COALESCE(a.payload->>'book_author', b.author),
          'book_cover_url',  COALESCE(a.payload->>'book_cover_url', b.cover_url),
          'session_id',      a.payload->>'session_id',
          'start_page',      ROUND((a.payload->>'start_page')::NUMERIC)::INT,
          'end_page',        ROUND((a.payload->>'end_page')::NUMERIC)::INT,
          'duration_minutes',ROUND((a.payload->>'duration_minutes')::NUMERIC)::INT,
          'author_id',       a.author_id
        )
      WHEN n.type = 'group_join_request' THEN
        (
          SELECT jsonb_build_object(
            'group_id', gjr.group_id,
            'group_name', rg.name,
            'request_id', gjr.id,
            'request_status', gjr.status
          )
          FROM group_join_requests gjr
          JOIN reading_groups rg ON rg.id = gjr.group_id
          WHERE gjr.user_id = n.from_user_id
          AND EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = gjr.group_id AND gm.user_id = n.user_id AND gm.role = 'admin'
          )
          AND gjr.status = 'pending'
          ORDER BY gjr.created_at DESC
          LIMIT 1
        )
      ELSE NULL
    END AS activity_payload,
    c.content AS comment_content,
    n.is_read,
    n.created_at
  FROM notifications n
  LEFT JOIN profiles p ON p.id = n.from_user_id
  LEFT JOIN activities a ON a.id = n.activity_id AND n.type IN ('like', 'comment', 'comment_reply')
  LEFT JOIN books b ON b.id = (a.payload->>'book_id')::BIGINT
    AND n.type IN ('like', 'comment', 'comment_reply')
    AND a.id IS NOT NULL
  LEFT JOIN LATERAL (
    SELECT c2.content
    FROM comments c2
    WHERE c2.activity_id = n.activity_id
      AND c2.author_id = n.from_user_id
      AND c2.created_at <= n.created_at
    ORDER BY c2.created_at DESC
    LIMIT 1
  ) c ON n.type IN ('comment', 'comment_reply')
  WHERE n.user_id = p_user_id
  ORDER BY n.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ═══════════════════════════════════════════════════════════════
-- 5. Push : branche 'comment_reply'
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION send_push_on_notification()
RETURNS TRIGGER AS $$
DECLARE
  v_fcm_token TEXT;
  v_from_name TEXT;
  v_title TEXT;
  v_body TEXT;
  v_data JSONB;
BEGIN
  -- Récupérer le fcm_token du destinataire
  SELECT fcm_token INTO v_fcm_token
  FROM profiles
  WHERE id = NEW.user_id;

  -- Si pas de token, on ne fait rien
  IF v_fcm_token IS NULL OR v_fcm_token = '' THEN
    RETURN NEW;
  END IF;

  -- Récupérer le nom de l'expéditeur
  SELECT COALESCE(display_name, 'Quelqu''un') INTO v_from_name
  FROM profiles
  WHERE id = NEW.from_user_id;

  -- Construire le titre et le body selon le type de notification
  CASE NEW.type
    WHEN 'comment' THEN
      v_title := 'Nouveau commentaire';
      v_body := v_from_name || ' a commenté ta session';
      v_data := jsonb_build_object(
        'type', 'comment',
        'activityId', COALESCE(NEW.activity_id::TEXT, '')
      );
    WHEN 'comment_reply' THEN
      v_title := 'Nouvelle réponse';
      v_body := v_from_name || ' a répondu à ton commentaire';
      v_data := jsonb_build_object(
        'type', 'comment_reply',
        'activityId', COALESCE(NEW.activity_id::TEXT, '')
      );
    WHEN 'like' THEN
      v_title := 'Session appréciée';
      v_body := v_from_name || ' a aimé ta session';
      v_data := jsonb_build_object(
        'type', 'like',
        'activityId', COALESCE(NEW.activity_id::TEXT, '')
      );
    WHEN 'friend_request' THEN
      v_title := 'Nouvelle demande d''ami';
      v_body := v_from_name || ' veut être ton ami';
      v_data := jsonb_build_object(
        'type', 'friend_request',
        'fromUserId', NEW.from_user_id::TEXT
      );
    ELSE
      -- Type inconnu, on ne push pas
      RETURN NEW;
  END CASE;

  -- Appeler l'Edge Function via pg_net (appel HTTP asynchrone)
  PERFORM net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := jsonb_build_object(
      'token', v_fcm_token,
      'title', v_title,
      'body', v_body,
      'data', v_data
    )
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais bloquer l'INSERT de la notification si le push échoue
    RAISE WARNING 'Push notification failed: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
