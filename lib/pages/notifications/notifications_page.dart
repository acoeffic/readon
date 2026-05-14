// lib/pages/notifications/notifications_page.dart
// Page d'affichage des notifications

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    HapticFeedback.mediumImpact();
    if (n.type == NotificationType.groupJoinRequest) {
      _respondToGroupJoinRequest(n, true);
    } else {
      _respondToFriendRequest(n, true);
    }
  }

  void _handleIgnore(AppNotification n) {
    HapticFeedback.selectionClick();
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
    HapticFeedback.selectionClick();
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
      final bookIdInt = int.tryParse(bookId) ?? 0;

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

  Future<void> _deleteNotification(AppNotification notification) async {
    HapticFeedback.mediumImpact();
    // Optimistic remove
    final removedIndex = _notifications.indexWhere((n) => n.id == notification.id);
    if (removedIndex == -1) return;
    final removed = _notifications[removedIndex];
    setState(() {
      _notifications.removeAt(removedIndex);
    });

    try {
      await notificationsService.deleteNotification(notification.id);
    } catch (_) {
      // Restore on failure
      if (!mounted) return;
      setState(() {
        _notifications.insert(removedIndex, removed);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).actionImpossible),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDismissibleCard(AppNotification n) {
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: _buildSwipeBackground(),
      onDismissed: (_) => _deleteNotification(n),
      child: _NotificationCard(
        notification: n,
        isProcessing: _processingRequests.contains(n.id),
        onAccept: () => _handleAccept(n),
        onIgnore: () => _handleIgnore(n),
        onTap: () => _onNotificationTap(n),
      ),
    );
  }

  Widget _buildSwipeBackground() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE85B6E),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Supprimer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.selectionClick();
    await notificationsService.markAllAsRead();
    setState(() {
      for (var i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = AppNotification(
            id: _notifications[i].id,
            type: _notifications[i].type,
            activityId: _notifications[i].activityId,
            fromUserId: _notifications[i].fromUserId,
            fromUserName: _notifications[i].fromUserName,
            fromUserAvatar: _notifications[i].fromUserAvatar,
            activityPayload: _notifications[i].activityPayload,
            commentContent: _notifications[i].commentContent,
            isRead: true,
            createdAt: _notifications[i].createdAt,
          );
        }
      }
    });
  }

  List<AppNotification> get _newNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  List<AppNotification> get _readNotifications =>
      _notifications.where((n) => n.isRead).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasUnread = _newNotifications.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        l10n.notifications,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (hasUnread)
                      TextButton(
                        onPressed: _markAllAsRead,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.markAllRead,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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
                            color: AppColors.primary,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              children: [
                                if (_newNotifications.isNotEmpty) ...[
                                  _SectionHeader(
                                    title: l10n.newNotifications,
                                    count: _newNotifications.length,
                                    isDark: isDark,
                                  ),
                                  ..._newNotifications
                                      .map(_buildDismissibleCard),
                                  if (_readNotifications.isNotEmpty)
                                    const SizedBox(height: 20),
                                ],
                                if (_readNotifications.isNotEmpty) ...[
                                  _SectionHeader(
                                    title: l10n.recentNotifications,
                                    count: null,
                                    isDark: isDark,
                                  ),
                                  ..._readNotifications
                                      .map(_buildDismissibleCard),
                                ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noNotifications,
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.noNotificationsDesc,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Section header
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.black.withValues(alpha: 0.75),
              letterSpacing: 0.2,
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Notification card
// ============================================================================

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

  // ── Type metadata ──────────────────────────────────────────────────────────

  Color get _typeColor {
    switch (notification.type) {
      case NotificationType.like:
        return const Color(0xFFE85B6E); // coral red — heart
      case NotificationType.comment:
        return AppColors.sageGreen;
      case NotificationType.friendRequest:
        return AppColors.gold;
      case NotificationType.groupJoinRequest:
        return AppColors.primary;
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
      case NotificationType.like:
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.chat_bubble_rounded;
      case NotificationType.friendRequest:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.groupJoinRequest:
        return Icons.groups_rounded;
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = !notification.isRead;
    final isTappable = onTap != null &&
        (notification.type == NotificationType.like ||
            notification.type == NotificationType.comment);

    // ── Couleurs / styles différenciés lu vs non-lu ──────────────────────
    // Non-lu : fond teinté sage, ombre, accent gauche épais, chip "Nouveau"
    // Lu     : fond gris très léger, pas d'ombre, texte fortement estompé
    final cardColor = isUnread
        ? (isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primary.withValues(alpha: 0.10))
        : (isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.025));

    final borderColor = isUnread
        ? AppColors.primary.withValues(alpha: 0.35)
        : Colors.transparent;

    final boxShadow = isUnread
        ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.20 : 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ]
        : <BoxShadow>[];

    final messageColor = isDark ? Colors.white : Colors.black87;
    final messageOpacity = isUnread ? 1.0 : 0.42;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: boxShadow,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isTappable
                ? () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  }
                : null,
            splashColor: AppColors.primary.withValues(alpha: 0.08),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            child: Stack(
              children: [
                // Barre d'accent gauche épaisse (uniquement non-lu)
                if (isUnread)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(isUnread ? 16 : 4, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with type badge overlay
                      _AvatarWithBadge(
                        avatarUrl: notification.fromUserAvatar,
                        fallbackInitial: notification.fromUserName.isNotEmpty
                            ? notification.fromUserName[0].toUpperCase()
                            : '?',
                        badgeIcon: _typeIcon,
                        badgeColor: _typeColor,
                        isUnread: isUnread,
                      ),

                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chip "Nouveau" pour les non-lus
                            if (isUnread) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'NOUVEAU',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            // Message
                            Text(
                              _message(l10n),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                height: 1.35,
                                color: messageColor.withValues(
                                    alpha: messageOpacity),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Time
                            Text(
                              notification.timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(
                                        alpha: isUnread ? 0.5 : 0.35),
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                      // Quoted comment
                      if (notification.type == NotificationType.comment &&
                          notification.commentContent != null) ...[
                        const SizedBox(height: 10),
                        _QuotedComment(
                          content: notification.commentContent!,
                          isDark: isDark,
                        ),
                      ],

                      // Action buttons
                      if (_hasActions) ...[
                        const SizedBox(height: 12),
                        if (isProcessing)
                          const SizedBox(
                            height: 36,
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
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
                                        borderRadius:
                                            BorderRadius.circular(10),
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
                                            .withValues(alpha: 0.18),
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
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

                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Avatar with type badge overlay
// ============================================================================

class _AvatarWithBadge extends StatelessWidget {
  final String? avatarUrl;
  final String fallbackInitial;
  final IconData badgeIcon;
  final Color badgeColor;
  final bool isUnread;

  const _AvatarWithBadge({
    required this.avatarUrl,
    required this.fallbackInitial,
    required this.badgeIcon,
    required this.badgeColor,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    // Pour les notifs lues, le badge a un fond neutre (gris) pour réduire
    // l'attention visuelle. Pour les non-lues, le badge garde sa couleur vive.
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isUnread
        ? (isDark ? AppColors.surfaceDark : Colors.white)
        : scaffoldBg;
    final effectiveBadgeColor = isUnread
        ? badgeColor
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    final avatarOpacity = isUnread ? 1.0 : 0.6;

    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: avatarOpacity,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: effectiveBadgeColor.withValues(alpha: 0.18),
              backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      fallbackInitial,
                      style: TextStyle(
                        color: effectiveBadgeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: effectiveBadgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: cardBg, width: 2),
              ),
              child: Icon(
                badgeIcon,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Quoted comment block
// ============================================================================

class _QuotedComment extends StatelessWidget {
  final String content;
  final bool isDark;

  const _QuotedComment({required this.content, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: AppColors.sageGreen.withValues(alpha: 0.5),
            width: 2.5,
          ),
        ),
      ),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          fontStyle: FontStyle.italic,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.78),
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
