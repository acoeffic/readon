// lib/widgets/badges_grid.dart
// Widget pour afficher la grille de badges

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/badges_service.dart';
import '../features/badges/widgets/first_book_badge_painter.dart';

class BadgesGrid extends StatelessWidget {
  final List<UserBadge> badges;
  final VoidCallback? onViewAll;
  final String? title;

  const BadgesGrid({
    super.key,
    required this.badges,
    this.onViewAll,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Afficher seulement les 3 derniers badges débloqués
    final displayBadges = badges.where((b) => b.isUnlocked).take(3).toList();

    // Si pas assez de badges débloqués, compléter avec les prochains à débloquer
    if (displayBadges.length < 3) {
      final locked = badges.where((b) => !b.isUnlocked).take(3 - displayBadges.length);
      displayBadges.addAll(locked);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title ?? 'Mes badges',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22),
            ),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                child: const Text('Voir tout →'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: displayBadges.map((badge) => BadgeItem(badge: badge)).toList(),
        ),
      ],
    );
  }
}

class BadgeItem extends StatelessWidget {
  final UserBadge badge;

  const BadgeItem({super.key, required this.badge});

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  bool get _isAnniversaryHidden => badge.category == 'anniversary' && !badge.isUnlocked;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(badge.color);

    return GestureDetector(
      onTap: () {
        _showBadgeDetails(context);
      },
      child: Column(
        children: [
          ClipOval(
            child: ImageFiltered(
              imageFilter: _isAnniversaryHidden
                  ? ImageFilter.blur(sigmaX: 6, sigmaY: 6)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: isFirstBookBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                  ? FirstBookBadge(size: 80, isLocked: !badge.isUnlocked)
                  : isApprenticeReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                  ? ApprenticeReaderBadge(size: 80, isLocked: !badge.isUnlocked)
                  : Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: badge.isUnlocked ? color.withValues(alpha:0.2) : Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: badge.isUnlocked ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badge.icon,
                          style: TextStyle(
                            fontSize: 36,
                            color: badge.isUnlocked ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          ImageFiltered(
            imageFilter: _isAnniversaryHidden
                ? ImageFilter.blur(sigmaX: 4, sigmaY: 4)
                : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: SizedBox(
              width: 100,
              child: Text(
                badge.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badge.isUnlocked ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (!badge.isUnlocked) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 80,
              child: LinearProgressIndicator(
                value: badge.progressPercentage,
                backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              badge.progressText,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showBadgeDetails(BuildContext context) {
    final color = _hexToColor(badge.color);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: ImageFiltered(
                imageFilter: _isAnniversaryHidden
                    ? ImageFilter.blur(sigmaX: 8, sigmaY: 8)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: isFirstBookBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? FirstBookBadge(size: 100, isLocked: !badge.isUnlocked)
                    : isApprenticeReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ApprenticeReaderBadge(size: 100, isLocked: !badge.isUnlocked)
                    : Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: badge.isUnlocked ? color.withValues(alpha:0.2) : Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: badge.isUnlocked ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            badge.icon,
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            ImageFiltered(
              imageFilter: _isAnniversaryHidden
                  ? ImageFilter.blur(sigmaX: 5, sigmaY: 5)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Text(
                badge.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            ImageFiltered(
              imageFilter: _isAnniversaryHidden
                  ? ImageFilter.blur(sigmaX: 4, sigmaY: 4)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Text(
                badge.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (badge.isUnlocked) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.green.shade900.withValues(alpha: 0.3)
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Débloqué',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Le ${_formatDate(badge.unlockedAt!)}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.shade900.withValues(alpha: 0.3)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Progression',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: badge.progressPercentage,
                      backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge.progressText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin', 'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}