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
                                ? const FirstBookBadge(size: 56)
                                : isApprenticeReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const ApprenticeReaderBadge(size: 56)
                                : isOneHourMagicBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OneHourMagicBadge(size: 56)
                                : isSundayReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const SundayReaderBadge(size: 56)
                                : isPassionateBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const PassionateBadge(size: 56)
                                : isCenturionBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const CenturionBadge(size: 56)
                                : isMarathonBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const MarathonBadge(size: 56)
                                : isHalfMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const HalfMillenniumBadge(size: 56)
                                : isMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const MillenniumBadge(size: 56)
                                : isClubFounderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const ClubFounderBadge(size: 56)
                                : isClubLeaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const ClubLeaderBadge(size: 56)
                                : isResidentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const ResidentBadge(size: 56)
                                : isHabitueBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const HabitueBadge(size: 56)
                                : isPilierBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const PilierBadge(size: 56)
                                : isMonumentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const MonumentBadge(size: 56)
                                : isAnnualOnePerMonthBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const AnnualOnePerMonthBadge(size: 56)
                                : isAnnualTwoPerMonthBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const AnnualTwoPerMonthBadge(size: 56)
                                : isAnnualOnePerWeekBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const AnnualOnePerWeekBadge(size: 56)
                                : isAnnualCentenaireBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const AnnualCentenaireBadge(size: 56)
                                : isOccasionBastilleDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionBastilleDayBadge(size: 56)
                                : isOccasionChristmasBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionChristmasBadge(size: 56)
                                : isOccasionFeteMusiqueBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionFeteMusiqueBadge(size: 56)
                                : isOccasionHalloweenBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionHalloweenBadge(size: 56)
                                : isOccasionSummerReadBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionSummerReadBadge(size: 56)
                                : isOccasionValentineBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionValentineBadge(size: 56)
                                : isOccasionNyeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionNyeBadge(size: 56)
                                : isOccasionLabourDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionLabourDayBadge(size: 56)
                                : isOccasionWorldBookDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionWorldBookDayBadge(size: 56)
                                : isOccasionNewYearBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionNewYearBadge(size: 56)
                                : isOccasionEasterBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionEasterBadge(size: 56)
                                : isOccasionAprilFoolsBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const OccasionAprilFoolsBadge(size: 56)
                                : isGenreSfInitieBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const GenreSfInitieBadge(size: 56)
                                : isGenrePolarApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const GenrePolarApprentiBadge(size: 56)
                                : isGenrePolarAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const GenrePolarAdepteBadge(size: 56)
                                : isGenrePolarMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const GenrePolarMaitreBadge(size: 56)
                                : isGenrePolarLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const GenrePolarLegendeBadge(size: 56)
                                : isGenreSfApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const GenreSfApprentiBadge(size: 56)
                                : isGenreSfAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const GenreSfAdepteBadge(size: 56)
                                : isGenreSfMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const GenreSfMaitreBadge(size: 56)
                                : isGenreSfLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                                ? const GenreSfLegendeBadge(size: 56)
                                : Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        badge.icon,
                                        style: const TextStyle(fontSize: 28),
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
