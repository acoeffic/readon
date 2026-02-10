import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../yearly_wrapped_data.dart';
import '../yearly_animations.dart';

/// Slide 7 — Social: "Top X%" badge + ranking rows.
class SlideSocial extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideSocial({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'Parmi la communaute Lexsta',
            style: GoogleFonts.libreBaskerville(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Big Top X% card
        FadeUp(
          delay: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  YearlyColors.gold.withValues(alpha: 0.08),
                  YearlyColors.gold.withValues(alpha: 0.03),
                ],
              ),
              border: Border.all(
                color: YearlyColors.gold.withValues(alpha: 0.12),
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [YearlyColors.cream, YearlyColors.gold],
                  ).createShader(bounds),
                  child: Text(
                    'Top ${data.percentileRank}%',
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 0.9,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'des lecteurs les plus assidus',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Ranking rows
        ..._buildRankingRows(),
      ],
    );
  }

  List<Widget> _buildRankingRows() {
    final rows = [
      _RankRow(
          emoji: '\u23F1\uFE0F',
          metric: 'Temps de lecture',
          rank: 'Top ${data.percentileRank}%',
          delay: const Duration(milliseconds: 500)),
      _RankRow(
          emoji: '\uD83D\uDCD6',
          metric: 'Livres termines',
          rank: 'Top ${(data.percentileRank * 1.8).round().clamp(1, 99)}%',
          delay: const Duration(milliseconds: 620)),
      _RankRow(
          emoji: '\uD83D\uDD25',
          metric: 'Flow le plus long',
          rank: 'Top ${(data.percentileRank * 2.7).round().clamp(1, 99)}%',
          delay: const Duration(milliseconds: 740)),
      _RankRow(
          emoji: '\uD83C\uDF19',
          metric: 'Sessions de nuit',
          rank: 'Top ${(data.percentileRank * 0.4).round().clamp(1, 99)}%',
          delay: const Duration(milliseconds: 860)),
    ];
    return rows;
  }
}

class _RankRow extends StatelessWidget {
  final String emoji;
  final String metric;
  final String rank;
  final Duration delay;

  const _RankRow({
    required this.emoji,
    required this.metric,
    required this.rank,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: delay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                metric,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
            Text(
              rank,
              style: GoogleFonts.libreBaskerville(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: YearlyColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
