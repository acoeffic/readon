// lib/services/people_you_may_know_service.dart
//
// Suggestions multi-signal de profils à connecter. Combine 4 signaux
// (amis communs, livres communs, clubs communs, genre dominant) pondérés
// dans un score, et retourne pour chaque candidat les "raisons" du match
// pour explicabilité côté UI.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mutual_friends_service.dart';

/// Type de signal qui justifie une suggestion.
enum PymkReasonType { mutualFriends, commonBooks, commonGroups, commonGenres }

PymkReasonType? _reasonTypeFromString(String? raw) {
  switch (raw) {
    case 'mutual_friends':
      return PymkReasonType.mutualFriends;
    case 'common_books':
      return PymkReasonType.commonBooks;
    case 'common_groups':
      return PymkReasonType.commonGroups;
    case 'common_genres':
      return PymkReasonType.commonGenres;
  }
  return null;
}

String _reasonTypeToString(PymkReasonType type) {
  switch (type) {
    case PymkReasonType.mutualFriends:
      return 'mutual_friends';
    case PymkReasonType.commonBooks:
      return 'common_books';
    case PymkReasonType.commonGroups:
      return 'common_groups';
    case PymkReasonType.commonGenres:
      return 'common_genres';
  }
}

/// Raison ponctuelle d'une suggestion (signal × valeur).
@immutable
class PymkReason {
  final PymkReasonType type;
  final int count;

  const PymkReason({required this.type, required this.count});

  Map<String, dynamic> toJson() => {
        'type': _reasonTypeToString(type),
        'count': count,
      };

  /// Phrase courte localisée pour la carte ("3 amis en commun").
  String label() {
    switch (type) {
      case PymkReasonType.mutualFriends:
        return count == 1 ? '1 ami en commun' : '$count amis en commun';
      case PymkReasonType.commonBooks:
        return count == 1 ? '1 livre en commun' : '$count livres en commun';
      case PymkReasonType.commonGroups:
        return count == 1 ? 'Membre du même club' : '$count clubs en commun';
      case PymkReasonType.commonGenres:
        return count == 1 ? 'Même genre préféré' : '$count genres en commun';
    }
  }
}

/// Suggestion enrichie : profil + score composite + reasons + stats.
@immutable
class PeopleYouMayKnow {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? readingHabit;
  final int booksFinished;
  final int currentFlow;
  final String? currentBookTitle;
  final String? currentBookCover;
  final int score;
  final int mutualFriendsCount;
  final int commonBooksCount;
  final int commonGroupsCount;
  final int commonGenresCount;
  final List<PymkReason> reasons;
  final List<MutualFriendAvatar> mutualAvatars;

  const PeopleYouMayKnow({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.readingHabit,
    required this.booksFinished,
    required this.currentFlow,
    this.currentBookTitle,
    this.currentBookCover,
    required this.score,
    required this.mutualFriendsCount,
    required this.commonBooksCount,
    required this.commonGroupsCount,
    required this.commonGenresCount,
    required this.reasons,
    required this.mutualAvatars,
  });

  /// Synthèse compatible avec MutualFriendsBadge.
  MutualFriendsSummary get mutualSummary => MutualFriendsSummary(
        count: mutualFriendsCount,
        avatars: mutualAvatars,
      );

  /// Première raison "forte" (dans l'ordre amis>livres>clubs>genres).
  PymkReason? get topReason {
    if (reasons.isEmpty) return null;
    const order = [
      PymkReasonType.mutualFriends,
      PymkReasonType.commonBooks,
      PymkReasonType.commonGroups,
      PymkReasonType.commonGenres,
    ];
    for (final t in order) {
      final r = reasons.where((r) => r.type == t).cast<PymkReason?>().firstOrNull;
      if (r != null) return r;
    }
    return reasons.first;
  }

  factory PeopleYouMayKnow.fromJson(Map<String, dynamic> json) {
    final reasonsRaw = json['reasons'];
    final reasons = <PymkReason>[];
    if (reasonsRaw is List) {
      for (final r in reasonsRaw) {
        if (r is Map) {
          final m = Map<String, dynamic>.from(r);
          final t = _reasonTypeFromString(m['type']?.toString());
          final c = (m['count'] as num?)?.toInt() ?? 0;
          if (t != null && c > 0) {
            reasons.add(PymkReason(type: t, count: c));
          }
        }
      }
    }

    final avatarsRaw = json['mutual_avatars'];
    final avatars = <MutualFriendAvatar>[];
    if (avatarsRaw is List) {
      for (final a in avatarsRaw) {
        if (a is Map) {
          avatars.add(
            MutualFriendAvatar.fromJson(Map<String, dynamic>.from(a)),
          );
        }
      }
    }

    return PeopleYouMayKnow(
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      readingHabit: json['reading_habit']?.toString(),
      booksFinished: (json['books_finished'] as num?)?.toInt() ?? 0,
      currentFlow: (json['current_flow'] as num?)?.toInt() ?? 0,
      currentBookTitle: json['current_book_title']?.toString(),
      currentBookCover: json['current_book_cover']?.toString(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      mutualFriendsCount:
          (json['mutual_friends_count'] as num?)?.toInt() ?? 0,
      commonBooksCount: (json['common_books_count'] as num?)?.toInt() ?? 0,
      commonGroupsCount: (json['common_groups_count'] as num?)?.toInt() ?? 0,
      commonGenresCount: (json['common_genres_count'] as num?)?.toInt() ?? 0,
      reasons: reasons,
      mutualAvatars: avatars,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'reading_habit': readingHabit,
        'books_finished': booksFinished,
        'current_flow': currentFlow,
        'current_book_title': currentBookTitle,
        'current_book_cover': currentBookCover,
        'score': score,
        'mutual_friends_count': mutualFriendsCount,
        'common_books_count': commonBooksCount,
        'common_groups_count': commonGroupsCount,
        'common_genres_count': commonGenresCount,
        'reasons': reasons.map((r) => r.toJson()).toList(),
        'mutual_avatars': mutualAvatars.map((a) => a.toJson()).toList(),
      };
}

class PeopleYouMayKnowService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<PeopleYouMayKnow>> getSuggestions({int limit = 15}) async {
    try {
      final res = await _supabase.rpc(
        'get_people_you_may_know',
        params: {'p_limit': limit},
      );
      if (res is! List) return [];
      return res
          .map((e) => PeopleYouMayKnow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('PeopleYouMayKnowService.getSuggestions error: $e');
      return [];
    }
  }
}

extension _FirstOrNull<T> on Iterable<T?> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
