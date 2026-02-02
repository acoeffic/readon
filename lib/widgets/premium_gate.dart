// lib/widgets/premium_gate.dart
// Widget qui affiche le contenu si premium, sinon un prompt upgrade

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/feature_flags.dart';
import '../providers/subscription_provider.dart';
import '../pages/profile/upgrade_page.dart';
import '../theme/app_theme.dart';

class PremiumGate extends StatelessWidget {
  final Feature feature;
  final Widget child;
  final Widget? lockedWidget;

  const PremiumGate({
    super.key,
    required this.feature,
    required this.child,
    this.lockedWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, sub, _) {
        if (sub.isLoading) {
          return const SizedBox.shrink();
        }

        final isUnlocked = FeatureFlags.isAvailable(
          feature,
          isPremium: sub.isPremium,
        );

        if (isUnlocked) return child;

        return lockedWidget ?? _DefaultLockedWidget(feature: feature);
      },
    );
  }
}

class _DefaultLockedWidget extends StatelessWidget {
  final Feature feature;
  const _DefaultLockedWidget({required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UpgradePage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    FeatureFlags.title(feature),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
