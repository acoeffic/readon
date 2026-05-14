// lib/pages/profile/theme_picker_page.dart
// Sélecteur de thème de couleurs. Sage est le défaut gratuit ; les 5 autres
// variantes sont gated derrière l'abonnement Premium (Feature.customThemes).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/feature_flags.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/native_paywall_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_variant.dart';
import '../../widgets/constrained_content.dart';

class ThemePickerPage extends StatelessWidget {
  const ThemePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = context.watch<ThemeProvider>();
    final isPremium = context.watch<SubscriptionProvider>().isPremium;

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        title: Text(l.themePickerTitle),
        backgroundColor: colors.scaffoldBg,
        elevation: 0,
      ),
      body: SafeArea(
        child: ConstrainedContent.wide(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.l),
            children: [
              Text(
                l.themePickerSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpace.l),
              ...ThemeVariants.all.map((variant) {
                final locked = variant.isPremium && !isPremium;
                final selected = theme.variant.id == variant.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ThemeVariantCard(
                    variant: variant,
                    selected: selected,
                    locked: locked,
                    onTap: () async {
                      if (locked) {
                        await NativePaywallService.present(
                          context,
                          highlightedFeature: Feature.customThemes,
                        );
                        return;
                      }
                      await theme.setVariant(variant);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeVariantCard extends StatelessWidget {
  final ThemeVariantPalette variant;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _ThemeVariantCard({
    required this.variant,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? variant.primary
                  : colors.border.withValues(alpha: 0.5),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: variant.primary.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Mini-mockup preview
              _MiniMockup(variant: variant),
              const SizedBox(width: 14),
              // Name + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          variant.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (variant.isPremium) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: variant.accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PREMIUM',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: variant.accent,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      variant.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing icon
              if (locked)
                Icon(
                  Icons.lock_outline_rounded,
                  size: 22,
                  color: colors.textSecondary.withValues(alpha: 0.6),
                )
              else if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: variant.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                )
              else
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colors.border,
                      width: 1.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini-aperçu visuel d'un thème : un petit "écran" avec header + carte.
class _MiniMockup extends StatelessWidget {
  final ThemeVariantPalette variant;
  const _MiniMockup({required this.variant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header coloré (= AppBar / FAB)
          Container(
            height: 22,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [variant.primary, variant.primaryDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Container(
                width: 24,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Body (= scaffoldBg light) + faux cards
          Expanded(
            child: Container(
              color: const Color(0xFFFAF3E8),
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: variant.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: variant.primary,
                      borderRadius: BorderRadius.circular(4),
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
}
