-- Fonction RPC pour calculer le percentile de flow d'un utilisateur
-- Compare les jours de lecture distincts sur les 30 derniers jours
-- par rapport à tous les autres utilisateurs actifs

CREATE OR REPLACE FUNCTION get_flow_percentile()
RETURNS INTEGER AS $$
DECLARE
  my_active_days INTEGER;
  total_users INTEGER;
  users_below INTEGER;
BEGIN
  -- Jours actifs de l'utilisateur courant sur les 30 derniers jours
  SELECT COUNT(DISTINCT DATE(end_time))
  INTO my_active_days
  FROM reading_sessions
  WHERE user_id = auth.uid()
    AND end_time >= NOW() - INTERVAL '30 days';

  -- Compter les utilisateurs et ceux avec moins de jours actifs
  WITH user_days AS (
    SELECT user_id, COUNT(DISTINCT DATE(end_time)) as days
    FROM reading_sessions
    WHERE end_time >= NOW() - INTERVAL '30 days'
    GROUP BY user_id
  )
  SELECT COUNT(*), COUNT(*) FILTER (WHERE days < my_active_days)
  INTO total_users, users_below
  FROM user_days;

  IF total_users <= 1 THEN RETURN 0; END IF;
  RETURN LEAST(99, GREATEST(1, (users_below * 100 / total_users)));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
