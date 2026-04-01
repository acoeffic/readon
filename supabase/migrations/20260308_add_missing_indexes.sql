-- Migration : Ajout des index manquants pour la performance à grande échelle
-- Cible les tables sociales (likes, comments, user_badges) qui n'ont aucun index,
-- et ajoute des index composites pour les fonctions RPC les plus sollicitées.

-- ═══════════════════════════════════════════════════════════════
-- 1. user_badges — aucun index existant, utilisé dans :
--    - check_and_award_badges() : SELECT 1 FROM user_badges WHERE badge_id = ... AND user_id = ...
--    - get_all_user_badges()    : LEFT JOIN user_badges ON ub.user_id = p_user_id
--    - getUserBadgesById()      : RPC get_all_user_badges
--    - delete_user_account()    : DELETE FROM user_badges WHERE user_id = uid
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id
  ON user_badges(user_id);

CREATE INDEX IF NOT EXISTS idx_user_badges_user_badge
  ON user_badges(user_id, badge_id);

-- ═══════════════════════════════════════════════════════════════
-- 2. likes — aucun index existant, utilisé dans :
--    - check_and_award_badges() : SELECT COUNT(*) FROM likes WHERE user_id = ...
--    - likes_service.dart       : .eq('activity_id', ...).eq('user_id', ...)
--    - delete_user_account()    : DELETE FROM likes WHERE user_id = uid
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_likes_activity_id
  ON likes(activity_id);

CREATE INDEX IF NOT EXISTS idx_likes_user_id
  ON likes(user_id);

-- Composite pour le check "est-ce que l'utilisateur a déjà liké ?"
CREATE INDEX IF NOT EXISTS idx_likes_user_activity
  ON likes(user_id, activity_id);

-- ═══════════════════════════════════════════════════════════════
-- 3. comments — aucun index existant, utilisé dans :
--    - check_and_award_badges() : SELECT COUNT(*) FROM comments WHERE user_id = ...
--    - comments_service.dart    : .eq('activity_id', ...).order('created_at')
--    - delete_user_account()    : DELETE FROM comments WHERE author_id = uid
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_comments_activity_id
  ON comments(activity_id);

CREATE INDEX IF NOT EXISTS idx_comments_author_id
  ON comments(author_id);

-- Pour le fil de commentaires paginé par activité
CREATE INDEX IF NOT EXISTS idx_comments_activity_created
  ON comments(activity_id, created_at DESC);

-- ═══════════════════════════════════════════════════════════════
-- 4. reading_sessions — index existants axés sur start_time,
--    mais les calculs de flow/percentile filtrent sur end_time
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_reading_sessions_user_end_time
  ON reading_sessions(user_id, end_time DESC)
  WHERE end_time IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════
-- 5. books — lookup fréquent par google_id depuis le client
--    (.eq('google_id', ...) dans books_service.dart, lignes 20, 419, 889)
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_books_google_id
  ON books(google_id)
  WHERE google_id IS NOT NULL;

-- Lookup par source pour les livres Kindle
CREATE INDEX IF NOT EXISTS idx_books_source
  ON books(source)
  WHERE source IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════
-- 6. notifications — index existant sur (user_id, created_at)
--    mais le compteur non-lu a besoin d'un filtre partiel
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications(user_id, created_at DESC)
  WHERE is_read = FALSE;

-- ═══════════════════════════════════════════════════════════════
-- 7. user_books — index partiel pour les livres terminés
--    (badge calculations : COUNT(*) FROM user_books WHERE status = 'finished')
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_user_books_user_finished
  ON user_books(user_id)
  WHERE status = 'finished';
