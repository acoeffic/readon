-- =====================================================
-- Migration: get_feed_bundle — un seul round-trip réseau
--
-- Combine 9 requêtes parallèles du feed en une seule RPC
-- qui retourne un objet JSONB avec toutes les sections.
-- Réduit la latence de ~9× overhead réseau à 1.
-- =====================================================

-- Drop the old BIGINT-cursor overload so PostgreSQL doesn't see two
-- ambiguous candidates when p_feed_cursor is NULL.
DROP FUNCTION IF EXISTS get_feed_bundle(INT, BIGINT, INT, INT, INT, INT, INT, INT[]);

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
  -- ── 1. Friend count ────────────────────────────────────────
  SELECT COUNT(*) INTO v_friend_count
  FROM friends
  WHERE (requester_id = v_uid OR addressee_id = v_uid)
    AND status = 'accepted';

  -- ── Build the bundle ───────────────────────────────────────
  SELECT jsonb_build_object(
    'friend_count', v_friend_count,

    -- ── 2. Feed items (fan-out dénormalisé) ──────────────────
    'feed', COALESCE((
      SELECT jsonb_agg(row_to_json(fi.*) ORDER BY fi.created_at DESC)
      FROM (
        SELECT fi2.id, fi2.activity_id, fi2.type, fi2.payload,
               fi2.author_id, fi2.author_name, fi2.author_avatar,
               fi2.created_at
        FROM feed_items fi2
        WHERE fi2.owner_id = v_uid
          AND (p_feed_cursor IS NULL OR fi2.created_at < p_feed_cursor::timestamptz)
        ORDER BY fi2.created_at DESC
        LIMIT p_feed_limit
      ) fi
    ), '[]'::jsonb),

    -- ── 3. Trending books (materialized view) ────────────────
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

    -- ── 4. Community sessions (materialized view) ────────────
    'community_sessions', COALESCE((
      SELECT jsonb_agg(row_to_json(cs.*))
      FROM (
        SELECT mv.session_id, mv.start_page, mv.end_page,
               mv.start_time, mv.end_time, mv.session_created_at,
               mv.display_name, mv.avatar_url, mv.user_id,
               mv.book_title, mv.book_author, mv.book_cover
        FROM mv_community_sessions mv
        WHERE mv.user_id != v_uid
        ORDER BY mv.session_created_at DESC
        LIMIT p_sessions_limit
      ) cs
    ), '[]'::jsonb),

    -- ── 5. Active readers (live query) ───────────────────────
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
        ORDER BY rs.start_time DESC
        LIMIT p_readers_limit
      ) ar
    ), '[]'::jsonb),

    -- ── 6. Badge unlocks (last 7 days) ───────────────────────
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
        ORDER BY ub.unlocked_at DESC
        LIMIT p_badges_limit
      ) bu
    ), '[]'::jsonb),

    -- ── 7. Prize lists ───────────────────────────────────────
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

    -- ── 8. Saved curated list IDs (for current user) ─────────
    'saved_curated_ids', COALESCE((
      SELECT jsonb_agg(list_id)
      FROM user_saved_curated_lists
      WHERE user_id = v_uid
    ), '[]'::jsonb),

    -- ── 9. Curated reader counts ─────────────────────────────
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

-- L'index (owner_id, created_at DESC) de la migration 20260507
-- couvre la pagination par timestamp. L'ancien index (owner_id, id DESC)
-- n'est plus utilisé mais on le garde pour ne pas casser d'éventuelles
-- requêtes directes.
CREATE INDEX IF NOT EXISTS idx_feed_items_owner_id_desc
  ON feed_items(owner_id, id DESC);

-- =====================================================
-- Patch get_feed_v2 : cursor par ID + retirer le filtre 7 jours
--
-- Le cron cleanup_old_feed_items supprime déjà les items
-- > 30 jours. Le filtre 7 jours dans la requête est
-- redondant et empêche l'utilisateur de scroller au-delà
-- d'une semaine. L'index (owner_id, created_at DESC)
-- suffit pour la performance.
-- =====================================================

-- Drop the old BIGINT-cursor overload.
DROP FUNCTION IF EXISTS get_feed_v2(INT, BIGINT);

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
  ORDER BY fi.created_at DESC
  LIMIT p_limit;
END;
$$;
