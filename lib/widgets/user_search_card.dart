// lib/widgets/user_search_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_search_result.dart';

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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _buildAvatar(60),
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
                      Icon(Icons.lock, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Profil privé',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec avatar, nom et bouton
            Row(
              children: [
                _buildAvatar(64),
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
                            color: Colors.grey.shade600,
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
              const Text(
                'Badges récents',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
                          Text(
                            badge.icon,
                            style: const TextStyle(fontSize: 16),
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
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.book_outlined,
                    '${user.booksFinished ?? 0}',
                    'Livres',
                  ),
                  Container(width: 1, height: 30, color: AppColors.border),
                  _buildStatItem(
                    Icons.local_fire_department,
                    '${user.currentStreak ?? 0}',
                    'Streak',
                  ),
                  Container(width: 1, height: 30, color: AppColors.border),
                  _buildStatItem(
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
                  Icon(Icons.auto_stories, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    'En cours:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
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

  Widget _buildAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentLight,
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

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
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
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Annuler',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
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
