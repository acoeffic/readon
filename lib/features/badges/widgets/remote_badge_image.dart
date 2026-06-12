// lib/features/badges/widgets/remote_badge_image.dart
//
// Widget générique pour afficher l'image WebP d'un badge depuis les assets
// locaux (`assets/badges/<id>.webp`). Si le badge est verrouillé, un filtre
// greyscale + opacité réduite est appliqué. En cas de PNG manquant,
// fallback sur l'emoji du badge entouré d'un cercle thématique.

import 'package:flutter/material.dart';

import 'package:lexday/models/user_search_result.dart';
import 'package:lexday/features/badges/services/badges_service.dart';

class RemoteBadgeImage extends StatelessWidget {
  final String badgeId;
  final String? badgeCategory;
  final bool isUnlocked;
  final String? fallbackEmoji;
  final String? fallbackColorHex;
  final double size;

  const RemoteBadgeImage({
    super.key,
    required this.badgeId,
    this.badgeCategory,
    this.isUnlocked = true,
    this.fallbackEmoji,
    this.fallbackColorHex,
    this.size = 100,
  });

  RemoteBadgeImage.fromBadge(
    UserBadge badge, {
    super.key,
    this.size = 100,
  })  : badgeId = badge.id,
        badgeCategory = badge.category,
        isUnlocked = badge.isUnlocked,
        fallbackEmoji = badge.icon,
        fallbackColorHex = badge.color;

  RemoteBadgeImage.fromSimple(
    UserBadgeSimple badge, {
    super.key,
    this.size = 100,
  })  : badgeId = badge.id,
        badgeCategory = null,
        isUnlocked = true,
        fallbackEmoji = badge.icon,
        fallbackColorHex = badge.color;

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      'assets/badges/$badgeId.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _emojiFallback(context),
    );

    if (!isUnlocked) {
      image = ColorFiltered(
        colorFilter: _greyscale,
        child: Opacity(opacity: 0.45, child: image),
      );
    }

    return SizedBox(width: size, height: size, child: image);
  }

  Widget _emojiFallback(BuildContext context) {
    final color = _hexToColor(fallbackColorHex);
    final emoji = fallbackEmoji ?? '🏅';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isUnlocked
            ? color.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: isUnlocked
              ? color
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: size * 0.44,
            color: isUnlocked
                ? null
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  static Color _hexToColor(String? hex) {
    if (hex == null) return Colors.grey;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return Colors.grey;
  }
}
