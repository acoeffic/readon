// lib/pages/reading/reading_session_summary_page.dart

import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../models/trophy.dart';
import '../../services/books_service.dart';
import '../../services/flow_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import 'session_share_service.dart';

class ReadingSessionSummaryPage extends StatefulWidget {
  final ReadingSession session;
  final Trophy? trophy;

  const ReadingSessionSummaryPage({
    super.key,
    required this.session,
    this.trophy,
  });

  @override
  State<ReadingSessionSummaryPage> createState() =>
      _ReadingSessionSummaryPageState();
}

class _ReadingSessionSummaryPageState
    extends State<ReadingSessionSummaryPage> {
  Book? _book;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        BooksService().getBookById(int.parse(widget.session.bookId)),
        FlowService().getUserFlow(),
      ]);
      if (!mounted) return;
      setState(() {
        _book = results[0] as Book?;
        final flow = results[1] as dynamic;
        _currentStreak = flow.currentFlow as int;
      });
    } catch (_) {
      // Non-critical — page still renders with fallback data
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}min';
  }

  String _formatDateTime(DateTime date) {
    const months = [
      'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
    ];
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day} ${months[date.month - 1]} ${date.year} · $time';
  }

  int? _progressionPercent() {
    final pageCount = _book?.pageCount;
    if (pageCount == null || pageCount == 0) return null;
    final endPage = widget.session.endPage;
    if (endPage == null) return null;
    return (endPage / pageCount * 100).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildHeader(isDark),
              const SizedBox(height: 28),
              _buildMainCard(isDark),
              const SizedBox(height: 28),
              _buildShareButton(),
              const SizedBox(height: 12),
              _buildSkipButton(isDark),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header: emoji + title + date ──────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        const Text('🎉', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(
          'Session terminée !',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formatDateTime(widget.session.endTime ?? widget.session.startTime),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Main card ─────────────────────────────────────────────────────

  Widget _buildMainCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.l),
        color: isDark ? null : Colors.white,
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2332), Color(0xFF0F1923)],
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: isDark ? 24 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildBookRow(isDark),
            const SizedBox(height: 20),
            _buildProgressionSection(isDark),
            const SizedBox(height: 20),
            _buildStatsRow(isDark),
            const SizedBox(height: 20),
            Text(
              'R E A D O N',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 6,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Book row: cover + title/author ────────────────────────────────

  Widget _buildBookRow(bool isDark) {
    final bookTitle = _book?.title ?? 'Ma lecture';
    final bookAuthor = _book?.author;

    return Row(
      children: [
        // Book cover
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CachedBookCover(
            imageUrl: _book?.coverUrl,
            width: 80,
            height: 110,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 16),
        // Title + author
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bookTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (bookAuthor != null) ...[
                const SizedBox(height: 4),
                Text(
                  bookAuthor,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Progression section ───────────────────────────────────────────

  Widget _buildProgressionSection(bool isDark) {
    final session = widget.session;
    final percent = _progressionPercent();
    final pageCount = _book?.pageCount;

    return Column(
      children: [
        // Label + percentage
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progression',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            if (percent != null)
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent != null ? percent / 100 : 0.0,
            minHeight: 6,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 6),
        // Page range
        Text(
          pageCount != null
              ? 'p. ${session.startPage} → ${session.endPage} sur $pageCount'
              : 'p. ${session.startPage} → ${session.endPage}',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────

  Widget _buildStatsRow(bool isDark) {
    final session = widget.session;

    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            emoji: '⏱',
            value: _formatDuration(session.durationMinutes),
            label: 'DURÉE',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatBox(
            emoji: '📄',
            value: '${session.pagesRead} p.',
            label: 'PAGES LUES',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatBox(
            emoji: '🔥',
            value: '$_currentStreak j.',
            label: 'SÉRIE',
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required String emoji,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () {
          showSessionShareSheet(
            context: context,
            session: widget.session,
            bookTitle: _book?.title ?? 'Ma lecture',
            bookAuthor: _book?.author,
          );
        },
        icon: const Icon(Icons.share_outlined, size: 20),
        label: const Text(
          'Partager la session',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSkipButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.textPrimaryDark : Colors.black87,
          side: BorderSide(
            color: isDark
                ? AppColors.borderDark
                : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
        ),
        child: const Text(
          'Passer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
