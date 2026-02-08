import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../yearly_wrapped_data.dart';
import '../yearly_animations.dart';

/// Slide 8 — Evolution: year-over-year comparison.
class SlideEvolution extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideEvolution({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (!data.hasPreviousYear) return _buildFirstYear();
    return _buildComparison();
  }

  Widget _buildFirstYear() {
    return FadeUp(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('\uD83C\uDF1F', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [YearlyColors.cream, YearlyColors.gold],
            ).createShader(bounds),
            child: Text(
              'Ta premiere annee\nsur ReadOn !',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreBaskerville(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'L\'annee prochaine, tu pourras\ncomparer ta progression.',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.35),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparison() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'Ton evolution',
            style: GoogleFonts.libreBaskerville(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Side-by-side year comparison
        FadeUp(
          delay: const Duration(milliseconds: 200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous year
              Column(
                children: [
                  Text(
                    '${data.year - 1}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.3),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.formattedPreviousYearTime,
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '\u2192',
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 24,
                    color: YearlyColors.gold,
                  ),
                ),
              ),
              // Current year
              Column(
                children: [
                  Text(
                    '${data.year}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: YearlyColors.gold.withValues(alpha: 0.7),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [YearlyColors.cream, YearlyColors.gold],
                    ).createShader(bounds),
                    child: Text(
                      data.formattedTotalTime,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Big evolution percentage
        FadeUp(
          delay: const Duration(milliseconds: 400),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                colors: [
                  YearlyColors.gold.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: YearlyColors.gold.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '${data.evolutionPercent >= 0 ? '+' : ''}${data.evolutionPercent}%',
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: data.evolutionPercent >= 0
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'de temps de lecture par rapport a ${data.year - 1}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3-column breakdown
        FadeUp(
          delay: const Duration(milliseconds: 600),
          child: Row(
            children: [
              _EvoCell(
                label: 'Livres',
                from: '${data.previousYearBooks}',
                to: '${data.booksFinished}',
                change:
                    '${data.evolutionBooksPercent >= 0 ? '+' : ''}${data.evolutionBooksPercent}%',
                isPositive: data.evolutionBooksPercent >= 0,
              ),
              const SizedBox(width: 10),
              _EvoCell(
                label: 'Sessions',
                from: '${data.previousYearSessions}',
                to: '${data.totalSessions}',
                change:
                    '${data.evolutionSessionsPercent >= 0 ? '+' : ''}${data.evolutionSessionsPercent}%',
                isPositive: data.evolutionSessionsPercent >= 0,
              ),
              const SizedBox(width: 10),
              _EvoCell(
                label: 'Flow max',
                from: '${data.previousYearFlow}j',
                to: '${data.bestFlow}j',
                change:
                    '${data.evolutionFlowPercent >= 0 ? '+' : ''}${data.evolutionFlowPercent}%',
                isPositive: data.evolutionFlowPercent >= 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EvoCell extends StatelessWidget {
  final String label;
  final String from;
  final String to;
  final String change;
  final bool isPositive;

  const _EvoCell({
    required this.label,
    required this.from,
    required this.to,
    required this.change,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              change,
              style: GoogleFonts.libreBaskerville(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isPositive
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$from \u2192 $to',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
