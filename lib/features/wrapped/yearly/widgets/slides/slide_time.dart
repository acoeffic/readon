import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../yearly_wrapped_data.dart';
import '../yearly_animations.dart';
import '../common/gold_line.dart';

/// Slide 1 — Dramatic stat: typewriter + animated counter + humanized time.
class SlideTime extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideTime({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Typewriter(
          text: 'Cette annee, tu as passe...',
          delay: const Duration(milliseconds: 200),
          style: GoogleFonts.libreBaskerville(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Colors.white.withValues(alpha: 0.4),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),
        FadeUp(
          delay: const Duration(milliseconds: 1800),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [YearlyColors.cream, YearlyColors.gold],
            ).createShader(bounds),
            child: AnimatedCounter(
              value: data.totalHours,
              delay: const Duration(milliseconds: 2000),
              duration: const Duration(milliseconds: 2000),
              style: GoogleFonts.libreBaskerville(
                fontSize: 96,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 0.85,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FadeUp(
          delay: const Duration(milliseconds: 2200),
          child: Text(
            'heures a lire',
            style: GoogleFonts.libreBaskerville(
              fontSize: 22,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        const GoldLine(delay: Duration(milliseconds: 2400)),
        FadeUp(
          delay: const Duration(milliseconds: 2600),
          child: Text(
            data.totalTimeHumanized,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
      ],
    );
  }
}
