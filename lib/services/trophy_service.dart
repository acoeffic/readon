// lib/services/trophy_service.dart
// Service pour la sélection et l'attribution des trophées de lecture

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trophy.dart';
import '../models/reading_session.dart';

class TrophyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sélectionne un trophée contextuel basé sur la session de lecture.
  /// Évalue les conditions par ordre de priorité, retourne le premier match.
  Trophy selectTrophy(ReadingSession session) {
    final startHour = session.startTime.hour;
    final endHour = session.endTime?.hour ?? startHour;
    final duration = session.durationMinutes;
    final pages = session.pagesRead;
    final isWeekday = session.startTime.weekday <= 5;

    // Priorité 1 : très peu de pages
    if (pages <= 2 && pages > 0) {
      return Trophy(type: TrophyType.memeUnParagraphe);
    }

    // Priorité 2 : session très courte
    if (duration <= 3) {
      return Trophy(type: TrophyType.lectureEclair);
    }

    // Priorité 3 : session ~5 minutes
    if (duration >= 4 && duration <= 7) {
      return Trophy(type: TrophyType.justeCinqMinutes);
    }

    // Priorité 4 : longue session sans distraction
    if (duration >= 45) {
      return Trophy(type: TrophyType.lectureSansDistraction);
    }

    // Priorité 5 : session longue ou beaucoup de pages
    if (duration >= 30 || pages >= 25) {
      return Trophy(type: TrophyType.unePageDePlus);
    }

    // Priorité 6 : lecture tard le soir
    if (endHour >= 23) {
      return Trophy(type: TrophyType.dernierePageAvantMinuit);
    }

    // Priorité 7 : rituel du matin (tôt)
    if (startHour >= 5 && startHour < 8) {
      return Trophy(type: TrophyType.rituelDuMatin);
    }

    // Priorité 8 : café & chapitre (matin)
    if (startHour >= 6 && startHour < 10) {
      return Trophy(type: TrophyType.cafeChapitre);
    }

    // Priorité 9 : pause lecture (midi)
    if (startHour >= 12 && startHour < 14) {
      return Trophy(type: TrophyType.pauseLecture);
    }

    // Priorité 10 : chapitre volé (après-midi en semaine)
    if (startHour >= 14 && startHour < 18 && isWeekday) {
      return Trophy(type: TrophyType.chapitreVole);
    }

    // Priorité 11 : lecture du soir
    if (startHour >= 20 && startHour < 23) {
      return Trophy(type: TrophyType.lectureDuSoir);
    }

    // Priorité 12 : fallback
    return Trophy(type: TrophyType.pageDuJour);
  }

  /// Vérifie et attribue les trophées débloquables.
  /// Retourne la liste des trophées nouvellement débloqués.
  Future<List<Trophy>> checkUnlockableTrophies({
    required ReadingSession session,
    required int currentStreak,
    required int activeBookCount,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Récupérer les trophées déjà attribués
      final existingBadges = await _supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId);

      final existingIds = (existingBadges as List)
          .map((b) => b['badge_id'] as String)
          .toSet();

      final newTrophies = <Trophy>[];

      // Trophée 13 : Lecture imprévue
      if (!existingIds.contains(TrophyType.lectureImprevue.id)) {
        final isNewTimeBucket = await _isNewTimeBucket(session, userId);
        if (isNewTimeBucket) {
          await _awardTrophy(TrophyType.lectureImprevue, userId);
          newTrophies.add(Trophy(
            type: TrophyType.lectureImprevue,
            isNewlyUnlocked: true,
            unlockedAt: DateTime.now(),
          ));
        }
      }

      // Trophée 14 : Toujours un livre
      if (!existingIds.contains(TrophyType.toujoursUnLivre.id)) {
        if (activeBookCount >= 2) {
          await _awardTrophy(TrophyType.toujoursUnLivre, userId);
          newTrophies.add(Trophy(
            type: TrophyType.toujoursUnLivre,
            isNewlyUnlocked: true,
            unlockedAt: DateTime.now(),
          ));
        }
      }

      // Trophée 15 : Fidélité quotidienne
      if (!existingIds.contains(TrophyType.fideliteQuotidienne.id)) {
        if (currentStreak >= 2) {
          await _awardTrophy(TrophyType.fideliteQuotidienne, userId);
          newTrophies.add(Trophy(
            type: TrophyType.fideliteQuotidienne,
            isNewlyUnlocked: true,
            unlockedAt: DateTime.now(),
          ));
        }
      }

      return newTrophies;
    } catch (e) {
      debugPrint('Erreur checkUnlockableTrophies: $e');
      return [];
    }
  }

  /// Vérifie si la session actuelle utilise un créneau horaire jamais utilisé.
  Future<bool> _isNewTimeBucket(ReadingSession session, String userId) async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select('start_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .neq('id', session.id);

      final existingBuckets = <int>{};
      for (final row in response as List) {
        final startTime = DateTime.parse(row['start_time'] as String).toLocal();
        existingBuckets.add(_getTimeBucket(startTime.hour));
      }

      final currentBucket = _getTimeBucket(session.startTime.hour);
      return !existingBuckets.contains(currentBucket);
    } catch (e) {
      debugPrint('Erreur _isNewTimeBucket: $e');
      return false;
    }
  }

  /// Retourne un identifiant de créneau horaire (0-7).
  int _getTimeBucket(int hour) {
    if (hour < 5) return 0;   // 00h-05h
    if (hour < 8) return 1;   // 05h-08h
    if (hour < 12) return 2;  // 08h-12h
    if (hour < 14) return 3;  // 12h-14h
    if (hour < 18) return 4;  // 14h-18h
    if (hour < 20) return 5;  // 18h-20h
    if (hour < 23) return 6;  // 20h-23h
    return 7;                  // 23h-00h
  }

  /// Attribue un trophée à l'utilisateur (persiste en base).
  Future<void> _awardTrophy(TrophyType type, String userId) async {
    try {
      await _ensureTrophyExists(type);
      await _supabase.from('user_badges').insert({
        'user_id': userId,
        'badge_id': type.id,
        'unlocked_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Erreur _awardTrophy: $e');
    }
  }

  /// S'assure que le trophée existe dans la table badges.
  Future<void> _ensureTrophyExists(TrophyType type) async {
    try {
      final existing = await _supabase
          .from('badges')
          .select('id')
          .eq('id', type.id)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('badges').insert({
          'id': type.id,
          'name': type.name,
          'description': type.description,
          'icon': type.icon,
          'color': '#7FA497',
          'category': 'trophy',
          'requirement': 1,
        });
      }
    } catch (e) {
      debugPrint('Erreur _ensureTrophyExists: $e');
    }
  }
}
