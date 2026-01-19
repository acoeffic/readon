// lib/services/streak_service.dart
// Service pour gérer les streaks de lecture

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_streak.dart';

class StreakService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupérer le streak actuel de l'utilisateur
  Future<ReadingStreak> getUserStreak() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return ReadingStreak.empty();

      // Récupérer toutes les sessions terminées de l'utilisateur
      // On ne garde que les dates distinctes (un jour = une session minimum)
      final response = await _supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .order('end_time', ascending: false);

      if (response == null || (response as List).isEmpty) {
        return ReadingStreak.empty();
      }

      // Extraire les dates uniques (format YYYY-MM-DD)
      final Set<String> uniqueDates = {};
      final List<DateTime> readDates = [];

      for (final session in response as List) {
        final endTime = session['end_time'] as String?;
        if (endTime != null) {
          final date = DateTime.parse(endTime);
          final dateKey = _dateToKey(date);
          if (!uniqueDates.contains(dateKey)) {
            uniqueDates.add(dateKey);
            readDates.add(DateTime(date.year, date.month, date.day));
          }
        }
      }

      // Trier les dates du plus récent au plus ancien
      readDates.sort((a, b) => b.compareTo(a));

      if (readDates.isEmpty) {
        return ReadingStreak.empty();
      }

      // Calculer le streak actuel
      final streakData = _calculateStreak(readDates);

      return ReadingStreak(
        currentStreak: streakData['current'] ?? 0,
        longestStreak: streakData['longest'] ?? 0,
        lastReadDate: readDates.first,
        readDates: readDates,
      );
    } catch (e) {
      print('Erreur getUserStreak: $e');
      return ReadingStreak.empty();
    }
  }

  /// Calculer le streak actuel et le record
  Map<String, int> _calculateStreak(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) {
      return {'current': 0, 'longest': 0};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;
    DateTime? expectedDate = today;

    // Vérifier si la dernière lecture était aujourd'hui ou hier
    final lastRead = sortedDates.first;
    if (lastRead != today && lastRead != yesterday) {
      // Le streak est cassé
      expectedDate = null;
    }

    // Parcourir les dates pour calculer les streaks
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];

      if (expectedDate != null && date == expectedDate) {
        // Continuer le streak
        tempStreak++;
        if (i == 0 || expectedDate == today || expectedDate == yesterday) {
          currentStreak = tempStreak;
        }
        expectedDate = date.subtract(const Duration(days: 1));
      } else {
        // Streak cassé, enregistrer le record
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
        // Recommencer un nouveau streak
        tempStreak = 1;
        expectedDate = date.subtract(const Duration(days: 1));
      }
    }

    // Vérifier le dernier streak
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }

    return {
      'current': currentStreak,
      'longest': longestStreak,
    };
  }

  /// Vérifier et attribuer des badges de streak
  Future<List<StreakBadgeLevel>> checkAndAwardStreakBadges() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final streak = await getUserStreak();
      final newBadges = <StreakBadgeLevel>[];

      // Récupérer les badges déjà attribués
      final existingBadges = await _supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId);

      final existingBadgeIds = (existingBadges as List)
          .map((b) => b['badge_id'] as String)
          .toSet();

      // Vérifier chaque niveau de badge
      for (final level in StreakBadgeLevel.values) {
        if (streak.currentStreak >= level.days &&
            !existingBadgeIds.contains(level.badgeId)) {
          // Créer le badge s'il n'existe pas
          await _ensureBadgeExists(level);

          // Attribuer le badge à l'utilisateur
          await _supabase.from('user_badges').insert({
            'user_id': userId,
            'badge_id': level.badgeId,
            'earned_at': DateTime.now().toIso8601String(),
          });

          newBadges.add(level);
        }
      }

      return newBadges;
    } catch (e) {
      print('Erreur checkAndAwardStreakBadges: $e');
      return [];
    }
  }

  /// S'assurer que le badge existe dans la table badges
  Future<void> _ensureBadgeExists(StreakBadgeLevel level) async {
    try {
      final existing = await _supabase
          .from('badges')
          .select('id')
          .eq('id', level.badgeId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('badges').insert({
          'id': level.badgeId,
          'name': level.name,
          'description': level.description,
          'icon': level.icon,
          'color': level.color,
          'category': 'streak',
        });
      }
    } catch (e) {
      print('Erreur _ensureBadgeExists: $e');
    }
  }

  /// Convertir une date en clé unique (YYYY-MM-DD)
  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Récupérer l'historique des lectures par jour (pour un calendrier)
  Future<Map<String, int>> getReadingHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null);

      final Map<String, int> history = {};

      for (final session in response as List) {
        final endTime = session['end_time'] as String?;
        if (endTime != null) {
          final date = DateTime.parse(endTime);
          final dateKey = _dateToKey(date);
          history[dateKey] = (history[dateKey] ?? 0) + 1;
        }
      }

      return history;
    } catch (e) {
      print('Erreur getReadingHistory: $e');
      return {};
    }
  }

  /// Stream pour suivre le streak en temps réel
  Stream<ReadingStreak> watchUserStreak() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value(ReadingStreak.empty());
    }

    return _supabase
        .from('reading_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((_) async => await getUserStreak());
  }
}
