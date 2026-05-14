-- Migration: filtrer côté serveur les utilisateurs bloqués dans les
-- RPC qui surfacent du contenu généré par les utilisateurs (UGC).
--
-- Principe : pour chaque ligne contenant `author_id` / `user_id`, on
-- s'assure qu'il n'existe pas de row dans `user_blocks` entre l'auteur
-- et l'utilisateur courant (dans un sens ou dans l'autre).
--
-- RPCs mises à jour ici :
--   - get_feed_bundle  (sections: feed, community_sessions,
--                       active_readers, badge_unlocks)
--   - get_feed_v2      (timeline du feed)
--   - get_friend_recent_sessions (sessions du profil ami)
--   - get_activity_comments      (commentaires d'un post)
--
-- Note : `is_blocked()` (RPC déjà existante de 20260523) renvoie le bon
-- résultat aussi côté SECURITY DEFINER car `auth.uid()` reste celui du
-- JWT caller. On utilise quand même NOT EXISTS direct pour permettre à
-- l'optimiseur Postgres d'utiliser l'index sur user_blocks.

-- ─────────────────────────────────────────────────────────────────────
-- get_feed_v2
-- ─────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS get_feed_v2(INT, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION get_feed_v2(
  p_limit   INT          DEFAULT 20,
  p_cursor  TIMESTAMPTZ  DEFAULT NULL
)
RETURNS TABLE (
  id             BIGINT,
  activity_id    BIGINT,
  type           TEXT,
  payload        JSONB,
  author_id      UUID,
  author_name    TEXT,
  author_avatar  TEXT,
  created_at     TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    fi.id,
    fi.activity_id,
    fi.type,
    fi.payload,
    fi.author_id,
    fi.author_name,
    fi.author_avatar,
    fi.created_at
  FROM feed_items fi
  WHERE fi.owner_id = auth.uid()
    AND (p_cursor IS NULL OR fi.created_at < p_cursor)
    AND NOT EXISTS (
      SELECT 1 FROM user_blocks ub
      WHERE (ub.blocker_id = auth.uid() AND ub.blocked_id = fi.author_id)
         OR (ub.blocker_id = fi.author_id AND ub.blocked_id = auth.uid())
    )
  ORDER BY fi.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_feed_v2(INT, TIMESTAMPTZ) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────
-- get_feed_bundle
-- ─────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS get_feed_bundle(INT, TIMESTAMPTZ, INT, INT, INT, INT, INT, INT[]);

CREATE OR REPLACE FUNCTION get_feed_bundle(
  p_feed_limit      INT     DEFAULT 20,
  p_feed_cursor     TIMESTAMPTZ DEFAULT NULL,
  p_trending_limit  INT     DEFAULT 5,
  p_sessions_limit  INT     DEFAULT 10,
  p_readers_limit   INT     DEFAULT 10,
  p_badges_limit    INT     DEFAULT 8,
  p_prizes_limit    INT     DEFAULT 10,
  p_curated_ids     INT[]   DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid          UUID := auth.uid();
  v_friend_count INT;
  v_result       JSONB;
BEGIN
  SELECT COUNT(*) INTO v_friend_count
  FROM friends
  WHERE (requester_id = v_uid OR addressee_id = v_uid)
    AND status = 'accepted';

  SELECT jsonb_build_object(
    'friend_count', v_friend_count,

    'feed', COALESCE((
      SELECT jsonb_agg(row_to_json(fi.*) ORDER BY fi.created_at DESC)
      FROM (
        SELECT fi2.id, fi2.activity_id, fi2.type, fi2.payload,
               fi2.author_id, fi2.author_name, fi2.author_avatar,
               fi2.created_at
        FROM feed_items fi2
        WHERE fi2.owner_id = v_uid
          AND (p_feed_cursor IS NULL OR fi2.created_at < p_feed_cursor::timestamptz)
          AND NOT EXISTS (
            SELECT 1 FROM user_blocks ub
            WHERE (ub.blocker_id = v_uid AND ub.blocked_id = fi2.author_id)
               OR (ub.blocker_id = fi2.author_id AND ub.blocked_id = v_uid)
          )
        ORDER BY fi2.created_at DESC
        LIMIT p_feed_limit
      ) fi
    ), '[]'::jsonb),

    'trending_books', COALESCE((
      SELECT jsonb_agg(row_to_json(tb.*))
      FROM (
        SELECT mv.book_id, mv.book_title, mv.book_author,
               mv.book_cover,
               mv.session_count, mv.reader_count
        FROM mv_trending_books mv
        ORDER BY mv.session_count DESC
        LIMIT p_trending_limit
      ) tb
    ), '[]'::jsonb),

    'community_sessions', COALESCE((
      SELECT jsonb_agg(row_to_json(cs.*))
      FROM (
        SELECT mv.session_id, mv.start_page, mv.end_page,
               mv.start_time, mv.end_time, mv.session_created_at,
               mv.display_name, mv.avatar_url, mv.user_id,
               mv.book_title, mv.book_author, mv.book_cover
        FROM mv_community_sessions mv
        WHERE mv.user_id != v_uid
          AND NOT EXISTS (
            SELECT 1 FROM user_blocks ub
            WHERE (ub.blocker_id = v_uid AND ub.blocked_id = mv.user_id)
               OR (ub.blocker_id = mv.user_id AND ub.blocked_id = v_uid)
          )
        ORDER BY mv.session_created_at DESC
        LIMIT p_sessions_limit
      ) cs
    ), '[]'::jsonb),

    'active_readers', COALESCE((
      SELECT jsonb_agg(row_to_json(ar.*))
      FROM (
        SELECT rs.id AS session_id, p.id AS user_id,
               p.display_name, p.avatar_url,
               rs.book_id, b.title AS book_title,
               b.author AS book_author, b.cover_url AS book_cover,
               rs.start_time, rs.start_page
        FROM reading_sessions rs
        JOIN profiles p ON p.id = rs.user_id
        JOIN books b ON b.id::text = rs.book_id
        WHERE rs.end_time IS NULL
          AND COALESCE(p.is_profile_private, FALSE) = FALSE
          AND rs.user_id != v_uid
          AND NOT EXISTS (
            SELECT 1 FROM user_blocks ub
            WHERE (ub.blocker_id = v_uid AND ub.blocked_id = rs.user_id)
               OR (ub.blocker_id = rs.user_id AND ub.blocked_id = v_uid)
          )
        ORDER BY rs.start_time DESC
        LIMIT p_readers_limit
      ) ar
    ), '[]'::jsonb),

    'badge_unlocks', COALESCE((
      SELECT jsonb_agg(row_to_json(bu.*))
      FROM (
        SELECT p.id AS user_id, p.display_name, p.avatar_url,
               b.id AS badge_id, b.name AS badge_name,
               b.icon AS badge_icon, b.color AS badge_color,
               b.category AS badge_category,
               ub.unlocked_at AS unlocked_at
        FROM user_badges ub
        JOIN badges b ON b.id = ub.badge_id
        JOIN profiles p ON p.id = ub.user_id
        WHERE COALESCE(p.is_profile_private, FALSE) = FALSE
          AND ub.user_id != v_uid
          AND ub.unlocked_at > NOW() - INTERVAL '7 days'
          AND COALESCE(b.is_secret, FALSE) = FALSE
          AND NOT EXISTS (
            SELECT 1 FROM user_blocks blk
            WHERE (blk.blocker_id = v_uid AND blk.blocked_id = ub.user_id)
               OR (blk.blocker_id = ub.user_id AND blk.blocked_id = v_uid)
          )
        ORDER BY ub.unlocked_at DESC
        LIMIT p_badges_limit
      ) bu
    ), '[]'::jsonb),

    'prize_lists', COALESCE((
      SELECT jsonb_agg(row_to_json(pl.*))
      FROM (
        SELECT *
        FROM prize_lists
        WHERE is_active = TRUE
          AND list_type = 'prize_year'
        ORDER BY year DESC
        LIMIT p_prizes_limit
      ) pl
    ), '[]'::jsonb),

    'saved_curated_ids', COALESCE((
      SELECT jsonb_agg(list_id)
      FROM user_saved_curated_lists
      WHERE user_id = v_uid
    ), '[]'::jsonb),

    'curated_reader_counts', COALESCE((
      SELECT jsonb_object_agg(list_id::text, cnt)
      FROM (
        SELECT list_id, COUNT(*) AS cnt
        FROM user_saved_curated_lists
        WHERE list_id = ANY(p_curated_ids)
        GROUP BY list_id
      ) rc
    ), '{}'::jsonb)

  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_feed_bundle(INT, TIMESTAMPTZ, INT, INT, INT, INT, INT, INT[]) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────
-- get_friend_recent_sessions
-- Bloque l'accès au profil si l'un des deux a bloqué l'autre.
-- ─────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_friend_recent_sessions(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_private BOOLEAN;
  v_is_blocked BOOLEAN;
BEGIN
  -- Gate blocage : aucun contenu si la relation est bloquée dans un sens
  -- ou dans l'autre.
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE (blocker_id = auth.uid() AND blocked_id = p_user_id)
       OR (blocker_id = p_user_id AND blocked_id = auth.uid())
  ) INTO v_is_blocked;
  IF v_is_blocked THEN
    RETURN '[]'::json;
  END IF;

  SELECT COALESCE(is_profile_private, FALSE)
  INTO v_is_private
  FROM profiles
  WHERE id = p_user_id;

  IF v_is_private THEN
    IF NOT EXISTS (
      SELECT 1 FROM friends
      WHERE status = 'accepted'
      AND (
        (requester_id = auth.uid() AND addressee_id = p_user_id)
        OR (addressee_id = auth.uid() AND requester_id = p_user_id)
      )
    ) AND auth.uid() != p_user_id THEN
      RAISE EXCEPTION 'Not a friend';
    END IF;
  END IF;

  RETURN (
    SELECT json_agg(row_to_json(t))
    FROM (
      SELECT
        rs.id,
        rs.user_id,
        rs.start_page,
        rs.end_page,
        rs.start_time,
        rs.end_time,
        rs.book_id,
        rs.is_hidden,
        rs.reading_for,
        rs.created_at,
        rs.updated_at,
        b.id AS b_id,
        b.title AS book_title,
        b.author AS book_author,
        b.cover_url AS book_cover_url,
        b.page_count AS book_page_count
      FROM reading_sessions rs
      INNER JOIN user_books ub
        ON ub.book_id::text = rs.book_id AND ub.user_id = rs.user_id
      INNER JOIN books b ON b.id = ub.book_id
      WHERE rs.user_id = p_user_id
        AND rs.end_time IS NOT NULL
        AND ub.is_hidden = FALSE
      ORDER BY rs.end_time DESC
      LIMIT 5
    ) t
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- get_activity_comments
-- ─────────────────────────────────────────────────────────────────────

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
    -- Masquer les commentaires des utilisateurs bloqués (sauf les siens,
    -- qu'on continue d'afficher pour ne pas perturber l'utilisateur).
    AND (
      c.author_id = auth.uid()
      OR NOT EXISTS (
        SELECT 1 FROM user_blocks ub
        WHERE (ub.blocker_id = auth.uid() AND ub.blocked_id = c.author_id)
           OR (ub.blocker_id = c.author_id AND ub.blocked_id = auth.uid())
      )
    )
  ORDER BY c.created_at ASC;
END;
$$;
GRANT EXECUTE ON FUNCTION get_activity_comments(BIGINT) TO authenticated;
