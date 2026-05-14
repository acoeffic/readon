// lib/widgets/mutual_friends_badge.dart
//
// Badge "X amis en commun" avec mini-avatars empilés. À placer sous le nom
// d'un profil dans une carte de suggestion. Rien ne s'affiche si count == 0.

import 'package:flutter/material.dart';

import '../services/mutual_friends_service.dart';
import '../theme/app_theme.dart';
import 'cached_profile_avatar.dart';

class MutualFriendsBadge extends StatelessWidget {
  final MutualFriendsSummary summary;
  final double avatarRadius;
  final double fontSize;
  final Color? textColor;

  const MutualFriendsBadge({
    super.key,
    required this.summary,
    this.avatarRadius = 9,
    this.fontSize = 11.5,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return const SizedBox.shrink();

    final color = textColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringColor = isDark ? AppColors.surfaceDark : Colors.white;

    final stackWidth = _computeStackWidth();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summary.avatars.isNotEmpty)
          SizedBox(
            width: stackWidth,
            height: avatarRadius * 2,
            child: Stack(
              children: [
                for (var i = 0; i < summary.avatars.length; i++)
                  Positioned(
                    left: i * (avatarRadius * 2 - 6),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: 1.5),
                      ),
                      child: CachedProfileAvatar(
                        imageUrl: summary.avatars[i].avatarUrl,
                        userName: summary.avatars[i].displayName,
                        radius: avatarRadius - 1.5,
                        fontSize: fontSize - 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (summary.avatars.isNotEmpty) const SizedBox(width: 6),
        Flexible(
          child: Text(
            _label(summary.count),
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  double _computeStackWidth() {
    final n = summary.avatars.length;
    if (n == 0) return 0;
    final overlap = avatarRadius * 2 - 6;
    return overlap * (n - 1) + avatarRadius * 2;
  }

  String _label(int count) {
    if (count == 1) return '1 ami en commun';
    return '$count amis en commun';
  }
}
