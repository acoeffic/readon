-- Agrégat par livre pour le mur « Mes passages ».
--
-- La grille chargeait jusqu'ici TOUTES les annotations de l'utilisateur
-- (getAllAnnotationsWithBooks, limit 500) pour les grouper côté client :
-- au-delà de 500, les passages anciens sortaient silencieusement du mur.
-- Avec l'import des surlignages Kindle (359 lignes dès le premier sync),
-- la limite était à portée immédiate. La grille n'a besoin que d'un
-- agrégat (compte + date du dernier passage par livre) ; le contenu est
-- chargé à la demande dans la page du livre (getAnnotationsForBook).
--
-- `p_query` (optionnel) : recherche plein-texte naïve dans le contenu et la
-- note — sert au champ de recherche du mur (« cette phrase dont je me
-- souviens »). `position(...)` plutôt que ILIKE : pas de métacaractères
-- LIKE à échapper.
--
-- SECURITY INVOKER : la RLS d'annotations s'applique, le filtre
-- `user_id = auth.uid()` est une ceinture en plus des bretelles.

CREATE OR REPLACE FUNCTION public.get_annotation_book_groups(
  p_query text DEFAULT NULL
)
RETURNS TABLE (
  book_id text,
  passage_count integer,
  latest_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT a.book_id,
         count(*)::integer AS passage_count,
         max(a.created_at) AS latest_at
  FROM public.annotations a
  WHERE a.user_id = auth.uid()
    AND (
      p_query IS NULL
      OR btrim(p_query) = ''
      OR position(lower(btrim(p_query)) IN lower(a.content)) > 0
      OR position(lower(btrim(p_query)) IN lower(coalesce(a.note, ''))) > 0
    )
  GROUP BY a.book_id
  ORDER BY max(a.created_at) DESC
$$;

-- Durcissement RLS du 22/07/2026 : les nouvelles RPC exigent un GRANT
-- explicite à authenticated, et anon/public ne doivent pas avoir EXECUTE.
REVOKE EXECUTE ON FUNCTION public.get_annotation_book_groups(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_annotation_book_groups(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_annotation_book_groups(text) TO authenticated;

COMMENT ON FUNCTION public.get_annotation_book_groups(text) IS
  'Agrégat des annotations de l''utilisateur courant par livre (compte + dernier passage), avec recherche optionnelle dans contenu/note. Alimente la grille Mes passages.';
