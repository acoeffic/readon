import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/rate_book_sheet.dart' show emotionTagLabel;
import '../../widgets/star_rating.dart';
import '../sessions/session_detail_page.dart';

/// Détail d'un livre de la bibliothèque d'un ami : statut, note publique,
/// stats agrégées et sessions de lecture (RPC get_friend_book_detail).
class FriendBookDetailPage extends StatefulWidget {
  final String userId;
  final String userName;

  /// Map livre issue de get_friend_profile_v2 :
  /// b_id, book_title, book_author, book_cover_url, book_isbn,
  /// book_google_id, éventuellement book_page_count.
  final Map<String, dynamic> book;

  const FriendBookDetailPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.book,
  });

  @override
  State<FriendBookDetailPage> createState() => _FriendBookDetailPageState();
}

class _FriendBookDetailPageState extends State<FriendBookDetailPage> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic>? _userBook;
  Map<String, dynamic>? _rating;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _sessions = [];

  String get _title => widget.book['book_title'] as String? ?? '';
  String get _author => widget.book['book_author'] as String? ?? '';
  String? get _coverUrl {
    final url = widget.book['book_cover_url'] as String?;
    return (url == null || url.isEmpty) ? null : url;
  }

  int? get _bookId => (widget.book['b_id'] as num?)?.toInt();

  Book get _bookModel => Book(
        id: _bookId ?? 0,
        title: _title,
        author: _author.isEmpty ? null : _author,
        coverUrl: _coverUrl,
        pageCount: (widget.book['book_page_count'] as num?)?.toInt(),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bookId = _bookId;
      if (bookId == null) return;
      final response = await supabase.rpc(
        'get_friend_book_detail',
        params: {'p_user_id': widget.userId, 'p_book_id': bookId},
      );

      if (response != null && mounted) {
        final data = response is Map<String, dynamic>
            ? response
            : Map<String, dynamic>.from(response as Map);

        Map<String, dynamic>? asMap(dynamic v) =>
            v is Map ? Map<String, dynamic>.from(v) : null;

        setState(() {
          _userBook = asMap(data['user_book']);
          _rating = asMap(data['rating']);
          _stats = asMap(data['stats']);
          _sessions = (data['sessions'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Erreur _load FriendBookDetail: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _statusLabel(AppLocalizations l, String? status) {
    switch (status) {
      case 'finished':
        return l.completed;
      case 'reading':
        return l.inProgressTag;
      case 'to_read':
        return l.profileToReadChip;
      default:
        return '';
    }
  }

  String _formatDuration(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return '';
    final start = DateTime.parse(startTime);
    final end = DateTime.parse(endTime);
    final minutes = end.difference(start).inMinutes;
    if (minutes >= 60) {
      return '${minutes ~/ 60}h ${minutes % 60}min';
    }
    return '${minutes}min';
  }

  String _formatDate(String? dateStr, AppLocalizations l) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return l.today;
    if (diff.inDays == 1) return l.yesterday;
    if (diff.inDays < 7) return l.daysAgo(diff.inDays);
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('d MMM', locale).format(date);
  }

  void _openSession(Map<String, dynamic> session) {
    final now = DateTime.now();
    final readingSession = ReadingSession(
      id: session['id'] as String,
      userId: session['user_id'] as String,
      bookId: session['book_id'] as String,
      startPage: (session['start_page'] as num).toInt(),
      endPage: (session['end_page'] as num?)?.toInt(),
      startTime: DateTime.parse(session['start_time'] as String).toLocal(),
      endTime: session['end_time'] != null
          ? DateTime.parse(session['end_time'] as String).toLocal()
          : null,
      isHidden: session['is_hidden'] as bool? ?? false,
      readingFor: session['reading_for'] as String?,
      createdAt: session['created_at'] != null
          ? DateTime.parse(session['created_at'] as String).toLocal()
          : now,
      updatedAt: session['updated_at'] != null
          ? DateTime.parse(session['updated_at'] as String).toLocal()
          : now,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailPage(
          session: readingSession,
          book: _bookModel,
          isOwn: false,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.appColors;
    final immersive = _coverUrl != null;

    final overlayStyle = (immersive || colors.isDark)
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(l, colors, immersive),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _buildStatsRow(l, colors),
                if (_rating != null) _buildRatingCard(l, colors),
                if (_sessions.isNotEmpty) _buildSessions(l, colors),
              ],
              const SizedBox(height: 46),
            ],
          ),
        ),
      ),
    );
  }

  // --- HEADER -----------------------------------------------------------------

  Widget _buildHeader(
      AppLocalizations l, AppThemeColors colors, bool immersive) {
    final topPad = MediaQuery.of(context).padding.top;
    final onHeroColor = immersive ? Colors.white : colors.textPrimary;
    final status = _userBook?['status'] as String?;
    final statusLabel = _statusLabel(l, status);

    final content = Column(
      children: [
        SizedBox(height: topPad),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: onHeroColor),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  widget.userName.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: onHeroColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: CachedBookCover(
            imageUrl: widget.book['book_cover_url'] as String?,
            isbn: widget.book['book_isbn'] as String?,
            googleId: widget.book['book_google_id'] as String?,
            title: _title,
            author: _author,
            width: 124,
            height: 186,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.2,
              color: colors.textPrimary,
            ),
          ),
        ),
        if (_author.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            _author,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ],
        if (statusLabel.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: colors.textPrimary,
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.scaffoldBg,
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
      ],
    );

    if (!immersive) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: content,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: Transform.scale(
              scale: 1.3,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: CachedNetworkImage(
                  imageUrl: _coverUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: colors.primaryDeep),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.26, 0.58, 0.80, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.62),
                  Colors.black.withValues(alpha: 0.30),
                  colors.scaffoldBg.withValues(alpha: 0.55),
                  colors.scaffoldBg.withValues(alpha: 0.96),
                  colors.scaffoldBg,
                ],
              ),
            ),
          ),
        ),
        content,
      ],
    );
  }

  // --- STATS ------------------------------------------------------------------

  Widget _buildStatsRow(AppLocalizations l, AppThemeColors colors) {
    final sessionCount = (_stats?['session_count'] as num?)?.toInt() ?? 0;
    final totalPages = (_stats?['total_pages'] as num?)?.toInt() ?? 0;
    final totalMinutes = (_stats?['total_minutes'] as num?)?.toDouble() ?? 0;
    final hours = totalMinutes ~/ 60;
    final minutes = (totalMinutes % 60).round();
    final timeLabel = hours > 0 ? '$hours h' : '$minutes min';

    final items = <(String, String)>[
      ('$sessionCount', l.sessions),
      ('$totalPages', l.pagesLabel),
      (timeLabel, l.readingLabel),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    width: 1,
                    color: colors.textPrimary.withValues(alpha: 0.10),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      items[i].$1,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].$2.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- SA NOTE ----------------------------------------------------------------

  Widget _buildRatingCard(AppLocalizations l, AppThemeColors colors) {
    final rating = (_rating?['rating'] as num?)?.toDouble();
    final reviewText = _rating?['review_text'] as String?;
    final wouldRecommend = _rating?['would_recommend'] as bool? ?? false;
    final tags = (_rating?['emotion_tags'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    if (rating == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l.profileTheirRating.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.7,
                color: colors.primary,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StarRating(
                      rating: rating,
                      size: 20,
                      spacing: 2,
                      color: colors.variantAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rating.toStringAsFixed(rating == rating.roundToDouble() ? 0 : 1),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (wouldRecommend)
                      Text(
                        l.recommended,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                  ],
                ),
                if (reviewText != null && reviewText.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '« ${reviewText.trim()} »',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      color: colors.textPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: colors.pillBg,
                          ),
                          child: Text(
                            emotionTagLabel(l, tag),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  colors.textPrimary.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SESSIONS ---------------------------------------------------------------

  Widget _buildSessions(AppLocalizations l, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  l.recentSessions,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_sessions.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < _sessions.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: colors.textPrimary.withValues(alpha: 0.06),
                    ),
                  _buildSessionTile(l, colors, _sessions[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(
    AppLocalizations l,
    AppThemeColors colors,
    Map<String, dynamic> session,
  ) {
    final startPage = (session['start_page'] as num?)?.toInt() ?? 0;
    final endPage = (session['end_page'] as num?)?.toInt();
    final pagesRead = endPage != null ? endPage - startPage : 0;
    final duration = _formatDuration(
      session['start_time'] as String?,
      session['end_time'] as String?,
    );
    final date = _formatDate(session['end_time'] as String?, l);

    return InkWell(
      onTap: () => _openSession(session),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.auto_stories, color: colors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    endPage != null
                        ? l.sessionPageRange(startPage, endPage)
                        : l.pageAtNumber(startPage),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pagesRead > 0 ? l.nPages(pagesRead) : ''}'
                    '${pagesRead > 0 && duration.isNotEmpty ? ' · ' : ''}'
                    '$duration',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              date,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colors.textPrimary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
