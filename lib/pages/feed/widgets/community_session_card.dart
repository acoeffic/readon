// pages/feed/widgets/community_session_card.dart
// Card pour afficher une session de lecture de la communaute (profils publics)

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_book_cover.dart';
import '../../../widgets/cached_profile_avatar.dart';

class CommunitySessionCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const CommunitySessionCard({super.key, required this.session});

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return 'Récemment';
    try {
      final DateTime activityTime = DateTime.parse(createdAt);
      final Duration difference = DateTime.now().difference(activityTime);
      if (difference.inSeconds < 60) return 'À l\'instant';
      if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
      if (difference.inHours < 24) return 'Il y a ${difference.inHours}h';
      if (difference.inDays < 7) return 'Il y a ${difference.inDays}j';
      return 'Il y a ${(difference.inDays / 7).floor()}sem';
    } catch (e) {
      return 'Récemment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = session['display_name'] as String? ?? 'Un lecteur';
    final avatarUrl = session['avatar_url'] as String?;
    final bookTitle = session['book_title'] as String?;
    final bookAuthor = session['book_author'] as String?;
    final bookCover = session['book_cover'] as String?;
    final startPage = session['start_page'] as int?;
    final endPage = session['end_page'] as int?;
    final createdAt = session['session_created_at'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pagesRead = (startPage != null && endPage != null)
        ? (endPage - startPage).abs()
        : null;

    // Duree en minutes
    final startTime = session['start_time'] as String?;
    final endTime = session['end_time'] as String?;
    int? durationMinutes;
    if (startTime != null && endTime != null) {
      try {
        final start = DateTime.parse(startTime);
        final end = DateTime.parse(endTime);
        durationMinutes = end.difference(start).inMinutes;
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 0 : 1,
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
                        _getTimeAgo(createdAt),
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
                // Badge communaute
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              pagesRead != null
                  ? 'a lu $pagesRead page${pagesRead > 1 ? 's' : ''}'
                  : 'a terminé une session de lecture',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),

            // Détails du livre
            if (bookTitle != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    CachedBookCover(
                      imageUrl: bookCover,
                      width: 40,
                      height: 56,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bookTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (bookAuthor != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              bookAuthor,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (pagesRead != null || durationMinutes != null) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (pagesRead != null)
                                  _DetailChip(
                                    icon: Icons.menu_book,
                                    label:
                                        '$pagesRead page${pagesRead > 1 ? 's' : ''}',
                                  ),
                                if (durationMinutes != null &&
                                    durationMinutes > 0)
                                  _DetailChip(
                                    icon: Icons.schedule,
                                    label: durationMinutes >= 60
                                        ? '${(durationMinutes / 60).floor()}h${(durationMinutes % 60).round()}min'
                                        : '${durationMinutes}min',
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
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.3)
            : AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.7)
                : AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.7)
                  : AppColors.primary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
