// services/feed_prefetcher.dart
// Prefetch du feed au login — remplit FeedCache avant que la page ne s'affiche

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/curated_lists_data.dart';
import '../models/book_suggestion.dart';
import '../models/prize_list.dart';
import '../models/reading_flow.dart';
import '../services/books_service.dart';
import '../services/feed_cache.dart';
import '../services/feed_cache_service.dart';
import '../services/flow_service.dart';
import '../services/suggestions_service.dart';
import '../services/trending_service.dart';

class FeedPrefetcher {
  static bool _running = false;

  /// Lance le prefetch en fire-and-forget.
  /// Si un prefetch est déjà en cours ou le cache est valide, ne fait rien.
  static void start() {
    if (_running || FeedCache.isValid) return;
    _running = true;
    _prefetch().whenComplete(() => _running = false);
  }

  static Future<void> _prefetch() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final curatedIds = kCuratedLists.map((l) => l.id).toList();

      final results = await Future.wait([
        FlowService().getUserFlow(),
        BooksService().getCurrentReadingBook(),
        SuggestionsService().getPersonalizedSuggestions(limit: 5),
        supabase.rpc('get_feed_bundle', params: {
          'p_feed_limit': 15,
          'p_trending_limit': 5,
          'p_sessions_limit': 10,
          'p_readers_limit': 10,
          'p_badges_limit': 8,
          'p_prizes_limit': 10,
          'p_curated_ids': curatedIds,
        }),
      ]);

      final flow = results[0] as ReadingFlow?;
      final currentBook = results[1] as Map<String, dynamic>?;
      final suggestions = results[2] as List<BookSuggestion>;
      final bundle = Map<String, dynamic>.from(results[3] as Map);

      final fCount = bundle['friend_count'] as int? ?? 0;
      final tier = TrendingService().determineFeedTier(fCount);

      final readerCountsRaw =
          bundle['curated_reader_counts'] as Map<String, dynamic>? ?? {};

      List<Map<String, dynamic>> castList(dynamic list) =>
          (list as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

      final activities =
          (tier == FeedTier.friendsOnly || tier == FeedTier.mixed)
              ? castList(bundle['feed'])
              : <Map<String, dynamic>>[];

      final showCommunity =
          tier == FeedTier.mixed || tier == FeedTier.trending;

      final cacheData = FeedCacheData(
        friendActivities: activities,
        currentFlow: flow,
        currentReadingBook: currentBook,
        suggestions: suggestions,
        friendCount: fCount,
        feedTier: tier,
        trendingBooks: showCommunity ? castList(bundle['trending_books']) : [],
        communitySessions:
            showCommunity ? castList(bundle['community_sessions']) : [],
        activeReaders:
            showCommunity ? castList(bundle['active_readers']) : [],
        badgeUnlocks:
            showCommunity ? castList(bundle['badge_unlocks']) : [],
        curatedReaderCounts:
            readerCountsRaw.map((k, v) => MapEntry(int.parse(k), v as int)),
        savedCuratedListIds:
            (bundle['saved_curated_ids'] as List<dynamic>? ?? [])
                .map((e) => e as int)
                .toSet(),
        prizeLists: (bundle['prize_lists'] as List<dynamic>? ?? [])
            .map((e) =>
                PrizeList.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hasMore: activities.length >= 15,
      );

      FeedCache.store(cacheData);
      FeedCacheService.saveFeed(cacheData);
      debugPrint('FeedPrefetcher: cache prêt');
    } catch (e) {
      debugPrint('FeedPrefetcher error: $e');
    }
  }
}
