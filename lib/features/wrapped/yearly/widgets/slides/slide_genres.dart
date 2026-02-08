import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../yearly_wrapped_data.dart';
import '../yearly_animations.dart';

/// Slide 3 — Genres: elegant numbered list with hours and percentages.
class SlideGenres extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideGenres({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'Tes univers favoris',
            style: GoogleFonts.libreBaskerville(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 28),
        ...List.generate(data.topGenres.length.clamp(0, 5), (i) {
          final genre = data.topGenres[i];
          final isFirst = i == 0;
          return FadeUp(
            delay: Duration(milliseconds: 200 + i * 120),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: i < data.topGenres.length - 1
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    )
                  : null,
              child: Row(
                children: [
                  // Rank number
                  SizedBox(
                    width: 24,
                    child: Text(
                      '0${i + 1}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: isFirst
                            ? YearlyColors.gold
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Genre info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          genre.name,
                          style: GoogleFonts.libreBaskerville(
                            fontSize: 16,
                            fontWeight: isFirst ? FontWeight.w700 : FontWeight.w400,
                            color: isFirst ? YearlyColors.gold : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${genre.formattedHours} de lecture',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Percentage
                  Text(
                    '${genre.percentage.round()}%',
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isFirst
                          ? YearlyColors.gold
                          : Colors.white.withValues(alpha: 0.3),
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
