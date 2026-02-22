import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/reading_session.dart';
import '../../models/book.dart';
import '../../providers/subscription_provider.dart';
import '../../pages/profile/upgrade_page.dart';
import '../../services/reading_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';

class SessionDetailPage extends StatefulWidget {
  final ReadingSession session;
  final Book? book;
  final bool isOwn;

  const SessionDetailPage({
    super.key,
    required this.session,
    this.book,
    this.isOwn = true,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late bool _isHidden;
  Map<String, double> _userAverages = {};

  @override
  void initState() {
    super.initState();
    _isHidden = widget.session.isHidden;
    _loadAverages();
  }

  Future<void> _loadAverages() async {
    try {
      final averages = await ReadingSessionService().getUserReadingAverages();
      if (!mounted) return;
      setState(() => _userAverages = averages);
    } catch (_) {}
  }

  Future<void> _toggleHidden() async {
    final newValue = !_isHidden;
    setState(() => _isHidden = newValue);

    try {
      await ReadingSessionService().toggleSessionHidden(
        widget.session.id,
        newValue,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newValue
              ? 'Session masquee des classements'
              : 'Session visible dans les classements'),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () async {
              setState(() => _isHidden = !newValue);
              try {
                await ReadingSessionService().toggleSessionHidden(
                  widget.session.id,
                  !newValue,
                );
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (e) {
      setState(() => _isHidden = !newValue);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la modification')),
      );
    }
  }

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la session'),
        content: const Text(
            'Voulez-vous vraiment supprimer cette session de lecture ? Cette action est irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ReadingSessionService().cancelSession(widget.session.id);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la suppression')),
          );
        }
      }
    }
  }

  void _shareSession() {
    final bookTitle = widget.book?.title ?? 'un livre';
    final author = widget.book?.author ?? '';
    final pages = widget.session.pagesRead;
    final duration = _formatDuration(widget.session.durationMinutes);

    final text =
        "Je viens de lire $pages pages de \"$bookTitle\"${author.isNotEmpty ? ' de $author' : ''} en $duration ! \u{1F4DA}\n\n#LexDay #Lecture";
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    Share.share(text, sharePositionOrigin: origin);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final terracotta = const Color(0xFFCC8B65);
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chevron_left,
                color: isDark ? Colors.white : Colors.black87, size: 20),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'SESSION',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.isOwn) ...[
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isHidden ? Icons.visibility : Icons.visibility_off_outlined,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 18,
                ),
              ),
              tooltip: _isHidden ? 'Rendre visible' : 'Masquer la session',
              onPressed: _toggleHidden,
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline,
                    color: Colors.red, size: 18),
              ),
              onPressed: _deleteSession,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Hidden indicator
            if (_isHidden && widget.isOwn)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.shade900.withValues(alpha: 0.3)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility_off, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Session masquee des classements et du feed',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Book Header with progress
            _buildBookHeader(isDark, terracotta, subtitleColor),
            const SizedBox(height: 24),

            // Stats Row (duration, pages, pace)
            if (!widget.session.isActive) ...[
              _buildStatsCard(isDark, cardColor, terracotta, subtitleColor),
              const SizedBox(height: 16),

              // Session Progression
              _buildProgressionCard(isDark, cardColor, terracotta, subtitleColor),
              const SizedBox(height: 16),

              // Insights
              _buildInsightsCard(isDark, cardColor),
              const SizedBox(height: 16),

              // Timeline
              _buildTimelineCard(isDark, cardColor, terracotta, subtitleColor),
              const SizedBox(height: 20),

              // Share Button
              _buildShareButton(isDark),
            ] else ...[
              _buildActiveSessionCard(isDark, cardColor, terracotta),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBookHeader(bool isDark, Color terracotta, Color subtitleColor) {
    final progressPercent = _getBookProgress();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book cover
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CachedBookCover(
            imageUrl: widget.book?.coverUrl,
            width: 80,
            height: 110,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                widget.book?.title ?? 'Livre inconnu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.book?.author != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.book!.author!,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              // Progress bar
              Row(
                children: [
                  Text(
                    'Progression du livre',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    progressPercent != null ? '${progressPercent.round()}%' : '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: terracotta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPercent != null ? progressPercent / 100 : 0,
                  backgroundColor:
                      isDark ? Colors.grey[700] : const Color(0xFFE8E0D8),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'p.${widget.session.endPage ?? widget.session.startPage}',
                    style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.book?.pageCount != null ? '${widget.book!.pageCount} pages' : '',
                    style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(
      bool isDark, Color cardColor, Color terracotta, Color subtitleColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            '\u{23F1}',
            _formatDuration(widget.session.durationMinutes),
            'duree',
            terracotta,
            subtitleColor,
          ),
          _buildStatItem(
            '\u{1F4C4}',
            '${widget.session.pagesRead}',
            'pages lues',
            terracotta,
            subtitleColor,
          ),
          _buildStatItem(
            '\u{1F4C8}',
            _formatPace(),
            'rythme',
            terracotta,
            subtitleColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label,
      Color valueColor, Color labelColor) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: labelColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressionCard(
      bool isDark, Color cardColor, Color terracotta, Color subtitleColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Progression de la session',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+${widget.session.pagesRead} pages',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Start page
              _buildPageBubble(
                'Debut',
                '${widget.session.startPage}',
                isDark,
                false,
              ),
              // Dashed line with arrow
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, 2),
                        painter: _DashedLinePainter(
                          color: isDark
                              ? Colors.grey[600]!
                              : const Color(0xFFD0C8C0),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // End page
              _buildPageBubble(
                'Fin',
                '${widget.session.endPage ?? widget.session.startPage}',
                isDark,
                true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageBubble(
      String label, String page, bool isDark, bool isEnd) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isEnd
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.08))
            : (isDark ? Colors.grey[800] : const Color(0xFFF5F0EB)),
        borderRadius: BorderRadius.circular(14),
        border: isEnd
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            page,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(
      bool isDark, Color cardColor, Color terracotta, Color subtitleColor) {
    final startTime = widget.session.startTime;
    final endTime = widget.session.endTime;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chronologie',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          // Start time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 60,
                    color: isDark
                        ? Colors.grey[700]
                        : const Color(0xFFE0D8D0),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatTime(startTime),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'debut de session',
                        style: TextStyle(
                          fontSize: 13,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('\u{1F4C5}', style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatDateFull(startTime)} \u00B7 ${_getDayPeriod(startTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Duration badge
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? terracotta.withValues(alpha: 0.15)
                    : terracotta.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('\u{23F1}', style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatDuration(widget.session.durationMinutes)} de lecture',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: terracotta,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // End time
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.grey[600]!
                        : const Color(0xFFD0C8C0),
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                endTime != null ? _formatTime(endTime) : '--:--',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'fin de session',
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _shareSession,
        icon: const Icon(Icons.share_outlined, size: 20),
        label: const Text(
          'Partager',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(
      bool isDark, Color cardColor, Color terracotta) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.shade900.withValues(alpha: 0.3)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: Colors.orange.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session en cours',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Demarree a la page ${widget.session.startPage}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Insights card ──────────────────────────────────────────────────

  Widget _buildInsightsCard(bool isDark, Color cardColor) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final session = widget.session;

    final pagesPerMin = session.durationMinutes > 0
        ? session.pagesRead / session.durationMinutes
        : 0.0;
    final minPerPage = session.pagesRead > 0
        ? session.durationMinutes / session.pagesRead
        : 0.0;

    // Estimated finish date
    String? estimatedFinish;
    final pageCount = widget.book?.pageCount;
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

    final paceValue = pagesPerMin >= 1
        ? '${pagesPerMin.toStringAsFixed(1)} p/min'
        : '${pagesPerMin.toStringAsFixed(2)} p/min';
    final timePerPageValue = minPerPage < 1
        ? '${(minPerPage * 60).round()} sec'
        : '${minPerPage.toStringAsFixed(1)} min';

    final insights = [
      _InsightData(emoji: '\u{1F4C8}', label: 'Rythme de lecture', value: paceValue),
      _InsightData(emoji: '\u{23F3}', label: 'Temps moyen par page', value: timePerPageValue),
      if (estimatedFinish != null)
        _InsightData(emoji: '\u{1F4C5}', label: 'Fin estimée du livre', value: estimatedFinish),
      if (vsAverage != null)
        _InsightData(emoji: '\u{1F4CA}', label: 'vs. ta moyenne', value: vsAverage),
    ];

    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
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
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Text(insights[i].emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          insights[i].label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (isPremium)
                        Text(
                          insights[i].value,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD4A54A),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                            child: Text(
                              insights[i].value,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD4A54A),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }),
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
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\u{2728} Débloquer tes insights',
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

  // Helpers

  double? _getBookProgress() {
    if (widget.book?.pageCount == null || widget.book!.pageCount == 0) return null;
    final currentPage = widget.session.endPage ?? widget.session.startPage;
    return (currentPage / widget.book!.pageCount!) * 100;
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h${mins.toString().padLeft(2, '0')}';
  }

  String _formatPace() {
    if (widget.session.pagesRead == 0 || widget.session.durationMinutes == 0) return '-';
    final minutesPerPage = widget.session.durationMinutes / widget.session.pagesRead;
    if (minutesPerPage < 1) {
      final pagesPerMinute = widget.session.pagesRead / widget.session.durationMinutes;
      return '${pagesPerMinute.toStringAsFixed(1)} p/min';
    }
    return '${minutesPerPage.round()} min/p';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateFull(DateTime date) {
    const months = [
      'jan', 'fev', 'mar', 'avr', 'mai', 'juin',
      'juil', 'aout', 'sep', 'oct', 'nov', 'dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _getDayPeriod(DateTime time) {
    const days = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
    ];
    final dayName = days[time.weekday - 1];

    if (time.hour < 12) return '$dayName matin';
    if (time.hour < 18) return '$dayName apres-midi';
    return '$dayName soir';
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InsightData {
  final String emoji;
  final String label;
  final String value;

  const _InsightData({
    required this.emoji,
    required this.label,
    required this.value,
  });
}
