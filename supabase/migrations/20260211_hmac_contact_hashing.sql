-- Migration : Remplacer SHA256 par HMAC-SHA256 pour le hashing des contacts
--
-- Problème : SHA256 simple sur des emails/téléphones (faible entropie)
-- est réversible via rainbow tables en cas de fuite de la DB.
--
-- Solution : HMAC-SHA256 avec un secret serveur.
-- Le client n'envoie plus de hashes mais des données brutes normalisées
-- à une RPC SECURITY DEFINER qui fait le hashing côté serveur.
--
-- IMPORTANT : Avant d'exécuter cette migration, configurer le secret HMAC
-- via le Vault Supabase :
--   SELECT vault.create_secret('votre-clé-secrète-aléatoire-64-chars', 'hmac_contact_secret');

-- ============================================================================
-- 1. Fonction utilitaire : récupérer le secret HMAC depuis le Vault
-- ============================================================================
CREATE OR REPLACE FUNCTION get_hmac_secret()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, vault, extensions
AS $$
  SELECT decrypted_secret FROM vault.decrypted_secrets
  WHERE name = 'hmac_contact_secret'
  LIMIT 1;
$$;

-- ============================================================================
-- 2. Fonction utilitaire : HMAC-SHA256 d'une chaîne
-- ============================================================================
CREATE OR REPLACE FUNCTION hmac_hash(input text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT encode(
    extensions.hmac(
      lower(trim(input))::bytea,
      get_hmac_secret()::bytea,
      'sha256'
    ),
    'hex'
  );
$$;

-- ============================================================================
-- 3. Mettre à jour le trigger pour utiliser HMAC
-- ============================================================================
CREATE OR REPLACE FUNCTION hash_profile_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NEW.email IS NOT NULL AND (OLD IS NULL OR OLD.email IS DISTINCT FROM NEW.email) THEN
    NEW.email_hash := hmac_hash(NEW.email);
  END IF;
  RETURN NEW;
END;
$$;

-- Le trigger existe déjà, pas besoin de le recréer (il appelle la même fonction)

-- ============================================================================
-- 4. Re-hasher les données existantes avec HMAC
-- ============================================================================
UPDATE profiles
SET email_hash = hmac_hash(email)
WHERE email IS NOT NULL;

UPDATE profiles
SET phone_hash = hmac_hash(phone)
WHERE phone IS NOT NULL AND phone_hash IS NOT NULL;

-- ============================================================================
-- 5. Nouvelle RPC : matching côté serveur (le client envoie du brut)
-- ============================================================================
CREATE OR REPLACE FUNCTION find_contacts_matches_v2(
  p_emails text[] DEFAULT '{}',
  p_phones text[] DEFAULT '{}'
)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_current_user_id UUID;
  v_email_hashes text[];
  v_phone_hashes text[];
BEGIN
  v_current_user_id := auth.uid();
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  -- Hasher les emails côté serveur
  SELECT array_agg(hmac_hash(e))
  INTO v_email_hashes
  FROM unnest(p_emails) AS e
  WHERE e IS NOT NULL AND e != '';

  -- Hasher les téléphones côté serveur
  SELECT array_agg(hmac_hash(p))
  INTO v_phone_hashes
  FROM unnest(p_phones) AS p
  WHERE p IS NOT NULL AND p != '';

  RETURN QUERY
  SELECT jsonb_build_object(
    'id', p.id,
    'display_name', p.display_name,
    'email', p.email,
    'avatar_url', p.avatar_url,
    'is_profile_private', COALESCE(p.is_profile_private, FALSE)
  )
  FROM profiles p
  WHERE (
    (v_email_hashes IS NOT NULL AND p.email_hash = ANY(v_email_hashes))
    OR
    (v_phone_hashes IS NOT NULL AND p.phone_hash = ANY(v_phone_hashes))
  )
    AND p.id != v_current_user_id
    AND p.id NOT IN (
      SELECT CASE
        WHEN f.requester_id = v_current_user_id THEN f.addressee_id
        ELSE f.requester_id
      END
      FROM friends f
      WHERE f.requester_id = v_current_user_id
         OR f.addressee_id = v_current_user_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION find_contacts_matches_v2(text[], text[]) TO authenticated;

-- ============================================================================
-- 6. Révoquer l'accès à l'ancienne RPC (optionnel, pour nettoyage)
-- ============================================================================
-- On garde l'ancienne fonction pour compatibilité temporaire,
-- mais on pourra la supprimer après déploiement complet :
-- DROP FUNCTION IF EXISTS find_contacts_matches(text[]);
