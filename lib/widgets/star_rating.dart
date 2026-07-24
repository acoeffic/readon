// lib/widgets/star_rating.dart
//
// Widget d'étoiles réutilisable (0.5 à 5.0 par pas de 0.5).
// Interactif si onChanged est fourni (tap + drag), sinon affichage seul.

import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double>? onChanged;
  final double size;
  final Color color;
  final double spacing;

  const StarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 32,
    this.color = Colors.amber,
    this.spacing = 4,
  });

  double get _totalWidth => size * 5 + spacing * 4;

  void _handlePosition(double dx) {
    if (onChanged == null) return;
    final clamped = dx.clamp(0.0, _totalWidth);
    // Valeur continue 0..5 puis arrondi au 0.5 supérieur, minimum 0.5
    final raw = clamped / _totalWidth * 5;
    var value = (raw * 2).ceil() / 2;
    if (value < 0.5) value = 0.5;
    if (value > 5.0) value = 5.0;
    onChanged!(value);
  }

  Widget _buildStar(int index) {
    final position = index + 1; // 1..5
    final IconData icon;
    if (rating >= position) {
      icon = Icons.star_rounded;
    } else if (rating >= position - 0.5) {
      icon = Icons.star_half_rounded;
    } else {
      icon = Icons.star_border_rounded;
    }
    return Icon(icon, size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          _buildStar(i),
        ],
      ],
    );

    if (onChanged == null) return row;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _handlePosition(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => _handlePosition(d.localPosition.dx),
      child: row,
    );
  }
}
