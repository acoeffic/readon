import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../theme/app_theme.dart';

/// Share card for a finished book, rendered off-screen and captured as an image.
///
/// Story format only (360x640 logical, captured at 3x → 1080×1920).
class BookFinishedShareCard extends StatelessWidget {
  final Book book;
  final BookReadingStats stats;
  final Uint8List? coverBytes;

  const BookFinishedShareCard({
    super.key,
    required this.book,
    required this.stats,
    this.coverBytes,
  });

  @override
  Widget build(BuildContext context) {
    return _StoryCard(book: book, stats: stats, coverBytes: coverBytes);
  }
}

// ==========================================================================
// Constants
// ==========================================================================

const _dark = Color(0xFF1A1408);
const _gold = Color(0xFFD4A855);

String _formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}h\n${m > 0 ? '${m}min' : ''}';
}

String _formatDate() {
  final now = DateTime.now();
  const months = [
    'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
  ];
  return '${now.day} ${months[now.month - 1]} ${now.year}';
}

// ==========================================================================
// STORY CARD (9:16) – 360 x 640 logical, captured at 3x → 1080 x 1920
// ==========================================================================

class _StoryCard extends StatelessWidget {
  final Book book;
  final BookReadingStats stats;
  final Uint8List? coverBytes;

  const _StoryCard({required this.book, required this.stats, this.coverBytes});

  @override
  Widget build(BuildContext context) {
    final seed = book.title.hashCode;

    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.4,
            colors: [const Color(0xFF2A1E10), _dark],
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
                top: 0,
                left: 0,
                right: 0,
                height: 220,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1),
                      radius: 1.0,
                      colors: [
                        _gold.withValues(alpha: 0.08),
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
                    // ── Header: Logo + date ──
                    _Header(),
                    const SizedBox(height: 20),

                    // ── Badge: LIVRE TERMINÉ ──
                    _CompletedBadge(),
                    const SizedBox(height: 24),

                    // ── Book cover ──
                    if (coverBytes != null)
                      _BookCover(coverBytes: coverBytes!)
                    else
                      _BookCoverPlaceholder(
                        title: book.title,
                        author: book.author,
                      ),
                    const SizedBox(height: 24),

                    // ── Book title + author ──
                    Text(
                      book.title,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.author != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        book.author!,
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: _gold.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const Spacer(),

                    // ── Stats row ──
                    _StatsRow(stats: stats),
                    const SizedBox(height: 20),

                    // ── Footer ──
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
// Sub-widgets
// ==========================================================================

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // LexDay icon placeholder
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

class _CompletedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF2ECC71),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'LIVRE TERMINÉ',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: const Color(0xFF2ECC71),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  final Uint8List coverBytes;

  const _BookCover({required this.coverBytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          coverBytes,
          width: 160,
          height: 220,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _BookCoverPlaceholder extends StatelessWidget {
  final String title;
  final String? author;

  const _BookCoverPlaceholder({required this.title, this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3A2D18),
            const Color(0xFF2A1E10),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.libreBaskerville(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (author != null) ...[
              const SizedBox(height: 12),
              // Separator line
              Container(
                width: 30,
                height: 1,
                color: _gold.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                author!.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final BookReadingStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            value: '${stats.totalPagesRead}',
            label: 'PAGES',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            value: _formatDuration(stats.totalMinutesRead),
            label: 'DE LECTURE',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            value: '${stats.sessionsCount}',
            label: 'SESSIONS',
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
