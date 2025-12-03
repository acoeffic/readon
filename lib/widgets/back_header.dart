// widgets/back_header.dart
// Extrait depuis votre fichier monolithique

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BackHeader extends StatelessWidget {
  final String title;
  final Color? titleColor;

  const BackHeader({super.key, required this.title, this.titleColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: titleColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}