// pages/feed/widgets/invite_friends_banner.dart
// Bannière d'invitation d'amis pour réduire le cold start

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class InviteFriendsBanner extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onFindFriends;

  const InviteFriendsBanner({
    super.key,
    required this.onShare,
    required this.onFindFriends,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.accentDark,
                  AppColors.accentDark.withValues(alpha: 0.6),
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.accentLight,
                ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Text(
            '\u{1F4EC}',
            style: TextStyle(fontSize: 32),
          ),
          const SizedBox(height: AppSpace.m),
          Text(
            AppLocalizations.of(context).feedEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            AppLocalizations.of(context).feedEmptySubtitle,
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
            onPressed: onShare,
            icon: const Icon(Icons.share, size: 18),
            label: Text(AppLocalizations.of(context).feedShareLink),
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
          const SizedBox(height: AppSpace.s),
          TextButton(
            onPressed: onFindFriends,
            child: Text(
              AppLocalizations.of(context).feedOrSearchFriends,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
