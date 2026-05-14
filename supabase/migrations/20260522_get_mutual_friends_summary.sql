-- get_mutual_friends_summary
-- Retourne pour un couple (caller, target) :
--   - mutual_count : nombre d'amis communs (status accepted des deux côtés)
--   - avatars      : jusqu'à 3 mini-profils {id, display_name, avatar_url}
-- Utilisé par toutes les cartes de suggestion d'amis.

DROP FUNCTION IF EXISTS get_mutual_friends_summary(UUID) CASCADE;

CREATE OR REPLACE FUNCTION get_mutual_friends_summary(p_target_user_id UUID)
RETURNS TABLE (
  mutual_count INTEGER,
  avatars JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  IF v_caller IS NULL OR v_caller = p_target_user_id THEN
    RETURN QUERY SELECT 0, '[]'::JSONB;
    RETURN;
  END IF;

  RETURN QUERY
  WITH caller_friends AS (
    SELECT CASE WHEN requester_id = v_caller THEN addressee_id
                ELSE requester_id END AS friend_id
    FROM friends
    WHERE status = 'accepted'
      AND (requester_id = v_caller OR addressee_id = v_caller)
  ),
  target_friends AS (
    SELECT CASE WHEN requester_id = p_target_user_id THEN addressee_id
                ELSE requester_id END AS friend_id
    FROM friends
    WHERE status = 'accepted'
      AND (requester_id = p_target_user_id OR addressee_id = p_target_user_id)
  ),
  mutuals AS (
    SELECT cf.friend_id
    FROM caller_friends cf
    JOIN target_friends tf ON cf.friend_id = tf.friend_id
  ),
  enriched AS (
    SELECT
      p.id,
      p.display_name,
      p.avatar_url
    FROM mutuals m
    JOIN profiles p ON p.id = m.friend_id
    ORDER BY (p.avatar_url IS NOT NULL) DESC, p.display_name ASC
    LIMIT 3
  )
  SELECT
    (SELECT COUNT(*)::INTEGER FROM mutuals),
    COALESCE(
      (SELECT jsonb_agg(jsonb_build_object(
         'id', id,
         'display_name', display_name,
         'avatar_url', avatar_url
       )) FROM enriched),
      '[]'::JSONB
    );
END;
$$;

GRANT EXECUTE ON FUNCTION get_mutual_friends_summary(UUID) TO authenticated;

-- Variante batch : pour une liste de target_ids, retourner le summary de chacun.
-- Évite N appels RPC quand on affiche 10 cartes de suggestion.

DROP FUNCTION IF EXISTS get_mutual_friends_summary_batch(UUID[]) CASCADE;

CREATE OR REPLACE FUNCTION get_mutual_friends_summary_batch(p_target_user_ids UUID[])
RETURNS TABLE (
  target_user_id UUID,
  mutual_count INTEGER,
  avatars JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  IF v_caller IS NULL OR p_target_user_ids IS NULL OR array_length(p_target_user_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH caller_friends AS (
    SELECT CASE WHEN requester_id = v_caller THEN addressee_id
                ELSE requester_id END AS friend_id
    FROM friends
    WHERE status = 'accepted'
      AND (requester_id = v_caller OR addressee_id = v_caller)
  ),
  targets AS (
    SELECT unnest(p_target_user_ids) AS uid
  ),
  target_friend_pairs AS (
    SELECT t.uid AS target_id,
           CASE WHEN f.requester_id = t.uid THEN f.addressee_id
                ELSE f.requester_id END AS friend_id
    FROM targets t
    JOIN friends f
      ON (f.requester_id = t.uid OR f.addressee_id = t.uid)
     AND f.status = 'accepted'
  ),
  mutuals AS (
    SELECT tfp.target_id, tfp.friend_id
    FROM target_friend_pairs tfp
    JOIN caller_friends cf ON cf.friend_id = tfp.friend_id
    WHERE tfp.target_id <> v_caller
  ),
  ranked AS (
    SELECT
      m.target_id,
      p.id AS friend_id,
      p.display_name,
      p.avatar_url,
      ROW_NUMBER() OVER (
        PARTITION BY m.target_id
        ORDER BY (p.avatar_url IS NOT NULL) DESC, p.display_name ASC
      ) AS rn
    FROM mutuals m
    JOIN profiles p ON p.id = m.friend_id
  )
  SELECT
    t.uid AS target_user_id,
    COALESCE((SELECT COUNT(*)::INTEGER FROM mutuals m WHERE m.target_id = t.uid), 0),
    COALESCE(
      (SELECT jsonb_agg(jsonb_build_object(
         'id', friend_id,
         'display_name', display_name,
         'avatar_url', avatar_url
       ))
       FROM ranked r
       WHERE r.target_id = t.uid AND r.rn <= 3),
      '[]'::JSONB
    )
  FROM targets t;
END;
$$;

GRANT EXECUTE ON FUNCTION get_mutual_friends_summary_batch(UUID[]) TO authenticated;
