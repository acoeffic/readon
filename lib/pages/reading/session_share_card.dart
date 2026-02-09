import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/reading_session.dart';
import '../../features/wrapped/share/share_format.dart';
import '../../theme/app_theme.dart';

/// Share card for a reading session, rendered off-screen and captured as an image.
///
/// All widgets are static (no animations) so the screenshot captures
/// a fully-rendered frame at [pixelRatio] 3.0.
class SessionShareCard extends StatelessWidget {
  final ReadingSession session;
  final String bookTitle;
  final String? bookAuthor;
  final ShareFormat format;

  const SessionShareCard({
    super.key,
    required this.session,
    required this.bookTitle,
    this.bookAuthor,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return switch (format) {
      ShareFormat.story => _StoryCard(
          session: session,
          bookTitle: bookTitle,
          bookAuthor: bookAuthor,
        ),
      ShareFormat.square => _SquareCard(
          session: session,
          bookTitle: bookTitle,
          bookAuthor: bookAuthor,
        ),
    };
  }
}

// ==========================================================================
// Shared helpers
// ==========================================================================

const _accent = AppColors.primary;
const _dark = Color(0xFF0A1F1A);

String _formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}h${m > 0 ? ' ${m}min' : ''}';
}

String _formatPace(ReadingSession session) {
  if (session.pagesRead == 0 || session.durationMinutes == 0) return '-';
  final ppm = session.pagesRead / session.durationMinutes;
  if (ppm >= 1) return '${ppm.toStringAsFixed(1)} p/min';
  final mpp = session.durationMinutes / session.pagesRead;
  return '${mpp.toStringAsFixed(1)} min/p';
}

class _AccentLine extends StatelessWidget {
  final double width;
  const _AccentLine({this.width = 60});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              _accent.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

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
      final opacity = 0.1 + rng.nextDouble() * 0.25;
      final paint = Paint()
        ..color = _accent.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) =>
      old.seed != seed || old.count != count;
}

// ==========================================================================
// STORY CARD (9:16) – 360 x 640 logical, captured at 3x → 1080 x 1920
// ==========================================================================

class _StoryCard extends StatelessWidget {
  final ReadingSession session;
  final String bookTitle;
  final String? bookAuthor;
  const _StoryCard({
    required this.session,
    required this.bookTitle,
    this.bookAuthor,
  });

  @override
  Widget build(BuildContext context) {
    final seed = bookTitle.hashCode;

    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [const Color(0xFF0F2A22), _dark],
          ),
          border: Border.all(color: _accent.withValues(alpha: 0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotsPainter(seed: seed, count: 35),
                ),
              ),
              // Glow at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 200,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1),
                      radius: 1.0,
                      colors: [
                        _accent.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  children: [
                    // ── Header ──
                    Text(
                      'SESSION DE LECTURE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 5,
                        color: _accent.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Book icon
                    Text(
                      '\uD83D\uDCDA',
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 10),
                    const _AccentLine(width: 60),
                    const SizedBox(height: 14),

                    // ── Book title ──
                    Text(
                      bookTitle,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bookAuthor != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        bookAuthor!,
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ── Stats 2x2 grid ──
                    _StatsGrid(session: session),
                    const SizedBox(height: 16),

                    // ── Progression ──
                    _ProgressionBar(session: session),

                    const Spacer(),

                    // ── Footer ──
                    const _AccentLine(width: 30),
                    const SizedBox(height: 10),
                    Text(
                      'READON',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 3,
                        color: _accent.withValues(alpha: 0.25),
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
  final ReadingSession session;
  final String bookTitle;
  final String? bookAuthor;
  const _SquareCard({
    required this.session,
    required this.bookTitle,
    this.bookAuthor,
  });

  @override
  Widget build(BuildContext context) {
    final seed = bookTitle.hashCode;

    return SizedBox(
      width: 360,
      height: 360,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.2,
            colors: [const Color(0xFF0F2A22), _dark],
          ),
          border: Border.all(color: _accent.withValues(alpha: 0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotsPainter(seed: seed, count: 20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\uD83D\uDCDA',
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bookTitle,
                                style: GoogleFonts.libreBaskerville(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (bookAuthor != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  bookAuthor!,
                                  style: GoogleFonts.libreBaskerville(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _AccentLine(width: 40),
                    const SizedBox(height: 16),

                    // ── Horizontal stats ──
                    _HorizontalStats(session: session),

                    const Spacer(),

                    // ── Footer ──
                    Center(
                      child: Text(
                        'READON',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8,
                          letterSpacing: 3,
                          color: _accent.withValues(alpha: 0.25),
                        ),
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

class _StatsGrid extends StatelessWidget {
  final ReadingSession session;
  const _StatsGrid({required this.session});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _StatItem(
                emoji: '\uD83D\uDCD6',
                value: '${session.pagesRead}',
                label: 'pages',
              ),
              const SizedBox(height: 10),
              _StatItem(
                emoji: '\u26A1',
                value: _formatPace(session),
                label: 'rythme',
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 80,
          color: _accent.withValues(alpha: 0.08),
        ),
        Expanded(
          child: Column(
            children: [
              _StatItem(
                emoji: '\u23F1\uFE0F',
                value: _formatDuration(session.durationMinutes),
                label: 'de lecture',
              ),
              const SizedBox(height: 10),
              _StatItem(
                emoji: '\uD83D\uDCCC',
                value: 'p.${session.startPage}\u2192${session.endPage}',
                label: 'progression',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatItem({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _ProgressionBar extends StatelessWidget {
  final ReadingSession session;
  const _ProgressionBar({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Text(
            'Page ${session.startPage}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 1.0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _accent.withValues(alpha: 0.3),
                          _accent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Page ${session.endPage}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalStats extends StatelessWidget {
  final ReadingSession session;
  const _HorizontalStats({required this.session});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('\uD83D\uDCD6', '${session.pagesRead}', 'pages'),
      ('\u23F1\uFE0F', _formatDuration(session.durationMinutes), 'durée'),
      ('\u26A1', _formatPace(session), 'rythme'),
      ('\uD83D\uDCCC', '${session.startPage}\u2192${session.endPage}', 'pages'),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Column(
            children: [
              Text(item.$1, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                item.$2,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                item.$3,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
