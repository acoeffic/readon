// lib/pages/reading/reading_session_summary_page.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../models/trophy.dart';
import '../../providers/subscription_provider.dart';
import '../../pages/profile/upgrade_page.dart';
import '../../services/books_service.dart';
import '../../services/flow_service.dart';
import '../../services/reading_session_service.dart';
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
  Map<String, double> _userAverages = {};

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
        ReadingSessionService().getUserReadingAverages(),
      ]);
      if (!mounted) return;
      setState(() {
        _book = results[0] as Book?;
        final flow = results[1] as dynamic;
        _currentStreak = flow.currentFlow as int;
        _userAverages = results[2] as Map<String, double>;
      });
    } catch (_) {
      // Non-critical — page still renders with fallback data
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h${mins.toString().padLeft(2, '0')}';
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
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFAF6F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              _buildAppBar(isDark),
              const SizedBox(height: 20),
              _buildHeader(isDark),
              const SizedBox(height: 24),
              _buildBookCard(isDark),
              const SizedBox(height: 16),
              _buildFreeStatsCard(isDark),
              const SizedBox(height: 20),
              _buildInsightsSection(isDark),
              const SizedBox(height: 28),
              _buildShareButton(),
              const SizedBox(height: 12),
              _buildHideButton(isDark),
              const SizedBox(height: 12),
              _buildSkipButton(isDark),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────

  Widget _buildAppBar(bool isDark) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const Spacer(),
        Text(
          'SESSION TERMINÉE',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: isDark
                ? const Color(0xFFD4A54A)
                : const Color(0xFF8B6914),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 40),
      ],
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
            fontSize: 26,
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

  // ── Book card (cover + title/author + progression) ─────────────────

  Widget _buildBookCard(bool isDark) {
    final bookTitle = _book?.title ?? 'Ma lecture';
    final bookAuthor = _book?.author;
    final session = widget.session;
    final percent = _progressionPercent();
    final pageCount = _book?.pageCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // Book row
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookTitle,
                      style: TextStyle(
                        fontSize: 18,
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
                    const SizedBox(height: 12),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (percent != null)
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          Text(
                            'p. ${session.startPage} → ${session.endPage}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        if (pageCount != null)
                          Text(
                            '$pageCount pages',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Free stats card (3 columns) ────────────────────────────────────

  Widget _buildFreeStatsCard(bool isDark) {
    final session = widget.session;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildFreeStat(
                emoji: '⏱',
                value: _formatDuration(session.durationMinutes),
                label: 'durée',
                isDark: isDark,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
            ),
            Expanded(
              child: _buildFreeStat(
                emoji: '📄',
                value: '${session.pagesRead}',
                label: 'pages lues',
                isDark: isDark,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
            ),
            Expanded(
              child: _buildFreeStat(
                emoji: '🔥',
                value: '$_currentStreak j.',
                label: 'série',
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeStat({
    required String emoji,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Insights section ─────────────────────────────────────────────

  Widget _buildInsightsSection(bool isDark) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final session = widget.session;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Compute session metrics
    final pagesPerMin = session.durationMinutes > 0
        ? session.pagesRead / session.durationMinutes
        : 0.0;
    final minPerPage = session.pagesRead > 0
        ? session.durationMinutes / session.pagesRead
        : 0.0;

    // Estimated finish date
    String? estimatedFinish;
    final pageCount = _book?.pageCount;
    final endPage = session.endPage;
    if (pageCount != null && endPage != null && pageCount > endPage) {
      final remaining = pageCount - endPage;
      final avgPagesPerDay = _userAverages['avg_pages_per_day'] ?? 0;
      if (avgPagesPerDay > 0) {
        final daysLeft = (remaining / avgPagesPerDay).ceil();
        final finishDate = DateTime.now().add(Duration(days: daysLeft));
        estimatedFinish = '${finishDate.day}/${finishDate.month}/${finishDate.year}';
      }
    }

    // vs. average
    String? vsAverage;
    final userAvgMinPerPage = _userAverages['avg_minutes_per_page'] ?? 0;
    if (userAvgMinPerPage > 0 && minPerPage > 0) {
      final diff = ((userAvgMinPerPage - minPerPage) / userAvgMinPerPage * 100).round();
      if (diff > 0) {
        vsAverage = '+$diff% plus rapide';
      } else if (diff < 0) {
        vsAverage = '${diff.abs()}% plus lent';
      } else {
        vsAverage = 'Dans ta moyenne';
      }
    }

    // Format values
    final paceValue = pagesPerMin >= 1
        ? '${pagesPerMin.toStringAsFixed(1)} p/min'
        : '${pagesPerMin.toStringAsFixed(2)} p/min';
    final timePerPageValue = minPerPage < 1
        ? '${(minPerPage * 60).round()} sec'
        : '${minPerPage.toStringAsFixed(1)} min';

    final insights = [
      _InsightRow(emoji: '\u{1F4C8}', label: 'Rythme de lecture', value: paceValue),
      _InsightRow(emoji: '\u{23F3}', label: 'Temps moyen par page', value: timePerPageValue),
      if (estimatedFinish != null)
        _InsightRow(emoji: '\u{1F4C5}', label: 'Fin estimée du livre', value: estimatedFinish),
      if (vsAverage != null)
        _InsightRow(emoji: '\u{1F4CA}', label: 'vs. ta moyenne', value: vsAverage),
    ];

    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // Header with PREMIUM badge
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A54A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Insights de la session',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Insight rows (blurred for free users)
          ...List.generate(insights.length, (i) {
            return Column(
              children: [
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                  ),
                _buildInsightRow(insights[i], isDark, isPremium),
              ],
            );
          }),
          // CTA for free users
          if (!isPremium) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpgradePage()),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9F0D9),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.l),
                    bottomRight: Radius.circular(AppRadius.l),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\u{2728} Voir le bilan complet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.brown.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rythme, tendances, estimation de fin et plus',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.brown.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A54A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Essayer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInsightRow(_InsightRow insight, bool isDark, bool isPremium) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(insight.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : Colors.black87,
              ),
            ),
          ),
          if (isPremium)
            Flexible(
              child: Text(
                insight.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : const Color(0xFFD4A54A),
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Text(
                  insight.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : const Color(0xFFD4A54A),
                  ),
                ),
              ),
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

  Widget _buildHideButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () async {
          try {
            await ReadingSessionService().toggleSessionHidden(
              widget.session.id,
              true,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Session masquee des classements'),
                action: SnackBarAction(
                  label: 'Annuler',
                  onPressed: () async {
                    try {
                      await ReadingSessionService().toggleSessionHidden(
                        widget.session.id,
                        false,
                      );
                    } catch (_) {}
                  },
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur lors du masquage')),
            );
          }
        },
        icon: Icon(
          Icons.visibility_off_outlined,
          size: 18,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        label: Text(
          'Masquer cette session',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.textPrimaryDark : Colors.black87,
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
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

class _InsightRow {
  final String emoji;
  final String label;
  final String value;

  const _InsightRow({
    required this.emoji,
    required this.label,
    required this.value,
  });
}
