-- =====================================================================
-- Migration : cacher un livre (user_books.is_hidden) ou une session
-- (reading_sessions.is_hidden) = invisible PARTOUT pour les autres,
-- y compris rétroactivement.
--
-- Contexte
-- --------
-- Depuis la refonte fan-out-on-write du feed (20260507), le feed des amis
-- lit `feed_items` (alimentés par le trigger d'activité + fan-out), et ni
-- le trigger, ni le fan-out, ni get_feed_v2 / get_feed_bundle ne
-- regardaient `is_hidden`. Le contrat de 20260214 ("cacher ses sessions
-- vis-à-vis des autres : feed, classements, profil ami") était perdu pour
-- le feed. Par ailleurs la policy RLS SELECT de reading_sessions laissait
-- les amis lire les sessions cachées / de livres cachés en direct.
--
-- Décision produit (31/07/2026) : cacher = invisible partout, y compris
-- rétroactivement. Conséquence assumée : dé-cacher ne restaure PAS les
-- histoires de feed supprimées (les activités et leurs likes/commentaires
-- sont supprimés en cascade).
--
-- Contenu :
--   1. Choke point : BEFORE INSERT ON activities — aucune activité créée
--      pour un livre caché ou une session cachée (couvre le trigger de
--      session, les inserts client book_finished / book_rated, et tout
--      futur type portant payload->book_id).
--   2. Purge rétroactive à la bascule is_hidden FALSE→TRUE (user_books et
--      reading_sessions) : DELETE des activités correspondantes ;
--      feed_items / likes / comments / notifications suivent par FK
--      ON DELETE CASCADE.
--   3. RLS : la policy SELECT de reading_sessions ne montre plus aux amis
--      ni les sessions cachées ni celles d'un livre caché. Le test livre
--      caché passe par une fonction SECURITY DEFINER : un sous-select
--      direct sur user_books dans la policy serait toujours vide (RLS de
--      user_books = "own only" pour le caller).
--   4. Backfill one-shot : purge des activités des livres/sessions déjà
--      cachés.
--
-- Idempotent : ré-applicable sans effet (DROP IF EXISTS + OR REPLACE).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Choke point : bloquer les nouvelles activités de contenu caché
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.block_hidden_content_activities()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_book_id    TEXT := NEW.payload->>'book_id';
  v_session_id TEXT := NEW.payload->>'session_id';
BEGIN
  -- Livre caché chez l'auteur → pas d'activité (tous types confondus).
  IF v_book_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM user_books ub
    WHERE ub.user_id = NEW.author_id
      AND ub.book_id::text = v_book_id
      AND COALESCE(ub.is_hidden, FALSE)
  ) THEN
    RETURN NULL; -- annule l'INSERT silencieusement
  END IF;

  -- Session déjà marquée cachée → pas d'activité.
  IF v_session_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM reading_sessions rs
    WHERE rs.id::text = v_session_id
      AND rs.user_id = NEW.author_id
      AND COALESCE(rs.is_hidden, FALSE)
  ) THEN
    RETURN NULL;
  END IF;

  RETURN NEW;
END;
$$;

