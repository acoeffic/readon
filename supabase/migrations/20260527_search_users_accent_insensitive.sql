-- =====================================================
-- Migration: recherche d'utilisateurs insensible aux accents
--
-- Avant : `search_users_page.dart` faisait
--   .from('profiles').ilike('display_name', '%voge%')
-- → match "Vogel" mais PAS "Vögel" / "Vögél". L'utilisateur doit taper
-- les accents exacts pour trouver son ami.
--
-- Fix : RPC `search_users_by_name` qui applique `unaccent(lower(...))`
-- des deux côtés du LIKE. Cherche "voge" → trouve "Vogel", "Vögel",
-- "Végél", etc.
-- =====================================================

CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE OR REPLACE FUNCTION search_users_by_name(
  p_term  TEXT,
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  id            UUID,
  display_name  TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_pattern TEXT;
BEGIN
  IF p_term IS NULL OR length(trim(p_term)) < 2 THEN
    RETURN;
  END IF;

  -- Échapper les wildcards LIKE de l'input, puis wrapper avec %...%
  v_pattern := '%' || replace(replace(unaccent(lower(trim(p_term))), '%', '\%'), '_', '\_') || '%';

  RETURN QUERY
  SELECT p.id, p.display_name
  FROM profiles p
  WHERE unaccent(lower(p.display_name)) LIKE v_pattern
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION search_users_by_name(TEXT, INT) TO authenticated;
