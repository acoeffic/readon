import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/badges_service.dart';
import '../../../theme/app_theme.dart';
import '../../profile/all_badges_page.dart';
import '../../../features/badges/widgets/first_book_badge_painter.dart';

class BadgeOverviewCard extends StatelessWidget {
  final int unlocked;
  final int total;
  final List<UserBadge> recentBadges;

  const BadgeOverviewCard({
    super.key,
    required this.unlocked,
    required this.total,
    required this.recentBadges,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? unlocked / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tes badges',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AllBadgesPage()),
                ),
                child: Text(
                  'Voir tout \u2192',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.m),

          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(70, 70),
                      painter: _BadgeProgressPainter(
                        progress: progress,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.shade200,
                        progressColor: AppColors.primary,
                      ),
                    ),
                    Text(
                      '$unlocked/$total',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpace.l),

              // Recent badges
              Expanded(
                child: recentBadges.isEmpty
                    ? Text(
                        'Aucun badge débloqué',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      )
                    : Row(
                        children: recentBadges.map((badge) {
                          final badgeColor = _parseColor(badge.color);
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpace.s),
                            child: isFirstBookBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const FirstBookBadge(size: 44)
                                : isApprenticeReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const ApprenticeReaderBadge(size: 44)
                                : isOneHourMagicBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OneHourMagicBadge(size: 44)
                                : isSundayReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const SundayReaderBadge(size: 44)
                                : isPassionateBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const PassionateBadge(size: 44)
                                : isCenturionBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const CenturionBadge(size: 44)
                                : isMarathonBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const MarathonBadge(size: 44)
                                : isHalfMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const HalfMillenniumBadge(size: 44)
                                : isMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const MillenniumBadge(size: 44)
                                : isClubFounderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const ClubFounderBadge(size: 44)
                                : isClubLeaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const ClubLeaderBadge(size: 44)
                                : isResidentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const ResidentBadge(size: 44)
                                : isHabitueBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const HabitueBadge(size: 44)
                                : isPilierBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const PilierBadge(size: 44)
                                : isMonumentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const MonumentBadge(size: 44)
                                : Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        badge.icon,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

class _BadgeProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _BadgeProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 6.0;
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
