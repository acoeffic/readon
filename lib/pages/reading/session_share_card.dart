import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/reading_session.dart';
import '../../features/wrapped/share/share_format.dart';

/// Share card for a reading session, rendered off-screen and captured as an image.
class SessionShareCard extends StatelessWidget {
  final ReadingSession session;
  final String bookTitle;
  final String? bookAuthor;
  final Uint8List? coverBytes;
  final int? totalPages;
  final int streak;
  final ShareFormat format;
  final String? readingForLabel;

  const SessionShareCard({
    super.key,
    required this.session,
    required this.bookTitle,
    this.bookAuthor,
    this.coverBytes,
    this.totalPages,
    this.streak = 0,
    required this.format,
    this.readingForLabel,
  });

  @override
  Widget build(BuildContext context) {
    return switch (format) {
      ShareFormat.story => _StoryCard(
          session: session,
          bookTitle: bookTitle,
          bookAuthor: bookAuthor,
          coverBytes: coverBytes,
          totalPages: totalPages,
          streak: streak,
          readingForLabel: readingForLabel,
        ),
      ShareFormat.square => _SquareCard(
          session: session,
          bookTitle: bookTitle,
          bookAuthor: bookAuthor,
          coverBytes: coverBytes,
          totalPages: totalPages,
          streak: streak,
          readingForLabel: readingForLabel,
        ),
    };
  }
}

// ==========================================================================
// Shared constants & helpers
// ==========================================================================

const _bgColor = Color(0xFFF5F0E8); // Warm beige
const _textDark = Color(0xFF2D2D2D);
const _textMuted = Color(0xFF9B9585);
const _accent = Color(0xFF5B7B6D); // Muted green/teal

String _formatDuration(int minutes) {
  if (minutes < 60) return '$minutes';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}h${m > 0 ? '${m.toString().padLeft(2, '0')}' : ''}';
}


// ==========================================================================
// Book cover placeholder (when no coverUrl)
// ==========================================================================

class _BookCoverPlaceholder extends StatelessWidget {
  final String title;
  final String? author;
  final double width;
  final double height;

  const _BookCoverPlaceholder({
    required this.title,
    this.author,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF3A4A5C),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.libreBaskerville(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (author != null) ...[
              const SizedBox(height: 6),
              Text(
                author!,
                style: GoogleFonts.libreBaskerville(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFA8B8C8),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// STORY CARD (9:16) – 360 x 640 logical, captured at 3x → 1080 x 1920
// ==========================================================================

class _StoryCard extends StatelessWidget {
  final ReadingSession session;
  final String bookTitle;
  final String? bookAuthor;
  final Uint8List? coverBytes;
  final int? totalPages;
  final int streak;
  final String? readingForLabel;

  const _StoryCard({
    required this.session,
    required this.bookTitle,
    this.bookAuthor,
    this.coverBytes,
    this.totalPages,
    this.streak = 0,
    this.readingForLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // ── Book cover (hero) ──
              _buildCover(140, 210),
              const SizedBox(height: 28),

              // ── Book title ──
              Text(
                bookTitle,
                style: GoogleFonts.libreBaskerville(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (bookAuthor != null) ...[
                const SizedBox(height: 6),
                Text(
                  bookAuthor!,
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: _textMuted,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (readingForLabel != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '\u{1F4D6} $readingForLabel',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _accent,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // ── Stats: pages + duration on one line ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${session.pagesRead} pages',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '·',
                      style: TextStyle(
                        fontSize: 18,
                        color: _textMuted,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatDuration(session.durationMinutes)} min',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // ── Footer ──
              _LexDayFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(double width, double height) {
    if (coverBytes != null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            coverBytes!,
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return _BookCoverPlaceholder(
      title: bookTitle,
      author: bookAuthor,
      width: width,
      height: height,
    );
  }
}

// ==========================================================================
// SQUARE CARD (1:1) – 360 x 360 logical, captured at 3x → 1080 x 1080
// ==========================================================================

class _SquareCard extends StatelessWidget {
  final ReadingSession session;
  final String bookTitle;
  final String? bookAuthor;
  final Uint8List? coverBytes;
  final int? totalPages;
  final int streak;
  final String? readingForLabel;

  const _SquareCard({
    required this.session,
    required this.bookTitle,
    this.bookAuthor,
    this.coverBytes,
    this.totalPages,
    this.streak = 0,
    this.readingForLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 360,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // ── Cover ──
              _buildCover(100, 150),
              const SizedBox(width: 20),
              // ── Text content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      bookTitle,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bookAuthor != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        bookAuthor!,
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: _textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (readingForLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '\u{1F4D6} $readingForLabel',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: _accent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // ── Stats ──
                    Text(
                      '${session.pagesRead} pages · ${_formatDuration(session.durationMinutes)} min',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _accent,
                      ),
                    ),
                    const Spacer(),
                    // ── Footer ──
                    _LexDayFooter(compact: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(double width, double height) {
    if (coverBytes != null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            coverBytes!,
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return _BookCoverPlaceholder(
      title: bookTitle,
      author: bookAuthor,
      width: width,
      height: height,
    );
  }
}

// ==========================================================================
// Sub-widgets
// ==========================================================================

class _LexDayFooter extends StatelessWidget {
  final bool compact;
  const _LexDayFooter({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.bookmark,
          size: compact ? 18 : 22,
          color: _accent,
        ),
        const SizedBox(height: 4),
        Text(
          'LexDay',
          style: GoogleFonts.libreBaskerville(
            fontSize: compact ? 16 : 20,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'YOUR READING LIFE, TRACKED',
          style: GoogleFonts.jetBrainsMono(
            fontSize: compact ? 7 : 8,
            letterSpacing: 2,
            color: _textMuted,
          ),
        ),
      ],
    );
  }
}
