import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/badges_service.dart';
import '../../features/badges/widgets/first_book_badge_painter.dart';
import '../../features/wrapped/share/share_format.dart';

/// Share card for a badge unlock, rendered off-screen and captured as an image.
class BadgeShareCard extends StatelessWidget {
  final UserBadge badge;
  final ShareFormat format;

  const BadgeShareCard({
    super.key,
    required this.badge,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return switch (format) {
      ShareFormat.story => _StoryCard(badge: badge),
      ShareFormat.square => _SquareCard(badge: badge),
    };
  }
}

// ==========================================================================
// Constants
// ==========================================================================

const _dark = Color(0xFF0A1628);
const _gold = Color(0xFFD4A855);

String _formatDate() {
  final now = DateTime.now();
  const months = [
    'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
  ];
  return '${now.day} ${months[now.month - 1]} ${now.year}';
}

Color _badgeColor(UserBadge badge) {
  try {
    final colorStr = badge.color.replaceAll('#', '');
    return Color(int.parse('FF$colorStr', radix: 16));
  } catch (_) {
    return Colors.amber;
  }
}

// ==========================================================================
// Badge icon builder (static, no animations — safe for screenshot)
// ==========================================================================

Widget _buildBadgeIcon(UserBadge badge, {required double size}) {
  if (isFirstBookBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return FirstBookBadge(size: size);
  }
  if (isApprenticeReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return ApprenticeReaderBadge(size: size);
  }
  if (isConfirmedReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return ConfirmedReaderBadge(size: size);
  }
  if (isBibliophileBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return BibliophileBadge(size: size);
  }
  if (isOneHourMagicBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OneHourMagicBadge(size: size);
  }
  if (isSundayReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return SundayReaderBadge(size: size);
  }
  if (isPassionateBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return PassionateBadge(size: size);
  }
  if (isCenturionBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return CenturionBadge(size: size);
  }
  if (isMarathonBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return MarathonBadge(size: size);
  }
  if (isHalfMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return HalfMillenniumBadge(size: size);
  }
  if (isMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return MillenniumBadge(size: size);
  }
  if (isClubFounderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return ClubFounderBadge(size: size);
  }
  if (isClubLeaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return ClubLeaderBadge(size: size);
  }
  if (isResidentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return ResidentBadge(size: size);
  }
  if (isHabitueBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return HabitueBadge(size: size);
  }
  if (isPilierBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return PilierBadge(size: size);
  }
  if (isMonumentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return MonumentBadge(size: size);
  }
  if (isAnnualOnePerMonthBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return AnnualOnePerMonthBadge(size: size);
  }
  if (isAnnualTwoPerMonthBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return AnnualTwoPerMonthBadge(size: size);
  }
  if (isAnnualOnePerWeekBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return AnnualOnePerWeekBadge(size: size);
  }
  if (isAnnualCentenaireBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return AnnualCentenaireBadge(size: size);
  }
  if (isOccasionBastilleDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionBastilleDayBadge(size: size);
  }
  if (isOccasionChristmasBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionChristmasBadge(size: size);
  }
  if (isOccasionFeteMusiqueBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionFeteMusiqueBadge(size: size);
  }
  if (isOccasionHalloweenBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionHalloweenBadge(size: size);
  }
  if (isOccasionSummerReadBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionSummerReadBadge(size: size);
  }
  if (isOccasionValentineBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionValentineBadge(size: size);
  }
  if (isOccasionNyeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionNyeBadge(size: size);
  }
  if (isOccasionLabourDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionLabourDayBadge(size: size);
  }

  if (isOccasionWorldBookDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionWorldBookDayBadge(size: size);
  }

  if (isOccasionNewYearBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionNewYearBadge(size: size);
  }

  if (isOccasionEasterBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionEasterBadge(size: size);
  }

  if (isOccasionAprilFoolsBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return OccasionAprilFoolsBadge(size: size);
  }

  if (isGenreSfInitieBadge(id: badge.id, category: badge.category, requirement: badge.requirement)) {
    return GenreSfInitieBadge(size: size);
  }

  // Fallback: emoji in a circle
  final color = _badgeColor(badge);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.2),
      border: Border.all(color: color, width: 4),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 20,
          spreadRadius: 5,
        ),
      ],
    ),
    child: Center(
      child: Text(
        badge.icon,
        style: TextStyle(fontSize: size * 0.5),
      ),
    ),
  );
}

// ==========================================================================
// STORY CARD (9:16) – 360 x 640 logical, captured at 3x → 1080 x 1920
// ==========================================================================

class _StoryCard extends StatelessWidget {
  final UserBadge badge;
  const _StoryCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final seed = badge.id.hashCode;
    final color = _badgeColor(badge);

    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.4,
            colors: [const Color(0xFF152040), _dark],
          ),
          border: Border.all(color: _gold.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Dots background
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotsPainter(seed: seed, count: 40),
                ),
              ),
              // Glow at top
              Positioned(
                top: 0, left: 0, right: 0, height: 240,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1),
                      radius: 1.0,
                      colors: [
                        color.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    // Header
                    _Header(),
                    const SizedBox(height: 24),

                    // Label
                    _UnlockedLabel(),
                    const SizedBox(height: 40),

                    // Badge icon
                    _buildBadgeIcon(badge, size: 140),
                    const SizedBox(height: 32),

                    // Badge name
                    Text(
                      badge.name,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (badge.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        badge.description,
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: _gold.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const Spacer(),

                    // Footer
                    Text(
                      'Suis ma lecture sur lexday.app',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// SQUARE CARD (1:1) – 360 x 360 logical, captured at 3x → 1080 x 1080
// ==========================================================================

class _SquareCard extends StatelessWidget {
  final UserBadge badge;
  const _SquareCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final seed = badge.id.hashCode;
    final color = _badgeColor(badge);

    return SizedBox(
      width: 360,
      height: 360,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.2,
            colors: [const Color(0xFF152040), _dark],
          ),
          border: Border.all(color: _gold.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotsPainter(seed: seed, count: 25),
                ),
              ),
              Positioned(
                top: 0, left: 0, right: 0, height: 160,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1),
                      radius: 1.0,
                      colors: [
                        color.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    // Header compact
                    Row(
                      children: [
                        _UnlockedLabel(),
                        const Spacer(),
                        Text(
                          'LEXSTA',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: _gold.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Badge icon + info
                    _buildBadgeIcon(badge, size: 110),
                    const SizedBox(height: 16),
                    Text(
                      badge.name,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (badge.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        badge.description,
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: _gold.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const Spacer(),
                    Text(
                      'Suis ma lecture sur lexday.app',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// Sub-widgets
// ==========================================================================

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4A855), Color(0xFFB8923A)],
            ),
          ),
          child: Center(
            child: Text(
              'L',
              style: GoogleFonts.libreBaskerville(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'LEXSTA',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: _gold,
          ),
        ),
        const Spacer(),
        Text(
          _formatDate(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class _UnlockedLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFFFD700),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.emoji_events, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(
          'BADGE DÉBLOQUÉ',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: const Color(0xFFFFD700),
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// Background painter
// ==========================================================================

class _DotsPainter extends CustomPainter {
  final int seed;
  final int count;

  _DotsPainter({required this.seed, this.count = 30});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = 0.6 + rng.nextDouble() * 1.0;
      final opacity = 0.08 + rng.nextDouble() * 0.15;
      final paint = Paint()
        ..color = _gold.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) =>
      old.seed != seed || old.count != count;
}
