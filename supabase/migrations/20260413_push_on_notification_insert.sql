-- Migration : Envoi automatique de push notifications via pg_net
-- Quand une notification interne est insérée, on appelle l'Edge Function
-- send-push-notification si le destinataire a un fcm_token.
-- Pattern identique à send_friend_request_email (20260315).

-- Fonction trigger : envoie un push via l'Edge Function
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

-- Trigger sur INSERT dans notifications
DROP TRIGGER IF EXISTS trigger_push_on_notification ON notifications;
CREATE TRIGGER trigger_push_on_notification
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION send_push_on_notification();
