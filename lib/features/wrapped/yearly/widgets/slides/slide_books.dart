import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../yearly_wrapped_data.dart';
import '../yearly_animations.dart';
import '../common/gold_line.dart';
import '../common/month_bar.dart';

/// Slide 2 — Books finished: big number + horizontal bars per month.
class SlideBooks extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideBooks({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxCount = data.booksPerMonth
        .map((e) => e.count)
        .fold(1, (a, b) => a > b ? a : b);
    // Scale hours for visual bar (count * ~6h avg for display)
    final maxHours = maxCount * 6;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'Tu as termine',
            style: GoogleFonts.libreBaskerville(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeUp(
          delay: const Duration(milliseconds: 200),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [YearlyColors.cream, YearlyColors.gold],
            ).createShader(bounds),
            child: AnimatedCounter(
              value: data.booksFinished,
              delay: const Duration(milliseconds: 400),
              style: GoogleFonts.libreBaskerville(
                fontSize: 96,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 0.85,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        FadeUp(
          delay: const Duration(milliseconds: 400),
          child: Text(
            'livres',
            style: GoogleFonts.libreBaskerville(
              fontSize: 24,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        const GoldLine(delay: Duration(milliseconds: 500)),
        const SizedBox(height: 4),
        ...List.generate(data.booksPerMonth.length.clamp(0, 12), (i) {
          final m = data.booksPerMonth[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: MonthBar(
              month: m.label,
              value: m.count * 6,
              maxValue: maxHours,
              animationDelay: Duration(milliseconds: 600 + i * 40),
            ),
          );
        }),
      ],
    );
  }
}
