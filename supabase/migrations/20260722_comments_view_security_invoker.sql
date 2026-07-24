-- Fix advisor ERROR security_definer_view : comments_with_user
-- La vue avait été recréée le 20/07 (migration comment_replies) sans
-- security_invoker → elle contournait la RLS de l'appelant et était
-- accessible à anon (tous les commentaires + e-mails des auteurs).
-- Appliquée en prod le 22/07/2026 (migration `comments_view_security_invoker`).

-- 1. La vue respecte désormais la RLS de l'appelant
ALTER VIEW public.comments_with_user SET (security_invoker = on);

-- 2. Pas d'accès anon, pas d'écriture via la vue
REVOKE ALL ON public.comments_with_user FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.comments_with_user FROM authenticated;

-- 3. Policies héritées sur comments :
--    "Anyone can view comments" (USING true) court-circuitait read_comments
--    (la modération devenait sans effet en lecture directe) ; les trois
--    autres sont des doublons exacts de insert/update/delete_comments.
DROP POLICY IF EXISTS "Anyone can view comments" ON public.comments;
DROP POLICY IF EXISTS "Users can create own comments" ON public.comments;
DROP POLICY IF EXISTS "Users can update own comments" ON public.comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON public.comments;
