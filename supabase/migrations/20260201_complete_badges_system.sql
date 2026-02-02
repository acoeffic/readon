-- ============================================================================
-- MIGRATION: Système de Badges Complet ReadOn
-- ============================================================================
-- Ajoute ~95 badges répartis en catégories gratuites et premium
-- Inclut les RPCs get_all_user_badges et check_and_award_badges
-- ============================================================================

-- ============================================================================
-- 1. AJOUT COLONNES À LA TABLE BADGES
-- ============================================================================

ALTER TABLE badges ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT false;
ALTER TABLE badges ADD COLUMN IF NOT EXISTS is_secret BOOLEAN DEFAULT false;
ALTER TABLE badges ADD COLUMN IF NOT EXISTS is_animated BOOLEAN DEFAULT false;
ALTER TABLE badges ADD COLUMN IF NOT EXISTS progress_unit TEXT DEFAULT 'livres';
ALTER TABLE badges ADD COLUMN IF NOT EXISTS lottie_asset TEXT;
ALTER TABLE badges ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- ============================================================================
-- 2. SUPPRESSION DES ANCIENS BADGES DE STREAK (on les recrée avec les bons champs)
-- ============================================================================

DELETE FROM badges WHERE category = 'streak' AND id LIKE 'streak_%';

-- ============================================================================
-- 3. INSERT TOUTES LES DÉFINITIONS DE BADGES
-- ============================================================================

