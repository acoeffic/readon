import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/book.dart';
import '../../models/reading_sheet.dart';

/// Share card for a reading sheet, rendered off-screen and captured as an image.
///
/// Story format only (360x640 logical, captured at 3x → 1080×1920).
class ReadingSheetShareCard extends StatelessWidget {
  final Book book;
  final ReadingSheet readingSheet;

  const ReadingSheetShareCard({
    super.key,
    required this.book,
    required this.readingSheet,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.4,
            colors: [Color(0xFF2A1E10), Color(0xFF1A1408)],
          ),
          border: Border.all(color: const Color(0xFFD4A855).withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A855).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD4A855).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'FICHE DE LECTURE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD4A855),
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Book title
              Text(
                book.title,
                style: GoogleFonts.libreBaskerville(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (book.author != null) ...[
                const SizedBox(height: 6),
                Text(
                  book.author!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 24),

              // Divider
              Container(
                height: 1,
                color: const Color(0xFFD4A855).withValues(alpha: 0.2),
              ),
              const SizedBox(height: 20),

              // Themes as chips
              if (readingSheet.themes.isNotEmpty) ...[
                Text(
                  'THÈMES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD4A855).withValues(alpha: 0.7),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: readingSheet.themes.take(3).map((theme) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A855).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFD4A855).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        theme.title,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD4A855),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // First quote
              if (readingSheet.quotes.isNotEmpty) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.format_quote,
                        color: const Color(0xFFD4A855).withValues(alpha: 0.4),
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          readingSheet.quotes.first.text,
                          style: GoogleFonts.libreBaskerville(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (readingSheet.quotes.first.page != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '— p. ${readingSheet.quotes.first.page}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else
                const Spacer(),

              // Footer
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: const Color(0xFFD4A855).withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${readingSheet.annotationCount} annotations analysées',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  Text(
                    'lexday.app',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD4A855).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
