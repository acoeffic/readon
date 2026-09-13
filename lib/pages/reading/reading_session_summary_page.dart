// lib/pages/reading/reading_session_summary_page.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../models/feature_flags.dart';
import '../../providers/subscription_provider.dart';
import '../../services/native_paywall_service.dart';
import '../../services/books_service.dart';
import '../../services/app_review_service.dart';
import '../../services/analytics_service.dart';
import '../../services/focus_mode_service.dart';
import '../profile/focus_mode_guide_page.dart';
import '../../services/flow_service.dart';
import '../../services/reading_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/reading_for_picker.dart';
import '../../features/wrapped/share/share_format.dart';
import '../../navigation/main_navigation.dart';
import 'session_share_service.dart';

class ReadingSessionSummaryPage extends StatefulWidget {
  final ReadingSession session;

  const ReadingSessionSummaryPage({
    super.key,
    required this.session,
  });

  @override
  State<ReadingSessionSummaryPage> createState() =>
      _ReadingSessionSummaryPageState();
}

class _ReadingSessionSummaryPageState
    extends State<ReadingSessionSummaryPage>
    with SingleTickerProviderStateMixin {
  Book? _book;
  int _currentStreak = 0;
  Map<String, double> _userAverages = {};

  /// Cascade d'entrée de l'écran (header → livre → stats → insights).
  late final AnimationController _entryController;

  /// « Pour qui » modifiable a posteriori — état local, initialisé depuis la
  /// session, mis à jour en base via updateSessionReadingFor.
  String? _readingFor;

  /// Suggestion unique « mode sans distraction » (iOS, ≥ 2e session — cf.
  /// FocusModeService pour le pourquoi de la cadence).
  bool _showFocusSuggestion = false;

  @override
  void initState() {
    super.initState();
    _readingFor = widget.session.readingFor;
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _loadData();
    _maybeShowFocusSuggestion();
    // Lancée après le premier frame, pour partir d'un écran layouté et
    // pouvoir lire le réglage d'accessibilité « réduire les animations ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _entryController.value = 1.0;
        return;
      }
      _entryController.forward();
      _scheduleStatHaptics();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  /// Trois petites impulsions calées sur le pop des trois stats
  /// (la dernière — la série — un peu plus marquée).
  void _scheduleStatHaptics() {
    Future.delayed(const Duration(milliseconds: 730), () {
      if (mounted) HapticFeedback.lightImpact();
    });
    Future.delayed(const Duration(milliseconds: 870), () {
      if (mounted) HapticFeedback.lightImpact();
    });
    Future.delayed(const Duration(milliseconds: 1010), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
  }

  /// Fondu + légère translation vers le haut sur un segment de la cascade.
  Widget _entryReveal({
    required double begin,
    required double end,
    required Widget child,
  }) {
    final curved = CurvedAnimation(
      parent: _entryController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  Future<void> _maybeShowFocusSuggestion() async {
    final show = await FocusModeService()
        .registerCompletedSessionAndCheckSuggestion();
    if (!show || !mounted) return;
    setState(() => _showFocusSuggestion = true);
    // Cartouche consommée dès l'affichage, quelle que soit la suite.
    FocusModeService().markSuggestionShown();
    AnalyticsService().track(AnalyticsEvent.focusSuggestionShown);
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
      _maybeAskReviewForStreakMilestone();
    } catch (_) {
      // Non-critical — page still renders with fallback data
    }
  }

  /// Moment de fierté : streak qui atteint un palier symbolique.
  /// Les garde-fous (ancienneté, fréquence) sont dans AppReviewService.
  void _maybeAskReviewForStreakMilestone() {
    const milestones = {7, 14, 30, 50, 100, 200, 365};
    if (!milestones.contains(_currentStreak)) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        AppReviewService.maybeRequestReview(
          trigger: 'streak_$_currentStreak',
        );
      }
    });
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
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: ConstrainedContent(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Column(
                    children: [
                      _buildAppBar(isDark, l),
                      const SizedBox(height: 8),
                      _entryReveal(
                        begin: 0.0,
                        end: 0.25,
                        child: _buildHeader(isDark, l),
                      ),
                      const SizedBox(height: 8),
                      _entryReveal(
                        begin: 0.06,
                        end: 0.31,
                        child: _buildReadingForBadge(isDark, l),
                      ),
                      const SizedBox(height: 14),
                      _entryReveal(
                        begin: 0.14,
                        end: 0.42,
                        child: _buildBookCard(isDark, l),
                      ),
                      const SizedBox(height: 10),
                      _entryReveal(
                        begin: 0.28,
                        end: 0.55,
                        child: _buildFreeStatsCard(isDark, l),
                      ),
                      const SizedBox(height: 12),
                      _entryReveal(
                        begin: 0.55,
                        end: 0.85,
                        child: _buildInsightsSection(isDark),
                      ),
                      if (_showFocusSuggestion) ...[
                        const SizedBox(height: 12),
                        _entryReveal(
                          begin: 0.65,
                          end: 0.95,
                          child: _buildFocusSuggestionCard(isDark, l),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    top: BorderSide(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.06),
                    ),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildShareButton(),
                    const SizedBox(height: 4),
                    _buildSecondaryActions(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reading for badge (modifiable a posteriori) ─────────────────────

  /// Ouvre le sélecteur et enregistre la modification en base.
  /// 'myself' → NULL (convention identique au démarrage de session).
  Future<void> _editReadingFor() async {
    final selected = await showReadingForPicker(
      context,
      current: _readingFor ?? 'myself',
    );
    if (selected == null || !mounted) return;

    final newValue = selected == 'myself' ? null : selected;
    if (newValue == _readingFor) return;

    final previous = _readingFor;
    setState(() => _readingFor = newValue);
    try {
      await ReadingSessionService()
          .updateSessionReadingFor(widget.session.id, newValue);
    } catch (_) {
      if (!mounted) return;
      setState(() => _readingFor = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).errorModifying),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildReadingForBadge(bool isDark, AppLocalizations l) {
    final hasValue = _readingFor != null;
    final label = hasValue
        ? l.readingForDisplay(readingForLabel(l, _readingFor!))
        : l.readingForAddPrompt;
    final color = hasValue
        ? AppColors.primary
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);

    return GestureDetector(
      onTap: _editReadingFor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: hasValue
              ? (isDark
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasValue
                ? AppColors.primary.withValues(alpha: 0.25)
                : color.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasValue ? readingForEmoji(_readingFor!) : '\u{1F4D6}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              hasValue ? Icons.edit_rounded : Icons.add_rounded,
              size: 14,
              color: color.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  // ── Suggestion « mode sans distraction » (unique, iOS) ──────────────

  Widget _buildFocusSuggestionCard(bool isDark, AppLocalizations l) {
    final secondary = isDark ? Colors.white70 : Colors.black54;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🌙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.focusSuggestionTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.focusSuggestionBody,
                      style: TextStyle(fontSize: 13, color: secondary),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  AnalyticsService()
                      .track(AnalyticsEvent.focusSuggestionDismissed);
                  setState(() => _showFocusSuggestion = false);
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.close_rounded, size: 18, color: secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FocusModeGuidePage(
                      source: 'post_session_suggestion',
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l.focusSuggestionCta),
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────

  Widget _buildAppBar(bool isDark, AppLocalizations l) {
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
          l.sessionCompleted,
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

  Widget _buildHeader(bool isDark, AppLocalizations l) {
    return Column(
      children: [
        const Text('🎉', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 6),
        Text(
          l.sessionCompletedTitle,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDateTime(widget.session.endTime ?? widget.session.startTime),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Book card (cover + title/author + progression) ─────────────────

  Widget _buildBookCard(bool isDark, AppLocalizations l) {
    final bookTitle = _book?.title ?? l.myReadingDefault;
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
                  isbn: _book?.isbn,
                  googleId: _book?.googleId,
                  title: _book?.title,
                  author: _book?.author,
                  width: 65,
                  height: 90,
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
                            l.nPages(pageCount),
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

  Widget _buildFreeStatsCard(bool isDark, AppLocalizations l) {
    final session = widget.session;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
                valueOf: (t) =>
                    _formatDuration((session.durationMinutes * t).round()),
                label: 'durée',
                isDark: isDark,
                begin: 0.40,
                end: 0.60,
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
                valueOf: (t) => '${(session.pagesRead * t).round()}',
                label: 'pages lues',
                isDark: isDark,
                begin: 0.50,
                end: 0.70,
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
                valueOf: (t) => '${(_currentStreak * t).round()} j.',
                label: 'série',
                isDark: isDark,
                begin: 0.60,
                end: 0.80,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeStat({
    required String emoji,
    required String Function(double t) valueOf,
    required String label,
    required bool isDark,
    required double begin,
    required double end,
  }) {
    // Pop avec un léger rebond, fondu simple, et compteur qui « tourne »
    // un peu plus longtemps que le pop.
    final pop = CurvedAnimation(
      parent: _entryController,
      curve: Interval(begin, end, curve: Curves.easeOutBack),
    );
    final fade = CurvedAnimation(
      parent: _entryController,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    final count = CurvedAnimation(
      parent: _entryController,
      curve: Interval(begin, 0.95, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(pop),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: count,
              builder: (context, _) => Text(
                valueOf(count.value),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Insights section ─────────────────────────────────────────────

  Widget _buildInsightsSection(bool isDark) {
    final l = AppLocalizations.of(context);
    // Insights de performance : routés via FeatureFlags (advancedStats est
    // désormais gratuit — 19/08/2026).
    final insightsUnlocked = FeatureFlags.isAvailable(
      Feature.advancedStats,
      isPremium: context.watch<SubscriptionProvider>().isPremium,
    );
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
        vsAverage = l.fasterPercent(diff);
      } else if (diff < 0) {
        vsAverage = l.slowerPercent(diff.abs());
      } else {
        vsAverage = l.withinAverage;
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
      _InsightRow(emoji: '\u{1F4C8}', label: l.readingPace, value: paceValue),
      _InsightRow(emoji: '\u{23F3}', label: l.avgTimePerPage, value: timePerPageValue),
      if (estimatedFinish != null)
        _InsightRow(emoji: '\u{1F4C5}', label: l.estimatedBookEnd, value: estimatedFinish),
      if (vsAverage != null)
        _InsightRow(emoji: '\u{1F4CA}', label: l.vsYourAverage, value: vsAverage),
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
          // Header (badge PREMIUM seulement si la feature est verrouillée)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                if (!insightsUnlocked) ...[
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
                ],
                Text(
                  l.sessionInsights,
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
                _buildInsightRow(insights[i], isDark, insightsUnlocked),
              ],
            );
          }),
          // CTA for free users
          if (!insightsUnlocked) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => NativePaywallService.present(
                context,
                highlightedFeature: Feature.advancedStats,
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
                            l.viewFullReport,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.brown.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.paceAndTrends,
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
                      child: Text(
                        l.tryPremium,
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

  Widget _buildInsightRow(_InsightRow insight, bool isDark, bool unlocked) {
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
          if (unlocked)
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

  bool _isSharing = false;

  final GlobalKey _shareButtonKey = GlobalKey();

  Rect? _shareOrigin() {
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareDirectly() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final service = SessionShareService();
      final l = AppLocalizations.of(context);
      // Use the same cover URL that CachedBookCover resolved (fallback chain),
      // not the raw database URL which may be wrong or a placeholder.
      final resolvedCover = CachedBookCover.resolvedUrl(
        imageUrl: _book?.coverUrl,
        isbn: _book?.isbn,
        googleId: _book?.googleId,
      );
      final coverBytes = await service.downloadCover(resolvedCover ?? _book?.coverUrl);
      if (!mounted) return;

      // Resolve "reading for" label for the share card
      String? readingForText;
      if (_readingFor != null) {
        readingForText = l.readingForDisplay(readingForLabel(l, _readingFor!));
      }

      final imageBytes = await service.captureCard(
        session: widget.session,
        bookTitle: _book?.title ?? l.noTitleDefault,
        bookAuthor: _book?.author,
        coverBytes: coverBytes,
        totalPages: _book?.pageCount,
        streak: _currentStreak,
        format: ShareFormat.story,
        readingForLabel: readingForText,
      );
      if (!mounted || imageBytes == null) return;

      await service.shareToDestination(
        imageBytes: imageBytes,
        destination: ShareDestination.more,
        session: widget.session,
        sharePositionOrigin: _shareOrigin(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Erreur partage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _saveImage() async {
    setState(() => _isSharing = true);
    try {
      final service = SessionShareService();
      final l = AppLocalizations.of(context);
      final resolvedCover = CachedBookCover.resolvedUrl(
        imageUrl: _book?.coverUrl,
        isbn: _book?.isbn,
        googleId: _book?.googleId,
      );
      final coverBytes = await service.downloadCover(resolvedCover ?? _book?.coverUrl);
      if (!mounted) return;

      String? readingForText;
      if (_readingFor != null) {
        readingForText = l.readingForDisplay(readingForLabel(l, _readingFor!));
      }

      final imageBytes = await service.captureCard(
        session: widget.session,
        bookTitle: _book?.title ?? l.noTitleDefault,
        bookAuthor: _book?.author,
        coverBytes: coverBytes,
        totalPages: _book?.pageCount,
        streak: _currentStreak,
        format: ShareFormat.story,
        readingForLabel: readingForText,
      );
      if (!mounted || imageBytes == null) return;

      await service.saveToGallery(imageBytes, widget.session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.imageSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Erreur sauvegarde image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sauvegarde'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget _buildShareButton() {
    final l = AppLocalizations.of(context);
    return SizedBox(
      key: _shareButtonKey,
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSharing ? null : _shareDirectly,
        icon: _isSharing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.share_rounded, size: 22),
        label: Text(
          l.shareMySession,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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

  Widget _buildSecondaryActions(bool isDark) {
    final l = AppLocalizations.of(context);
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: _isSharing ? null : _saveImage,
            icon: Icon(Icons.download_rounded, size: 18, color: secondaryColor),
            label: Text(
              l.saveImage,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: secondaryColor,
              ),
            ),
          ),
        ),
        Container(
          width: 1,
          height: 20,
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l.later,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: secondaryColor,
              ),
            ),
          ),
        ),
      ],
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
