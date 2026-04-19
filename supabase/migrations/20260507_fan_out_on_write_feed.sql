-- =====================================================
-- Migration: Fan-out on write pour le feed social
--
-- Architecture dénormalisée : quand un utilisateur crée
-- une activité, on pré-écrit une entrée dans feed_items
-- pour chacun de ses amis acceptés.
-- Lecture du feed = simple SELECT sans JOIN.
-- =====================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. Table feed_items : le feed pré-calculé de chaque utilisateur
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS feed_items (
  id           BIGSERIAL    PRIMARY KEY,
  owner_id     UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_id  BIGINT       NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  author_id    UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Données dénormalisées de l'auteur (évite un JOIN profiles)
  author_name  TEXT,
  author_avatar TEXT,
  -- Données dénormalisées de l'activité (évite un JOIN activities)
  type         TEXT         NOT NULL,
  payload      JSONB        DEFAULT '{}'::jsonb,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  -- Contrainte unique : un owner ne peut pas avoir 2x la même activité
  UNIQUE(owner_id, activity_id)
);

-- Index principal : le feed d'un utilisateur, trié par date
CREATE INDEX IF NOT EXISTS idx_feed_items_owner_created
  ON feed_items(owner_id, created_at DESC);

-- Index pour le cleanup par activité (suppression en cascade)
CREATE INDEX IF NOT EXISTS idx_feed_items_activity
  ON feed_items(activity_id);

-- Index pour le cleanup par auteur (quand un ami est supprimé)
CREATE INDEX IF NOT EXISTS idx_feed_items_author_owner
  ON feed_items(author_id, owner_id);

-- TTL : on ne garde que 30 jours de feed (nettoyage par cron)
CREATE INDEX IF NOT EXISTS idx_feed_items_created_at
  ON feed_items(created_at);

-- ═══════════════════════════════════════════════════════════════
-- 2. RLS : chaque utilisateur ne voit que son propre feed
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE feed_items ENABLE ROW LEVEL SECURITY;

-- Lecture : uniquement son propre feed
DROP POLICY IF EXISTS "Users can read their own feed items" ON feed_items;
CREATE POLICY "Users can read their own feed items"
  ON feed_items FOR SELECT
  USING (owner_id = auth.uid());

-- Pas d'INSERT/UPDATE/DELETE direct par le client
-- Les écritures passent par le trigger (SECURITY DEFINER)
DROP POLICY IF EXISTS "No direct insert by users" ON feed_items;
CREATE POLICY "No direct insert by users"
  ON feed_items FOR INSERT
  WITH CHECK (false);

DROP POLICY IF EXISTS "No direct update by users" ON feed_items;
CREATE POLICY "No direct update by users"
  ON feed_items FOR UPDATE
  USING (false);

DROP POLICY IF EXISTS "No direct delete by users" ON feed_items;
CREATE POLICY "No direct delete by users"
  ON feed_items FOR DELETE
  USING (false);

-- ═══════════════════════════════════════════════════════════════
-- 3. Fonction de fan-out : distribue une activité à tous les amis
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fan_out_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_name  TEXT;
  v_author_avatar TEXT;
