// lib/services/badges_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final int requirement;
  final String color;
  final DateTime? unlockedAt;
  final int progress;
  final bool isUnlocked;
  final bool isPremium;
  final bool isSecret;
  final bool isAnimated;
  final String progressUnit;
  final String? lottieAsset;
  final int sortOrder;

  UserBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.requirement,
    required this.color,
    this.unlockedAt,
    required this.progress,
    required this.isUnlocked,
    this.isPremium = false,
    this.isSecret = false,
    this.isAnimated = false,
    this.progressUnit = 'livres',
    this.lottieAsset,
    this.sortOrder = 0,
  });

  factory UserBadge.fromJson(dynamic json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json as Map);

    return UserBadge(
      id: map['badge_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      requirement: (map['requirement'] as num?)?.toInt() ?? 0,
      color: map['color']?.toString() ?? '#000000',
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.parse(map['unlocked_at'].toString())
          : null,
      progress: (map['progress'] as num?)?.toInt() ?? 0,
      isUnlocked: map['is_unlocked'] == true,
      isPremium: map['is_premium'] == true,
      isSecret: map['is_secret'] == true,
      isAnimated: map['is_animated'] == true,
      progressUnit: map['progress_unit']?.toString() ?? 'livres',
      lottieAsset: map['lottie_asset']?.toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// Progression en pourcentage (0.0 à 1.0)
  double get progressPercentage {
    if (isUnlocked) return 1.0;
    if (requirement == 0) return 0.0;
    return (progress / requirement).clamp(0.0, 1.0);
  }

  /// Texte de progression avec l'unité appropriée
  String get progressText {
    if (progressUnit == 'minutes') {
      final progressHours = (progress / 60).floor();
      final requirementHours = (requirement / 60).floor();
      return '${progressHours}h / ${requirementHours}h';
    }
    if (progressUnit.isEmpty) {
      return isUnlocked ? 'Débloqué' : 'Verrouillé';
    }
    return '$progress / $requirement $progressUnit';
  }
}

class BadgesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupérer les badges d'un utilisateur
  Future<List<UserBadge>> getUserBadges() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase.rpc(
        'get_all_user_badges',
        params: {'p_user_id': userId},
      );

      if (response == null) return [];

      final List<dynamic> list = response is List ? response : [response];

      return list
          .map((item) => UserBadge.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('Erreur getUserBadges: $e');
      return [];
    }
  }

  /// Récupérer les badges d'un utilisateur par son ID
  Future<List<UserBadge>> getUserBadgesById(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_all_user_badges',
        params: {'p_user_id': userId},
      );

      if (response == null) return [];

      final List<dynamic> list = response is List ? response : [response];

      return list
          .map((item) => UserBadge.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('Erreur getUserBadgesById: $e');
      return [];
    }
  }

  /// Vérifier et attribuer les badges (après une session)
  Future<List<UserBadge>> checkAndAwardBadges() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase.rpc(
        'check_and_award_badges',
        params: {'p_user_id': userId},
      );

      if (response == null) return [];

      final List<dynamic> list = response is List ? response : [response];
      if (list.isEmpty) return [];

      // Retourner les badges nouvellement débloqués
      return list.map((item) {
        final map = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);

        return UserBadge(
          id: map['badge_id']?.toString() ?? '',
          name: map['badge_name']?.toString() ?? '',
          description: '',
          icon: map['badge_icon']?.toString() ?? '📚',
          category: map['badge_category']?.toString() ?? 'books_completed',
          requirement: 0,
          color: map['badge_color']?.toString() ?? '#3498db',
          unlockedAt: DateTime.now(),
          progress: 0,
          isUnlocked: true,
          isPremium: map['badge_is_premium'] == true,
          isSecret: map['badge_is_secret'] == true,
          isAnimated: map['badge_is_animated'] == true,
          lottieAsset: map['badge_lottie_asset']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Erreur checkAndAwardBadges: $e');
      return [];
    }
  }

  /// Vérifier les badges secrets basés sur l'heure locale (côté client)
  Future<List<UserBadge>> checkSecretBadges({
    required DateTime sessionStartTime,
    required DateTime? sessionEndTime,
    required bool bookFinished,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Récupérer les badges secrets déjà attribués
      final existingBadges = await _supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId);

      final existingIds = (existingBadges as List)
          .map((b) => b['badge_id'] as String)
          .toSet();

      final newBadges = <UserBadge>[];

      // Minuit Pile: session commencée à 00:00
      if (!existingIds.contains('secret_midnight') &&
          sessionStartTime.hour == 0 && sessionStartTime.minute == 0) {
        await _awardSecretBadge(userId, 'secret_midnight');
        newBadges.add(UserBadge(
          id: 'secret_midnight', name: 'Minuit Pile',
          description: 'Commencer une session à 00:00',
          icon: '🕛', category: 'secret', requirement: 1,
          color: '#311B92', unlockedAt: DateTime.now(),
          progress: 1, isUnlocked: true, isSecret: true,
        ));
      }

      // Premier de l'An: lire le 1er janvier
      if (!existingIds.contains('secret_new_year') &&
          sessionStartTime.month == 1 && sessionStartTime.day == 1) {
        await _awardSecretBadge(userId, 'secret_new_year');
        newBadges.add(UserBadge(
          id: 'secret_new_year', name: 'Premier de l\'An',
          description: 'Lire le 1er janvier',
          icon: '🎆', category: 'secret', requirement: 1,
          color: '#1A237E', unlockedAt: DateTime.now(),
          progress: 1, isUnlocked: true, isSecret: true,
        ));
      }

      // Marathon Nocturne: lire de 22h à 6h
      if (!existingIds.contains('secret_night_marathon') &&
          sessionEndTime != null &&
          sessionStartTime.hour >= 22 && sessionEndTime.hour < 6) {
        await _awardSecretBadge(userId, 'secret_night_marathon');
        newBadges.add(UserBadge(
          id: 'secret_night_marathon', name: 'Marathon Nocturne',
          description: 'Lire de 22h à 6h',
          icon: '🦉', category: 'secret', requirement: 1,
          color: '#0D47A1', unlockedAt: DateTime.now(),
          progress: 1, isUnlocked: true, isSecret: true,
        ));
      }

      // Finisher: terminer un livre en 1 session
      if (!existingIds.contains('secret_finisher') && bookFinished) {
        // On considère que si le livre est fini dans cette session, c'est un finisher
        // La vérification plus précise peut être faite côté serveur
        await _awardSecretBadge(userId, 'secret_finisher');
        newBadges.add(UserBadge(
          id: 'secret_finisher', name: 'Finisher',
          description: 'Terminer un livre en 1 session',
          icon: '🚀', category: 'secret', requirement: 1,
          color: '#01579B', unlockedAt: DateTime.now(),
          progress: 1, isUnlocked: true, isSecret: true,
        ));
      }

      // Palindrome: lire un jour palindrome (ex: 12/12, 11/11, 01/01, etc.)
      if (!existingIds.contains('secret_palindrome') &&
          sessionStartTime.month == sessionStartTime.day) {
        await _awardSecretBadge(userId, 'secret_palindrome');
        newBadges.add(UserBadge(
          id: 'secret_palindrome', name: 'Palindrome',
          description: 'Lire un 12/12, 11/11, etc.',
          icon: '🔢', category: 'secret', requirement: 1,
          color: '#006064', unlockedAt: DateTime.now(),
          progress: 1, isUnlocked: true, isSecret: true,
        ));
      }

      return newBadges;
    } catch (e) {
      debugPrint('Erreur checkSecretBadges: $e');
      return [];
    }
  }

  /// Attribuer un badge secret
  Future<void> _awardSecretBadge(String userId, String badgeId) async {
    try {
      await _supabase.from('user_badges').insert({
        'user_id': userId,
        'badge_id': badgeId,
        'earned_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Erreur _awardSecretBadge: $e');
    }
  }

  /// Compter les livres terminés
  Future<int> getCompletedBooksCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase.rpc(
        'count_completed_books',
        params: {'p_user_id': userId},
      );

      return (response as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Erreur getCompletedBooksCount: $e');
      return 0;
    }
  }

  /// Stream en temps réel des badges
  Stream<List<UserBadge>> watchUserBadges() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('user_badges')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((_) async => await getUserBadges());
  }
}
