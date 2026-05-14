import 'package:flutter/material.dart';
import '../../../models/reading_statistics.dart';
import '../../../theme/app_theme.dart';

const _genreColors = [
  Color(0xFF6B988D), // sage
  Color(0xFFC97C5D), // terracotta
  Color(0xFF9B6B8E), // mauve
  Color(0xFFC6A85A), // gold
  Color(0xFF7C6F5C), // taupe
  Color(0xFF5F8090), // slate blue
];

class GenreDistributionChart extends StatelessWidget {
  final List<GenreStatData> data;
  final bool showHeader;
  final bool embedded;

  const GenreDistributionChart({
    super.key,
    required this.data,
    this.showHeader = true,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      final empty = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.l),
          child: Text(
            'Pas encore de données',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ),
      );
      if (embedded) return empty;
      return Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Text(
                'Répartition des genres',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpace.l),
            ],
            empty,
          ],
        ),
      );
    }

    final totalBooks = data.fold<int>(
      0,
      (sum, g) => sum + (g.totalMinutes > 0 ? 1 : 0),
    );

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Donut chart
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutPainter(
              data: data,
              colors: _genreColors,
              ringWidth: 18,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$totalBooks',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    totalBooks > 1 ? 'GENRES' : 'GENRE',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.l),
        // Legend with bars
        Expanded(
          child: Column(
            children: data.asMap().entries.map((e) {
              final color = _genreColors[e.key % _genreColors.length];
              final pct = e.value.percentage.round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: AppSpace.s),
                        Expanded(
                          child: Text(
                            e.value.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 4,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );

    if (embedded) return body;

    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(
              'Répartition des genres',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpace.l),
          ],
          body,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<GenreStatData> data;
  final List<Color> colors;
  final double ringWidth;

  _DonutPainter({
    required this.data,
    required this.colors,
    required this.ringWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - ringWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -3.14159265 / 2;
    final total = data.fold<double>(0, (s, g) => s + g.percentage);
    if (total <= 0) return;

    for (var i = 0; i < data.length; i++) {
      final sweep = (data[i].percentage / total) * 2 * 3.14159265;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.ringWidth != ringWidth;
}
