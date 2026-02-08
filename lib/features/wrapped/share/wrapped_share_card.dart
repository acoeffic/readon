import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../yearly/yearly_wrapped_data.dart';
import '../yearly/widgets/yearly_animations.dart';
import 'share_format.dart';

/// The share card rendered off-screen and captured as an image.
///
/// All widgets are static (no animations) so the screenshot captures
/// a fully-rendered frame at [pixelRatio] 3.0.
class WrappedShareCard extends StatelessWidget {
  final YearlyWrappedData data;
  final ShareFormat format;

  const WrappedShareCard({
    super.key,
    required this.data,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return switch (format) {
      ShareFormat.story => _StoryCard(data: data),
      ShareFormat.square => _SquareCard(data: data),
    };
  }
}

// ==========================================================================
// Shared helpers
// ==========================================================================

const _gold = YearlyColors.gold;
const _cream = YearlyColors.cream;
const _wine = YearlyColors.bordeaux;
const _deep = YearlyColors.deepBg;

/// A thin horizontal gold gradient line used as a separator.
class _GoldLine extends StatelessWidget {
  final double width;
  const _GoldLine({this.width = 60});

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
              _gold.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// Deterministic starfield painted via [CustomPainter].
///
/// Uses a seed so each user always sees the same star pattern,
/// and screenshots are reproducible.
class _StarfieldPainter extends CustomPainter {
  final int seed;
  final int count;

  _StarfieldPainter({required this.seed, this.count = 35});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = 0.8 + rng.nextDouble() * 1.2;
      final opacity = 0.15 + rng.nextDouble() * 0.35;
      final paint = Paint()
        ..color = _gold.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) =>
      old.seed != seed || old.count != count;
}

/// Text with a vertical gold gradient (cream → gold) fill.
class _GoldGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _GoldGradientText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_cream, _gold],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

// ==========================================================================
// STORY CARD (9:16) – 360 x 640 logical, captured at 3x → 1080 x 1920
// ==========================================================================

