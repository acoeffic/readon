-- Migration : Déplacer la logique des badges secrets côté serveur
-- Au lieu de faire confiance aux timestamps client, la RPC vérifie
-- directement start_time / end_time depuis reading_sessions.

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

  -- Extraire les composants temporels (timezone de la session)
  v_start_hour  := EXTRACT(HOUR FROM v_start_time);
  v_start_min   := EXTRACT(MINUTE FROM v_start_time);
  v_start_month := EXTRACT(MONTH FROM v_start_time);
  v_start_day   := EXTRACT(DAY FROM v_start_time);

  IF v_end_time IS NOT NULL THEN
    v_end_hour := EXTRACT(HOUR FROM v_end_time);
  END IF;

  -- ── Minuit Pile : session commencée à 00:00 ──
  IF v_start_hour = 0 AND v_start_min = 0
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_midnight'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, earned_at)
    VALUES (v_user_id, 'secret_midnight', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_midnight';
  END IF;

  -- ── Premier de l'An : lire le 1er janvier ──
  IF v_start_month = 1 AND v_start_day = 1
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_new_year'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, earned_at)
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
    INSERT INTO user_badges (user_id, badge_id, earned_at)
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
    INSERT INTO user_badges (user_id, badge_id, earned_at)
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
    INSERT INTO user_badges (user_id, badge_id, earned_at)
    VALUES (v_user_id, 'secret_palindrome', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_palindrome';
  END IF;

END;
$$;

GRANT EXECUTE ON FUNCTION check_and_award_secret_badges(UUID, BOOLEAN) TO authenticated;
