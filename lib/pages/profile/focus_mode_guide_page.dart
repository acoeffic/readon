// lib/pages/profile/focus_mode_guide_page.dart
//
// Guide « Mode sans distraction » (iOS uniquement).
//
// iOS interdit d'activer Ne pas déranger / un mode Concentration depuis une
// app tierce. La seule voie native : l'utilisateur crée deux automatisations
// personnelles dans Raccourcis (« LexDay ouverte → activer NPD », « LexDay
// fermée → désactiver »). Depuis iOS 17 elles s'exécutent sans confirmation.
// Cette page se contente donc d'expliquer les étapes et d'ouvrir Raccourcis.
//
// Points d'entrée : Réglages → Lecture, et la suggestion unique post-session
// (cf. FocusModeService). Le paramètre [source] alimente PostHog pour savoir
// lequel des deux convertit.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../widgets/constrained_content.dart';

class FocusModeGuidePage extends StatefulWidget {
  /// D'où vient l'utilisateur : 'settings' ou 'post_session_suggestion'.
  final String source;

  const FocusModeGuidePage({super.key, required this.source});

  @override
  State<FocusModeGuidePage> createState() => _FocusModeGuidePageState();
}

class _FocusModeGuidePageState extends State<FocusModeGuidePage> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().track(
      AnalyticsEvent.focusGuideOpened,
      properties: {'source': widget.source},
    );
  }

  Future<void> _openShortcuts() async {
    AnalyticsService().track(AnalyticsEvent.focusGuideShortcutsOpened);
    final uri = Uri.parse('shortcuts://');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _showShortcutsUnavailable();
    } catch (_) {
      if (mounted) _showShortcutsUnavailable();
    }
  }

  /// Raccourcis est préinstallée mais peut avoir été supprimée.
  void _showShortcutsUnavailable() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.focusModeShortcutsUnavailable),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.l, AppSpace.l, AppSpace.l, 0),
              child: BackHeader(
                title: l10n.focusModeTitle,
                titleColor: AppColors.primary,
              ),
            ),
            Expanded(
              child: ConstrainedContent(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Intro : le bénéfice, pas la technique ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpace.l),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.l),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🌙', style: TextStyle(fontSize: 28)),
                            const SizedBox(height: AppSpace.s),
                            Text(
                              l10n.focusModeIntroTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpace.s),
                            Text(
                              l10n.focusModeIntroBody,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpace.l),

                      // ── Automatisation 1 : à l'ouverture ──
                      _AutomationCard(
                        emoji: '📖',
                        title: l10n.focusModeAutomation1Title,
                        subtitle: l10n.focusModeAutomation1Subtitle,
                        steps: [
                          l10n.focusModeStepOpenShortcuts,
                          l10n.focusModeStepAutomationTab,
                          l10n.focusModeStepChooseApp,
                          l10n.focusModeStepIsOpened,
                          l10n.focusModeStepActionOn,
                        ],
                      ),

                      const SizedBox(height: AppSpace.m),

                      // ── Automatisation 2 : à la fermeture ──
                      _AutomationCard(
                        emoji: '🔔',
                        title: l10n.focusModeAutomation2Title,
                        subtitle: l10n.focusModeAutomation2Subtitle,
                        steps: [
                          l10n.focusModeStepAutomationTab,
                          l10n.focusModeStepChooseApp,
                          l10n.focusModeStepIsClosed,
                          l10n.focusModeStepActionOff,
                        ],
                      ),

                      const SizedBox(height: AppSpace.l),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openShortcuts,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpace.l - 4),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded,
                              size: 18),
                          label: Text(
                            l10n.focusModeOpenShortcuts,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpace.m),

                      // Transparence : réglage système, réversible, zéro accès.
                      Text(
                        l10n.focusModeNote,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutomationCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<String> steps;

  const _AutomationCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(
                  bottom: i == steps.length - 1 ? 0 : AppSpace.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
