-- ============================================================================
-- Jours de lecture Kindle (calendrier Amazon) → flamme LexDay
-- ----------------------------------------------------------------------------
-- Le sync Kindle lit `days_read` sur la page Reading Insights d'Amazon (jours
-- où l'utilisateur a lu sur Kindle, quel que soit le livre). Ces jours
-- comptent pour la flamme au même titre qu'une session LexDay ou qu'un
-- freeze : un lecteur 100 % Kindle garde sa série sans rien saisir.
-- Table par utilisateur, RLS « own rows » (comme streak_freezes) ; le calcul
-- serveur get_user_streak_stats les UNIONne ; le client FlowService aussi.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.kindle_read_days (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day        DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, day)
);

COMMENT ON TABLE public.kindle_read_days IS
  'Jours où l''utilisateur a lu sur Kindle selon Amazon (Reading Insights days_read). Comptent pour la flamme.';

ALTER TABLE public.kindle_read_days ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own kindle read days" ON public.kindle_read_days;
CREATE POLICY "Users can view own kindle read days"
  ON public.kindle_read_days FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own kindle read days" ON public.kindle_read_days;
CREATE POLICY "Users can insert own kindle read days"
  ON public.kindle_read_days FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own kindle read days" ON public.kindle_read_days;
CREATE POLICY "Users can delete own kindle read days"
  ON public.kindle_read_days FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

REVOKE ALL ON public.kindle_read_days FROM anon;
GRANT SELECT, INSERT, DELETE ON public.kindle_read_days TO authenticated;

-- Flamme serveur (badges de série) : sessions ∪ freezes ∪ jours Kindle.
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
    UNION
    SELECT kd.day FROM kindle_read_days kd WHERE kd.user_id = p_user_id
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
