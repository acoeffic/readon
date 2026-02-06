// lib/services/streak_service.dart
// Service pour gérer les streaks de lecture

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_streak.dart';
import '../models/streak_freeze.dart';
import 'kindle_webview_service.dart';

class StreakService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // METHODES STREAK FREEZE
  // =====================================================

  /// Récupérer le statut du freeze pour l'utilisateur courant
  Future<StreakFreezeStatus> getFreezeStatus() async {
    try {
      final result = await _supabase.rpc('get_freeze_status');
      return StreakFreezeStatus.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Erreur getFreezeStatus: $e');
      return StreakFreezeStatus.empty();
    }
  }

  /// Utiliser un freeze pour protéger un jour (par défaut: hier)
  Future<FreezeResult> useFreeze({DateTime? date, bool isAuto = false}) async {
    try {
      final params = <String, dynamic>{
        'p_is_auto': isAuto,
      };
      if (date != null) {
        params['p_frozen_date'] = date.toIso8601String().split('T')[0];
      }

      final result = await _supabase.rpc('use_streak_freeze', params: params);
      return FreezeResult.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Erreur useFreeze: $e');
      return FreezeResult(
        success: false,
        error: 'UNKNOWN_ERROR',
        message: 'Une erreur est survenue: $e',
      );
    }
  }

  /// Récupérer les dates frozen pour un utilisateur
  Future<List<DateTime>> getFrozenDates({String? userId}) async {
    try {
      final params = userId != null ? {'p_user_id': userId} : <String, dynamic>{};
      final result = await _supabase.rpc('get_frozen_dates', params: params);

      if (result == null) return [];

      return (result as List)
          .map((date) => DateTime.parse(date as String))
          .toList();
    } catch (e) {
      debugPrint('Erreur getFrozenDates: $e');
      return [];
    }
  }

  /// Vérifie si un freeze automatique doit être utilisé
  /// Retourne true si le freeze a été utilisé avec succès
  /// NOTE: Pour les utilisateurs premium uniquement (à implémenter)
  Future<bool> checkAndUseAutoFreeze({bool isPremium = false}) async {
    if (!isPremium) return false;

    try {
      final streak = await getUserStreak();

      // Si le streak est à 0, pas besoin de freeze
      if (streak.currentStreak == 0) return false;

      // Si l'utilisateur a lu aujourd'hui, pas besoin de freeze
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (streak.lastReadDate != null) {
        final lastRead = DateTime(
          streak.lastReadDate!.year,
          streak.lastReadDate!.month,
          streak.lastReadDate!.day,
        );
        if (lastRead == today) return false;
      }

      // Vérifier si un freeze est disponible
      final freezeStatus = await getFreezeStatus();
      if (!freezeStatus.freezeAvailable) return false;

      // Utiliser le freeze automatiquement pour hier
      final result = await useFreeze(isAuto: true);
      return result.success;
    } catch (e) {
      debugPrint('Erreur checkAndUseAutoFreeze: $e');
      return false;
    }
  }

  /// Récupérer le streak actuel de l'utilisateur
  Future<ReadingStreak> getUserStreak() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return ReadingStreak.empty();

      // Récupérer toutes les sessions terminées de l'utilisateur
      final response = await _supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .order('end_time', ascending: false);

      // Récupérer les dates frozen et le statut du freeze
      final frozenDates = await getFrozenDates();
      final freezeStatus = await getFreezeStatus();

      // Extraire les dates uniques (format YYYY-MM-DD)
      final Set<String> uniqueDates = {};
      final List<DateTime> readDates = [];

      for (final session in response) {
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

      if (readDates.isEmpty && frozenDates.isEmpty) {
        // Même sans sessions locales, vérifier le streak Kindle
        final kindleStreak = await _getKindleStreak();
        if (kindleStreak != null && kindleStreak.currentStreak > 0) {
          return kindleStreak.copyWith(freezeStatus: freezeStatus);
        }
        return ReadingStreak.empty().copyWith(freezeStatus: freezeStatus);
      }

      // Calculer le streak actuel (avec les dates frozen)
      final streakData = _calculateStreakWithFreezes(readDates, frozenDates);

      int currentStreak = streakData['current'] ?? 0;
      int longestStreak = streakData['longest'] ?? 0;

      // Fusionner avec le streak Kindle (prendre le max)
      final kindleData = await KindleWebViewService().loadFromCache();
      if (kindleData != null && kindleData.currentStreak != null) {
        if (kindleData.currentStreak! > currentStreak) {
          currentStreak = kindleData.currentStreak!;
        }
        if (kindleData.currentStreak! > longestStreak) {
          longestStreak = kindleData.currentStreak!;
        }
      }

      return ReadingStreak(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        lastReadDate: readDates.isNotEmpty ? readDates.first : null,
        readDates: readDates,
        frozenDates: frozenDates,
        freezeStatus: freezeStatus,
      );
    } catch (e) {
      debugPrint('Erreur getUserStreak: $e');
      return ReadingStreak.empty();
    }
  }

  /// Récupérer le streak d'un utilisateur par son ID
  Future<int> getStreakForUser(String userId) async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .order('end_time', ascending: false);

      if ((response as List).isEmpty) {
        return 0;
      }

      final Set<String> uniqueDates = {};
      final List<DateTime> readDates = [];

      for (final session in response) {
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

      readDates.sort((a, b) => b.compareTo(a));
      if (readDates.isEmpty) return 0;

      final streakData = _calculateStreak(readDates);
      return streakData['current'] ?? 0;
    } catch (e) {
      debugPrint('Erreur getStreakForUser: $e');
      return 0;
    }
  }

  /// Récupérer le streak depuis les données Kindle en cache
  Future<ReadingStreak?> _getKindleStreak() async {
    try {
      final kindleData = await KindleWebViewService().loadFromCache();
      if (kindleData == null || kindleData.currentStreak == null) return null;
      return ReadingStreak(
        currentStreak: kindleData.currentStreak!,
        longestStreak: kindleData.currentStreak!,
        lastReadDate: DateTime.now(),
        readDates: [],
      );
    } catch (e) {
      return null;
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

  /// Calculer le streak en tenant compte des jours frozen
  Map<String, int> _calculateStreakWithFreezes(
    List<DateTime> sortedReadDates,
    List<DateTime> frozenDates,
  ) {
    if (sortedReadDates.isEmpty && frozenDates.isEmpty) {
      return {'current': 0, 'longest': 0};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Créer un set des dates frozen pour recherche rapide
    final frozenSet = frozenDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    // Créer un set des dates de lecture pour recherche rapide
    final readSet = sortedReadDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    // Combiner toutes les dates "valides" (lecture ou frozen)
    final allValidDates = <DateTime>{...readSet, ...frozenSet};
    final sortedValidDates = allValidDates.toList()
      ..sort((a, b) => b.compareTo(a));

    if (sortedValidDates.isEmpty) {
      return {'current': 0, 'longest': 0};
    }

    int currentStreak = 0;
    int longestStreak = 0;

    // Calculer le streak actuel en partant d'aujourd'hui
    DateTime checkDate = today;
    bool isCurrentStreak = true;

    while (true) {
      final isValidDay = allValidDates.contains(checkDate);

      if (isValidDay) {
        if (isCurrentStreak) {
          currentStreak++;
        }
        longestStreak = currentStreak > longestStreak ? currentStreak : longestStreak;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        // Jour manquant - on vérifie si c'est aujourd'hui (pas encore lu)
        if (checkDate == today) {
          // Pas encore lu aujourd'hui, on continue avec hier
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        // Streak cassé
        break;
      }
    }

    // Calculer le longest streak historique
    int tempStreak = 0;
    for (int i = 0; i < sortedValidDates.length; i++) {
      final date = sortedValidDates[i];
      final previousDate = i > 0 ? sortedValidDates[i - 1] : null;

      if (previousDate == null) {
        tempStreak = 1;
      } else {
        final diff = previousDate.difference(date).inDays;
        if (diff == 1) {
          tempStreak++;
        } else {
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
          }
          tempStreak = 1;
        }
      }
    }

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
      debugPrint('Erreur checkAndAwardStreakBadges: $e');
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
      debugPrint('Erreur _ensureBadgeExists: $e');
    }
  }

  /// Convertir une date en clé unique (YYYY-MM-DD)
  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Récupérer l'historique des lectures par jour (pour un calendrier)
  /// Limité aux 365 derniers jours pour éviter les problèmes de performance
  Future<Map<String, int>> getReadingHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .order('end_time', ascending: false)
          .limit(1000);

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
      debugPrint('Erreur getReadingHistory: $e');
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
