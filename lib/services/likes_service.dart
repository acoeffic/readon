// lib/services/likes_service.dart
// Service pour gérer les likes sur les activités

import 'package:supabase_flutter/supabase_flutter.dart';

class LikesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Liker une activité
  Future<void> likeActivity(int activityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await _supabase.from('likes').insert({
        'activity_id': activityId,
        'user_id': userId,
      });
    } catch (e) {
      print('Erreur likeActivity: $e');
      rethrow;
    }
  }

  /// Unlike une activité
  Future<void> unlikeActivity(int activityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await _supabase
          .from('likes')
          .delete()
          .eq('activity_id', activityId)
          .eq('user_id', userId);
    } catch (e) {
      print('Erreur unlikeActivity: $e');
      rethrow;
    }
  }

  /// Compter les likes d'une activité
  Future<int> getLikeCount(int activityId) async {
    try {
      final response = await _supabase
          .from('likes')
          .select('id')
          .eq('activity_id', activityId);

      return (response as List).length;
    } catch (e) {
      print('Erreur getLikeCount: $e');
      return 0;
    }
  }

  /// Vérifier si l'utilisateur a liké une activité
  Future<bool> hasLiked(int activityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('likes')
          .select('id')
          .eq('activity_id', activityId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Erreur hasLiked: $e');
      return false;
    }
  }

  /// Récupérer les infos de like d'une activité (count + user liked)
  Future<Map<String, dynamic>> getActivityLikeInfo(int activityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      final likeCountFuture = getLikeCount(activityId);
      final hasLikedFuture = hasLiked(activityId);
      
      final results = await Future.wait([likeCountFuture, hasLikedFuture]);
      
      return {
        'count': results[0] as int,
        'hasLiked': results[1] as bool,
      };
    } catch (e) {
      print('Erreur getActivityLikeInfo: $e');
      return {'count': 0, 'hasLiked': false};
    }
  }

  /// Stream en temps réel du nombre de likes
Stream<int> watchLikeCount(int activityId) {
  return _supabase
      .from('likes')
      .stream(primaryKey: ['id'])
      .order('created_at')
      .map((data) {
        // Filtrer côté client
        return data.where((like) => like['activity_id'] == activityId).length;
      });
}

/// Stream pour vérifier si l'utilisateur a liké
Stream<bool> watchHasLiked(int activityId) {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value(false);

  return _supabase
      .from('likes')
      .stream(primaryKey: ['id'])
      .order('created_at')
      .map((data) {
        // Filtrer côté client
        return data.any((like) => 
          like['activity_id'] == activityId && 
          like['user_id'] == userId
        );
      });
}
}