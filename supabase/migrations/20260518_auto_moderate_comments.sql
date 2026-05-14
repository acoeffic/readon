-- Auto-modération des commentaires.
--
-- Symptôme avant ce fix : la migration `20260410_ai_moderated_comments.sql`
-- ajoute le statut 'pending'/'approved'/'rejected' et l'edge function
-- `moderate-comment` existe — mais rien ne l'invoque, donc tout commentaire
-- créé reste « en attente » à vie.
--
-- Ce fichier branche un trigger AFTER INSERT qui appelle l'edge function via
-- pg_net. L'appel est non-bloquant : l'utilisateur voit son commentaire
-- immédiatement (RLS le laisse voir ses propres commentaires en pending), et
-- la modération met à jour `status` quelques secondes plus tard. Si l'edge
-- function n'a pas de clé OpenAI, elle auto-approuve (cf.
-- `moderate-comment/index.ts`).
--
-- Prérequis (à faire UNE FOIS dans Studio, pas committé) :
--   SELECT vault.create_secret('<service_role_key>', 'service_role_key', '...');
-- L'URL du projet est hardcodée car publique.

CREATE EXTENSION IF NOT EXISTS pg_net;

-- ──────────────────────────────────────────────────────────────────────
-- Trigger function : appelle moderate-comment via HTTP POST
-- La clé service_role est lue depuis Supabase Vault.
-- ──────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION trigger_moderate_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  v_supabase_url      CONSTANT text := 'https://nzbhmshkcwudzydeahrq.supabase.co';
  v_service_role_key  text;
BEGIN
  IF NEW.status <> 'pending' THEN
    RETURN NEW;
  END IF;

  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key';

  IF v_service_role_key IS NULL THEN
    RAISE WARNING 'trigger_moderate_comment: vault secret "service_role_key" missing';
    RETURN NEW;
  END IF;

  -- Fire-and-forget : pg_net ne bloque pas la transaction.
  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/moderate-comment',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'comment_id', NEW.id,
      'content', NEW.content
    )
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais bloquer l'INSERT si pg_net échoue ; on log et on continue.
    RAISE WARNING 'trigger_moderate_comment failed for comment %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_moderate_comment_after_insert ON comments;
CREATE TRIGGER trg_moderate_comment_after_insert
  AFTER INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_moderate_comment();

-- ──────────────────────────────────────────────────────────────────────
-- Cleanup du backlog : les commentaires bloqués depuis plus d'une heure
-- ne seront jamais modérés rétroactivement par le trigger (qui ne se
-- déclenche qu'à l'INSERT). On les approuve directement — c'est cohérent
-- avec l'auto-approve par défaut de l'edge function quand OpenAI est down.
-- ──────────────────────────────────────────────────────────────────────

UPDATE comments
SET status = 'approved'
WHERE status = 'pending'
  AND created_at < (now() - interval '1 hour');
