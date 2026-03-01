// lib/widgets/user_search_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_search_result.dart';
import '../features/badges/widgets/first_book_badge_painter.dart';

class UserSearchCard extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback? onAddFriend;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onTap;
  final bool isRequestPending;

  const UserSearchCard({
    super.key,
    required this.user,
    this.onAddFriend,
    this.onCancelRequest,
    this.onTap,
    this.isRequestPending = false,
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
      return '${months}m';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}an${years > 1 ? 's' : ''}';
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            _buildAvatar(context, 60),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    children: [
                      Icon(Icons.lock, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        'Profil privé',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildActionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec avatar, nom et bouton
            Row(
              children: [
                _buildAvatar(context, 64),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (user.memberSince != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Membre depuis ${_formatMemberSince(user.memberSince!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildActionButton(context),
              ],
            ),

            const SizedBox(height: AppSpace.l),

            // Badges récents
            if (user.recentBadges != null && user.recentBadges!.isNotEmpty) ...[
              Text(
                'Badges récents',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Row(
                children: user.recentBadges!.take(3).map((badge) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpace.s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.m,
                        vertical: AppSpace.s,
                      ),
                      decoration: BoxDecoration(
                        color: _hexToColor(badge.color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(
                          color: _hexToColor(badge.color).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFirstBookBadge(id: badge.id))
                            const FirstBookBadge(size: 26)
                          else if (isApprenticeReaderBadge(id: badge.id))
                            const ApprenticeReaderBadge(size: 26)
                          else if (isOneHourMagicBadge(id: badge.id))
                            const OneHourMagicBadge(size: 26)
                          else if (isSundayReaderBadge(id: badge.id))
                            const SundayReaderBadge(size: 26)
                          else if (isPassionateBadge(id: badge.id))
                            const PassionateBadge(size: 26)
                          else if (isCenturionBadge(id: badge.id))
                            const CenturionBadge(size: 26)
                          else if (isMarathonBadge(id: badge.id))
                            const MarathonBadge(size: 26)
                          else if (isHalfMillenniumBadge(id: badge.id))
                            const HalfMillenniumBadge(size: 26)
                          else if (isMillenniumBadge(id: badge.id))
                            const MillenniumBadge(size: 26)
                          else if (isClubFounderBadge(id: badge.id))
                            const ClubFounderBadge(size: 26)
                          else if (isClubLeaderBadge(id: badge.id))
                            const ClubLeaderBadge(size: 26)
                          else if (isResidentBadge(id: badge.id))
                            const ResidentBadge(size: 26)
                          else if (isHabitueBadge(id: badge.id))
                            const HabitueBadge(size: 26)
                          else if (isPilierBadge(id: badge.id))
                            const PilierBadge(size: 26)
                          else if (isMonumentBadge(id: badge.id))
                            const MonumentBadge(size: 26)
                          else if (isAnnualOnePerMonthBadge(id: badge.id))
                            const AnnualOnePerMonthBadge(size: 26)
                          else if (isAnnualTwoPerMonthBadge(id: badge.id))
                            const AnnualTwoPerMonthBadge(size: 26)
                          else if (isAnnualOnePerWeekBadge(id: badge.id))
                            const AnnualOnePerWeekBadge(size: 26)
                          else if (isAnnualCentenaireBadge(id: badge.id))
                            const AnnualCentenaireBadge(size: 26)
                          else if (isOccasionBastilleDayBadge(id: badge.id))
                            const OccasionBastilleDayBadge(size: 26)
                          else if (isOccasionChristmasBadge(id: badge.id))
                            const OccasionChristmasBadge(size: 26)
                          else if (isOccasionFeteMusiqueBadge(id: badge.id))
                            const OccasionFeteMusiqueBadge(size: 26)
                          else if (isOccasionHalloweenBadge(id: badge.id))
                            const OccasionHalloweenBadge(size: 26)
                          else if (isOccasionSummerReadBadge(id: badge.id))
                            const OccasionSummerReadBadge(size: 26)
                          else if (isOccasionValentineBadge(id: badge.id))
                            const OccasionValentineBadge(size: 26)
                          else if (isOccasionNyeBadge(id: badge.id))
                            const OccasionNyeBadge(size: 26)
                          else if (isOccasionLabourDayBadge(id: badge.id))
                            const OccasionLabourDayBadge(size: 26)
                          else if (isOccasionWorldBookDayBadge(id: badge.id))
                            const OccasionWorldBookDayBadge(size: 26)
                          else if (isOccasionNewYearBadge(id: badge.id))
                            const OccasionNewYearBadge(size: 26)
                          else if (isOccasionEasterBadge(id: badge.id))
                            const OccasionEasterBadge(size: 26)
                          else if (isOccasionAprilFoolsBadge(id: badge.id))
                            const OccasionAprilFoolsBadge(size: 26)
                          else if (isGenreSfApprentiBadge(id: badge.id))
                            const GenreSfApprentiBadge(size: 26)
                          else if (isGenrePolarApprentiBadge(id: badge.id))
                            const GenrePolarApprentiBadge(size: 26)
                          else if (isGenrePolarAdepteBadge(id: badge.id))
                            const GenrePolarAdepteBadge(size: 26)
                          else if (isGenrePolarMaitreBadge(id: badge.id))
                            const GenrePolarMaitreBadge(size: 26)
                          else if (isGenrePolarLegendeBadge(id: badge.id))
                            const GenrePolarLegendeBadge(size: 26)
                          else if (isGenreSfApprentiBadge(id: badge.id))
                            const GenreSfApprentiBadge(size: 26)
                          else if (isGenreSfAdepteBadge(id: badge.id))
                            const GenreSfAdepteBadge(size: 26)
                          else if (isGenreSfMaitreBadge(id: badge.id))
                            const GenreSfMaitreBadge(size: 26)
                          else if (isGenreSfLegendeBadge(id: badge.id))
                            const GenreSfLegendeBadge(size: 26)
                          else if (isGenreRomanceApprentiBadge(id: badge.id))
                            const GenreRomanceApprentiBadge(size: 26)
                          else if (isGenreRomanceAdepteBadge(id: badge.id))
                            const GenreRomanceAdepteBadge(size: 26)
                          else if (isGenreRomanceMaitreBadge(id: badge.id))
                            const GenreRomanceMaitreBadge(size: 26)
                          else if (isGenreRomanceLegendeBadge(id: badge.id))
                            const GenreRomanceLegendeBadge(size: 26)
                          else if (isGenreHorreurApprentiBadge(id: badge.id))
                            const GenreHorreurApprentiBadge(size: 26)
                          else if (isGenreHorreurAdepteBadge(id: badge.id))
                            const GenreHorreurAdepteBadge(size: 26)
                          else if (isGenreHorreurMaitreBadge(id: badge.id))
                            const GenreHorreurMaitreBadge(size: 26)
                          else if (isGenreHorreurLegendeBadge(id: badge.id))
                            const GenreHorreurLegendeBadge(size: 26)
                          else if (isGenreBioApprentiBadge(id: badge.id))
                            const GenreBioApprentiBadge(size: 26)
                          else if (isGenreBioAdepteBadge(id: badge.id))
                            const GenreBioAdepteBadge(size: 26)
                          else if (isGenreBioMaitreBadge(id: badge.id))
                            const GenreBioMaitreBadge(size: 26)
                          else if (isGenreBioLegendeBadge(id: badge.id))
                            const GenreBioLegendeBadge(size: 26)
                          else if (isGenreHistoireApprentiBadge(id: badge.id))
                            const GenreHistoireApprentiBadge(size: 26)
                          else if (isGenreHistoireAdepteBadge(id: badge.id))
                            const GenreHistoireAdepteBadge(size: 26)
                          else if (isGenreHistoireMaitreBadge(id: badge.id))
                            const GenreHistoireMaitreBadge(size: 26)
                          else if (isGenreHistoireLegendeBadge(id: badge.id))
                            const GenreHistoireLegendeBadge(size: 26)
                          else if (isGenreDevpersoApprentiBadge(id: badge.id))
                            const GenreDevpersoApprentiBadge(size: 26)
                          else if (isGenreDevpersoAdepteBadge(id: badge.id))
                            const GenreDevpersoAdepteBadge(size: 26)
                          else if (isGenreDevpersoMaitreBadge(id: badge.id))
                            const GenreDevpersoMaitreBadge(size: 26)
                          else if (isGenreDevpersoLegendeBadge(id: badge.id))
                            const GenreDevpersoLegendeBadge(size: 26)
                          else
                            Text(
                              badge.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          const SizedBox(width: 4),
                          Text(
                            badge.name,
                            style: TextStyle(
                              fontSize: 11,
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
              const SizedBox(height: AppSpace.l),
            ],

            // Statistiques en grille
            Container(
              padding: const EdgeInsets.all(AppSpace.m),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(context,
                    Icons.book_outlined,
                    '${user.booksFinished ?? 0}',
                    'Livres',
                  ),
                  Container(width: 1, height: 30, color: Theme.of(context).dividerColor),
                  _buildStatItem(context,
                    Icons.local_fire_department,
                    '${user.currentFlow ?? 0}',
                    'Flow',
                  ),
                  Container(width: 1, height: 30, color: Theme.of(context).dividerColor),
                  _buildStatItem(context,
                    Icons.people_outline,
                    '${user.friendsCount ?? 0}',
                    'Amis',
                  ),
                ],
              ),
            ),

            // Livre en cours
            if (user.currentBook != null) ...[
              const SizedBox(height: AppSpace.l),
              Row(
                children: [
                  Icon(Icons.auto_stories, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    'En cours:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      user.currentBook!.title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.accentDark
            : AppColors.accentLight,
        image: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(user.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: user.avatarUrl == null || user.avatarUrl!.isEmpty
          ? Center(
              child: Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 26),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (isRequestPending) {
      return GestureDetector(
        onTap: onCancelRequest,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.m,
            vertical: AppSpace.s,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                'Annuler',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onAddFriend,
      icon: const Icon(Icons.person_add, size: 16),
      label: const Text('Ajouter'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.m,
          vertical: AppSpace.s,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        elevation: 0,
      ),
    );
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
