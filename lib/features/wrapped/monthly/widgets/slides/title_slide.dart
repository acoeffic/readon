import 'package:flutter/material.dart';
import '../../monthly_wrapped_data.dart';
import '../fade_up_animation.dart';

/// Slide 0 – Month title with emoji, month name and year.
class TitleSlide extends StatelessWidget {
  final MonthlyWrappedData data;
  final MonthTheme theme;

  const TitleSlide({super.key, required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            theme.emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 4),
          Text(
            'TON MOIS',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.monthName,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.year}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: theme.accent,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
