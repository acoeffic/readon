// pages/feed/widgets/trending_welcome_card.dart
// Message d'accueil chaleureux pour les utilisateurs sans amis

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class TrendingWelcomeCard extends StatelessWidget {
  final String? userName;

  const TrendingWelcomeCard({super.key, this.userName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.accentDark.withValues(alpha: 0.5),
                    AppColors.surfaceDark,
                  ]
                : [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.accentLight,
                  ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        child: Column(
          children: [
            Text(
              '📚 Tendances sur LexDay',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s),
            Text(
              'Voici ce que lit la communauté cette semaine',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
