// lib/widgets/user_search_card.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/mutual_friends_service.dart';
import '../theme/app_theme.dart';
import '../models/user_search_result.dart';
import 'mutual_friends_badge.dart';
import 'package:lexday/features/badges/widgets/remote_badge_image.dart';
import 'cached_profile_avatar.dart';

class UserSearchCard extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback? onAddFriend;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onViewProfile;
  final bool isRequestPending;
  final MutualFriendsSummary mutualFriends;

  const UserSearchCard({
    super.key,
    required this.user,
    this.onAddFriend,
    this.onCancelRequest,
    this.onViewProfile,
    this.isRequestPending = false,
    this.mutualFriends = MutualFriendsSummary.empty,
  });

  String _formatMemberSince(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}sem';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months mois';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years an${years > 1 ? 's' : ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user.isProfilePrivate) {
      return _buildPrivateCard(context);
    } else {
      return _buildPublicCard(context);
    }
  }

  Widget _buildPrivateCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: avatar + name + button
        Row(
          children: [
            _buildAvatar(context, 40),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.lock, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        l10n.privateProfileLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  if (!mutualFriends.isEmpty) ...[
                    const SizedBox(height: 6),
                    MutualFriendsBadge(summary: mutualFriends),
                  ],
                ],
              ),
            ),
            _buildActionButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildPublicCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: avatar + name + button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatarWithStreak(context),
            const SizedBox(width: AppSpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (user.memberSince != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatMemberSince(user.memberSince!),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (!mutualFriends.isEmpty) ...[
                    const SizedBox(height: 6),
                    MutualFriendsBadge(summary: mutualFriends),
                  ],
                ],
              ),
            ),
            _buildActionButton(context),
          ],
        ),

        const SizedBox(height: AppSpace.l),
        Divider(color: Theme.of(context).dividerColor, height: 1),
        const SizedBox(height: AppSpace.l),

        // Stats card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.l),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  '\u{1F4D6}',
                  '${user.booksFinished ?? 0}',
                  l10n.books,
                ),
              ),
              Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
              Expanded(
                child: _buildStatItem(
                  context,
                  '\u{1F525}',
                  '${user.currentFlow ?? 0}',
                  l10n.streakLabel,
                ),
              ),
              Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
              Expanded(
                child: _buildStatItem(
                  context,
                  '\u{1F465}',
                  '${user.friendsCount ?? 0}',
                  l10n.friends,
                ),
              ),
            ],
          ),
        ),

        // Badges section
        if (user.recentBadges != null && user.recentBadges!.isNotEmpty) ...[
          const SizedBox(height: AppSpace.l),
          Text(
            l10n.recentBadges.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpace.s),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: user.recentBadges!.take(3).map((badge) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.m,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _hexToColor(badge.color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.l),
                      border: Border.all(
                        color: _hexToColor(badge.color).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBadgeIcon(badge),
                        const SizedBox(width: 6),
                        Text(
                          badge.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _hexToColor(badge.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Current book card
        if (user.currentBook != null) ...[
          const SizedBox(height: AppSpace.l),
          _buildCurrentBookCard(context),
        ],

        // View full profile button
        if (onViewProfile != null) ...[
          const SizedBox(height: AppSpace.l),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewProfile,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
              ),
              child: Text(
                '${l10n.viewFullProfile} \u{2192}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatarWithStreak(BuildContext context) {
    final streak = user.currentFlow ?? 0;
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Green ring border
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 2.5,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: CachedProfileAvatar(
              imageUrl: user.avatarUrl,
              userName: user.displayName,
              radius: 38,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.accentDark
                  : AppColors.accentLight,
              textColor: AppColors.primary,
              fontSize: 30,
            ),
          ),
          // Streak badge
          if (streak > 0)
            Positioned(
              bottom: -2,
              left: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3D2E0A)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('\u{1F525}', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 2),
                    Text(
                      '${streak}j',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, double size) {
    return CachedProfileAvatar(
      imageUrl: user.avatarUrl,
      userName: user.displayName,
      radius: size / 2,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.accentDark
          : AppColors.accentLight,
      textColor: AppColors.primary,
      fontSize: size * 0.4,
    );
  }

  Widget _buildStatItem(BuildContext context, String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentBookCard(BuildContext context) {
    final book = user.currentBook!;
    final l10n = AppLocalizations.of(context);
    final progress = book.progress;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3E2E1E),
            Color(0xFF2A1F14),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.currentlyReading.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD4A96A),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Book cover
              Container(
                width: 50,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white.withValues(alpha: 0.15),
                  image: book.coverUrl != null
                      ? DecorationImage(
                          image: NetworkImage(book.coverUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: book.coverUrl == null
                    ? const Icon(Icons.book, color: Colors.white54, size: 24)
                    : null,
              ),
              const SizedBox(width: 14),
              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.author != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        book.author!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (progress != null && book.totalPages != null) ...[
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).round()} % \u{00B7} ${book.currentPage} / ${book.totalPages} pages',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (isRequestPending) {
      return GestureDetector(
        onTap: onCancelRequest,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                l10n.cancel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onAddFriend,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          '+ ${l10n.followLabel}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeIcon(UserBadgeSimple badge) {
    return RemoteBadgeImage.fromSimple(badge, size: 26);
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
