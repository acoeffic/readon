// lib/widgets/referral_invite_card.dart
//
// Carte « Invite un ami » affichée aux moments forts (livre terminé, paliers
// de flow). Affichage seul : le partage et l'analytics sont portés par la page
// hôte. Voir ReferralPrompt pour les règles d'affichage.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class ReferralInviteCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String body;

  /// Reçoit la zone du bouton (origine du partage, requise sur iPad).
  final ValueChanged<Rect?> onShare;
  final VoidCallback onLater;

  const ReferralInviteCard({
    super.key,
    required this.isDark,
    required this.title,
    required this.body,
    required this.onShare,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondary = isDark ? Colors.white70 : Colors.black54;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🎁', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Builder(
                builder: (btnContext) => FilledButton.icon(
                  onPressed: () {
                    final box = btnContext.findRenderObject() as RenderBox?;
                    final origin = box != null && box.hasSize
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null;
                    onShare(origin);
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(l.referralPromptCta),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onLater,
                child: Text(
                  l.firstSessionGoalLater,
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
