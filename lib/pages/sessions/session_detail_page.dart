import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/reading_session.dart';
import '../../models/book.dart';
import '../../services/reading_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';

class SessionDetailPage extends StatelessWidget {
  final ReadingSession session;
  final Book? book;

  const SessionDetailPage({
    super.key,
    required this.session,
    this.book,
  });

  Future<void> _deleteSession(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la session'),
        content: const Text(
            'Voulez-vous vraiment supprimer cette session de lecture ? Cette action est irréversible.'),
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

    if (confirm == true && context.mounted) {
      try {
        await ReadingSessionService().cancelSession(session.id);
        if (context.mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la suppression')),
          );
        }
      }
    }
  }

  void _shareSession(BuildContext context) {
    final bookTitle = book?.title ?? 'un livre';
    final author = book?.author ?? '';
    final pages = session.pagesRead;
    final duration = _formatDuration(session.durationMinutes);

    final text =
        "Je viens de lire $pages pages de \"$bookTitle\"${author.isNotEmpty ? ' de $author' : ''} en $duration ! \u{1F4DA}\n\n#Lexsta #Lecture";
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
            onPressed: () => _deleteSession(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Book Header with progress
            _buildBookHeader(isDark, terracotta, subtitleColor),
            const SizedBox(height: 24),

            // Stats Row (duration, pages, pace)
            if (!session.isActive) ...[
              _buildStatsCard(isDark, cardColor, terracotta, subtitleColor),
              const SizedBox(height: 16),

              // Session Progression
              _buildProgressionCard(isDark, cardColor, terracotta, subtitleColor),
              const SizedBox(height: 16),

              // Timeline
              _buildTimelineCard(isDark, cardColor, terracotta, subtitleColor),
              const SizedBox(height: 20),

              // Share Button
              _buildShareButton(isDark, context),
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
            imageUrl: book?.coverUrl,
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
                book?.title ?? 'Livre inconnu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (book?.author != null) ...[
                const SizedBox(height: 4),
                Text(
                  book!.author!,
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
                    'p.${session.endPage ?? session.startPage}',
                    style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    book?.pageCount != null ? '${book!.pageCount} pages' : '',
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
            _formatDuration(session.durationMinutes),
            'duree',
            terracotta,
            subtitleColor,
          ),
          _buildStatItem(
            '\u{1F4C4}',
            '${session.pagesRead}',
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
                  '+${session.pagesRead} pages',
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
                '${session.startPage}',
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
                '${session.endPage ?? session.startPage}',
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
    final startTime = session.startTime;
    final endTime = session.endTime;

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
                    '${_formatDuration(session.durationMinutes)} de lecture',
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

  Widget _buildShareButton(bool isDark, BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _shareSession(context),
        icon: const Text('\u{1F4EC}', style: TextStyle(fontSize: 18)),
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
                  'Demarree a la page ${session.startPage}',
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

  // Helpers

  double? _getBookProgress() {
    if (book?.pageCount == null || book!.pageCount == 0) return null;
    final currentPage = session.endPage ?? session.startPage;
    return (currentPage / book!.pageCount!) * 100;
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h${mins.toString().padLeft(2, '0')}';
  }

  String _formatPace() {
    if (session.pagesRead == 0 || session.durationMinutes == 0) return '-';
    final minutesPerPage = session.durationMinutes / session.pagesRead;
    if (minutesPerPage < 1) {
      final pagesPerMinute = session.pagesRead / session.durationMinutes;
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
