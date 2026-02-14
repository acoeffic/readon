// lib/services/badges_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'access_guard.dart';

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
  final String? tier;

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
    this.tier,
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
      tier: map['tier']?.toString(),
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
    } catch (e, stack) {
      debugPrint('❌ ERREUR getUserBadges: $e');
      debugPrint('❌ Stack: $stack');
      return [];
    }
  }

  /// Récupérer les badges d'un utilisateur par son ID.
  /// Vérifie que le demandeur est autorisé (soi-même, ami, ou profil public).
  Future<List<UserBadge>> getUserBadgesById(String userId) async {
    try {
      if (!await canAccessUserData(userId)) return [];

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

  /// Vérifier et attribuer les badges secrets via RPC serveur.
  /// Les timestamps sont vérifiés côté serveur (non manipulables).
  Future<List<UserBadge>> checkSecretBadges({
    required String sessionId,
    required bool bookFinished,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase.rpc(
        'check_and_award_secret_badges',
        params: {
          'p_session_id': sessionId,
          'p_book_finished': bookFinished,
        },
      );

      final rows = List<Map<String, dynamic>>.from(result ?? []);
      return rows.map((row) => UserBadge(
        id: row['badge_id'] as String,
        name: row['badge_name'] as String,
        description: row['badge_desc'] as String,
        icon: row['badge_icon'] as String,
        category: 'secret',
        requirement: 1,
        color: row['badge_color'] as String,
        unlockedAt: DateTime.now(),
        progress: 1,
        isUnlocked: true,
        isSecret: true,
      )).toList();
    } catch (e) {
      debugPrint('Erreur checkSecretBadges: $e');
      return [];
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
