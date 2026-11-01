// lib/widgets/first_session_goal_card.dart
//
// Carte « Fixe-toi un petit objectif » de l'écran de fin de première session.
// Trois préréglages en un tap + un « Plus tard » discret. La logique
// (création de l'objectif, pré-prompt notifications, analytics) est portée par
// ReadingSessionSummaryPage ; ce widget ne fait qu'afficher et remonter les
// taps. Voir FirstSessionGoalOffer.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/first_session_goal_offer.dart';
import '../theme/app_theme.dart';

class FirstSessionGoalCard extends StatelessWidget {
  final bool isDark;

  /// Enregistrement en cours : les préréglages sont désactivés.
  final bool busy;

  /// Objectif créé : la carte affiche la confirmation à la place des choix.
  final bool saved;

  /// Préréglage tapé (en cours d'enregistrement ou enregistré).
  final FirstSessionGoalPreset? selected;

  final ValueChanged<FirstSessionGoalPreset> onPreset;
  final VoidCallback onLater;

  const FirstSessionGoalCard({
    super.key,
    required this.isDark,
    required this.busy,
    required this.saved,
    required this.selected,
    required this.onPreset,
    required this.onLater,
  });

  /// Libellé court d'un préréglage (réutilisé par le pré-prompt notifications).
  static String presetLabel(AppLocalizations l, FirstSessionGoalPreset p) {
    switch (p) {
      case FirstSessionGoalPreset.tenMinutesPerDay:
        return l.firstSessionGoalPresetMinutes;
      case FirstSessionGoalPreset.threeDaysPerWeek:
        return l.firstSessionGoalPresetDays;
      case FirstSessionGoalPreset.oneBookPerMonth:
        return l.firstSessionGoalPresetBook;
    }
  }

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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: saved
            ? _buildSaved(l, primaryText, secondary)
            : _buildChoices(context, l, primaryText, secondary),
      ),
    );
  }

  Widget _buildSaved(AppLocalizations l, Color primaryText, Color secondary) {
    final preset = selected;
    return Row(
      key: const ValueKey('saved'),
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 24, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.firstSessionGoalSaved,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
              if (preset != null) ...[
                const SizedBox(height: 2),
                Text(
                  presetLabel(l, preset),
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoices(
    BuildContext context,
    AppLocalizations l,
    Color primaryText,
    Color secondary,
  ) {
    return Column(
      key: const ValueKey('choices'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.firstSessionGoalTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.firstSessionGoalBody,
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in FirstSessionGoalPreset.values)
              _buildPresetChip(l, preset, primaryText),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: busy ? null : onLater,
            style: TextButton.styleFrom(foregroundColor: secondary),
            child: Text(
              l.firstSessionGoalLater,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(
    AppLocalizations l,
    FirstSessionGoalPreset preset,
    Color primaryText,
  ) {
    final isSelected = selected == preset;
    return InkWell(
      onTap: busy ? null : () => onPreset(preset),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.22)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              presetLabel(l, preset),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
