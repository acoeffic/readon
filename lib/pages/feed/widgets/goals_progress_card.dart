// lib/pages/feed/widgets/goals_progress_card.dart
// Carte de progression des objectifs de lecture dans le feed.
// Affiche jusqu'à 3 objectifs actifs avec leur barre de progression,
// ou un CTA discret si aucun objectif n'est défini.

import 'package:flutter/material.dart';
import '../../../models/reading_goal.dart';
import '../../../theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

class GoalsProgressCard extends StatelessWidget {
  /// Objectifs actifs (liste vide → CTA de création).
  final List<ReadingGoal> goals;
  final VoidCallback? onTap;

  /// Nombre max d'objectifs affichés dans la carte.
  static const int _maxGoals = 3;

  const GoalsProgressCard({
    super.key,
    required this.goals,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return goals.isEmpty ? _buildCta(context) : _buildGoals(context);
  }

  // ── CTA discret quand aucun objectif ──
  Widget _buildCta(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.feedGoalsCta,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Carte avec progression ──
  Widget _buildGoals(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Objectifs les plus avancés d'abord — plus motivant.
    final sorted = List<ReadingGoal>.from(goals)
      ..sort((a, b) => _ratio(b).compareTo(_ratio(a)));
    final visible = sorted.take(_maxGoals).toList();
    final hiddenCount = goals.length - visible.length;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '🎯 ${l10n.feedGoalsCardTitle} ${DateTime.now().year}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hiddenCount > 0)
                    Text(
                      '+$hiddenCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _GoalRow(goal: visible[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static double _ratio(ReadingGoal g) {
    if (g.targetValue <= 0) return 0;
    return (g.currentValue / g.targetValue).clamp(0.0, 1.0);
  }
}

class _GoalRow extends StatelessWidget {
  final ReadingGoal goal;

  const _GoalRow({required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = GoalsProgressCard._ratio(goal);
    final done = ratio >= 1.0;
    final color = done ? const Color(0xFF4CAF50) : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(goal.goalType.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                goal.goalType.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              done
                  ? '✓ ${goal.targetValue}/${goal.targetValue}'
                  : '${goal.currentValue}/${goal.targetValue}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: done
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
