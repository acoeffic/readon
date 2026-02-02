// services/trending_service.dart
// Service pour le contenu communautaire et les tendances

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum FeedTier { trending, mixed, friendsOnly }

class TrendingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache statique (survit aux re-instantiations du service)
  static List<Map<String, dynamic>>? _cachedTrendingBooks;
  static List<Map<String, dynamic>>? _cachedCommunitySessions;
  static DateTime? _trendingCacheTime;
  static DateTime? _sessionsCacheTime;
  static const _cacheDuration = Duration(minutes: 15);

  /// Determine le tier du feed selon le nombre d'amis
  FeedTier determineFeedTier(int friendCount) {
    if (friendCount >= 3) return FeedTier.friendsOnly;
    if (friendCount >= 1) return FeedTier.mixed;
    return FeedTier.trending;
  }

  /// Nombre d'amis acceptes de l'utilisateur courant
  Future<int> getAcceptedFriendCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final result = await _supabase.rpc(
        'get_accepted_friend_count',
        params: {'p_user_id': userId},
      );
      return (result as int?) ?? 0;
    } catch (e) {
      debugPrint('Erreur getAcceptedFriendCount: $e');
      return 0;
    }
  }

  /// Top livres les plus lus cette semaine
  Future<List<Map<String, dynamic>>> getTrendingBooks({
    int limit = 5,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedTrendingBooks != null &&
        _trendingCacheTime != null &&
        DateTime.now().difference(_trendingCacheTime!) < _cacheDuration) {
      return _cachedTrendingBooks!;
    }

    try {
      final result = await _supabase.rpc(
        'get_trending_books_by_sessions',
        params: {'p_limit': limit},
      );

      final books = List<Map<String, dynamic>>.from(result ?? []);
      _cachedTrendingBooks = books;
      _trendingCacheTime = DateTime.now();
      return books;
    } catch (e) {
      debugPrint('Erreur getTrendingBooks: $e');
      return _cachedTrendingBooks ?? [];
    }
  }

  /// Sessions recentes de profils publics
  Future<List<Map<String, dynamic>>> getCommunitySessions({
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedCommunitySessions != null &&
        _sessionsCacheTime != null &&
        DateTime.now().difference(_sessionsCacheTime!) < _cacheDuration) {
      return _cachedCommunitySessions!;
    }

    try {
      final result = await _supabase.rpc(
        'get_community_sessions',
        params: {'p_limit': limit},
      );

      final sessions = List<Map<String, dynamic>>.from(result ?? []);
      _cachedCommunitySessions = sessions;
      _sessionsCacheTime = DateTime.now();
      return sessions;
    } catch (e) {
      debugPrint('Erreur getCommunitySessions: $e');
      return _cachedCommunitySessions ?? [];
    }
  }

  /// Vider le cache (a appeler au logout)
  static void clearCache() {
    _cachedTrendingBooks = null;
    _cachedCommunitySessions = null;
    _trendingCacheTime = null;
    _sessionsCacheTime = null;
  }
}
