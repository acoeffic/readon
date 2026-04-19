// services/feed_cache_service.dart
// Cache Hive persistant pour le feed — stale-while-revalidate

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/reading_flow.dart';
import '../models/book_suggestion.dart';
import '../models/book.dart';
import '../models/prize_list.dart';
import '../services/trending_service.dart';
import 'feed_cache.dart';

class FeedCacheService {
  static const String _boxName = 'feed_cache';
  static const String _dataKey = 'feed_data';
  static const String _timestampKey = 'feed_timestamp';
  static const Duration _ttl = Duration(hours: 24);

  static Box? _box;

  /// Initialise la box Hive (appeler dans main.dart)
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Lit le dernier feed depuis le cache Hive.
  /// Retourne null si le cache est absent ou expiré (> 24h).
  static Future<FeedCacheData?> getLastFeed() async {
    try {
      final box = _box;
      if (box == null) return null;

      final timestamp = box.get(_timestampKey) as int?;
      if (timestamp == null) return null;

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cachedAt) > _ttl) {
        return null;
      }

      final raw = box.get(_dataKey) as String?;
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _fromJson(json);
    } catch (e) {
      debugPrint('FeedCacheService.getLastFeed error: $e');
      return null;
    }
  }

  /// Sauvegarde le feed dans le cache Hive.
  static Future<void> saveFeed(FeedCacheData data) async {
    try {
      final box = _box;
      if (box == null) return;

      final json = _toJson(data);
      await box.put(_dataKey, jsonEncode(json));
      await box.put(_timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('FeedCacheService.saveFeed error: $e');
    }
  }

  /// Vide le cache (appeler au logout).
  static Future<void> clear() async {
    try {
      final box = _box;
      if (box == null) return;
      await box.delete(_dataKey);
      await box.delete(_timestampKey);
    } catch (e) {
      debugPrint('FeedCacheService.clear error: $e');
    }
  }

  // ── Sérialisation ──────────────────────────────────────────────

  static Map<String, dynamic> _toJson(FeedCacheData data) {
    return {
      'friendActivities': data.friendActivities,
      'currentFlow': data.currentFlow?.toJson(),
      'currentReadingBook': data.currentReadingBook,
      'suggestions': data.suggestions.map((s) => s.toJson()).toList(),
      'friendCount': data.friendCount,
      'feedTier': data.feedTier.name,
      'trendingBooks': data.trendingBooks,
      'communitySessions': data.communitySessions,
      'activeReaders': data.activeReaders,
      'badgeUnlocks': data.badgeUnlocks,
      'curatedReaderCounts': data.curatedReaderCounts.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'savedCuratedListIds': data.savedCuratedListIds.toList(),
      'prizeLists': data.prizeLists.map((p) => p.toJson()).toList(),
      'hasMore': data.hasMore,
    };
  }

  static FeedCacheData _fromJson(Map<String, dynamic> json) {
    return FeedCacheData(
      friendActivities: _castListOfMaps(json['friendActivities']),
      currentFlow: json['currentFlow'] != null
          ? ReadingFlow.fromJson(json['currentFlow'] as Map<String, dynamic>)
          : null,
      currentReadingBook: _deserializeCurrentReadingBook(json['currentReadingBook']),
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((e) => BookSuggestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      friendCount: json['friendCount'] as int? ?? 0,
      feedTier: FeedTier.values.firstWhere(
        (t) => t.name == json['feedTier'],
        orElse: () => FeedTier.trending,
      ),
      trendingBooks: _castListOfMaps(json['trendingBooks']),
      communitySessions: _castListOfMaps(json['communitySessions']),
      activeReaders: _castListOfMaps(json['activeReaders']),
      badgeUnlocks: _castListOfMaps(json['badgeUnlocks']),
      curatedReaderCounts: (json['curatedReaderCounts'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), v as int)) ??
          {},
      savedCuratedListIds:
          (json['savedCuratedListIds'] as List<dynamic>?)
                  ?.map((e) => e as int)
                  .toSet() ??
              {},
      prizeLists: (json['prizeLists'] as List<dynamic>?)
              ?.map((e) => PrizeList.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hasMore: json['hasMore'] as bool? ?? true,
    );
  }

  static List<Map<String, dynamic>> _castListOfMaps(dynamic list) {
    if (list == null) return [];
    return (list as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Deserialize currentReadingBook: rebuild the Book object from the cached
  /// Map so that downstream code can safely cast it with `as Book`.
  static Map<String, dynamic>? _deserializeCurrentReadingBook(dynamic raw) {
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(raw as Map);
    final bookRaw = map['book'];
    if (bookRaw is Map) {
      map['book'] = Book.fromJson(Map<String, dynamic>.from(bookRaw));
    }
    return map;
  }
}
