-- Migration : Audit log pour les opérations sensibles
-- Trace les suppressions de compte, attributions de badges,
-- et autres actions critiques pour diagnostic et conformité.

-- ============================================================================
-- 1. Table audit_log
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     uuid,                          -- peut être NULL si le user est déjà supprimé
  action      text NOT NULL,                 -- ex: 'delete_account', 'award_badge', 'award_secret_badge'
  details     jsonb DEFAULT '{}',            -- contexte libre (badge_id, erreur, etc.)
  ip_address  inet,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_created ON audit_log(created_at);

-- RLS : personne ne lit/écrit directement, tout passe par SECURITY DEFINER
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
-- Pas de policy = aucun accès direct pour les utilisateurs

-- ============================================================================
-- 2. Fonction utilitaire pour écrire un log
-- ============================================================================
CREATE OR REPLACE FUNCTION write_audit_log(
  p_action text,
  p_details jsonb DEFAULT '{}',
  p_user_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO audit_log (user_id, action, details)
  VALUES (
    COALESCE(p_user_id, auth.uid()),
    p_action,
    p_details
  );
END;
$$;

-- ============================================================================
-- 3. Ajouter un log dans delete_user_account
-- ============================================================================
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  uid UUID;
  v_email TEXT;
  v_display_name TEXT;
BEGIN
  uid := auth.uid();

  IF uid IS NULL THEN
    RETURN json_build_object(
      'success', FALSE,
      'error', 'NOT_AUTHENTICATED',
      'message', 'Utilisateur non authentifié'
    );
  END IF;

  -- Récupérer les infos du profil avant suppression (pour le log)
  SELECT email, display_name INTO v_email, v_display_name
  FROM profiles WHERE id = uid;

  -- Log AVANT la suppression
  PERFORM write_audit_log(
    'delete_account',
    jsonb_build_object(
      'email', v_email,
      'display_name', v_display_name
    ),
    uid
  );

  -- Supprimer les tables sans ON DELETE CASCADE
  DELETE FROM notifications WHERE user_id = uid OR from_user_id = uid;
  DELETE FROM comments WHERE author_id = uid;
  DELETE FROM likes WHERE user_id = uid;
  DELETE FROM reactions WHERE user_id = uid;
  DELETE FROM friends WHERE requester_id = uid OR addressee_id = uid;
  DELETE FROM user_badges WHERE user_id = uid;
  DELETE FROM reading_sessions WHERE user_id = uid;
  DELETE FROM user_books WHERE user_id = uid;

  DELETE FROM storage.objects
  WHERE bucket_id = 'profiles'
    AND name LIKE 'avatars/' || uid::TEXT || '/%';

  DELETE FROM profiles WHERE id = uid;

  DELETE FROM auth.users WHERE id = uid;

  RETURN json_build_object(
    'success', TRUE,
    'message', 'Compte supprimé avec succès'
  );

EXCEPTION WHEN OTHERS THEN
  -- Log l'échec aussi
  PERFORM write_audit_log(
    'delete_account_failed',
    jsonb_build_object('error', SQLERRM),
    uid
  );

  RETURN json_build_object(
    'success', FALSE,
    'error', 'DELETION_FAILED',
    'message', SQLERRM
  );
END;
$$;

-- ============================================================================
-- 4. Trigger sur user_badges pour logger les attributions
-- ============================================================================
CREATE OR REPLACE FUNCTION log_badge_awarded()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM write_audit_log(
    'award_badge',
    jsonb_build_object('badge_id', NEW.badge_id),
    NEW.user_id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_badge_awarded ON user_badges;
CREATE TRIGGER trg_log_badge_awarded
  AFTER INSERT ON user_badges
  FOR EACH ROW
  EXECUTE FUNCTION log_badge_awarded();
