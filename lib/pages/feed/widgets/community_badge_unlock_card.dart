// pages/feed/widgets/community_badge_unlock_card.dart
// Card pour afficher un badge recemment debloque par un membre de la communaute

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_profile_avatar.dart';

class CommunityBadgeUnlockCard extends StatelessWidget {
  final Map<String, dynamic> unlock;
  final VoidCallback? onTap;

  /// `true` (défaut) : source `get_feed_bundle.badge_unlocks`, un inconnu au
  /// hasard — affiche le badge « Communauté ». `false` : le déblocage vient
  /// du fil d'amis normal (activité `badge_unlocked`, fix 2026-09-26) — le
  /// pill n'a pas lieu d'être, l'auteur EST déjà un ami.
  final bool isCommunity;

  const CommunityBadgeUnlockCard({
    super.key,
    required this.unlock,
    this.onTap,
    this.isCommunity = true,
  });

  /// Construit la carte depuis une activité de fil d'amis (`type:
  /// 'badge_unlocked'`, payload posé par le trigger serveur
  /// `log_badge_awarded` sur `user_badges`) plutôt que depuis l'entrée
  /// `unlock` de `get_feed_bundle.badge_unlocks`. Les deux sources portent
  /// les mêmes clés de badge (`badge_name`, `badge_icon`, `badge_color`,
  /// `badge_category`) mais l'identité de l'auteur et l'horodatage sont à
  /// des emplacements différents (`author_name`/`author_id`/`created_at`
  /// au lieu de `display_name`/`user_id`/`unlocked_at`).
  factory CommunityBadgeUnlockCard.fromActivity({
    Key? key,
    required Map<String, dynamic> activity,
    VoidCallback? onTap,
  }) {
    final payload = activity['payload'] as Map<String, dynamic>? ?? {};
    return CommunityBadgeUnlockCard(
      key: key,
      isCommunity: false,
      onTap: onTap,
      unlock: {
        ...payload,
        'display_name': activity['author_name'],
        'avatar_url': activity['author_avatar'],
        'unlocked_at': activity['created_at']?.toString(),
        'user_id': activity['author_id'],
      },
    );
  }

  String _getTimeAgo(AppLocalizations l, String? unlockedAt) {
    if (unlockedAt == null) return l.timeAgoRecently;
    try {
      final DateTime time = DateTime.parse(unlockedAt);
      final Duration difference = DateTime.now().difference(time);
      final String text;
      if (difference.inSeconds < 60) {
        text = l.justNow;
      } else if (difference.inMinutes < 60) {
        text = l.timeAgoMinutes(difference.inMinutes);
      } else if (difference.inHours < 24) {
        text = l.timeAgoHours(difference.inHours);
      } else {
        text = l.timeAgoDays(difference.inDays);
      }
      return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
    } catch (e) {
      return l.timeAgoRecently;
    }
  }

  Color _parseBadgeColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return AppColors.primary;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = unlock['display_name'] as String? ?? 'Un lecteur';
    final avatarUrl = unlock['avatar_url'] as String?;
    final badgeName = unlock['badge_name'] as String? ?? '';
    final badgeIcon = unlock['badge_icon'] as String? ?? '🏅';
    final badgeColor = _parseBadgeColor(unlock['badge_color'] as String?);
    final unlockedAt = unlock['unlocked_at'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 0 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar + Nom + Temps + Badge communaute
              Row(
                children: [
                  CachedProfileAvatar(
                    imageUrl: avatarUrl,
                    userName: displayName,
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    textColor: AppColors.primary.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _getTimeAgo(AppLocalizations.of(context), unlockedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge communaute — absent pour une activité d'amis :
                  // l'auteur est déjà un ami, "Communauté" serait trompeur.
                  if (isCommunity)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.public,
                            size: 12,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Communauté',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Description
              Text(
                AppLocalizations.of(context).badgeUnlockedByFriend,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),

              // Detail du badge
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    // Badge icon (emoji)
                    Text(
                      badgeIcon,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badgeName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? badgeColor.withValues(alpha: 0.9) : badgeColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _categoryLabel(
                                  unlock['badge_category'] as String?),
                              style: TextStyle(
                                fontSize: 10,
                                color: badgeColor.withValues(alpha: isDark ? 0.8 : 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
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
    );
  }

  String _categoryLabel(String? category) {
    switch (category) {
      case 'books_completed':
        return 'Livres terminés';
      case 'reading_time':
        return 'Temps de lecture';
      case 'flow':
        return 'Flow de lecture';
      case 'goals':
        return 'Objectifs';
      case 'social':
        return 'Social';
      case 'genres':
        return 'Genres';
      case 'annual':
        return 'Annuel';
      case 'occasions':
        return 'Occasions';
      case 'comeback':
        return 'Retour';
      default:
        return 'Badge';
    }
  }
}
