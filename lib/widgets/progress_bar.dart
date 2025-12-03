// widgets/progress_bar.dart
// Barre de progression extraite du fichier monolithique

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final double value; // entre 0 et 1

  const ProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 8,
        backgroundColor: AppColors.accentLight.withOpacity(0.6),
        color: AppColors.primary,
      ),
    );
  }
}