// pages/feed/widgets/community_section_separator.dart
// Separateur visuel "Decouvre la communaute" pour le feed mixte

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CommunitySectionSeparator extends StatelessWidget {
  const CommunitySectionSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.l),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Découvre la communauté',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Divider(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
