// lib/services/notifications_service.dart
// Service pour gérer les notifications (likes et commentaires)

import 'package:supabase_flutter/supabase_flutter.dart';

enum NotificationType {
  like,
  comment;

  static NotificationType fromString(String type) {
    switch (type) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
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

      final response = await _supabase.rpc(
        'get_user_notifications',
        params: {
          'p_user_id': userId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (response == null) return [];

      final List<dynamic> list = response is List ? response : [response];
      
      return list.map((item) => AppNotification.fromJson(item)).toList();
    } catch (e) {
      print('Erreur getNotifications: $e');
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
      print('Erreur getUnreadCount: $e');
      return 0;
    }
  }

  /// Marquer les notifications comme lues
  Future<void> markAsRead({List<String>? notificationIds}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.rpc(
        'mark_notifications_as_read',
        params: {
          'p_user_id': userId,
          'p_notification_ids': notificationIds,
        },
      );
    } catch (e) {
      print('Erreur markAsRead: $e');
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
