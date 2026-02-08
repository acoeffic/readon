import 'package:flutter/material.dart';
import '../../monthly_wrapped_data.dart';
import '../fade_up_animation.dart';

/// Slide 2 – Daily heatmap + highlight stats (flow, longest session, etc.).
class CalendarSlide extends StatelessWidget {
  final MonthlyWrappedData data;
  final MonthTheme theme;

  const CalendarSlide({super.key, required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeUp(
            child: Text(
              'CALENDRIER',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.35),
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Heatmap grid
          _HeatmapRow(data: data.dailyMinutes, accent: theme.accent),

          const SizedBox(height: 16),

          // Legend
          FadeUp(
            delay: const Duration(milliseconds: 500),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: Colors.white.withValues(alpha: 0.06), label: '0 min'),
                const SizedBox(width: 16),
                _LegendItem(color: theme.accent.withValues(alpha: 0.27), label: '<30'),
                const SizedBox(width: 16),
                _LegendItem(color: theme.accent.withValues(alpha: 0.6), label: '30-60'),
                const SizedBox(width: 16),
                _LegendItem(color: theme.accent, label: '60+'),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Stat cards grid
          _HighlightGrid(data: data, theme: theme),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Heatmap row
// ---------------------------------------------------------------------------

class _HeatmapRow extends StatelessWidget {
  final List<int> data;
  final Color accent;

  const _HeatmapRow({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      alignment: WrapAlignment.center,
      children: List.generate(data.length, (i) {
        final v = data[i];
        final Color bg;
        if (v == 0) {
          bg = Colors.white.withValues(alpha: 0.06);
        } else if (v <= 30) {
          bg = accent.withValues(alpha: 0.27);
        } else if (v <= 60) {
          bg = accent.withValues(alpha: 0.6);
        } else {
          bg = accent;
        }

        return FadeUp(
          delay: Duration(milliseconds: i * 20),
          duration: const Duration(milliseconds: 300),
          child: Tooltip(
            message: 'Jour ${i + 1}: $v min',
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Legend item
// ---------------------------------------------------------------------------

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2x2 highlight cards
// ---------------------------------------------------------------------------

class _HighlightGrid extends StatelessWidget {
  final MonthlyWrappedData data;
  final MonthTheme theme;

  const _HighlightGrid({required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _HCard(emoji: '\uD83D\uDD25', value: '${data.longestFlow}j', label: 'MEILLEUR FLOW'),
      _HCard(emoji: '\u26A1', value: data.formattedLongestSession, label: 'PLUS LONGUE SESSION'),
      _HCard(emoji: '\uD83D\uDCC5', value: data.bestDayName, label: 'MEILLEUR JOUR'),
      _HCard(emoji: '\uD83D\uDCCA', value: '${data.currentFlow}j', label: 'FLOW ACTUEL'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: List.generate(cards.length, (i) {
        final c = cards[i];
        return FadeUp(
          delay: Duration(milliseconds: 600 + i * 100),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(c.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  c.value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.3),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _HCard {
  final String emoji;
  final String value;
  final String label;

  const _HCard({required this.emoji, required this.value, required this.label});
}
