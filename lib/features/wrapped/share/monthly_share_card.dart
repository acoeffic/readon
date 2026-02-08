import 'dart:math';
import 'package:flutter/material.dart';
import '../monthly/monthly_wrapped_data.dart';
import 'share_format.dart';

/// Share card for the Monthly Wrapped, adapting to [MonthTheme] colors.
///
/// All widgets are static (no animations) for screenshot capture.
class MonthlyWrappedShareCard extends StatelessWidget {
  final MonthlyWrappedData data;
  final ShareFormat format;

  const MonthlyWrappedShareCard({
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

/// Deterministic starfield using the month theme accent color.
class _StarfieldPainter extends CustomPainter {
  final int seed;
  final Color color;
  final int count;

  _StarfieldPainter({
    required this.seed,
    required this.color,
    this.count = 25,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = 0.6 + rng.nextDouble() * 1.0;
      final opacity = 0.1 + rng.nextDouble() * 0.25;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) =>
      old.seed != seed || old.color != color;
}

/// Thin accent-colored gradient line separator.
class _AccentLine extends StatelessWidget {
  final double width;
  final Color color;
  const _AccentLine({this.width = 50, required this.color});

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
              color.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// STORY CARD (9:16) – 360 x 640 logical, captured at 3x → 1080 x 1920
// ==========================================================================

class _StoryCard extends StatelessWidget {
  final MonthlyWrappedData data;
  const _StoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = data.theme;
    final accent = theme.accent;
    final seed = data.month * 1000 + data.year;

    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.2,
            colors: [theme.gradientColors.last, theme.gradientColors.first],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Stars
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarfieldPainter(
                    seed: seed,
                    color: accent,
                    count: 30,
                  ),
                ),
              ),
              // Glow at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 180,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1),
                      radius: 1.0,
                      colors: [
                        accent.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 36),
                child: Column(
                  children: [
                    // Header
                    Text(
                      'READON WRAPPED',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 5,
                        color: accent.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      theme.emoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.monthName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      '${data.year}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AccentLine(width: 50, color: accent),
                    const SizedBox(height: 24),

                    // Stats 2x2
                    _StatsGrid(data: data, accent: accent),
                    const SizedBox(height: 16),

                    // Top book
                    if (data.topBook != null)
                      _TopBookCard(
                        title: data.topBook!.title,
                        author: data.topBook!.author,
                        time: data.topBook!.formattedTime,
                        accent: accent,
                      ),

                    // vs last month
                    if (data.vsLastMonthPercent != 0) ...[
                      const SizedBox(height: 14),
                      _VsLastMonth(data: data, accent: accent),
                    ],

                    const Spacer(),

                    // Footer
                    _AccentLine(width: 30, color: accent),
                    const SizedBox(height: 12),
                    Text(
                      'READON',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                        color: accent.withValues(alpha: 0.25),
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
  final MonthlyWrappedData data;
  const _SquareCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = data.theme;
    final accent = theme.accent;
    final seed = data.month * 1000 + data.year;

    return SizedBox(
      width: 360,
      height: 360,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.4,
            colors: [theme.gradientColors.last, theme.gradientColors.first],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarfieldPainter(
                    seed: seed,
                    color: accent,
                    count: 20,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1),
                      radius: 1.0,
                      colors: [
                        accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WRAPPED',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 4,
                                  color: accent.withValues(alpha: 0.4),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    theme.emoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    data.monthName,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${data.year}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 4 stats in a row
                    _HorizontalStats(data: data, accent: accent),
                    const SizedBox(height: 14),

                    // Book + flow row
                    Expanded(
                      child: Row(
                        children: [
                          if (data.topBook != null)
                            Expanded(
                              flex: 3,
                              child: _SquareBookCard(
                                title: data.topBook!.title,
                                author: data.topBook!.author,
                                accent: accent,
                              ),
                            ),
                          if (data.topBook != null)
                            const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _FlowCard(
                              flow: data.longestFlow,
                              accent: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Footer
                    Container(
                      padding: const EdgeInsets.only(top: 10),
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
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 4,
                            color: accent.withValues(alpha: 0.25),
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
}

// ==========================================================================
// Sub-widgets
// ==========================================================================

class _StatsGrid extends StatelessWidget {
  final MonthlyWrappedData data;
  final Color accent;
  const _StatsGrid({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('\u23F1\uFE0F', data.formattedTotalTime, 'Lecture'),
      ('\uD83D\uDCDA', '${data.booksFinished}', 'Livres'),
      ('\uD83D\uDD25', '${data.longestFlow}j', 'Flow'),
      ('\uD83C\uDFAF', '${data.sessions}', 'Sessions'),
    ];

    return Column(
      children: [
        Row(children: [
          Expanded(child: _StatCell(item: items[0], accent: accent)),
          const SizedBox(width: 10),
          Expanded(child: _StatCell(item: items[1], accent: accent)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StatCell(item: items[2], accent: accent)),
          const SizedBox(width: 10),
          Expanded(child: _StatCell(item: items[3], accent: accent)),
        ]),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final (String, String, String) item;
  final Color accent;
  const _StatCell({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(item.$1, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            item.$2,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.$3.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 8,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBookCard extends StatelessWidget {
  final String title;
  final String author;
  final String time;
  final Color accent;
  const _TopBookCard({
    required this.title,
    required this.author,
    required this.time,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.06), Colors.transparent],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Text('\uD83D\uDCD6', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVRE DU MOIS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$author \u2022 $time',
                  style: TextStyle(
                    fontFamily: 'Inter',
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

class _VsLastMonth extends StatelessWidget {
  final MonthlyWrappedData data;
  final Color accent;
  const _VsLastMonth({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isUp = data.vsLastMonthPercent > 0;
    final arrow = isUp ? '\u2191' : '\u2193';
    final pct = data.vsLastMonthPercent.abs();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$arrow $pct%',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isUp ? accent : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'vs ${data.previousMonthName.toLowerCase()}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalStats extends StatelessWidget {
  final MonthlyWrappedData data;
  final Color accent;
  const _HorizontalStats({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('\u23F1\uFE0F', data.formattedTotalTime, 'Lecture'),
      ('\uD83D\uDCDA', '${data.booksFinished}', 'Livres'),
      ('\uD83D\uDD25', '${data.longestFlow}j', 'Flow'),
      ('\uD83C\uDFAF', '${data.sessions}', 'Sessions'),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  item.$2,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.$3.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
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

class _SquareBookCard extends StatelessWidget {
  final String title;
  final String author;
  final Color accent;
  const _SquareBookCard({
    required this.title,
    required this.author,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.06), Colors.transparent],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'LIVRE DU MOIS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 7,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('\uD83D\uDCD6', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      author,
                      style: TextStyle(
                        fontFamily: 'Inter',
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

class _FlowCard extends StatelessWidget {
  final int flow;
  final Color accent;
  const _FlowCard({required this.flow, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${flow}j',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'MEILLEUR\nFLOW',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 8,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
