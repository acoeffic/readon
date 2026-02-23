// lib/services/flow_service.dart
// Service pour gérer les flows de lecture

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_flow.dart';
import '../models/flow_freeze.dart';
import 'access_guard.dart';

class FlowService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // METHODES FLOW FREEZE
  // =====================================================

  /// Récupérer le statut du freeze pour l'utilisateur courant
  Future<FlowFreezeStatus> getFreezeStatus() async {
    try {
      final result = await _supabase.rpc('get_freeze_status');
      return FlowFreezeStatus.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Erreur getFreezeStatus: $e');
      return FlowFreezeStatus.empty();
    }
  }

  /// Utiliser un freeze pour protéger un jour (par défaut: hier)
  Future<FreezeResult> useFreeze({DateTime? date, bool isAuto = false}) async {
    try {
      // Empêcher le freeze de dates futures
      if (date != null) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final freezeDate = DateTime(date.year, date.month, date.day);
        if (freezeDate.isAfter(todayDate)) {
          return FreezeResult(
            success: false,
            error: 'FUTURE_DATE',
            message: 'Impossible de geler une date future',
          );
        }
      }

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

  /// Récupérer les dates frozen pour un utilisateur.
  /// Si [userId] est fourni, vérifie l'autorisation d'accès.
  Future<List<DateTime>> getFrozenDates({String? userId}) async {
    try {
      if (userId != null && !await canAccessUserData(userId)) return [];

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

  /// Vérifie si un auto-freeze doit être appliqué (fallback client du cron serveur).
  /// Fonctionne pour tous les utilisateurs (le SQL gère les limites free/premium).
  Future<bool> checkAndUseAutoFreeze() async {
    try {
      final flow = await getUserFlow();

      // Si le flow est à 0, pas besoin de freeze
      if (flow.currentFlow == 0) return false;

      // Si l'utilisateur a lu aujourd'hui, pas besoin de freeze
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (flow.lastReadDate != null) {
        final lastRead = DateTime(
          flow.lastReadDate!.year,
          flow.lastReadDate!.month,
          flow.lastReadDate!.day,
        );
        if (lastRead == today) return false;
      }

      // Vérifier si un freeze est disponible (quota + consécutif)
      final freezeStatus = await getFreezeStatus();
      if (!freezeStatus.canFreeze) return false;

      // Utiliser le freeze automatiquement pour hier
      final result = await useFreeze(isAuto: true);
      return result.success;
    } catch (e) {
      debugPrint('Erreur checkAndUseAutoFreeze: $e');
      return false;
    }
  }

  // =====================================================
  // PERCENTILE
  // =====================================================

  /// Récupérer le percentile du flow de l'utilisateur (0-99)
  /// Compare les jours de lecture sur 30 jours vs les autres utilisateurs
  Future<int> getFlowPercentile() async {
    try {
      final result = await _supabase.rpc('get_flow_percentile');
      return (result as int?) ?? 0;
    } catch (e) {
      debugPrint('Erreur getFlowPercentile: $e');
      return 0;
    }
  }

  /// Récupérer le flow actuel de l'utilisateur
  Future<ReadingFlow> getUserFlow() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return ReadingFlow.empty();

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
        return ReadingFlow.empty().copyWith(freezeStatus: freezeStatus);
      }

      // Calculer le flow actuel (avec les dates frozen)
      final flowData = _calculateFlowWithFreezes(readDates, frozenDates);

      final currentFlow = flowData['current'] ?? 0;
      final longestFlow = flowData['longest'] ?? 0;

      return ReadingFlow(
        currentFlow: currentFlow,
        longestFlow: longestFlow,
        lastReadDate: readDates.isNotEmpty ? readDates.first : null,
        readDates: readDates,
        frozenDates: frozenDates,
        freezeStatus: freezeStatus,
      );
    } catch (e) {
      debugPrint('Erreur getUserFlow: $e');
      return ReadingFlow.empty();
    }
  }

  /// Récupérer le flow d'un utilisateur par son ID.
  /// Vérifie que le demandeur est autorisé (soi-même, ami, ou profil public).
  Future<int> getFlowForUser(String userId) async {
    try {
      if (!await canAccessUserData(userId)) return 0;

      final response = await _supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', userId)
          .eq('is_hidden', false)
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

      final flowData = _calculateFlow(readDates);
      return flowData['current'] ?? 0;
    } catch (e) {
      debugPrint('Erreur getFlowForUser: $e');
      return 0;
    }
  }

  /// Calculer le flow actuel et le record
  Map<String, int> _calculateFlow(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) {
      return {'current': 0, 'longest': 0};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    int currentFlow = 0;
    int longestFlow = 0;
    int tempFlow = 0;
    DateTime? expectedDate = today;

    // Vérifier si la dernière lecture était aujourd'hui ou hier
    final lastRead = sortedDates.first;
    if (lastRead != today && lastRead != yesterday) {
      // Le flow est cassé
      expectedDate = null;
    }

    // Parcourir les dates pour calculer les flows
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];

      if (expectedDate != null && date == expectedDate) {
        // Continuer le flow
        tempFlow++;
        if (i == 0 || expectedDate == today || expectedDate == yesterday) {
          currentFlow = tempFlow;
        }
        expectedDate = date.subtract(const Duration(days: 1));
      } else {
        // Flow cassé, enregistrer le record
        if (tempFlow > longestFlow) {
          longestFlow = tempFlow;
        }
        // Recommencer un nouveau flow
        tempFlow = 1;
        expectedDate = date.subtract(const Duration(days: 1));
      }
    }

    // Vérifier le dernier flow
    if (tempFlow > longestFlow) {
      longestFlow = tempFlow;
    }

    return {
      'current': currentFlow,
      'longest': longestFlow,
    };
  }

  /// Calculer le flow en tenant compte des jours frozen
  Map<String, int> _calculateFlowWithFreezes(
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

    int currentFlow = 0;
    int longestFlow = 0;

    // Calculer le flow actuel en partant d'aujourd'hui
    DateTime checkDate = today;
    bool isCurrentFlow = true;

    while (true) {
      final isValidDay = allValidDates.contains(checkDate);

      if (isValidDay) {
        if (isCurrentFlow) {
          currentFlow++;
        }
        longestFlow = currentFlow > longestFlow ? currentFlow : longestFlow;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        // Jour manquant - on vérifie si c'est aujourd'hui (pas encore lu)
        if (checkDate == today) {
          // Pas encore lu aujourd'hui, on continue avec hier
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        // Flow cassé
        break;
      }
    }

    // Calculer le longest flow historique
    int tempFlow = 0;
    for (int i = 0; i < sortedValidDates.length; i++) {
      final date = sortedValidDates[i];
      final previousDate = i > 0 ? sortedValidDates[i - 1] : null;

      if (previousDate == null) {
        tempFlow = 1;
      } else {
        final diff = previousDate.difference(date).inDays;
        if (diff == 1) {
          tempFlow++;
        } else {
          if (tempFlow > longestFlow) {
            longestFlow = tempFlow;
          }
          tempFlow = 1;
        }
      }
    }

    if (tempFlow > longestFlow) {
      longestFlow = tempFlow;
    }

    return {
      'current': currentFlow,
      'longest': longestFlow,
    };
  }

  /// Vérifier et attribuer des badges de flow
  Future<List<FlowBadgeLevel>> checkAndAwardFlowBadges() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final flow = await getUserFlow();
      final newBadges = <FlowBadgeLevel>[];

      // Récupérer les badges déjà attribués
      final existingBadges = await _supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId);

      final existingBadgeIds = (existingBadges as List)
          .map((b) => b['badge_id'] as String)
          .toSet();

      // Vérifier chaque niveau de badge
      for (final level in FlowBadgeLevel.values) {
        if (flow.currentFlow >= level.days &&
            !existingBadgeIds.contains(level.badgeId)) {
          // Créer le badge s'il n'existe pas
          await _ensureBadgeExists(level);

          // Attribuer le badge à l'utilisateur (upsert pour éviter doublon)
          await _supabase.from('user_badges').upsert({
            'user_id': userId,
            'badge_id': level.badgeId,
            'earned_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id,badge_id', ignoreDuplicates: true);

          newBadges.add(level);
        }
      }

      return newBadges;
    } catch (e) {
      debugPrint('Erreur checkAndAwardFlowBadges: $e');
      return [];
    }
  }

  /// S'assurer que le badge existe dans la table badges
  Future<void> _ensureBadgeExists(FlowBadgeLevel level) async {
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

  /// Stream pour suivre le flow en temps réel
  Stream<ReadingFlow> watchUserFlow() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value(ReadingFlow.empty());
    }

    return _supabase
        .from('reading_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((_) async => await getUserFlow());
  }
}
