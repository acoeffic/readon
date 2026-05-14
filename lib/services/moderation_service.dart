// lib/services/moderation_service.dart
//
// Service unique pour les actions de modération côté client :
//   - signaler un contenu ou un utilisateur (`reportContent`)
//   - bloquer / débloquer un utilisateur (`blockUser` / `unblockUser`)
//   - vérifier le statut de blocage (`isBlocked`)
//
// Tout passe par les tables `content_reports` et `user_blocks` créées
// dans la migration 20260523. RLS garantit qu'un user ne peut écrire
// que ses propres signalements / blocs.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics_service.dart';

/// Cible d'un signalement. Doit matcher le CHECK de `content_reports.target_type`.
enum ReportTargetType {
  user,
  profile,
  comment,
  activity,
  readingSession,
  review;

  String get dbValue {
    switch (this) {
      case ReportTargetType.user:
        return 'user';
      case ReportTargetType.profile:
        return 'profile';
      case ReportTargetType.comment:
        return 'comment';
      case ReportTargetType.activity:
        return 'activity';
      case ReportTargetType.readingSession:
        return 'reading_session';
      case ReportTargetType.review:
        return 'review';
    }
  }
}

/// Raison d'un signalement. Doit matcher le CHECK de `content_reports.reason`.
enum ReportReason {
  spam,
  harassment,
  hateSpeech,
  sexualContent,
  violence,
  selfHarm,
  misinformation,
  impersonation,
  illegal,
  other;

  String get dbValue {
    switch (this) {
      case ReportReason.spam:
        return 'spam';
      case ReportReason.harassment:
        return 'harassment';
      case ReportReason.hateSpeech:
        return 'hate_speech';
      case ReportReason.sexualContent:
        return 'sexual_content';
      case ReportReason.violence:
        return 'violence';
      case ReportReason.selfHarm:
        return 'self_harm';
      case ReportReason.misinformation:
        return 'misinformation';
      case ReportReason.impersonation:
        return 'impersonation';
      case ReportReason.illegal:
        return 'illegal';
      case ReportReason.other:
        return 'other';
    }
  }
}

/// Résultat d'un appel `reportContent`.
enum ReportResult {
  success,
  alreadyReported,
  notAuthenticated,
  error,
}

class ModerationService {
  ModerationService._();
  static final ModerationService _instance = ModerationService._();
  factory ModerationService() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Soumet un signalement.
  ///
  /// `targetUserId` est l'auteur du contenu signalé. Optionnel pour les
  /// signalements directs d'utilisateur (où il est dérivable de `targetId`).
  Future<ReportResult> reportContent({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? targetUserId,
    String? details,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return ReportResult.notAuthenticated;

    try {
      await _supabase.from('content_reports').insert({
        'reporter_id': userId,
        'target_type': targetType.dbValue,
        'target_id': targetId,
        if (targetUserId != null) 'target_user_id': targetUserId,
        'reason': reason.dbValue,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      });

      unawaited(AnalyticsService().track(
        'content_reported',
        properties: {
          'target_type': targetType.dbValue,
          'reason': reason.dbValue,
        },
      ));

      return ReportResult.success;
    } on PostgrestException catch (e) {
      // 23505 = unique_violation → déjà signalé
      if (e.code == '23505') return ReportResult.alreadyReported;
      debugPrint('ModerationService.reportContent error: $e');
      return ReportResult.error;
    } catch (e) {
      debugPrint('ModerationService.reportContent error: $e');
      return ReportResult.error;
    }
  }

  /// Bloque un utilisateur. La requête `is_blocked()` côté DB devient
  /// `true` dans les 2 sens (le bloqué ne peut plus voir le bloqueur via
  /// les RPC qui s'en servent). Le trigger DB supprime aussi l'amitié.
  Future<bool> blockUser(String blockedUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    if (userId == blockedUserId) return false;

    try {
      await _supabase.from('user_blocks').insert({
        'blocker_id': userId,
        'blocked_id': blockedUserId,
      });
      unawaited(AnalyticsService().track(
        'user_blocked',
        properties: {'blocked_user_id': blockedUserId},
      ));
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return true; // déjà bloqué
      debugPrint('ModerationService.blockUser error: $e');
      return false;
    } catch (e) {
      debugPrint('ModerationService.blockUser error: $e');
      return false;
    }
  }

  Future<bool> unblockUser(String blockedUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', userId)
          .eq('blocked_id', blockedUserId);
      unawaited(AnalyticsService().track(
        'user_unblocked',
        properties: {'blocked_user_id': blockedUserId},
      ));
      return true;
    } catch (e) {
      debugPrint('ModerationService.unblockUser error: $e');
      return false;
    }
  }

  /// Renvoie true si l'utilisateur courant a bloqué OU est bloqué par
  /// `otherUserId`.
  Future<bool> isBlocked(String otherUserId) async {
    try {
      final result = await _supabase
          .rpc('is_blocked', params: {'p_user_id': otherUserId});
      return result == true;
    } catch (e) {
      debugPrint('ModerationService.isBlocked error: $e');
      return false;
    }
  }

  /// Liste des IDs des utilisateurs que l'utilisateur courant a bloqués
  /// (utile pour filtrer côté client les flux qui ne passent pas par un
  /// RPC qui filtre déjà).
  Future<Set<String>> getBlockedUserIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const {};

    try {
      final rows = await _supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', userId);
      return (rows as List)
          .map((r) => r['blocked_id'].toString())
          .toSet();
    } catch (e) {
      debugPrint('ModerationService.getBlockedUserIds error: $e');
      return const {};
    }
  }

  /// Liste enrichie des utilisateurs bloqués avec leur profil (nom +
  /// avatar). Utilisé par la page "Utilisateurs bloqués" pour permettre
  /// le déblocage avec contexte visuel.
  Future<List<BlockedUserInfo>> getBlockedUsers() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final blocks = await _supabase
          .from('user_blocks')
          .select('blocked_id, created_at')
          .eq('blocker_id', userId)
          .order('created_at', ascending: false);

      final list = (blocks as List);
      if (list.isEmpty) return const [];

      final ids = list.map((r) => r['blocked_id'].toString()).toList();
      final profiles = await _supabase
          .from('profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', ids);

      final profileById = {
        for (final p in (profiles as List))
          p['id'].toString(): p as Map<String, dynamic>,
      };

      return list.map((row) {
        final id = row['blocked_id'].toString();
        final p = profileById[id];
        return BlockedUserInfo(
          userId: id,
          displayName: p?['display_name'] as String?,
          avatarUrl: p?['avatar_url'] as String?,
          blockedAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
        );
      }).toList();
    } catch (e) {
      debugPrint('ModerationService.getBlockedUsers error: $e');
      return const [];
    }
  }
}

class BlockedUserInfo {
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? blockedAt;

  const BlockedUserInfo({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.blockedAt,
  });
}