class _StoryCard extends StatelessWidget {
  final YearlyWrappedData data;
  const _StoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data.userName ?? 'Lecteur';
    final seed = name.hashCode;
    final topBook =
        data.topBooks.isNotEmpty ? data.topBooks.first : null;

    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [const Color(0xFF1A1428), _deep],
          ),
          border: Border.all(color: _gold.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.04),
              blurRadius: 60,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Starfield
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarfieldPainter(seed: seed, count: 40),
                ),
              ),
              // Wine glow at top
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
                        _wine.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Column(
                  children: [
                    // ── Header ──
                    Text(
                      'READON WRAPPED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 5,
                        color: _gold.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GoldGradientText(
                      text: '${data.year}',
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _GoldLine(width: 60),
                    const SizedBox(height: 20),

                    // ── Name + badge ──
                    Text(
                      name,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ReaderBadge(
                      icon: data.readerEmoji,
                      label: data.readerType,
                    ),
                    const SizedBox(height: 22),

                    // ── Stats 2x2 grid ──
                    _StatsGrid(data: data),
                    const SizedBox(height: 16),

                    // ── Top book ──
                    if (topBook != null)
                      _TopBookCard(
                        title: topBook.title,
                        author: topBook.author,
                      ),

                    const Spacer(),

                    // ── Footer ──
                    const _GoldLine(width: 30),
                    const SizedBox(height: 14),
                    Text(
                      'READON',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 3,
                        color: _gold.withValues(alpha: 0.25),
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
  final YearlyWrappedData data;
  const _SquareCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data.userName ?? 'Lecteur';
    final seed = name.hashCode;
    final topBook =
        data.topBooks.isNotEmpty ? data.topBooks.first : null;

    return SizedBox(
      width: 360,
      height: 360,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.4,
            colors: [const Color(0xFF1A1428), _deep],
          ),
          border: Border.all(color: _gold.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.04),
              blurRadius: 60,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Starfield
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarfieldPainter(seed: seed, count: 25),
                ),
              ),
              // Wine glow at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1),
                      radius: 1.0,
                      colors: [
                        _wine.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // ── Header row: year left, name right ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WRAPPED',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8,
                                  letterSpacing: 4,
                                  color: _gold.withValues(alpha: 0.35),
                                ),
                              ),
                              _GoldGradientText(
                                text: '${data.year}',
                                style: GoogleFonts.libreBaskerville(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.libreBaskerville(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  data.readerEmoji,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _shortBadge(data.readerType),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    color: _gold.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── 4 stats in a row ──
                    _HorizontalStats(data: data),
                    const SizedBox(height: 14),

                    // ── Book + sessions row ──
                    Expanded(
                      child: Row(
                        children: [
                          // Book of the year
                          if (topBook != null)
                            Expanded(
                              flex: 3,
                              child: _SquareBookCard(
                                title: topBook.title,
                                author: topBook.author,
                              ),
                            ),
                          if (topBook != null) const SizedBox(width: 10),
                          // Sessions count
                          Expanded(
                            flex: 2,
                            child: _SessionsCard(
                              sessions: data.totalSessions,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Footer ──
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'READON \u2014 STRAVA FOR BOOKS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8,
                            letterSpacing: 4,
                            color: _gold.withValues(alpha: 0.22),
                          ),
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

  /// Shorten badge name for the compact square layout.
  static String _shortBadge(String badge) {
    // "Night Owl Reader" → "Night Owl"
    final words = badge.split(' ');
    if (words.length > 2) return words.sublist(0, 2).join(' ');
    return badge;
  }
}

// ==========================================================================
// Shared sub-widgets
// ==========================================================================

/// Reader badge pill (e.g. 🌙 Night Owl Reader).
class _ReaderBadge extends StatelessWidget {
  final String icon;
  final String label;
  const _ReaderBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: LinearGradient(
          colors: [
            _wine.withValues(alpha: 0.22),
            _gold.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2x2 stats grid used in the Story card.
class _StatsGrid extends StatelessWidget {
  final YearlyWrappedData data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(emoji: '\u23F1\uFE0F', value: '${data.totalHours}h', label: 'Lecture'),
      _StatItem(emoji: '\uD83D\uDCDA', value: '${data.booksFinished}', label: 'Livres'),
      _StatItem(emoji: '\uD83D\uDD25', value: '${data.bestFlow}j', label: 'Flow'),
      _StatItem(emoji: '\uD83C\uDFC6', value: 'Top ${data.percentileRank}%', label: 'Classement'),
    ];

    return Column(
      children: [
        Row(children: [
          Expanded(child: items[0]),
          const SizedBox(width: 10),
          Expanded(child: items[1]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: items[2]),
          const SizedBox(width: 10),
          Expanded(child: items[3]),
        ]),
      ],
    );
  }
}

/// A single stat cell with emoji, value and label.
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          _GoldGradientText(
            text: value,
            style: GoogleFonts.libreBaskerville(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top book card used in the Story layout.
class _TopBookCard extends StatelessWidget {
  final String title;
  final String author;
  const _TopBookCard({required this.title, required this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            _gold.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          const Text('\uD83D\uDCD6', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LIVRE DE L'ANNEE",
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 7,
                    letterSpacing: 2,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _gold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  author,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal 4-stat row used in the Square card.
class _HorizontalStats extends StatelessWidget {
  final YearlyWrappedData data;
  const _HorizontalStats({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('\u23F1\uFE0F', '${data.totalHours}h', 'Lecture'),
      ('\uD83D\uDCDA', '${data.booksFinished}', 'Livres'),
      ('\uD83D\uDD25', '${data.bestFlow}j', 'Flow'),
      ('\uD83C\uDFC6', 'Top ${data.percentileRank}%', 'Top'),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _gold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.$3.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 7,
                    letterSpacing: 1,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Book of the year card for the Square layout.
class _SquareBookCard extends StatelessWidget {
  final String title;
  final String author;
  const _SquareBookCard({required this.title, required this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _gold.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "LIVRE DE L'ANNEE",
            style: GoogleFonts.jetBrainsMono(
              fontSize: 7,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('\uD83D\uDCD6', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _gold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      author,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sessions count card for the Square layout.
class _SessionsCard extends StatelessWidget {
  final int sessions;
  const _SessionsCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatNumber(sessions),
            style: GoogleFonts.libreBaskerville(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SESSIONS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(int n) {
    if (n < 1000) return '$n';
    final k = n ~/ 1000;
    final r = (n % 1000) ~/ 100;
    if (r == 0) return '${k}k';
    return '$k\u202F${(n % 1000).toString().padLeft(3, '0')}';
  }
}
