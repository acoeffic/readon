// lib/services/notifications_service.dart
// Service pour gérer les notifications (likes et commentaires)

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum NotificationType {
  like,
  comment,
  friendRequest;

  static NotificationType fromString(String type) {
    switch (type) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'friend_request':
        return NotificationType.friendRequest;
      default:
        return NotificationType.like;
    }
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final int activityId;
  final String fromUserId;
  final String fromUserName;
  final String? fromUserAvatar;
  final Map<String, dynamic>? activityPayload;
  final String? commentContent;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.activityId,
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserAvatar,
    this.activityPayload,
    this.commentContent,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> 
        ? json 
        : Map<String, dynamic>.from(json as Map);
    
    return AppNotification(
      id: map['id']?.toString() ?? '',
      type: NotificationType.fromString(map['type']?.toString() ?? 'like'),
      activityId: (map['activity_id'] as num?)?.toInt() ?? 0,
      fromUserId: map['from_user_id']?.toString() ?? '',
      fromUserName: map['from_user_name']?.toString() ?? 'Un utilisateur',
      fromUserAvatar: map['from_user_avatar']?.toString(),
      activityPayload: map['activity_payload'] as Map<String, dynamic>?,
      commentContent: map['comment_content']?.toString(),
      isRead: map['is_read'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
    );
  }

  String get message {
    final bookTitle = activityPayload?['book_title']?.toString() ?? 'votre lecture';
    
    switch (type) {
      case NotificationType.like:
        return '$fromUserName a aimé votre lecture de $bookTitle';
      case NotificationType.comment:
        return '$fromUserName a commenté votre lecture de $bookTitle';
      case NotificationType.friendRequest:
        return '$fromUserName vous a envoyé une demande d\'ami';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}

class NotificationsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupérer les notifications de l'utilisateur
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('notifications')
          .select('id, type, activity_id, from_user_id, is_read, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) return [];

      // Récupérer les profils des expéditeurs
      final fromUserIds = (response as List)
          .map((n) => n['from_user_id'] as String)
          .toSet()
          .toList();

      final profiles = await _supabase
          .from('profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', fromUserIds);

      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profiles) {
        profileMap[p['id'] as String] = p;
      }

      return response.map((item) {
        final fromUserId = item['from_user_id'] as String;
        final profile = profileMap[fromUserId];
        return AppNotification.fromJson({
          ...item,
          'from_user_name': profile?['display_name'] ?? 'Un utilisateur',
          'from_user_avatar': profile?['avatar_url'],
        });
      }).toList();
    } catch (e) {
      debugPrint('Erreur getNotifications: $e');
      return [];
    }
  }

  /// Compter les notifications non lues
  Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase.rpc(
        'count_unread_notifications',
        params: {'p_user_id': userId},
      );

      return (response as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Erreur getUnreadCount: $e');
      return 0;
    }
  }

  /// Marquer les notifications comme lues
  Future<void> markAsRead({List<String>? notificationIds}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      if (notificationIds != null && notificationIds.isNotEmpty) {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .inFilter('id', notificationIds);
      } else {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false);
      }
    } catch (e) {
      debugPrint('Erreur markAsRead: $e');
    }
  }

  /// Marquer toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    await markAsRead();
  }

  /// Stream en temps réel des notifications
  Stream<List<AppNotification>> watchNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((_) async => await getNotifications());
  }

  /// Stream du compteur de notifications non lues
Stream<int> watchUnreadCount() {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value(0);

  return _supabase
      .from('notifications')
      .stream(primaryKey: ['id'])
      .order('created_at')
      .map((data) {
        // Filtrer côté client
        return data.where((notif) => 
          notif['user_id'] == userId && 
          notif['is_read'] == false
        ).length;
      });
}
}
