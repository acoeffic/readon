import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../yearly_wrapped_data.dart';
import '../yearly_animations.dart';

/// Slide 5 — Top 5 books ranked by reading time.
class SlideTopBooks extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideTopBooks({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'Tes livres les plus lus',
            style: GoogleFonts.libreBaskerville(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(data.topBooks.length.clamp(0, 5), (i) {
          final book = data.topBooks[i];
          final isFirst = i == 0;
          return FadeUp(
            delay: Duration(milliseconds: 200 + i * 120),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: i < data.topBooks.length - 1
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
                  // Rank
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: isFirst ? 34 : 18,
                        fontWeight: FontWeight.w700,
                        color: isFirst
                            ? YearlyColors.gold
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Book info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: GoogleFonts.libreBaskerville(
                            fontSize: isFirst ? 17 : 15,
                            fontWeight:
                                isFirst ? FontWeight.w700 : FontWeight.w400,
                            color: isFirst ? YearlyColors.gold : Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          book.author,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Time
                  Text(
                    book.formattedTime,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      color: isFirst
                          ? YearlyColors.gold
                          : Colors.white.withValues(alpha: 0.4),
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
