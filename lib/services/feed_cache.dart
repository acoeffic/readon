// services/feed_cache.dart
// Cache mémoire pour le feed — évite de re-fetcher entre navigations

import '../models/reading_flow.dart';
import '../models/book_suggestion.dart';
import '../models/prize_list.dart';
import '../services/trending_service.dart';

class FeedCacheData {
  final List<Map<String, dynamic>> friendActivities;
  final ReadingFlow? currentFlow;
  final Map<String, dynamic>? currentReadingBook;
  final List<BookSuggestion> suggestions;
  final int friendCount;
  final FeedTier feedTier;
  final List<Map<String, dynamic>> trendingBooks;
  final List<Map<String, dynamic>> communitySessions;
  final List<Map<String, dynamic>> activeReaders;
  final List<Map<String, dynamic>> badgeUnlocks;
  final Map<int, int> curatedReaderCounts;
  final Set<int> savedCuratedListIds;
  final List<PrizeList> prizeLists;
  final String? lastActivityCursor;
  final bool hasMoreActivities;

  FeedCacheData({
    required this.friendActivities,
    required this.currentFlow,
    required this.currentReadingBook,
    required this.suggestions,
    required this.friendCount,
    required this.feedTier,
    required this.trendingBooks,
    required this.communitySessions,
    required this.activeReaders,
    required this.badgeUnlocks,
    required this.curatedReaderCounts,
    required this.savedCuratedListIds,
    required this.prizeLists,
    required this.lastActivityCursor,
    required this.hasMoreActivities,
  });
}

class FeedCache {
  static FeedCacheData? _cached;
  static DateTime? _lastFetch;
  static const _ttl = Duration(minutes: 5);

  static bool get isValid =>
      _cached != null &&
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < _ttl;

  static FeedCacheData? get data => _cached;

  static void store(FeedCacheData data) {
    _cached = data;
    _lastFetch = DateTime.now();
  }

  static void invalidate() {
    _cached = null;
    _lastFetch = null;
  }
}
