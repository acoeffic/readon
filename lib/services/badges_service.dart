// lib/services/badges_service.dart

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
    );
  }

  /// Progression en pourcentage (0.0 à 1.0)
  double get progressPercentage {
    if (isUnlocked) return 1.0;
    if (requirement == 0) return 0.0;
    return (progress / requirement).clamp(0.0, 1.0);
  }

  /// Texte de progression "X/Y livres"
  String get progressText {
    return '$progress / $requirement livres';
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
      print('Erreur getUserBadges: $e');
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
          category: 'books_completed',
          requirement: 0,
          color: '#3498db',
          unlockedAt: DateTime.now(),
          progress: 0,
          isUnlocked: true,
        );
      }).toList();
    } catch (e) {
      print('Erreur checkAndAwardBadges: $e');
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
      print('Erreur getCompletedBooksCount: $e');
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