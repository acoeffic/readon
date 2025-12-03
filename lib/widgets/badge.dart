// widgets/badge.dart
// Widget Badge extrait depuis le fichier monolithique

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BadgeWidget extends StatelessWidget {
  final Color color;
  final String label;

  const BadgeWidget({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}