-- Fonction trigger : aucun appelant direct légitime (le grant EXECUTE par
-- défaut de Supabase l'exposerait via /rest/v1/rpc).
REVOKE ALL ON FUNCTION public.block_hidden_content_activities() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_block_hidden_content_activities ON activities;
CREATE TRIGGER trg_block_hidden_content_activities
  BEFORE INSERT ON activities
  FOR EACH ROW
  EXECUTE FUNCTION public.block_hidden_content_activities();

-- ---------------------------------------------------------------------
-- 2a. Purge rétroactive quand on cache un livre
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purge_feed_on_hide_book()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(NEW.is_hidden, FALSE) AND NOT COALESCE(OLD.is_hidden, FALSE) THEN
    -- feed_items, likes, comments, notifications suivent par FK CASCADE.
    DELETE FROM activities a
    WHERE a.author_id = NEW.user_id
      AND a.payload->>'book_id' = NEW.book_id::text;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_feed_on_hide_book() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_purge_feed_on_hide_book ON user_books;
CREATE TRIGGER trg_purge_feed_on_hide_book
  AFTER UPDATE OF is_hidden ON user_books
  FOR EACH ROW
  EXECUTE FUNCTION public.purge_feed_on_hide_book();

-- ---------------------------------------------------------------------
-- 2b. Purge rétroactive quand on cache une session
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purge_feed_on_hide_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(NEW.is_hidden, FALSE) AND NOT COALESCE(OLD.is_hidden, FALSE) THEN
    DELETE FROM activities a
    WHERE a.author_id = NEW.user_id
      AND a.type = 'reading_session'
      AND a.payload->>'session_id' = NEW.id::text;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_feed_on_hide_session() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_purge_feed_on_hide_session ON reading_sessions;
CREATE TRIGGER trg_purge_feed_on_hide_session
  AFTER UPDATE OF is_hidden ON reading_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.purge_feed_on_hide_session();

-- ---------------------------------------------------------------------
-- 3. RLS : les amis ne voient plus les sessions cachées / de livres cachés
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reading_session_visible_to_others(
  p_owner_id  UUID,
  p_book_id   TEXT,
  p_is_hidden BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    -- Garde anti-sonde : la policy vérifie déjà l'amitié, mais la fonction
    -- reste exposée en RPC (grant nécessaire : elle est évaluée par la
    -- policy en tant qu'authenticated) — sans ce garde, n'importe quel
    -- authenticated pourrait tester le statut caché d'un livre chez
    -- n'importe qui.
    (auth.uid() = p_owner_id
     OR EXISTS (
       SELECT 1 FROM friends f
       WHERE ((f.requester_id = auth.uid() AND f.addressee_id = p_owner_id)
           OR (f.addressee_id = auth.uid() AND f.requester_id = p_owner_id))
         AND f.status = 'accepted'
     ))
    AND NOT COALESCE(p_is_hidden, FALSE)
    AND NOT EXISTS (
      SELECT 1 FROM user_books ub
      WHERE ub.user_id = p_owner_id
        AND ub.book_id::text = p_book_id
        AND COALESCE(ub.is_hidden, FALSE)
    );
$$;

REVOKE ALL ON FUNCTION public.reading_session_visible_to_others(UUID, TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reading_session_visible_to_others(UUID, TEXT, BOOLEAN) TO authenticated;

-- Remplace les 3 policies SELECT redondantes (2 legacy {public} + 1
-- authenticated) par une seule policy canonique. Les RPC SECURITY DEFINER
-- (get_friend_recent_sessions, stats...) ne sont pas affectées.
DROP POLICY IF EXISTS "Users can view friends reading sessions" ON reading_sessions;
DROP POLICY IF EXISTS "Users can view own reading sessions" ON reading_sessions;
DROP POLICY IF EXISTS "Users can view their own sessions" ON reading_sessions;

CREATE POLICY "Users can view their own sessions"
ON reading_sessions FOR SELECT TO authenticated
USING (
  auth.uid() = user_id
  OR (
    EXISTS (
      SELECT 1 FROM friends
      WHERE ((friends.requester_id = auth.uid() AND friends.addressee_id = reading_sessions.user_id)
          OR (friends.addressee_id = auth.uid() AND friends.requester_id = reading_sessions.user_id))
        AND friends.status = 'accepted'
    )
    AND public.reading_session_visible_to_others(user_id, book_id, is_hidden)
  )
);

-- ---------------------------------------------------------------------
-- 4. Backfill : purge du contenu déjà caché (one-shot, re-runnable)
-- ---------------------------------------------------------------------
DELETE FROM activities a
USING user_books ub
WHERE a.author_id = ub.user_id
  AND COALESCE(ub.is_hidden, FALSE)
  AND a.payload->>'book_id' = ub.book_id::text;

DELETE FROM activities a
USING reading_sessions rs
WHERE a.author_id = rs.user_id
  AND a.type = 'reading_session'
  AND COALESCE(rs.is_hidden, FALSE)
  AND a.payload->>'session_id' = rs.id::text;
