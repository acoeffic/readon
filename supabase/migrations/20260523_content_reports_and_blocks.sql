-- Migration: signalement de contenu/utilisateurs + blocage d'utilisateurs.
-- Requis par les guidelines Apple App Store §1.2 (UGC moderation).
--
-- Deux tables :
--   1. content_reports : signalements de contenu (commentaire, activité,
--      profil) ou d'utilisateur (target_type = 'user'). Stocke la raison,
--      le détail optionnel, et le statut de modération.
--   2. user_blocks : utilisateurs bloqués par l'utilisateur courant. Sert
--      à filtrer le feed, les commentaires, les profils. Bloquer ≠
--      signaler ; les deux flux sont indépendants.

-- ─────────────────────────────────────────────────────────────────────
-- content_reports
-- ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.content_reports (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id     UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type     TEXT         NOT NULL CHECK (target_type IN (
                                'user', 'profile', 'comment', 'activity',
                                'reading_session', 'review'
                              )),
  -- TEXT pour pouvoir stocker UUID, BIGINT ou autre selon le target_type.
  target_id       TEXT         NOT NULL,
  -- Auteur du contenu signalé (si applicable). Utile pour les requêtes
  -- de modération côté admin : "tous les rapports contre user X".
  target_user_id  UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  reason          TEXT         NOT NULL CHECK (reason IN (
                                'spam', 'harassment', 'hate_speech',
                                'sexual_content', 'violence', 'self_harm',
                                'misinformation', 'impersonation',
                                'illegal', 'other'
                              )),
  details         TEXT,
  status          TEXT         NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending', 'reviewed', 'dismissed', 'actioned')),
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  reviewed_at     TIMESTAMPTZ,
  reviewer_id     UUID         REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Un user ne peut signaler qu'une fois le même contenu (anti-spam).
  CONSTRAINT content_reports_unique_reporter_target
    UNIQUE (reporter_id, target_type, target_id)
);

CREATE INDEX IF NOT EXISTS idx_content_reports_target
  ON public.content_reports (target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_target_user
  ON public.content_reports (target_user_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_status_created
  ON public.content_reports (status, created_at DESC);

-- RLS
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reporters insert own reports" ON public.content_reports;
CREATE POLICY "reporters insert own reports"
  ON public.content_reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "reporters read own reports" ON public.content_reports;
CREATE POLICY "reporters read own reports"
  ON public.content_reports FOR SELECT TO authenticated
  USING (auth.uid() = reporter_id);

-- Les UPDATE/DELETE sont réservés au service_role (admin/back-office).

-- ─────────────────────────────────────────────────────────────────────
-- user_blocks
-- ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_blocks (
  blocker_id  UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id  UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT user_blocks_no_self CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked
  ON public.user_blocks (blocked_id);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users manage own blocks" ON public.user_blocks;
CREATE POLICY "users manage own blocks"
  ON public.user_blocks FOR ALL TO authenticated
  USING (auth.uid() = blocker_id)
  WITH CHECK (auth.uid() = blocker_id);

-- ─────────────────────────────────────────────────────────────────────
-- RPC: is_blocked(p_user_id)
--   Retourne true si l'utilisateur courant a bloqué p_user_id OU si
--   p_user_id a bloqué l'utilisateur courant. Utilisé pour filtrer
--   l'affichage côté client.
-- ─────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_blocked(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE (blocker_id = auth.uid() AND blocked_id = p_user_id)
       OR (blocker_id = p_user_id AND blocked_id = auth.uid())
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_blocked(UUID) TO authenticated;

-- Side-effect du blocage : supprimer la relation d'amitié si elle existe
-- (sinon l'utilisateur bloqué resterait dans la liste d'amis).
CREATE OR REPLACE FUNCTION public.handle_user_block()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM friends
  WHERE (requester_id = NEW.blocker_id AND addressee_id = NEW.blocked_id)
     OR (requester_id = NEW.blocked_id AND addressee_id = NEW.blocker_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_block_remove_friendship ON public.user_blocks;
CREATE TRIGGER trg_user_block_remove_friendship
  AFTER INSERT ON public.user_blocks
  FOR EACH ROW EXECUTE FUNCTION public.handle_user_block();
