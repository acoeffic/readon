import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

  const SessionShareCard({
    super.key,
    required this.session,
    required this.bookTitle,
    this.bookAuthor,
    this.coverBytes,
    this.totalPages,
    this.streak = 0,
    required this.format,
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
        ),
      ShareFormat.square => _SquareCard(
          session: session,
          bookTitle: bookTitle,
          bookAuthor: bookAuthor,
          coverBytes: coverBytes,
          totalPages: totalPages,
          streak: streak,
        ),
    };
  }
}

// ==========================================================================
// Shared constants & helpers
// ==========================================================================

const _bgColor = Color(0xFFF5F0E8); // Warm beige
const _cardColor = Colors.white;
const _textDark = Color(0xFF2D2D2D);
const _textMuted = Color(0xFF9B9585);
const _accent = Color(0xFF5B7B6D); // Muted green/teal
const _accentLight = Color(0xFFD4E0DA);

String _formatDuration(int minutes) {
  if (minutes < 60) return '$minutes';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}h${m > 0 ? '${m.toString().padLeft(2, '0')}' : ''}';
}

String _formatDate(DateTime date) {
  final formatter = DateFormat("d MMM yyyy · HH:mm", 'fr_FR');
  return formatter.format(date);
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

  const _StoryCard({
    required this.session,
    required this.bookTitle,
    this.bookAuthor,
    this.coverBytes,
    this.totalPages,
    this.streak = 0,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercent = totalPages != null && totalPages! > 0
        ? ((session.endPage ?? 0) / totalPages! * 100).round()
        : null;

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
              _buildCover(100, 150),
              const SizedBox(height: 24),

              // ── Title ──
              Text(
                'Session terminée !',
                style: GoogleFonts.libreBaskerville(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(session.endTime ?? session.startTime),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 24),

              // ── Book info card ──
              _BookInfoCard(
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                session: session,
                progressPercent: progressPercent,
              ),
              const SizedBox(height: 12),

              // ── Stats card ──
              _StatsCard(session: session, streak: streak),

              const Spacer(),

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

  const _SquareCard({
    required this.session,
    required this.bookTitle,
    this.bookAuthor,
    this.coverBytes,
    this.totalPages,
    this.streak = 0,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercent = totalPages != null && totalPages! > 0
        ? ((session.endPage ?? 0) / totalPages! * 100).round()
        : null;

    return SizedBox(
      width: 360,
      height: 360,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Header row: cover + title ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCover(60, 90),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Session terminée !',
                          style: GoogleFonts.libreBaskerville(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bookTitle,
                          style: GoogleFonts.libreBaskerville(
                            fontSize: 12,
                            color: _textDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (bookAuthor != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            bookAuthor!,
                            style: GoogleFonts.libreBaskerville(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: _textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Progress bar ──
              _ProgressSection(
                session: session,
                progressPercent: progressPercent,
              ),
              const SizedBox(height: 12),

              // ── Stats ──
              _StatsCard(session: session, streak: streak),

              const Spacer(),

              // ── Footer ──
              _LexDayFooter(compact: true),
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
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
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

class _BookInfoCard extends StatelessWidget {
  final String bookTitle;
  final String? bookAuthor;
  final ReadingSession session;
  final int? progressPercent;

  const _BookInfoCard({
    required this.bookTitle,
    this.bookAuthor,
    required this.session,
    this.progressPercent,
  });

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
            bookTitle,
            style: GoogleFonts.libreBaskerville(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (bookAuthor != null) ...[
            const SizedBox(height: 3),
            Text(
              bookAuthor!,
              style: GoogleFonts.libreBaskerville(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: _textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),

          // Progress bar
          _ProgressSection(
            session: session,
            progressPercent: progressPercent,
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final ReadingSession session;
  final int? progressPercent;

  const _ProgressSection({
    required this.session,
    this.progressPercent,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = progressPercent != null ? progressPercent! / 100.0 : 0.0;

    return Column(
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _accentLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Page range + percentage
        Row(
          children: [
            Text(
              'p. ${session.startPage} \u2192 ${session.endPage ?? session.startPage}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ),
            const Spacer(),
            if (progressPercent != null)
              Text(
                '$progressPercent %',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: _textMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final ReadingSession session;
  final int streak;

  const _StatsCard({required this.session, required this.streak});

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
          // Duration
          Expanded(
            child: _StatColumn(
              emoji: '\u23F1\uFE0F',
              value: _formatDuration(session.durationMinutes),
              unit: session.durationMinutes < 60 ? ' min' : '',
              label: 'durée',
            ),
          ),
          // Pages
          Expanded(
            child: _StatColumn(
              emoji: '\uD83D\uDCC4',
              value: '${session.pagesRead}',
              unit: '',
              label: 'pages lues',
            ),
          ),
          // Streak
          if (streak > 0)
            Expanded(
              child: _StatColumn(
                emoji: '\uD83D\uDD25',
                value: '$streak',
                unit: ' j.',
                label: 'série',
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
