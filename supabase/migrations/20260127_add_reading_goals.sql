-- =====================================================
-- Migration: Reading Goals (3 types d'objectifs)
-- =====================================================

CREATE TABLE IF NOT EXISTS reading_goals (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category    TEXT NOT NULL,
  goal_type   TEXT NOT NULL,
  target_value INT NOT NULL,
  year        INT NOT NULL DEFAULT EXTRACT(YEAR FROM NOW())::INT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_category CHECK (
    category IN ('quantity', 'regularity', 'quality')
  ),
  CONSTRAINT valid_goal_type CHECK (
    goal_type IN (
      'books_per_year',
      'days_per_week',
      'streak_target',
      'minutes_per_day',
      'nonfiction_books',
      'fiction_books',
      'finish_started',
      'different_genres'
    )
  ),
  CONSTRAINT positive_target CHECK (target_value > 0)
);

-- Un seul objectif actif par goal_type par user par annee
-- (permet plusieurs objectifs dans la meme categorie, ex: regularity)
CREATE UNIQUE INDEX idx_reading_goals_active_per_type
  ON reading_goals (user_id, goal_type, year)
  WHERE is_active = TRUE;

CREATE INDEX idx_reading_goals_user ON reading_goals(user_id);
CREATE INDEX idx_reading_goals_user_active ON reading_goals(user_id) WHERE is_active = TRUE;

-- =====================================================
-- RLS Policies
-- =====================================================
ALTER TABLE reading_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own goals"
  ON reading_goals FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own goals"
  ON reading_goals FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own goals"
  ON reading_goals FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own goals"
  ON reading_goals FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- =====================================================
-- RPC: get_reading_goals_progress
-- Retourne les objectifs actifs avec progression calculee
-- =====================================================
CREATE OR REPLACE FUNCTION get_reading_goals_progress(
  p_year INT DEFAULT EXTRACT(YEAR FROM NOW())::INT
)
RETURNS JSON AS $$
DECLARE
  result JSON;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();

  SELECT json_agg(goal_data) INTO result
  FROM (
    SELECT
      g.id,
      g.category,
      g.goal_type,
      g.target_value,
      g.year,
      g.created_at,
      g.is_active,
      g.user_id,
      CASE
        WHEN g.goal_type = 'books_per_year' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
        )
        WHEN g.goal_type = 'nonfiction_books' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          JOIN books b ON b.id = ub.book_id
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
          AND b.genre IS NOT NULL
          AND LOWER(b.genre) NOT IN (
            'fiction', 'roman', 'romance', 'science-fiction',
            'fantasy', 'thriller', 'horreur', 'policier',
            'manga', 'bande dessinee', 'comics'
          )
        )
        WHEN g.goal_type = 'fiction_books' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          JOIN books b ON b.id = ub.book_id
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
          AND b.genre IS NOT NULL
          AND LOWER(b.genre) IN (
            'fiction', 'roman', 'romance', 'science-fiction',
            'fantasy', 'thriller', 'horreur', 'policier',
            'manga', 'bande dessinee', 'comics'
          )
        )
        WHEN g.goal_type = 'finish_started' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
        )
        WHEN g.goal_type = 'different_genres' THEN (
          SELECT COUNT(DISTINCT LOWER(b.genre))::INT FROM user_books ub
          JOIN books b ON b.id = ub.book_id
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
          AND b.genre IS NOT NULL
        )
        WHEN g.goal_type = 'days_per_week' THEN (
          SELECT COUNT(DISTINCT DATE(rs.end_time))::INT
          FROM reading_sessions rs
          WHERE rs.user_id = v_user_id
          AND rs.end_time IS NOT NULL
          AND DATE(rs.end_time) >= date_trunc('week', CURRENT_DATE)::DATE
          AND DATE(rs.end_time) <= CURRENT_DATE
        )
        WHEN g.goal_type = 'streak_target' THEN 0
        WHEN g.goal_type = 'minutes_per_day' THEN (
          SELECT COALESCE(AVG(daily_minutes)::INT, 0)
          FROM (
            SELECT DATE(rs.end_time) AS read_date,
                   SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 60)::INT AS daily_minutes
            FROM reading_sessions rs
            WHERE rs.user_id = v_user_id
            AND rs.end_time IS NOT NULL
            AND DATE(rs.end_time) >= CURRENT_DATE - INTERVAL '7 days'
            GROUP BY DATE(rs.end_time)
          ) sub
        )
        ELSE 0
      END AS current_value,
      CASE
        WHEN g.goal_type = 'finish_started' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          WHERE ub.user_id = v_user_id
          AND ub.status IN ('reading', 'finished')
          AND EXTRACT(YEAR FROM ub.created_at) = g.year
        )
        ELSE NULL
      END AS extra_value
    FROM reading_goals g
    WHERE g.user_id = v_user_id
    AND g.is_active = TRUE
    AND g.year = p_year
    ORDER BY
      CASE g.category
        WHEN 'quantity' THEN 1
        WHEN 'regularity' THEN 2
        WHEN 'quality' THEN 3
      END
  ) goal_data;

  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
