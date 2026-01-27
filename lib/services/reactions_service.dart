// lib/services/reactions_service.dart
// Service pour gérer les réactions avancées sur les activités

import 'package:supabase_flutter/supabase_flutter.dart';

class ReactionType {
  static const fire = 'fire';
  static const book = 'book';
  static const clap = 'clap';
  static const heart = 'heart';

  static const all = [fire, book, clap, heart];

  static String emoji(String type) {
    switch (type) {
      case fire:
        return '🔥';
      case book:
        return '📘';
      case clap:
        return '👏';
      case heart:
        return '❤️';
      default:
        return '❤️';
    }
  }

  static String label(String type) {
    switch (type) {
      case fire:
        return 'Feu';
      case book:
        return 'Livre';
      case clap:
        return 'Bravo';
      case heart:
        return 'Cœur';
      default:
        return 'Cœur';
    }
  }
}

class ReactionsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Ajouter une réaction
  Future<void> addReaction(int activityId, String reactionType) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await _supabase.from('reactions').insert({
        'activity_id': activityId,
        'user_id': userId,
        'reaction_type': reactionType,
      });
    } catch (e) {
      print('Erreur addReaction: $e');
      rethrow;
    }
  }

  /// Supprimer une réaction
  Future<void> removeReaction(int activityId, String reactionType) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await _supabase
          .from('reactions')
          .delete()
          .eq('activity_id', activityId)
          .eq('user_id', userId)
          .eq('reaction_type', reactionType);
    } catch (e) {
      print('Erreur removeReaction: $e');
      rethrow;
    }
  }

  /// Récupérer les infos de réactions d'une activité via RPC
  /// Retourne: { counts: {fire: 2, book: 1}, userReactions: ['fire'], total: 3 }
  Future<Map<String, dynamic>> getActivityReactions(int activityId) async {
    try {
      final result = await _supabase.rpc(
        'get_activity_reactions',
        params: {'p_activity_id': activityId},
      );

      if (result == null) {
        return {'counts': <String, int>{}, 'userReactions': <String>[], 'total': 0};
      }

      final data = result as Map<String, dynamic>;
      final countsRaw = data['counts'] as Map<String, dynamic>? ?? {};
      final userReactionsRaw = data['user_reactions'] as List<dynamic>? ?? [];

      return {
        'counts': countsRaw.map<String, int>(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ),
        'userReactions': userReactionsRaw.cast<String>().toList(),
        'total': (data['total'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      print('Erreur getActivityReactions: $e');
      return {'counts': <String, int>{}, 'userReactions': <String>[], 'total': 0};
    }
  }

  /// Stream temps réel des réactions pour une activité
  Stream<List<Map<String, dynamic>>> watchReactions(int activityId) {
    return _supabase
        .from('reactions')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((data) {
      return data
          .where((r) => r['activity_id'] == activityId)
          .toList();
    });
  }
}
