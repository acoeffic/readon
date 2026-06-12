-- =====================================================
-- Migration de diagnostic : RAISE NOTICE avec la liste de tous les
-- triggers actifs sur reading_sessions et activities, plus toutes les
-- fonctions PL/pgSQL dont la définition contient "INSERT INTO activities".
--
-- Le but est de débusquer un trigger ou une fonction inattendue (créée
-- manuellement via Supabase Studio, par exemple) qui insère dans
-- activities sans passer par notre create_activity_on_session_end.
--
-- La migration ne change rien à la base — uniquement des RAISE NOTICE
-- qui apparaîtront dans la sortie de `supabase db push`.
-- =====================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  RAISE NOTICE '═══ Triggers sur reading_sessions ═══';
  FOR r IN
    SELECT trigger_name, event_manipulation, action_timing, action_statement
    FROM information_schema.triggers
    WHERE event_object_schema = 'public'
      AND event_object_table  = 'reading_sessions'
    ORDER BY trigger_name
  LOOP
    RAISE NOTICE '  • % | % % | %', r.trigger_name, r.action_timing,
      r.event_manipulation, r.action_statement;
  END LOOP;

  RAISE NOTICE '═══ Triggers sur activities ═══';
  FOR r IN
    SELECT trigger_name, event_manipulation, action_timing, action_statement
    FROM information_schema.triggers
    WHERE event_object_schema = 'public'
      AND event_object_table  = 'activities'
    ORDER BY trigger_name
  LOOP
    RAISE NOTICE '  • % | % % | %', r.trigger_name, r.action_timing,
      r.event_manipulation, r.action_statement;
  END LOOP;

  RAISE NOTICE '═══ Fin diagnostic ═══';
END;
$$;
