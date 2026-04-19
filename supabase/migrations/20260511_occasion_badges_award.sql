-- Migration: Attribution automatique des badges "occasion" (dates spéciales)
-- Ajout d'une fonction easter_date() + logique occasion dans check_and_award_secret_badges

-- ── Fonction utilitaire : calcul de la date de Pâques (algorithme de Meeus/Butcher) ──
CREATE OR REPLACE FUNCTION easter_date(p_year INT)
RETURNS DATE
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  a INT; b INT; c INT; d INT; e INT; f INT; g INT; h INT;
  i INT; k INT; l INT; m INT; p INT;
  em INT; ed INT;
BEGIN
  a := p_year % 19;
  b := p_year / 100;
  c := p_year % 100;
  d := b / 4;
  e := b % 4;
  f := (b + 8) / 25;
  g := (b - f + 1) / 3;
  h := (19 * a + b - d - g + 15) % 30;
  i := c / 4;
  k := c % 4;
  l := (32 + 2 * e + 2 * i - h - k) % 7;
  m := (a + 11 * h + 22 * l) / 451;
  em := (h + l - 7 * m + 114) / 31;   -- mois (3=mars, 4=avril)
  ed := ((h + l - 7 * m + 114) % 31) + 1; -- jour
  RETURN make_date(p_year, em, ed);
END;
$$;

-- ── Mise à jour de check_and_award_secret_badges pour inclure les badges occasion ──
CREATE OR REPLACE FUNCTION check_and_award_secret_badges(
  p_session_id UUID,
  p_book_finished BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  badge_id   TEXT,
  badge_name TEXT,
  badge_desc TEXT,
  badge_icon TEXT,
  badge_color TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID;
  v_start_time TIMESTAMPTZ;
  v_end_time   TIMESTAMPTZ;
  v_start_hour INT;
  v_start_min  INT;
  v_end_hour   INT;
  v_start_month INT;
  v_start_day   INT;
  v_start_year  INT;
  v_duration_min DOUBLE PRECISION;
BEGIN
  -- Récupérer la session depuis la base (timestamps serveur, non manipulables)
  SELECT rs.user_id, rs.start_time, rs.end_time
  INTO v_user_id, v_start_time, v_end_time
  FROM reading_sessions rs
  WHERE rs.id = p_session_id;

  IF v_user_id IS NULL THEN
    RETURN; -- session inexistante
  END IF;

  -- Vérifier que c'est bien la session de l'utilisateur courant
  IF v_user_id != auth.uid() THEN
    RETURN;
  END IF;

  -- Extraire les composants temporels
  v_start_hour  := EXTRACT(HOUR FROM v_start_time);
  v_start_min   := EXTRACT(MINUTE FROM v_start_time);
  v_start_month := EXTRACT(MONTH FROM v_start_time);
  v_start_day   := EXTRACT(DAY FROM v_start_time);
  v_start_year  := EXTRACT(YEAR FROM v_start_time);

  IF v_end_time IS NOT NULL THEN
    v_end_hour := EXTRACT(HOUR FROM v_end_time);
    v_duration_min := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) / 60.0;
  ELSE
    v_duration_min := 0;
  END IF;

  -- ══════════════════════════════════════════════════════════
  -- BADGES SECRETS (existants)
  -- ══════════════════════════════════════════════════════════

  -- ── Minuit Pile : session commencée à 00:00 ──
  IF v_start_hour = 0 AND v_start_min = 0
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_midnight'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, unlocked_at)
    VALUES (v_user_id, 'secret_midnight', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_midnight';
  END IF;

  -- ── Premier de l'An (secret) : lire le 1er janvier ──
  IF v_start_month = 1 AND v_start_day = 1
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_new_year'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, unlocked_at)
    VALUES (v_user_id, 'secret_new_year', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_new_year';
  END IF;

  -- ── Marathon Nocturne : lire de 22h à 6h ──
  IF v_end_time IS NOT NULL
     AND v_start_hour >= 22 AND v_end_hour < 6
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_night_marathon'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, unlocked_at)
    VALUES (v_user_id, 'secret_night_marathon', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_night_marathon';
  END IF;

  -- ── Finisher : terminer un livre ──
  IF p_book_finished
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_finisher'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, unlocked_at)
    VALUES (v_user_id, 'secret_finisher', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_finisher';
  END IF;

  -- ── Palindrome : jour == mois (01/01, 02/02, … 12/12) ──
  IF v_start_month = v_start_day
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_palindrome'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, unlocked_at)
    VALUES (v_user_id, 'secret_palindrome', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_palindrome';
  END IF;

  -- ══════════════════════════════════════════════════════════
  -- BADGES OCCASION (> 15 min de lecture le jour J)
  -- ══════════════════════════════════════════════════════════

  -- On ne vérifie les badges occasion que si la session dure >= 15 min
  IF v_duration_min >= 15 THEN

    -- ── 14 juillet : Prise de la Bastille ──
    IF v_start_month = 7 AND v_start_day = 14
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_bastille_day')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_bastille_day', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_bastille_day';
    END IF;

    -- ── 25 décembre : Noël ──
    IF v_start_month = 12 AND v_start_day = 25
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_christmas')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_christmas', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_christmas';
    END IF;

    -- ── 21 juin : Fête de la Musique ──
    IF v_start_month = 6 AND v_start_day = 21
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_fete_musique')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_fete_musique', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_fete_musique';
    END IF;

    -- ── 31 octobre : Halloween ──
    IF v_start_month = 10 AND v_start_day = 31
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_halloween')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_halloween', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_halloween';
    END IF;

    -- ── 15 août : Lecture au soleil ──
    IF v_start_month = 8 AND v_start_day = 15
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_summer_read')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_summer_read', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_summer_read';
    END IF;

    -- ── 14 février : Saint-Valentin ──
    IF v_start_month = 2 AND v_start_day = 14
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_valentine')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_valentine', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_valentine';
    END IF;

    -- ── 31 décembre : Réveillon ──
    IF v_start_month = 12 AND v_start_day = 31
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_nye')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_nye', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_nye';
    END IF;

    -- ── 1er mai : Fête du Travail ──
    IF v_start_month = 5 AND v_start_day = 1
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_labour_day')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_labour_day', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_labour_day';
    END IF;

    -- ── 23 avril : Journée mondiale du Livre ──
    IF v_start_month = 4 AND v_start_day = 23
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_world_book_day')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_world_book_day', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_world_book_day';
    END IF;

    -- ── 1er janvier : Premier Chapitre de l'Année ──
    IF v_start_month = 1 AND v_start_day = 1
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_new_year')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_new_year', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_new_year';
    END IF;

    -- ── Pâques : date mobile calculée via easter_date() ──
    IF make_date(v_start_year, v_start_month, v_start_day) = easter_date(v_start_year)
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_easter')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_easter', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_easter';
    END IF;

    -- ── 1er avril : Poisson d'Avril ──
    IF v_start_month = 4 AND v_start_day = 1
       AND NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user_id AND ub.badge_id = 'occasion_april_fools')
    THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (v_user_id, 'occasion_april_fools', NOW()) ON CONFLICT DO NOTHING;
      RETURN QUERY SELECT b.id, b.name, b.description, b.icon, b.color FROM badges b WHERE b.id = 'occasion_april_fools';
    END IF;

  END IF; -- fin v_duration_min >= 15

END;
$$;
