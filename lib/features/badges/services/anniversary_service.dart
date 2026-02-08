// lib/features/badges/services/anniversary_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/anniversary_badge.dart';

class AnniversaryService {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isChecking = false;

  /// Point d'entrée principal — appelé depuis MainNavigation
  /// Retourne le badge à afficher, ou null si rien à montrer.
  Future<AnniversaryBadge?> checkAndTriggerAnniversary({
    required bool isPremium,
  }) async {
    if (_isChecking) return null;
    _isChecking = true;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final createdAt = DateTime.parse(user.createdAt);
      final now = DateTime.now();

      // Calculer le nombre d'années complètes
      final yearsSince = _calculateCompletedYears(createdAt, now);
      if (yearsSince < 1 || yearsSince > 5) return null;

      // Vérifier la fenêtre de grâce (7 jours après la date anniversaire)
      if (!_isWithinGraceWindow(createdAt, now)) return null;

      // Récupérer le badge correspondant
      final badge = AnniversaryBadge.getByYears(yearsSince);
      if (badge == null) return null;

      // Vérifier le gating premium
      if (badge.isPremium && !isPremium) return null;

      // Vérifier si déjà attribué
      final existing = await _supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', user.id)
          .eq('badge_id', badge.id)
          .maybeSingle();

      if (existing == null) {
        // Attribuer le badge
        await _supabase.from('user_badges').insert({
          'user_id': user.id,
          'badge_id': badge.id,
          'earned_at': DateTime.now().toIso8601String(),
        });
      }

      // Vérifier si l'animation a déjà été montrée
      final prefs = await SharedPreferences.getInstance();
      final seenKey = 'anniversary_badge_seen_${badge.id}';
      if (prefs.getBool(seenKey) == true) return null;

      return badge;
    } catch (e) {
      debugPrint('Erreur checkAndTriggerAnniversary: $e');
      return null;
    } finally {
      _isChecking = false;
    }
  }

  /// Marquer le badge comme vu (ne plus montrer l'animation)
  Future<void> markAsSeen(String badgeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('anniversary_badge_seen_$badgeId', true);
    } catch (e) {
      debugPrint('Erreur markAsSeen: $e');
    }
  }

  /// Récupérer les stats de l'année pour l'overlay
  Future<AnniversaryStats> getAnniversaryStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return AnniversaryStats.empty;

      final twelveMonthsAgo =
          DateTime.now().subtract(const Duration(days: 365)).toIso8601String();

      // 3 requêtes en parallèle
      final results = await Future.wait([
        // Livres terminés (12 derniers mois)
        _supabase
            .from('user_books')
            .select('book_id')
            .eq('user_id', userId)
            .eq('status', 'finished')
            .gte('updated_at', twelveMonthsAgo),
        // Sessions de lecture complètes (12 derniers mois)
        _supabase
            .from('reading_sessions')
            .select('start_time, end_time')
            .eq('user_id', userId)
            .not('end_time', 'is', null)
            .gte('start_time', twelveMonthsAgo),
        // Commentaires (12 derniers mois)
        _supabase
            .from('comments')
            .select('id')
            .eq('author_id', userId)
            .gte('created_at', twelveMonthsAgo),
      ]);

      final booksFinished = (results[0] as List).length;

      // Calculer heures et best flow depuis les sessions
      final sessions = results[1] as List;
      int totalMinutes = 0;
      final activeDates = <String>{};

      for (final s in sessions) {
        final st = DateTime.parse(s['start_time'] as String);
        final et = DateTime.parse(s['end_time'] as String);
        totalMinutes += et.difference(st).inMinutes;
        activeDates.add('${st.year}-${st.month.toString().padLeft(2, '0')}-${st.day.toString().padLeft(2, '0')}');
      }

      final hoursRead = totalMinutes ~/ 60;
      final bestFlow = _computeBestFlow(activeDates);
      final commentsCount = (results[2] as List).length;

      return AnniversaryStats(
        booksFinished: booksFinished,
        hoursRead: hoursRead,
        bestFlow: bestFlow,
        commentsCount: commentsCount,
      );
    } catch (e) {
      debugPrint('Erreur getAnniversaryStats: $e');
      return AnniversaryStats.empty;
    }
  }

  /// Calculer le nombre d'années complètes entre deux dates
  int _calculateCompletedYears(DateTime from, DateTime to) {
    int years = to.year - from.year;
    if (to.month < from.month ||
        (to.month == from.month && to.day < from.day)) {
      years--;
    }
    return years;
  }

  /// Vérifier si aujourd'hui est dans la fenêtre de grâce de 7 jours
  /// après la date anniversaire d'inscription
  bool _isWithinGraceWindow(DateTime createdAt, DateTime now) {
    // Date anniversaire cette année
    DateTime anniversaryThisYear;
    try {
      anniversaryThisYear =
          DateTime(now.year, createdAt.month, createdAt.day);
    } catch (_) {
      // Cas spécial : 29 février sur une année non-bissextile → 1er mars
      anniversaryThisYear = DateTime(now.year, 3, 1);
    }

    // Si l'anniversaire cette année n'est pas encore passé,
    // regarder l'anniversaire de l'année dernière
    final anniversaryDate = anniversaryThisYear.isAfter(now)
        ? DateTime(now.year - 1, createdAt.month, createdAt.day)
        : anniversaryThisYear;

    final daysSince = now.difference(anniversaryDate).inDays;
    return daysSince >= 0 && daysSince <= 7;
  }

  /// Calculer le meilleur flow (jours consécutifs) à partir d'un set de dates
  int _computeBestFlow(Set<String> dateStrings) {
    if (dateStrings.isEmpty) return 0;

    // Parser et trier les dates
    final dates = dateStrings
        .map((s) => DateTime.parse(s))
        .toList()
      ..sort();

    int bestFlow = 1;
    int currentFlow = 1;

    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        currentFlow++;
        if (currentFlow > bestFlow) bestFlow = currentFlow;
      } else if (diff > 1) {
        currentFlow = 1;
      }
      // diff == 0 : même jour, on ignore
    }

    return bestFlow;
  }
}
