// lib/services/goals_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_goal.dart';
import 'flow_service.dart';

class GoalsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlowService _flowService = FlowService();

  /// Recuperer tous les objectifs actifs avec progression
  Future<List<ReadingGoal>> getActiveGoalsWithProgress({int? year}) async {
    try {
      final targetYear = year ?? DateTime.now().year;
      final result = await _supabase.rpc(
        'get_reading_goals_progress',
        params: {'p_year': targetYear},
      );

      if (result == null) return [];

      final List<dynamic> list = result is List ? result : [];
      final goals = list
          .map((item) => ReadingGoal.fromJson(
                item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map),
              ))
          .toList();

      // Enrichir streak_target avec les donnees client
      for (int i = 0; i < goals.length; i++) {
        if (goals[i].goalType == GoalType.streakTarget) {
          final flow = await _flowService.getUserFlow();
          goals[i] = goals[i].copyWith(
            currentValue: flow.currentFlow,
          );
        }
      }

      return goals;
    } catch (e) {
      debugPrint('Erreur getActiveGoalsWithProgress: $e');
      return [];
    }
  }

  /// Creer ou remplacer un objectif dans une categorie
  Future<ReadingGoal> setGoal({
    required GoalType goalType,
    required int targetValue,
    int? year,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final targetYear = year ?? DateTime.now().year;

      // Desactiver l'ancien objectif de cette categorie
      await _supabase
          .from('reading_goals')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('category', goalType.category.dbValue)
          .eq('year', targetYear)
          .eq('is_active', true);

      // Inserer le nouvel objectif
      final response = await _supabase
          .from('reading_goals')
          .insert({
            'user_id': userId,
            'category': goalType.category.dbValue,
            'goal_type': goalType.dbValue,
            'target_value': targetValue,
            'year': targetYear,
            'is_active': true,
          })
          .select()
          .single();

      return ReadingGoal.fromJson(response);
    } catch (e) {
      debugPrint('Erreur setGoal: $e');
      rethrow;
    }
  }

  /// Supprimer (desactiver) un objectif
  Future<void> removeGoal(int goalId) async {
    try {
      await _supabase
          .from('reading_goals')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', goalId);
    } catch (e) {
      debugPrint('Erreur removeGoal: $e');
      rethrow;
    }
  }

  /// Sauvegarder tous les objectifs d'un coup
  /// Desactive tous les objectifs existants puis insere les nouveaux
  Future<void> saveAllGoals(Map<GoalType, int> goals) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final year = DateTime.now().year;

      // Desactiver tous les objectifs actifs de cette annee
      await _supabase
          .from('reading_goals')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('year', year)
          .eq('is_active', true);

      // Inserer tous les nouveaux objectifs
      if (goals.isNotEmpty) {
        final rows = goals.entries.map((entry) {
          return {
            'user_id': userId,
            'category': entry.key.category.dbValue,
            'goal_type': entry.key.dbValue,
            'target_value': entry.value,
            'year': year,
            'is_active': true,
          };
        }).toList();

        await _supabase.from('reading_goals').insert(rows);
      }
    } catch (e) {
      debugPrint('Erreur saveAllGoals: $e');
      rethrow;
    }
  }

  /// Recuperer l'objectif principal (quantite) pour le profil
  Future<ReadingGoal?> getPrimaryGoal({int? year}) async {
    final goals = await getActiveGoalsWithProgress(year: year);
    try {
      return goals.firstWhere((g) => g.category == GoalCategory.quantity);
    } catch (_) {
      return goals.isNotEmpty ? goals.first : null;
    }
  }
}
