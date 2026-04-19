// lib/pages/notifications/notifications_page.dart
// Page d'affichage des notifications — design avec sections et actions inline

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../services/groups_service.dart';
import '../../services/notifications_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_content.dart';
import '../feed/feed_page.dart';
import '../sessions/session_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final notificationsService = NotificationsService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  final Set<String> _processingRequests = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await notificationsService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
      await notificationsService.markAllAsRead();
    } catch (e) {
      debugPrint('Erreur _loadNotifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToFriendRequest(
      AppNotification notification, bool accept) async {
    final l10n = AppLocalizations.of(context);
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _processingRequests.add(notification.id));

    try {
      // Trouver la demande d'ami correspondante
      final friendsData = await supabase
          .from('friends')
          .select('id')
          .eq('requester_id', notification.fromUserId)
          .eq('addressee_id', currentUserId)
          .eq('status', 'pending')
          .limit(1);

      if ((friendsData as List).isNotEmpty) {
        final requestId = friendsData[0]['id'].toString();
        if (accept) {
          await supabase
              .from('friends')
              .update({'status': 'accepted'}).eq('id', requestId);
        } else {
          await supabase.from('friends').delete().eq('id', requestId);
        }
      }

      // Supprimer la notification de la base de données
      await supabase
          .from('notifications')
          .delete()
          .eq('id', notification.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(accept ? l10n.friendAdded : l10n.requestDeclined)),
      );

      if (accept) {
        FeedPage.notifyFriendsChanged();
      }

      // Retirer la notification de la liste
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionImpossible)),
      );
    } finally {
      if (mounted) setState(() => _processingRequests.remove(notification.id));
    }
  }

  void _handleAccept(AppNotification n) {
    if (n.type == NotificationType.groupJoinRequest) {
      _respondToGroupJoinRequest(n, true);
    } else {
      _respondToFriendRequest(n, true);
    }
  }

  void _handleIgnore(AppNotification n) {
    if (n.type == NotificationType.groupJoinRequest) {
      _respondToGroupJoinRequest(n, false);
    } else {
      _respondToFriendRequest(n, false);
    }
  }

  Future<void> _respondToGroupJoinRequest(
      AppNotification notification, bool accept) async {
    final l10n = AppLocalizations.of(context);
    final supabase = Supabase.instance.client;
    final groupsService = GroupsService();

    setState(() => _processingRequests.add(notification.id));

    try {
      final requestId = notification.activityPayload?['request_id']?.toString();
      if (requestId == null) throw Exception('Missing request_id');

      await groupsService.respondToJoinRequest(
        requestId: requestId,
        accept: accept,
      );

      // Supprimer la notification
      await supabase
          .from('notifications')
          .delete()
          .eq('id', notification.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? l10n.joinRequestAccepted(notification.fromUserName)
              : l10n.joinRequestRejected(notification.fromUserName)),
        ),
      );

      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionImpossible)),
      );
    } finally {
      if (mounted) {
        setState(() => _processingRequests.remove(notification.id));
      }
    }
  }

  void _onNotificationTap(AppNotification notification) {
    // Only navigate for like/comment notifications that have an activity
    if ((notification.type == NotificationType.like ||
            notification.type == NotificationType.comment) &&
        notification.activityId > 0) {
      final payload = notification.activityPayload;
      if (payload == null) return;

      final sessionId =
          (payload['session_id'] ?? notification.activityId).toString();
      final bookId = (payload['book_id'] ?? '').toString();
      final authorId = (payload['author_id'] ?? '').toString();
      final startPage = (payload['start_page'] as num?)?.toInt() ?? 0;
      final endPage = (payload['end_page'] as num?)?.toInt();
      final durationMin = (payload['duration_minutes'] as num?)?.toInt() ?? 0;

      final now = DateTime.now();
      final endTime = now;
      final startTime = endTime.subtract(Duration(minutes: durationMin));

      final session = ReadingSession(
        id: sessionId,
        userId: authorId,
        bookId: bookId,
        startPage: startPage,
        endPage: endPage,
        startTime: startTime,
        endTime: endTime,
        createdAt: notification.createdAt,
        updatedAt: notification.createdAt,
      );

      final bookTitle = payload['book_title']?.toString();
      final bookAuthor = payload['book_author']?.toString();
      final bookCoverUrl = payload['book_cover_url']?.toString();
      final bookIdInt =
          int.tryParse(bookId) ?? 0;

      final book = bookTitle != null
          ? Book(
              id: bookIdInt,
              title: bookTitle,
              author: bookAuthor,
              coverUrl: bookCoverUrl,
            )
          : null;

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final isOwn = authorId == currentUserId;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionDetailPage(
            session: session,
            book: book,
            isOwn: isOwn,
          ),
        ),
      );
    }
  }

  List<AppNotification> get _newNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  List<AppNotification> get _readNotifications =>
      _notifications.where((n) => n.isRead).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasUnread = _newNotifications.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        l10n.notifications,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (hasUnread)
                      TextButton(
                        onPressed: () async {
                          await notificationsService.markAllAsRead();
                          setState(() {
                            for (var i = 0; i < _notifications.length; i++) {
                              if (!_notifications[i].isRead) {
                                _notifications[i] = AppNotification(
                                  id: _notifications[i].id,
                                  type: _notifications[i].type,
                                  activityId: _notifications[i].activityId,
                                  fromUserId: _notifications[i].fromUserId,
                                  fromUserName:
                                      _notifications[i].fromUserName,
                                  fromUserAvatar:
                                      _notifications[i].fromUserAvatar,
                                  activityPayload:
                                      _notifications[i].activityPayload,
                                  commentContent:
                                      _notifications[i].commentContent,
                                  isRead: true,
                                  createdAt: _notifications[i].createdAt,
                                );
                              }
                            }
                          });
                        },
                        child: Text(
                          l10n.markAllRead,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _notifications.isEmpty
                        ? _buildEmptyState(context, l10n)
                        : RefreshIndicator(
                            onRefresh: _loadNotifications,
                            child: ListView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                if (_newNotifications.isNotEmpty) ...[
                                  _SectionHeader(
                                      title: l10n.newNotifications),
                                  ..._newNotifications.map((n) =>
                                      _NotificationCard(
                                        notification: n,
                                        isProcessing: _processingRequests
                                            .contains(n.id),
                                        onAccept: () => _handleAccept(n),
                                        onIgnore: () => _handleIgnore(n),
                                        onTap: () => _onNotificationTap(n),
                                      )),
                                  const SizedBox(height: 16),
                                ],
                                if (_readNotifications.isNotEmpty) ...[
                                  _SectionHeader(
                                      title: l10n.recentNotifications),
                                  ..._readNotifications.map((n) =>
                                      _NotificationCard(
                                        notification: n,
                                        isProcessing: _processingRequests
                                            .contains(n.id),
                                        onAccept: () => _handleAccept(n),
                                        onIgnore: () => _handleIgnore(n),
                                        onTap: () => _onNotificationTap(n),
                                      )),
                                ],
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noNotifications,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noNotificationsDesc,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.notification,
    required this.isProcessing,
    required this.onAccept,
    required this.onIgnore,
    this.onTap,
  });

  Color _avatarColor(BuildContext context) {
    switch (notification.type) {
      case NotificationType.like:
        return AppColors.primary;
      case NotificationType.comment:
        return AppColors.sageGreen;
      case NotificationType.friendRequest:
        return AppColors.gold;
      case NotificationType.groupJoinRequest:
        return AppColors.primary;
    }
  }

  String _typeLabel(AppLocalizations l10n) {
    switch (notification.type) {
      case NotificationType.like:
        return l10n.notifTypeLike;
      case NotificationType.comment:
        return l10n.notifTypeComment;
      case NotificationType.friendRequest:
        return l10n.notifTypeFriends;
      case NotificationType.groupJoinRequest:
        return l10n.notifTypeClub;
    }
  }

  String _message(AppLocalizations l10n) {
    final bookTitle =
        notification.activityPayload?['book_title']?.toString() ?? '';
    switch (notification.type) {
      case NotificationType.like:
        return l10n.likedYourReading(notification.fromUserName, bookTitle);
      case NotificationType.comment:
        return l10n.commentedYourReading(
            notification.fromUserName, bookTitle);
      case NotificationType.friendRequest:
        return l10n.sentYouFriendRequest(notification.fromUserName);
      case NotificationType.groupJoinRequest:
        final groupName =
            notification.activityPayload?['group_name']?.toString() ?? '';
        return l10n.sentGroupJoinRequest(
            notification.fromUserName, groupName);
    }
  }

  bool get _hasActions =>
      notification.type == NotificationType.friendRequest ||
      (notification.type == NotificationType.groupJoinRequest &&
          notification.activityPayload?['request_status'] == 'pending');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarBg = _avatarColor(context);

    final bool isTappable = onTap != null &&
        (notification.type == NotificationType.like ||
            notification.type == NotificationType.comment);

    return GestureDetector(
      onTap: isTappable ? onTap : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.6),
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: avatarBg.withValues(alpha: 0.25),
              backgroundImage: notification.fromUserAvatar != null &&
                      notification.fromUserAvatar!.isNotEmpty
                  ? NetworkImage(notification.fromUserAvatar!)
                  : null,
              child: notification.fromUserAvatar == null ||
                      notification.fromUserAvatar!.isEmpty
                  ? Text(
                      notification.fromUserName[0].toUpperCase(),
                      style: TextStyle(
                        color: avatarBg,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message
                  Text(
                    _message(l10n),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Time + type label
                  Row(
                    children: [
                      Text(
                        notification.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      Text(
                        _typeLabel(l10n),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Comment content for comment notifications
                  if (notification.type == NotificationType.comment &&
                      notification.commentContent != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notification.commentContent!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  // Friend/group join request actions
                  if (_hasActions) ...[
                    const SizedBox(height: 12),
                    if (isProcessing)
                      const SizedBox(
                        height: 36,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: onAccept,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  l10n.accept,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: OutlinedButton(
                                onPressed: onIgnore,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.2),
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  l10n.ignore,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),

            // Unread indicator dot
            if (!notification.isRead)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}