-- ─────────────────────────────────────────────
-- 3.1 LIVRES TERMINÉS (books_completed)
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('books_1',   'Premier Chapitre',   'Terminer son 1er livre',    '📖', 'books_completed', 1,   '#4CAF50', false, 'livres', 1),
  ('books_5',   'Apprenti Lecteur',   '5 livres terminés',         '📚', 'books_completed', 5,   '#66BB6A', false, 'livres', 2),
  ('books_10',  'Lecteur Confirmé',   '10 livres terminés',        '📚', 'books_completed', 10,  '#43A047', false, 'livres', 3),
  ('books_25',  'Bibliophile',        '25 livres terminés',        '🏛️', 'books_completed', 25,  '#388E3C', false, 'livres', 4),
  ('books_50',  'Dévoreur de Pages',  '50 livres terminés',        '🔥', 'books_completed', 50,  '#2E7D32', false, 'livres', 5),
  ('books_100', 'Centenaire',         '100 livres terminés',       '💯', 'books_completed', 100, '#FFD700', true,  'livres', 6),
  ('books_200', 'Légende Littéraire', '200 livres terminés',       '👑', 'books_completed', 200, '#FFC107', true,  'livres', 7),
  ('books_500', 'Bibliothèque Vivante', '500 livres terminés',     '🏛️', 'books_completed', 500, '#FF9800', true,  'livres', 8)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon = EXCLUDED.icon,
  category = EXCLUDED.category,
  requirement = EXCLUDED.requirement,
  color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium,
  progress_unit = EXCLUDED.progress_unit,
  sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.2 TEMPS DE LECTURE (reading_time)
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('time_first',  'Première Session',     '1ère session enregistrée',    '⏱️', 'reading_time', 1,    '#2196F3', false, 'sessions', 1),
  ('time_1h',     'Une Heure de Magie',   '1h de lecture cumulée',       '⌛', 'reading_time', 60,    '#1E88E5', false, 'minutes', 2),
  ('time_10h',    'Lecteur du Dimanche',  '10h de lecture cumulées',     '☕', 'reading_time', 600,   '#1976D2', false, 'minutes', 3),
  ('time_50h',    'Passionné',            '50h de lecture cumulées',     '💜', 'reading_time', 3000,  '#1565C0', false, 'minutes', 4),
  ('time_100h',   'Centurion',            '100h de lecture cumulées',    '🏆', 'reading_time', 6000,  '#0D47A1', false, 'minutes', 5),
  ('time_250h',   'Marathonien',          '250h de lecture',             '🏃', 'reading_time', 15000, '#FFD700', true,  'minutes', 6),
  ('time_500h',   'Demi-Millénaire',      '500h de lecture',             '⚡', 'reading_time', 30000, '#FFC107', true,  'minutes', 7),
  ('time_1000h',  'Millénaire',           '1000h de lecture',            '🌟', 'reading_time', 60000, '#FF9800', true,  'minutes', 8)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.3 STREAKS (streak)
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('streak_3_days',   'Premier Pas',          'Streak de 3 jours',          '👣', 'streak', 3,   '#FFB74D', false, 'jours', 1),
  ('streak_7_days',   'Une Semaine',          'Streak de 7 jours',          '📅', 'streak', 7,   '#FF9800', false, 'jours', 2),
  ('streak_14_days',  'Deux Semaines',        'Streak de 14 jours',         '🔥', 'streak', 14,  '#FFC107', false, 'jours', 3),
  ('streak_30_days',  'Un Mois',              'Streak de 30 jours',         '🌟', 'streak', 30,  '#FF5722', false, 'jours', 4),
  ('streak_60_days',  'Incassable',           'Streak de 60 jours',         '💎', 'streak', 60,  '#9C27B0', false, 'jours', 5),
  ('streak_90_days',  'Trimestre Parfait',    'Streak de 90 jours',         '🔥', 'streak', 90,  '#FFD700', true,  'jours', 6),
  ('streak_180_days', 'Semi-Annuel',          'Streak de 180 jours',        '💎', 'streak', 180, '#FFC107', true,  'jours', 7),
  ('streak_365_days', 'Année Complète',       'Streak de 365 jours',        '👑', 'streak', 365, '#FF9800', true,  'jours', 8),
  ('streak_500_days', 'Streak Légendaire',    'Streak de 500 jours',        '🏆', 'streak', 500, '#E91E63', true,  'jours', 9)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.4 OBJECTIFS (goals)
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('goal_created',    'Objectif Fixé',       'Créer son 1er objectif',       '🎯', 'goals', 1, '#9C27B0', false, 'objectifs', 1),
  ('goal_achieved_1', 'Mission Accomplie',   'Atteindre 1 objectif',         '✅', 'goals', 1, '#7B1FA2', false, 'objectifs', 2),
  ('goal_achieved_5', 'Performeur',          'Atteindre 5 objectifs',        '🏅', 'goals', 5, '#6A1B9A', false, 'objectifs', 3)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.5 SOCIAL (social)
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('social_follow_5',     'Sociable',           'Suivre 5 amis',                '👋', 'social', 5,    '#E91E63', false, 'amis', 1),
  ('social_follow_20',    'Networker',          'Suivre 20 amis',               '🤝', 'social', 20,   '#C2185B', false, 'amis', 2),
  ('social_first_like',   'Première Réaction',  'Liker une activité',           '❤️', 'social', 1,    '#F44336', false, 'likes', 3),
  ('social_comments_10',  'Bavard',             'Écrire 10 commentaires',       '💬', 'social', 10,   '#D32F2F', false, 'commentaires', 4),
  ('social_followers_10', 'Influenceur',        'Avoir 10 followers',           '⭐', 'social', 10,   '#B71C1C', false, 'followers', 5),
  -- Premium
  ('social_followers_100','Influenceur Pro',    '100 followers',                '📢', 'social', 100,  '#FFD700', true, 'followers', 6),
  ('social_followers_500','Star',               '500 followers',                '⭐', 'social', 500,  '#FFC107', true, 'followers', 7),
  ('social_followers_1k', 'Célébrité',          '1000 followers',               '👑', 'social', 1000, '#FF9800', true, 'followers', 8),
  ('social_reviews_50',   'Critique Littéraire','50 avis écrits',              '📝', 'social', 50,   '#FF5722', true, 'avis', 9),
  ('social_invite_10',    'Parrain d''Or',      '10 amis invités',              '🎁', 'social', 10,   '#E91E63', true, 'invitations', 10),
  ('social_invite_25',    'Parrain Platine',    '25 amis invités',              '🎁', 'social', 25,   '#9C27B0', true, 'invitations', 11),
  ('social_club_founder', 'Fondateur de Club',  'Créer un club de lecture',     '🏠', 'social', 1,    '#673AB7', true, 'clubs', 12),
  ('social_club_leader',  'Leader',             'Club avec 10+ membres',        '👥', 'social', 10,   '#512DA8', true, 'membres', 13)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.6 EXPLORATION / GENRES (genres)
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('genre_explorer_3',   'Explorateur',       'Lire 3 genres différents',       '🧭', 'genres', 3,  '#009688', false, 'genres', 1),
  ('genre_explorer_5',   'Éclectique',        'Lire 5 genres différents',       '🌈', 'genres', 5,  '#00796B', false, 'genres', 2),
  ('genre_fiction_5',    'Amateur de Fiction', '5 livres de fiction',            '🏰', 'genres', 5,  '#00695C', false, 'livres', 3),
  ('genre_nonfiction_5', 'Esprit Curieux',    '5 livres non-fiction',           '🧠', 'genres', 5,  '#004D40', false, 'livres', 4),
  -- Maîtres (premium)
  ('genre_master_thriller',  'Maître du Thriller',  '20 thrillers lus',         '🔪', 'genres', 20, '#FFD700', true, 'livres', 5),
  ('genre_master_romance',   'Maître de la Romance','20 romances lues',         '💕', 'genres', 20, '#E91E63', true, 'livres', 6),
  ('genre_master_sf',        'Maître de la SF',     '20 livres SF lus',         '🚀', 'genres', 20, '#2196F3', true, 'livres', 7),
  ('genre_master_fantasy',   'Maître de la Fantasy','20 livres fantasy lus',    '🐉', 'genres', 20, '#9C27B0', true, 'livres', 8),
  ('genre_master_mystery',   'Maître du Polar',     '20 polars lus',            '🔍', 'genres', 20, '#607D8B', true, 'livres', 9),
  ('genre_master_history',   'Maître de l''Histoire','20 livres historiques',   '⚔️', 'genres', 20, '#795548', true, 'livres', 10),
  ('genre_master_selfhelp',  'Maître du Dev Perso', '20 livres dev perso',      '🧘', 'genres', 20, '#FF9800', true, 'livres', 11),
  ('genre_master_biography', 'Maître de la Bio',    '20 biographies lues',      '👤', 'genres', 20, '#4CAF50', true, 'livres', 12),
  ('genre_master_all',       'Omniscient',          'Tous les badges Maître',   '🌟', 'genres', 8,  '#FFD700', true, 'badges', 13)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.7 ENGAGEMENT APP (engagement)
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('engage_profile',  'Bienvenue',  'Compléter son profil',              '👤', 'engagement', 1, '#795548', false, '', 1),
  ('engage_kindle',   'Connecté',   'Lier son compte Kindle',            '🔗', 'engagement', 1, '#6D4C41', false, '', 2),
  ('engage_invite_1', 'Parrain',    'Inviter 1 ami qui s''inscrit',      '🎁', 'engagement', 1, '#5D4037', false, 'invitations', 3)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.8 BADGES ANIMÉS (animated) - Premium
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_animated, lottie_asset, progress_unit, sort_order)
VALUES
  ('anim_rising_star',    'Étoile Montante',   '10 livres en 1 mois',           '⭐', 'animated', 10, '#FFD700', true, true, 'rising_star',    'livres', 1),
  ('anim_fire_burst',     'Feu de Paille',     'Session de 3h+ d''affilée',     '🔥', 'animated', 180,'#FF5722', true, true, 'fire_burst',     'minutes', 2),
  ('anim_night_owl',      'Noctambule',        '10 sessions après minuit',      '🌙', 'animated', 10, '#3F51B5', true, true, 'night_owl',      'sessions', 3),
  ('anim_early_bird',     'Lève-Tôt',          '10 sessions avant 7h',          '🌅', 'animated', 10, '#FF9800', true, true, 'early_bird',     'sessions', 4),
  ('anim_weekend_warrior','Week-end Warrior',   '5h de lecture un week-end',     '⚔️', 'animated', 300,'#9C27B0', true, true, 'weekend_warrior', 'minutes', 5)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, is_animated = EXCLUDED.is_animated, lottie_asset = EXCLUDED.lottie_asset,
  progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.9 BADGES SECRETS (secret)
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_secret, progress_unit, sort_order)
VALUES
  ('secret_midnight',     'Minuit Pile',         'Commencer une session à 00:00',     '🕛', 'secret', 1,   '#311B92', true, '', 1),
  ('secret_new_year',     'Premier de l''An',    'Lire le 1er janvier',               '🎆', 'secret', 1,   '#1A237E', true, '', 2),
  ('secret_night_marathon','Marathon Nocturne',   'Lire de 22h à 6h',                 '🦉', 'secret', 1,   '#0D47A1', true, '', 3),
  ('secret_finisher',     'Finisher',            'Terminer un livre en 1 session',    '🚀', 'secret', 1,   '#01579B', true, '', 4),
  ('secret_palindrome',   'Palindrome',          'Lire un 12/12, 11/11, etc.',        '🔢', 'secret', 1,   '#006064', true, '', 5),
  ('secret_loyal_1y',     'Fidèle',              'Utiliser l''app 1 an',              '💝', 'secret', 365, '#004D40', true, 'jours', 6),
  ('secret_loyal_2y',     'Ancien',              'Utiliser l''app 2 ans',             '🏺', 'secret', 730, '#1B5E20', true, 'jours', 7),
  ('secret_404',          'Page 404',            'Easter egg trouvé!',                '🐛', 'secret', 1,   '#BF360C', true, '', 8)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_secret = EXCLUDED.is_secret, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.10 STYLE / PERSONNALITÉ (style) - Premium
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('style_big_books',     'Gros Pavés',      '5 livres de 500+ pages',           '🧱', 'style', 5,  '#795548', true, 'livres', 1),
  ('style_speed_reader',  'Speed Reader',    '3 livres en 1 semaine',            '⚡', 'style', 3,  '#FF5722', true, 'livres', 2),
  ('style_slow_reader',   'Slow Reader',     '1 livre en 3+ mois (et le finir!)', '🐢', 'style', 1,  '#4CAF50', true, 'livres', 3),
  ('style_rereader',      'Relecteur',       'Relire un livre déjà terminé',     '🔄', 'style', 1,  '#2196F3', true, 'livres', 4),
  ('style_polyglot',      'Polyglotte',      'Lire dans 2+ langues',             '🌍', 'style', 2,  '#9C27B0', true, 'langues', 5),
  ('style_classic',       'Classique',       '10 classiques lus',                '🎭', 'style', 10, '#607D8B', true, 'livres', 6),
  ('style_contemporary',  'Contemporain',    '10 livres publiés dans l''année',  '📰', 'style', 10, '#FF9800', true, 'livres', 7),
  ('style_indie',         'Indé',            '5 livres d''auteurs indépendants', '🎸', 'style', 5,  '#E91E63', true, 'livres', 8)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.11 CHALLENGES MENSUELS (monthly) - Premium
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('monthly_jan',  'Challenge Janvier',   'Objectif mensuel janvier',     '❄️', 'monthly', 1, '#90CAF9', true, '', 1),
  ('monthly_feb',  'Challenge Février',   'Objectif mensuel février',     '💝', 'monthly', 1, '#F48FB1', true, '', 2),
  ('monthly_mar',  'Challenge Mars',      'Objectif mensuel mars',        '🌱', 'monthly', 1, '#A5D6A7', true, '', 3),
  ('monthly_apr',  'Challenge Avril',     'Objectif mensuel avril',       '🌸', 'monthly', 1, '#CE93D8', true, '', 4),
  ('monthly_may',  'Challenge Mai',       'Objectif mensuel mai',         '🌻', 'monthly', 1, '#FFF176', true, '', 5),
  ('monthly_jun',  'Challenge Juin',      'Objectif mensuel juin',        '☀️', 'monthly', 1, '#FFE082', true, '', 6),
  ('monthly_jul',  'Challenge Juillet',   'Objectif mensuel juillet',     '🏖️', 'monthly', 1, '#80DEEA', true, '', 7),
  ('monthly_aug',  'Challenge Août',      'Objectif mensuel août',        '🌴', 'monthly', 1, '#80CBC4', true, '', 8),
  ('monthly_sep',  'Challenge Septembre', 'Objectif mensuel septembre',   '📚', 'monthly', 1, '#BCAAA4', true, '', 9),
  ('monthly_oct',  'Challenge Octobre',   'Objectif mensuel octobre',     '🎃', 'monthly', 1, '#FFAB91', true, '', 10),
  ('monthly_nov',  'Challenge Novembre',  'Objectif mensuel novembre',    '🍂', 'monthly', 1, '#A1887F', true, '', 11),
  ('monthly_dec',  'Challenge Décembre',  'Objectif mensuel décembre',    '🎄', 'monthly', 1, '#EF9A9A', true, '', 12),
  ('monthly_collector', 'Collectionneur', '12 challenges mensuels',       '📅', 'monthly', 12,'#FFD700', true, 'challenges', 13)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────
