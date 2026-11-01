// lib/widgets/friend_challenge_card.dart
//
// Carte « Lis avec un ami » de l'écran de fin de session (2e journée de
// lecture). Affichage seul : le partage et l'analytics sont portés par
// ReadingSessionSummaryPage. Voir FriendChallengeOffer.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class FriendChallengeCard extends StatelessWidget {
  final bool isDark;

  /// Reçoit la zone du bouton (origine du partage, requise sur iPad).
  final ValueChanged<Rect?> onShare;
  final VoidCallback onLater;

  const FriendChallengeCard({
    super.key,
    required this.isDark,
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
              const Text('🤝', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.friendChallengeTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.friendChallengeBody,
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
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(l.friendChallengeCta),
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
