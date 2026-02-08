import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../yearly_wrapped_data.dart';
import '../yearly_animations.dart';

/// Slide 4 — Habits: reader profile badge + 2x2 stats grid.
class SlideHabits extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideHabits({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'Ton profil de lecteur',
            style: GoogleFonts.libreBaskerville(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Badge card
        FadeUp(
          delay: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  YearlyColors.bordeaux.withValues(alpha: 0.2),
                  YearlyColors.gold.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: YearlyColors.gold.withValues(alpha: 0.12),
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(data.readerEmoji,
                    style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [YearlyColors.cream, YearlyColors.gold],
                  ).createShader(bounds),
                  child: Text(
                    data.readerType,
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.nightSessionsPercent}% de tes sessions apres 21h\n'
                  'Ton heure de pointe : ${data.peakHour}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2x2 stats grid
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: 'Sessions',
                value: '${data.totalSessions}',
                sub: '${data.avgSessionMinutes} min en moyenne',
                delay: const Duration(milliseconds: 500),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                label: 'Jours actifs',
                value: '${data.activeDays}',
                sub: 'sur 365',
                delay: const Duration(milliseconds: 600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: 'Meilleur flow',
                value: '${data.bestFlow}j',
                sub: data.bestFlowPeriod,
                delay: const Duration(milliseconds: 700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                label: 'Record session',
                value: data.formattedLongestSession,
                sub: data.longestSessionDateLabel,
                delay: const Duration(milliseconds: 800),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Duration delay;

  const _StatBox({
    required this.label,
    required this.value,
    required this.sub,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: delay,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.libreBaskerville(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: YearlyColors.gold.withValues(alpha: 0.7),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