-- 3.12 BADGES ANNÉE / RÉCAP (yearly) - Premium
-- ─────────────────────────────────────────────

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('yearly_2025',  'Wrapped 2025',  'Voir son Year in Books 2025',    '🎁', 'yearly', 1,  '#E91E63', true, '', 1),
  ('yearly_2026',  'Wrapped 2026',  'Voir son Year in Books 2026',    '🎁', 'yearly', 1,  '#9C27B0', true, '', 2),
  ('yearly_top_1', 'Top 1%',        'Dans le top 1% des lecteurs',    '🏆', 'yearly', 1,  '#FFD700', true, '', 3),
  ('yearly_top_10','Top 10%',       'Dans le top 10% des lecteurs',   '🏆', 'yearly', 1,  '#FFC107', true, '', 4)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
  category = EXCLUDED.category, requirement = EXCLUDED.requirement, color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium, progress_unit = EXCLUDED.progress_unit, sort_order = EXCLUDED.sort_order;

-- ============================================================================
-- 4. RPC: get_all_user_badges
-- ============================================================================
-- Retourne tous les badges avec la progression de l'utilisateur

CREATE OR REPLACE FUNCTION get_all_user_badges(p_user_id UUID)
RETURNS TABLE (
  badge_id TEXT,
  name TEXT,
  description TEXT,
  icon TEXT,
  category TEXT,
  requirement INTEGER,
  color TEXT,
  is_premium BOOLEAN,
  is_secret BOOLEAN,
  is_animated BOOLEAN,
  progress_unit TEXT,
  lottie_asset TEXT,
  sort_order INTEGER,
  unlocked_at TIMESTAMPTZ,
  progress INTEGER,
  is_unlocked BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_completed_books INTEGER;
  v_total_reading_minutes INTEGER;
  v_session_count INTEGER;
  v_friend_count INTEGER;
  v_follower_count INTEGER;
  v_like_count INTEGER;
  v_comment_count INTEGER;
  v_goal_created_count INTEGER;
  v_goal_achieved_count INTEGER;
  v_distinct_genres INTEGER;
  v_fiction_count INTEGER;
  v_nonfiction_count INTEGER;
  v_account_age_days INTEGER;
  v_night_sessions INTEGER;
  v_morning_sessions INTEGER;
  v_has_profile BOOLEAN;
  v_has_kindle BOOLEAN;
  v_invite_count INTEGER;
BEGIN
  -- Calculer les statistiques de l'utilisateur

  -- Livres terminés
  SELECT COUNT(*) INTO v_completed_books
  FROM user_books
  WHERE user_id = p_user_id AND status = 'finished';

  -- Temps total de lecture (en minutes)
  SELECT COALESCE(SUM(
    EXTRACT(EPOCH FROM (end_time - start_time)) / 60
  ), 0)::INTEGER INTO v_total_reading_minutes
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL;

  -- Nombre de sessions
  SELECT COUNT(*) INTO v_session_count
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL;

  -- Amis (suivis acceptés)
  SELECT COUNT(*) INTO v_friend_count
  FROM friends
  WHERE (requester_id = p_user_id OR addressee_id = p_user_id)
    AND status = 'accepted';

  -- Followers
  SELECT COUNT(*) INTO v_follower_count
  FROM friends
  WHERE addressee_id = p_user_id AND status = 'accepted';

  -- Likes donnés
  SELECT COUNT(*) INTO v_like_count
  FROM likes
  WHERE user_id = p_user_id;

  -- Commentaires écrits
  SELECT COUNT(*) INTO v_comment_count
  FROM comments
  WHERE user_id = p_user_id;

  -- Objectifs créés
  SELECT COUNT(*) INTO v_goal_created_count
  FROM reading_goals
  WHERE user_id = p_user_id;

  -- Objectifs atteints
  SELECT COUNT(*) INTO v_goal_achieved_count
  FROM reading_goals
  WHERE user_id = p_user_id AND is_completed = true;

  -- Genres distincts lus
  SELECT COUNT(DISTINCT b.genre) INTO v_distinct_genres
  FROM user_books ub
  JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished' AND b.genre IS NOT NULL;

  -- Livres fiction (genres fiction)
  SELECT COUNT(*) INTO v_fiction_count
  FROM user_books ub
  JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished'
    AND b.genre IN ('Fiction', 'Roman', 'Fantasy', 'Science-Fiction', 'Romance', 'Thriller', 'Policier', 'Horreur');

  -- Livres non-fiction
  SELECT COUNT(*) INTO v_nonfiction_count
  FROM user_books ub
  JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished'
    AND b.genre NOT IN ('Fiction', 'Roman', 'Fantasy', 'Science-Fiction', 'Romance', 'Thriller', 'Policier', 'Horreur')
    AND b.genre IS NOT NULL;

  -- Ancienneté du compte (jours)
  SELECT COALESCE(
    EXTRACT(DAY FROM (NOW() - created_at))::INTEGER, 0
  ) INTO v_account_age_days
  FROM auth.users
  WHERE id = p_user_id;

  -- Sessions après minuit (00:00-05:00)
  SELECT COUNT(*) INTO v_night_sessions
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND EXTRACT(HOUR FROM start_time) BETWEEN 0 AND 4;

  -- Sessions avant 7h
  SELECT COUNT(*) INTO v_morning_sessions
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND EXTRACT(HOUR FROM start_time) < 7;

  -- Profil complété
  SELECT EXISTS(
    SELECT 1 FROM profiles
    WHERE id = p_user_id
      AND display_name IS NOT NULL
      AND display_name != ''
      AND avatar_url IS NOT NULL
  ) INTO v_has_profile;

  -- Kindle lié
  v_has_kindle := false; -- À implémenter quand la table kindle_accounts existe

  -- Invitations
  v_invite_count := 0; -- À implémenter quand le système d'invitations existe

  -- Retourner tous les badges avec leur progression
  RETURN QUERY
  SELECT
    b.id AS badge_id,
    b.name,
    b.description,
    b.icon,
    b.category,
    b.requirement,
    b.color,
    COALESCE(b.is_premium, false) AS is_premium,
    COALESCE(b.is_secret, false) AS is_secret,
    COALESCE(b.is_animated, false) AS is_animated,
    COALESCE(b.progress_unit, '') AS progress_unit,
    b.lottie_asset,
    COALESCE(b.sort_order, 0) AS sort_order,
    ub.earned_at AS unlocked_at,
    -- Calculer la progression selon la catégorie
    CASE b.category
      WHEN 'books_completed' THEN LEAST(v_completed_books, b.requirement)
      WHEN 'reading_time' THEN
        CASE b.id
          WHEN 'time_first' THEN LEAST(v_session_count, 1)
          ELSE LEAST(v_total_reading_minutes, b.requirement)
        END
      WHEN 'streak' THEN 0 -- Le streak est géré côté client
      WHEN 'goals' THEN
        CASE b.id
          WHEN 'goal_created' THEN LEAST(v_goal_created_count, 1)
          ELSE LEAST(v_goal_achieved_count, b.requirement)
        END
      WHEN 'social' THEN
        CASE
          WHEN b.id LIKE 'social_follow_%' THEN LEAST(v_friend_count, b.requirement)
          WHEN b.id = 'social_first_like' THEN LEAST(v_like_count, 1)
          WHEN b.id = 'social_comments_%' THEN LEAST(v_comment_count, b.requirement)
          WHEN b.id LIKE 'social_followers_%' THEN LEAST(v_follower_count, b.requirement)
          WHEN b.id LIKE 'social_invite_%' THEN LEAST(v_invite_count, b.requirement)
          WHEN b.id LIKE 'social_reviews_%' THEN LEAST(v_comment_count, b.requirement)
          ELSE 0
        END
      WHEN 'genres' THEN
        CASE
          WHEN b.id LIKE 'genre_explorer_%' THEN LEAST(v_distinct_genres, b.requirement)
          WHEN b.id = 'genre_fiction_5' THEN LEAST(v_fiction_count, b.requirement)
          WHEN b.id = 'genre_nonfiction_5' THEN LEAST(v_nonfiction_count, b.requirement)
          ELSE 0 -- Les genre_master sont complexes, gérés séparément
        END
      WHEN 'engagement' THEN
        CASE b.id
          WHEN 'engage_profile' THEN CASE WHEN v_has_profile THEN 1 ELSE 0 END
          WHEN 'engage_kindle' THEN CASE WHEN v_has_kindle THEN 1 ELSE 0 END
          WHEN 'engage_invite_1' THEN LEAST(v_invite_count, 1)
          ELSE 0
        END
      WHEN 'animated' THEN
        CASE b.id
          WHEN 'anim_night_owl' THEN LEAST(v_night_sessions, b.requirement)
          WHEN 'anim_early_bird' THEN LEAST(v_morning_sessions, b.requirement)
          ELSE 0
        END
      WHEN 'secret' THEN
        CASE b.id
          WHEN 'secret_loyal_1y' THEN LEAST(v_account_age_days, 365)
          WHEN 'secret_loyal_2y' THEN LEAST(v_account_age_days, 730)
          ELSE 0
        END
      ELSE 0
    END AS progress,
    (ub.earned_at IS NOT NULL) AS is_unlocked
  FROM badges b
  LEFT JOIN user_badges ub ON ub.badge_id = b.id AND ub.user_id = p_user_id
  ORDER BY b.category, COALESCE(b.sort_order, 0), b.requirement;
END;
$$;

-- ============================================================================
-- 5. RPC: check_and_award_badges
-- ============================================================================
-- Vérifie toutes les conditions et attribue les badges mérités
-- Retourne la liste des badges nouvellement débloqués

CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE (
  badge_id TEXT,
  badge_name TEXT,
  badge_icon TEXT,
  badge_color TEXT,
  badge_category TEXT,
  badge_is_premium BOOLEAN,
  badge_is_secret BOOLEAN,
  badge_is_animated BOOLEAN,
  badge_lottie_asset TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_completed_books INTEGER;
  v_total_reading_minutes INTEGER;
  v_session_count INTEGER;
  v_friend_count INTEGER;
  v_follower_count INTEGER;
  v_like_count INTEGER;
  v_comment_count INTEGER;
  v_goal_created_count INTEGER;
  v_goal_achieved_count INTEGER;
  v_distinct_genres INTEGER;
  v_fiction_count INTEGER;
  v_nonfiction_count INTEGER;
  v_has_profile BOOLEAN;
  v_account_age_days INTEGER;
  v_night_sessions INTEGER;
  v_morning_sessions INTEGER;
  rec RECORD;
BEGIN
  -- Calculer les statistiques

  SELECT COUNT(*) INTO v_completed_books
  FROM user_books WHERE user_id = p_user_id AND status = 'finished';

  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 60), 0)::INTEGER
  INTO v_total_reading_minutes
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL;

  SELECT COUNT(*) INTO v_session_count
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL;

  SELECT COUNT(*) INTO v_friend_count
  FROM friends WHERE (requester_id = p_user_id OR addressee_id = p_user_id) AND status = 'accepted';

  SELECT COUNT(*) INTO v_follower_count
  FROM friends WHERE addressee_id = p_user_id AND status = 'accepted';

  SELECT COUNT(*) INTO v_like_count FROM likes WHERE user_id = p_user_id;
  SELECT COUNT(*) INTO v_comment_count FROM comments WHERE user_id = p_user_id;

  SELECT COUNT(*) INTO v_goal_created_count FROM reading_goals WHERE user_id = p_user_id;
  SELECT COUNT(*) INTO v_goal_achieved_count FROM reading_goals WHERE user_id = p_user_id AND is_completed = true;

  SELECT COUNT(DISTINCT b.genre) INTO v_distinct_genres
  FROM user_books ub JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished' AND b.genre IS NOT NULL;

  SELECT COUNT(*) INTO v_fiction_count
  FROM user_books ub JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished'
    AND b.genre IN ('Fiction', 'Roman', 'Fantasy', 'Science-Fiction', 'Romance', 'Thriller', 'Policier', 'Horreur');

  SELECT COUNT(*) INTO v_nonfiction_count
  FROM user_books ub JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished'
    AND b.genre NOT IN ('Fiction', 'Roman', 'Fantasy', 'Science-Fiction', 'Romance', 'Thriller', 'Policier', 'Horreur')
    AND b.genre IS NOT NULL;

  SELECT EXISTS(
    SELECT 1 FROM profiles WHERE id = p_user_id
      AND display_name IS NOT NULL AND display_name != '' AND avatar_url IS NOT NULL
  ) INTO v_has_profile;

  SELECT COALESCE(EXTRACT(DAY FROM (NOW() - created_at))::INTEGER, 0) INTO v_account_age_days
  FROM auth.users WHERE id = p_user_id;

  SELECT COUNT(*) INTO v_night_sessions
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND EXTRACT(HOUR FROM start_time) BETWEEN 0 AND 4;

  SELECT COUNT(*) INTO v_morning_sessions
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND EXTRACT(HOUR FROM start_time) < 7;

  -- Parcourir tous les badges non encore attribués
  FOR rec IN
    SELECT b.*
    FROM badges b
    WHERE NOT EXISTS (
      SELECT 1 FROM user_badges ub WHERE ub.badge_id = b.id AND ub.user_id = p_user_id
    )
    -- Exclure les badges streak (gérés côté client), mensuels et annuels (gérés manuellement)
    AND b.category NOT IN ('streak', 'monthly', 'yearly')
  LOOP
    -- Vérifier la condition selon la catégorie
    IF rec.category = 'books_completed' AND v_completed_books >= rec.requirement THEN
      INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
      RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
        COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
        COALESCE(rec.is_animated, false), rec.lottie_asset;

    ELSIF rec.category = 'reading_time' THEN
      IF (rec.id = 'time_first' AND v_session_count >= 1)
        OR (rec.id != 'time_first' AND v_total_reading_minutes >= rec.requirement) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'goals' THEN
      IF (rec.id = 'goal_created' AND v_goal_created_count >= 1)
        OR (rec.id = 'goal_achieved_1' AND v_goal_achieved_count >= 1)
        OR (rec.id = 'goal_achieved_5' AND v_goal_achieved_count >= 5) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'social' THEN
      IF (rec.id LIKE 'social_follow_%' AND v_friend_count >= rec.requirement)
        OR (rec.id = 'social_first_like' AND v_like_count >= 1)
        OR (rec.id = 'social_comments_10' AND v_comment_count >= 10)
        OR (rec.id LIKE 'social_followers_%' AND v_follower_count >= rec.requirement) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'genres' THEN
      IF (rec.id LIKE 'genre_explorer_%' AND v_distinct_genres >= rec.requirement)
        OR (rec.id = 'genre_fiction_5' AND v_fiction_count >= 5)
        OR (rec.id = 'genre_nonfiction_5' AND v_nonfiction_count >= 5) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'engagement' THEN
      IF (rec.id = 'engage_profile' AND v_has_profile) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'animated' THEN
      IF (rec.id = 'anim_night_owl' AND v_night_sessions >= 10)
        OR (rec.id = 'anim_early_bird' AND v_morning_sessions >= 10) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'secret' THEN
      IF (rec.id = 'secret_loyal_1y' AND v_account_age_days >= 365)
        OR (rec.id = 'secret_loyal_2y' AND v_account_age_days >= 730) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    END IF;
  END LOOP;
END;
$$;

-- ============================================================================
-- 6. VÉRIFICATION
-- ============================================================================

SELECT category, COUNT(*) as count,
  SUM(CASE WHEN is_premium THEN 1 ELSE 0 END) as premium_count,
  SUM(CASE WHEN is_secret THEN 1 ELSE 0 END) as secret_count
FROM badges
GROUP BY category
ORDER BY category;
