-- Email notifications pour les commentaires.
--
-- Symétrique au pattern friend_request (cf. 20260315_notification_center.sql) :
-- 1) une colonne d'opt-out `notify_comments_email` sur profiles, par défaut TRUE ;
-- 2) un trigger sur `comments` qui appelle l'edge function `send-comment-email`
--    via pg_net **après modération**, c.-à-d. quand le statut passe de
--    'pending' à 'approved'. On évite ainsi d'emailer pour un commentaire
--    rejeté par `moderate-comment`.
--
-- La clé service_role est lue depuis Supabase Vault (même schéma que
-- 20260518_auto_moderate_comments.sql).

CREATE EXTENSION IF NOT EXISTS pg_net;

-- ──────────────────────────────────────────────────────────────────────
-- 1. Préférence utilisateur
-- ──────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notify_comments_email BOOLEAN NOT NULL DEFAULT true;

-- ──────────────────────────────────────────────────────────────────────
-- 2. Trigger function : envoie l'email après modération
-- ──────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION send_comment_email_on_approve()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  v_supabase_url      CONSTANT text := 'https://nzbhmshkcwudzydeahrq.supabase.co';
  v_service_role_key  text;
  v_activity          RECORD;
  v_recipient         RECORD;
  v_sender_name       text;
  v_recipient_email   text;
  v_book_title        text;
BEGIN
  -- N'agir qu'à la transition pending → approved.
  IF NEW.status <> 'approved' OR OLD.status = 'approved' THEN
    RETURN NEW;
  END IF;

  -- Auteur de l'activité commentée.
  SELECT author_id, payload INTO v_activity
  FROM activities
  WHERE id = NEW.activity_id;

  IF v_activity.author_id IS NULL OR v_activity.author_id = NEW.author_id THEN
    -- Pas d'activité, ou l'auteur commente sa propre session : on n'email pas.
    RETURN NEW;
  END IF;

  -- Préférence + email du destinataire.
  SELECT display_name, email, notify_comments_email
    INTO v_recipient
    FROM profiles
    WHERE id = v_activity.author_id;

  IF v_recipient IS NULL
     OR v_recipient.notify_comments_email IS NOT TRUE
     OR v_recipient.email IS NULL
     OR v_recipient.email = '' THEN
    RETURN NEW;
  END IF;

  v_recipient_email := v_recipient.email;

  -- Nom du commentateur.
  SELECT COALESCE(display_name, 'Un lecteur') INTO v_sender_name
  FROM profiles
  WHERE id = NEW.author_id;

  v_book_title := COALESCE(v_activity.payload->>'book_title', '');

  -- Clé service_role depuis Vault.
  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key';

  IF v_service_role_key IS NULL THEN
    RAISE WARNING 'send_comment_email_on_approve: vault secret "service_role_key" missing';
    RETURN NEW;
  END IF;

  -- Fire-and-forget : on ne bloque jamais l'UPDATE du commentaire.
  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/send-comment-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'to_email',     v_recipient_email,
      'to_name',      COALESCE(v_recipient.display_name, 'Lecteur'),
      'from_name',    v_sender_name,
      'book_title',   v_book_title,
      'comment',      NEW.content,
      'activity_id',  NEW.activity_id
    )
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'send_comment_email_on_approve failed for comment %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_comment_email_after_approve ON comments;
CREATE TRIGGER trg_comment_email_after_approve
  AFTER UPDATE OF status ON comments
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'approved')
  EXECUTE FUNCTION send_comment_email_on_approve();