BEGIN
  -- Récupérer le profil de l'auteur (une seule fois)
  SELECT display_name, avatar_url
  INTO v_author_name, v_author_avatar
  FROM profiles
  WHERE id = NEW.author_id;

  -- Insérer dans le feed de chaque ami accepté
  INSERT INTO feed_items (owner_id, activity_id, author_id, author_name, author_avatar, type, payload, created_at)
  SELECT
    CASE
      WHEN f.requester_id = NEW.author_id THEN f.addressee_id
      ELSE f.requester_id
    END AS owner_id,
    NEW.id,
    NEW.author_id,
    v_author_name,
    v_author_avatar,
    NEW.type,
    NEW.payload,
    NEW.created_at
  FROM friends f
  WHERE (f.requester_id = NEW.author_id OR f.addressee_id = NEW.author_id)
    AND f.status = 'accepted'
  ON CONFLICT (owner_id, activity_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Trigger : après chaque INSERT dans activities
DROP TRIGGER IF EXISTS trg_fan_out_activity ON activities;
CREATE TRIGGER trg_fan_out_activity
  AFTER INSERT ON activities
  FOR EACH ROW
  EXECUTE FUNCTION fan_out_activity();

-- ═══════════════════════════════════════════════════════════════
-- 4. Gestion des changements d'amitié
--    Quand un ami est accepté → ajouter ses activités récentes
--    Quand un ami est supprimé → retirer ses entrées du feed
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION handle_friendship_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_a UUID;
  v_user_b UUID;
BEGIN
  v_user_a := COALESCE(NEW.requester_id, OLD.requester_id);
  v_user_b := COALESCE(NEW.addressee_id, OLD.addressee_id);

  -- ── CAS 1 : Amitié acceptée → hydrater les feeds mutuels ──
  IF TG_OP = 'UPDATE' AND NEW.status = 'accepted' AND (OLD.status IS DISTINCT FROM 'accepted') THEN

    -- Activités de A → feed de B (7 derniers jours)
    INSERT INTO feed_items (owner_id, activity_id, author_id, author_name, author_avatar, type, payload, created_at)
    SELECT
      v_user_b,
      a.id,
      a.author_id,
      p.display_name,
      p.avatar_url,
      a.type,
      a.payload,
      a.created_at
    FROM activities a
    JOIN profiles p ON p.id = a.author_id
    WHERE a.author_id = v_user_a
      AND a.created_at >= NOW() - INTERVAL '7 days'
    ON CONFLICT (owner_id, activity_id) DO NOTHING;

    -- Activités de B → feed de A (7 derniers jours)
    INSERT INTO feed_items (owner_id, activity_id, author_id, author_name, author_avatar, type, payload, created_at)
    SELECT
      v_user_a,
      a.id,
      a.author_id,
      p.display_name,
      p.avatar_url,
      a.type,
      a.payload,
      a.created_at
    FROM activities a
    JOIN profiles p ON p.id = a.author_id
    WHERE a.author_id = v_user_b
      AND a.created_at >= NOW() - INTERVAL '7 days'
    ON CONFLICT (owner_id, activity_id) DO NOTHING;

  -- ── CAS 2 : Amitié supprimée ou refusée → purger les feeds mutuels ──
  ELSIF TG_OP = 'DELETE'
     OR (TG_OP = 'UPDATE' AND NEW.status != 'accepted' AND OLD.status = 'accepted') THEN

    -- Retirer les activités de A du feed de B
    DELETE FROM feed_items
    WHERE owner_id = v_user_b AND author_id = v_user_a;

    -- Retirer les activités de B du feed de A
    DELETE FROM feed_items
    WHERE owner_id = v_user_a AND author_id = v_user_b;

  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_friendship_change ON friends;
CREATE TRIGGER trg_friendship_change
  AFTER UPDATE OR DELETE ON friends
  FOR EACH ROW
  EXECUTE FUNCTION handle_friendship_change();

-- ═══════════════════════════════════════════════════════════════
-- 5. Mise à jour dénormalisée du profil auteur
--    Quand un auteur change son nom/avatar, on met à jour ses
--    feed_items (batch, pas critique en latence)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION sync_feed_items_author_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Ne mettre à jour que si le nom ou l'avatar a changé
  IF OLD.display_name IS DISTINCT FROM NEW.display_name
     OR OLD.avatar_url IS DISTINCT FROM NEW.avatar_url THEN
    UPDATE feed_items
    SET author_name = NEW.display_name,
        author_avatar = NEW.avatar_url
    WHERE author_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_feed_author_profile ON profiles;
CREATE TRIGGER trg_sync_feed_author_profile
  AFTER UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_feed_items_author_profile();

-- ═══════════════════════════════════════════════════════════════
-- 6. RPC de lecture du feed (remplace friend_activity_view)
--    Simple SELECT sur feed_items — zéro JOIN
-- ═══════════════════════════════════════════════════════════════

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
    AND fi.created_at >= NOW() - INTERVAL '7 days'
    AND (p_cursor IS NULL OR fi.created_at < p_cursor)
  ORDER BY fi.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_feed_v2(INT, TIMESTAMPTZ) TO authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 7. Nettoyage automatique : supprimer les feed_items > 30 jours
--    (via pg_cron si disponible)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION cleanup_old_feed_items()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM feed_items
  WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_namespace WHERE nspname = 'cron'
  ) THEN
    RAISE NOTICE 'pg_cron non disponible — lancer cleanup_old_feed_items() manuellement';
    RETURN;
  END IF;

  -- Supprimer le job s'il existe déjà
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_old_feed_items') THEN
    EXECUTE 'SELECT cron.unschedule(''cleanup_old_feed_items'')';
  END IF;

  -- Nettoyer tous les jours à 3h du matin
  EXECUTE 'SELECT cron.schedule(''cleanup_old_feed_items'', ''0 3 * * *'', ''SELECT cleanup_old_feed_items()'')';
END;
$$;
