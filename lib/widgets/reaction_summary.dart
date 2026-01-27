// lib/widgets/reaction_summary.dart
// Affichage des bulles de réactions groupées sous une activité

import 'package:flutter/material.dart';
import '../services/reactions_service.dart';
import '../theme/app_theme.dart';

class ReactionSummary extends StatelessWidget {
  final Map<String, int> reactionCounts;
  final List<String> userReactions;

  const ReactionSummary({
    super.key,
    required this.reactionCounts,
    required this.userReactions,
  });

  @override
  Widget build(BuildContext context) {
    // Ne rien afficher si pas de réactions
    final activeReactions = reactionCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (activeReactions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: activeReactions.map((entry) {
        final isUserReaction = userReactions.contains(entry.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isUserReaction
                ? AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15)
                : isDark
                    ? AppColors.surfaceDark
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: isUserReaction
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ReactionType.emoji(entry.key),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.value}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUserReaction
                      ? AppColors.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
