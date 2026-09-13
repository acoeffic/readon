-- ============================================================================
-- Sessions Kindle datées au vrai jour de lecture : elles comptent pour la
-- flamme même si end_time ≠ created_at.
-- ----------------------------------------------------------------------------
-- La règle « session manuelle antidatée exclue du flow » protège contre la
-- réparation d'un streak a posteriori par l'utilisateur. Une session
-- source = 'kindle' n'est pas saisie par l'utilisateur : sa date vient du
-- calendrier de lecture Amazon (days_read de Reading Insights). On l'exempte.
-- Miroir client : FlowService._sessionCountsForFlow / ReadingSession.isBackdated.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_streak_stats(p_user_id uuid)
 RETURNS TABLE(current_streak integer, longest_streak integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_tz text;
  v_today date;
BEGIN
  SELECT COALESCE(p.timezone, 'Europe/Paris') INTO v_tz
  FROM profiles p WHERE p.id = p_user_id;
  IF v_tz IS NULL OR v_tz = '' THEN
    v_tz := 'Europe/Paris';
  END IF;

  BEGIN
    v_today := (now() AT TIME ZONE v_tz)::date;
  EXCEPTION WHEN OTHERS THEN
    v_tz := 'Europe/Paris';
    v_today := (now() AT TIME ZONE v_tz)::date;
  END;

  RETURN QUERY
  WITH read_days AS (
    SELECT DISTINCT (rs.end_time AT TIME ZONE v_tz)::date AS d
    FROM reading_sessions rs
    WHERE rs.user_id = p_user_id
      AND rs.end_time IS NOT NULL
      AND rs.start_page IS NOT NULL
      AND rs.end_page IS NOT NULL
      AND (rs.end_page - rs.start_page) >= 1
      AND (rs.end_time - rs.start_time) >= interval '2 minutes'
      AND NOT (
        COALESCE(rs.is_manual, false)
        AND rs.source IS DISTINCT FROM 'kindle'
        AND (rs.end_time AT TIME ZONE v_tz)::date
            <> (rs.created_at AT TIME ZONE v_tz)::date
      )
  ),
  valid_days AS (
    SELECT d FROM read_days
    UNION
    SELECT sf.frozen_date FROM streak_freezes sf WHERE sf.user_id = p_user_id
  ),
  runs AS (
    SELECT d, d - (ROW_NUMBER() OVER (ORDER BY d))::int AS grp
    FROM valid_days
  ),
  islands AS (
    SELECT MAX(d) AS end_d, COUNT(*)::int AS len
    FROM runs
    GROUP BY grp
  )
  SELECT
    COALESCE((
      SELECT i.len FROM islands i
      WHERE i.end_d >= v_today - 1
      ORDER BY i.end_d DESC LIMIT 1
    ), 0),
    COALESCE((SELECT MAX(i.len) FROM islands i), 0);
END;
$function$;
