import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';

/// Share card for a finished book, rendered off-screen and captured as an image.
///
/// Story format only (360x640 logical, captured at 3x → 1080×1920).
class BookFinishedShareCard extends StatelessWidget {
  final Book book;
  final BookReadingStats stats;
  final Uint8List? coverBytes;

  const BookFinishedShareCard({
    super.key,
    required this.book,
    required this.stats,
    this.coverBytes,
  });

  @override
  Widget build(BuildContext context) {
    return _StoryCard(book: book, stats: stats, coverBytes: coverBytes);
  }
}

// ==========================================================================
// Constants
// ==========================================================================

const _bgColor = Color(0xFFF5F0E8); // Warm beige
const _cardColor = Colors.white;
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
// STORY CARD (9:16) – 360 x 640 logical, captured at 3x → 1080 x 1920
// ==========================================================================

class _StoryCard extends StatelessWidget {
  final Book book;
  final BookReadingStats stats;
  final Uint8List? coverBytes;

  const _StoryCard({
    required this.book,
    required this.stats,
    this.coverBytes,
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            children: [
              // ── Book cover ──
              const SizedBox(height: 8),
              _buildCover(),
              const SizedBox(height: 24),

              // ── Title ──
              Text(
                'Livre terminé !',
                style: GoogleFonts.libreBaskerville(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 16),

              // ── Book info card ──
              _BookInfoCard(book: book),
              const SizedBox(height: 12),

              // ── Stats card ──
              _StatsCard(stats: stats),

              const Spacer(),

              // ── Footer ──
              _LexDayFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    const width = 110.0;
    const height = 160.0;

    if (coverBytes != null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
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
      title: book.title,
      author: book.author,
      width: width,
      height: height,
    );
  }
}

// ==========================================================================
// Sub-widgets
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

class _BookInfoCard extends StatelessWidget {
  final Book book;

  const _BookInfoCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            style: GoogleFonts.libreBaskerville(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (book.author != null) ...[
            const SizedBox(height: 3),
            Text(
              book.author!,
              style: GoogleFonts.libreBaskerville(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: _textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (book.pageCount != null) ...[
            const SizedBox(height: 10),
            // Full progress bar (book is finished = 100%)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${book.pageCount} pages',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
                const Spacer(),
                Text(
                  '100 %',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final BookReadingStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Total pages
          Expanded(
            child: _StatColumn(
              emoji: '\uD83D\uDCC4',
              value: '${stats.totalPagesRead}',
              unit: '',
              label: 'pages lues',
            ),
          ),
          // Total time
          Expanded(
            child: _StatColumn(
              emoji: '\u23F1\uFE0F',
              value: _formatDuration(stats.totalMinutesRead),
              unit: stats.totalMinutesRead < 60 ? ' min' : '',
              label: 'de lecture',
            ),
          ),
          // Sessions
          Expanded(
            child: _StatColumn(
              emoji: '\uD83D\uDCD6',
              value: '${stats.sessionsCount}',
              unit: '',
              label: 'sessions',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String emoji;
  final String value;
  final String unit;
  final String label;

  const _StatColumn({
    required this.emoji,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: GoogleFonts.libreBaskerville(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              TextSpan(
                text: unit,
                style: GoogleFonts.libreBaskerville(
                  fontSize: 13,
                  color: _textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: _textMuted,
          ),
        ),
      ],
    );
  }
}

class _LexDayFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.bookmark,
          size: 22,
          color: _accent,
        ),
        const SizedBox(height: 4),
        Text(
          'LexDay',
          style: GoogleFonts.libreBaskerville(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'YOUR READING LIFE, TRACKED',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8,
            letterSpacing: 2,
            color: _textMuted,
          ),
        ),
      ],
    );
  }
}
