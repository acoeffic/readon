import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../yearly_wrapped_data.dart';
import '../yearly_animations.dart';
import '../common/gold_line.dart';

/// Slide 0 — Opening: "Lexsta présente" + year in gradient + "ANNÉE COMPLÈTE".
class SlideOpening extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideOpening({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'LEXSTA PRESENTE',
            style: GoogleFonts.libreBaskerville(
              fontSize: 12,
              color: YearlyColors.gold.withValues(alpha: 0.5),
              letterSpacing: 8,
            ),
          ),
        ),
        const SizedBox(height: 32),
        FadeUp(
          delay: const Duration(milliseconds: 300),
          child: Text(
            'Ton annee de lecture',
            style: GoogleFonts.libreBaskerville(
              fontSize: 17,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FadeUp(
          delay: const Duration(milliseconds: 500),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [YearlyColors.cream, YearlyColors.gold],
            ).createShader(bounds),
            child: Text(
              '${data.year}',
              style: GoogleFonts.libreBaskerville(
                fontSize: 96,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 0.9,
              ),
            ),
          ),
        ),
        const GoldLine(width: 100, delay: Duration(milliseconds: 700)),
        FadeUp(
          delay: const Duration(milliseconds: 900),
          child: Text(
            'ANNEE COMPLETE',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.2),
              letterSpacing: 4,
            ),
          ),
        ),
      ],
    );
  }
}
