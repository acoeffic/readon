// pages/feed/widgets/find_friends_cta.dart
// CTA discret pour encourager l'ajout d'amis

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class FindFriendsCta extends StatelessWidget {
  final VoidCallback onFindFriends;

  const FindFriendsCta({super.key, required this.onFindFriends});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: AppSpace.l),
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.accentDark.withValues(alpha: 0.4)
            : AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            color: AppColors.primary,
            size: 36,
          ),
          const SizedBox(height: AppSpace.m),
          Text(
            'Lis avec tes amis !',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            'Ajoute des amis pour découvrir leurs lectures\net partager tes sessions avec eux',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.l),
          FilledButton.icon(
            onPressed: onFindFriends,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Trouver mes amis'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
