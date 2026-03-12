// lib/services/reaction_service.dart
// Service pour gérer les réactions emoji sur les activités

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReactionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const freeEmojis = ['❤️'];
  static const premiumEmojis = ['📚', '🔥', '🌟', '😭'];
  static const allEmojis = ['❤️', '📚', '🔥', '🌟', '😭'];

  static bool isPremiumEmoji(String emoji) => premiumEmojis.contains(emoji);

  /// Récupérer les réactions d'une activité via RPC
  /// Retourne: { counts: {❤️: 5, 🔥: 2}, userEmoji: '❤️', total: 7 }
  Future<Map<String, dynamic>> getReactions(int activityId) async {
    try {
      final result = await _supabase.rpc(
        'get_activity_emoji_reactions',
        params: {'p_activity_id': activityId},
      );

      if (result == null) {
        return {'counts': <String, int>{}, 'userEmoji': null, 'total': 0};
      }

      final data = result as Map<String, dynamic>;
      final countsRaw = data['counts'] as Map<String, dynamic>? ?? {};

      return {
        'counts': countsRaw.map<String, int>(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ),
        'userEmoji': data['user_emoji'] as String?,
        'total': (data['total'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      debugPrint('Erreur getReactions: $e');
      return {'counts': <String, int>{}, 'userEmoji': null, 'total': 0};
    }
  }

  /// Toggle une réaction emoji
  /// - Si l'user a déjà cette emoji → supprime
  /// - Si l'user a une autre emoji ou aucune → upsert
  Future<void> toggleReaction(int activityId, String emoji, {String? currentUserEmoji}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      if (currentUserEmoji == emoji) {
        // L'user retire sa réaction
        await _supabase
            .from('activity_reactions')
            .delete()
            .eq('activity_id', activityId)
            .eq('user_id', userId);
      } else {
        // Upsert : ajouter ou changer de réaction
        await _supabase.from('activity_reactions').upsert(
          {
            'activity_id': activityId,
            'user_id': userId,
            'emoji': emoji,
          },
          onConflict: 'activity_id, user_id',
        );
      }
    } catch (e) {
      debugPrint('Erreur toggleReaction: $e');
      rethrow;
    }
  }
}
