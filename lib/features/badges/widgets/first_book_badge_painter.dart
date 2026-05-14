// lib/features/badges/widgets/first_book_badge_painter.dart
//
// Ce fichier ne contient désormais plus que le widget ComebackBadge, qui
// utilise des assets SVG hébergés dans le bucket `Image/badge/Retour/`.
// Les autres badges (PNG dans `Image/badge/Nouveau/<id>.png`) sont rendus
// par `widgets/remote_badge_image.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../config/env.dart';

/// Mapping badge_id → nom de fichier SVG dans le storage.
const _comebackSvgFiles = {
  'comeback_3d': 'badge_retour_3j',
  'comeback_5d': 'badge_retour_5j',
  'comeback_1w': 'badge_retour_1s',
  'comeback_2w': 'badge_retour_2s',
  'comeback_1m': 'badge_retour_1m',
  'comeback_3m': 'badge_retour_3m',
};

/// Widget générique pour afficher un badge Comeback (Retour).
class ComebackBadge extends StatelessWidget {
  final String badgeId;
  final double size;
  final bool isLocked;
  final String? fallbackEmoji;
  final String? fallbackColorHex;

  const ComebackBadge({
    super.key,
    required this.badgeId,
    this.size = 80,
    this.isLocked = false,
    this.fallbackEmoji,
    this.fallbackColorHex,
  });

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  static Color _hexToColor(String? hex) {
    if (hex == null) return const Color(0xFF4CAF50);
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context) {
    final svgName = _comebackSvgFiles[badgeId];
    Widget badge;
    if (svgName != null) {
      badge = SvgPicture.network(
        '${Env.supabaseStorageUrl}/asset/Image/badge/Retour/$svgName.svg',
        width: size,
        height: size,
        placeholderBuilder: (_) => _emojiFallback(context),
      );
    } else {
      // Pas de mapping pour ce badgeId → on évite le 404 et on rend
      // directement l'emoji fallback.
      badge = _emojiFallback(context);
    }

    if (isLocked) {
      badge = ColorFiltered(
        colorFilter: _greyscale,
        child: Opacity(
          opacity: 0.45,
          child: badge,
        ),
      );
    }

    return badge;
  }

  Widget _emojiFallback(BuildContext context) {
    final color = _hexToColor(fallbackColorHex);
    final emoji = fallbackEmoji ?? '\u{1F44B}'; // 👋 par défaut pour comeback
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.44),
      ),
    );
  }
}
