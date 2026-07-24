// lib/services/mutual_friends_service.dart
//
// Calcule le nombre d'amis communs (et un échantillon de 3 mini-profils)
// entre l'utilisateur courant et un utilisateur cible. Utilisé par les
// cartes de suggestion d'amis pour afficher un signal de confiance.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mini-profil d'un ami affiché dans le badge "amis en commun".
@immutable
class MutualFriendAvatar {
  final String id;
  final String displayName;
  final String? avatarUrl;

  const MutualFriendAvatar({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  factory MutualFriendAvatar.fromJson(Map<String, dynamic> json) {
    return MutualFriendAvatar(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'avatar_url': avatarUrl,
      };
}

/// Synthèse d'amis communs : compteur + jusqu'à 3 mini-profils.
@immutable
class MutualFriendsSummary {
  final int count;
  final List<MutualFriendAvatar> avatars;

  const MutualFriendsSummary({required this.count, required this.avatars});

  static const empty = MutualFriendsSummary(count: 0, avatars: []);

  bool get isEmpty => count == 0;

  factory MutualFriendsSummary.fromJson(Map<String, dynamic> json) {
    final avatarsRaw = json['avatars'];
    final avatars = <MutualFriendAvatar>[];
    if (avatarsRaw is List) {
      for (final a in avatarsRaw) {
        if (a is Map) {
          avatars.add(MutualFriendAvatar.fromJson(Map<String, dynamic>.from(a)));
        }
      }
    }
    return MutualFriendsSummary(
      count: (json['count'] as num?)?.toInt() ?? 0,
      avatars: avatars,
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'avatars': avatars.map((a) => a.toJson()).toList(),
      };
}

class MutualFriendsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère le summary pour un seul user. Préférer la variante batch
  /// dès qu'on en affiche plus d'un.
  Future<MutualFriendsSummary> getSummary(String targetUserId) async {
    try {
      final res = await _supabase.rpc(
        'get_mutual_friends_summary',
        params: {'p_target_user_id': targetUserId},
      );
      final list = res is List && res.isNotEmpty ? res.first : null;
      if (list == null) return MutualFriendsSummary.empty;
      return _parseRow(Map<String, dynamic>.from(list as Map));
    } catch (e) {
      debugPrint('MutualFriendsService.getSummary error: $e');
      return MutualFriendsSummary.empty;
    }
  }

  /// Récupère les summaries pour une liste de users en un seul appel.
  /// Renvoie une map keyed par user_id. Les ids absents = pas d'amis communs.
  Future<Map<String, MutualFriendsSummary>> getSummariesBatch(
    List<String> targetUserIds,
  ) async {
    if (targetUserIds.isEmpty) return {};
    try {
      final res = await _supabase.rpc(
        'get_mutual_friends_summary_batch',
        params: {'p_target_user_ids': targetUserIds},
      );
      final list = res is List ? res : const [];
      final out = <String, MutualFriendsSummary>{};
      for (final row in list) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['target_user_id']?.toString();
        if (id == null) continue;
        out[id] = _parseRow(map);
      }
      return out;
    } catch (e) {
      debugPrint('MutualFriendsService.getSummariesBatch error: $e');
      return {};
    }
  }

  MutualFriendsSummary _parseRow(Map<String, dynamic> map) {
    final count = (map['mutual_count'] as num?)?.toInt() ?? 0;
    final avatarsRaw = map['avatars'];
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
    return MutualFriendsSummary(count: count, avatars: avatars);
  }
}
