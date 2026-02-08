import 'package:flutter/material.dart';
import '../../monthly_wrapped_data.dart';
import '../fade_up_animation.dart';

/// Slide 1 – Key numbers: total time, sessions, books finished.
class StatsSlide extends StatelessWidget {
  final MonthlyWrappedData data;
  final MonthTheme theme;

  const StatsSlide({super.key, required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatRow(
        value: data.formattedTotalTime,
        label: 'de lecture',
        sub: data.vsLastMonthPercent >= 0
            ? '+${data.vsLastMonthPercent}% vs ${data.previousMonthName.toLowerCase()}'
            : '${data.vsLastMonthPercent}% vs ${data.previousMonthName.toLowerCase()}',
        isPositive: data.vsLastMonthPercent > 0,
      ),
      _StatRow(
        value: '${data.sessions}',
        label: 'sessions',
        sub: '${data.avgSessionMinutes} min en moyenne',
        isPositive: false,
      ),
      _StatRow(
        value: '${data.booksFinished}',
        label: 'livres termines',
        sub: '${data.booksInProgress} en cours',
        isPositive: false,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'RESUME',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.35),
              letterSpacing: 4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(items.length, (i) {
          final item = items[i];
          return FadeUp(
            delay: Duration(milliseconds: 150 + i * 120),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: i < items.length - 1
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    )
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      item.value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: theme.accent,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.sub,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: item.isPositive
                                ? const Color(0xFF4ADE80)
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StatRow {
  final String value;
  final String label;
  final String sub;
  final bool isPositive;

  const _StatRow({
    required this.value,
    required this.label,
    required this.sub,
    required this.isPositive,
  });
}
