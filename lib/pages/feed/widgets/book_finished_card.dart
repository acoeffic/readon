import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/likes_service.dart';
import '../../../services/reactions_service.dart';
import '../../../services/books_service.dart';
import '../../../services/reading_session_service.dart';
import '../../../services/flow_service.dart';
import '../../../models/feature_flags.dart';
import '../../../models/book.dart';
import '../../../models/reading_session.dart';
import '../../../models/reading_flow.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_book_cover.dart';
import '../../../widgets/cached_profile_avatar.dart';
import '../../../widgets/reaction_picker.dart';
import '../../../widgets/reaction_summary.dart';
import '../../friends/friend_profile_page.dart';
import '../../reading/book_finished_share_service.dart';
import '../../books/user_books_page.dart';

// ---------------------------------------------------------------------------
// Color constants for the book-finished card (light / dark)
// ---------------------------------------------------------------------------
class _BFColors {
  static const bgLight = Color(0xFFE8EFF8);
  static const bgDark = Color(0xFF0D1520);

  // Border conic-gradient
  static const borderColors = [
    Color(0xFF4A90D9),
    Color(0xFF7EB8E8),
    Color(0xFFB8D4F0),
    Color(0xFF4A90D9),
    Color(0xFF2E6BB0),
    Color(0xFF7EB8E8),
    Color(0xFF4A90D9),
  ];
  static const borderOpacityLight = 0.25;
  static const borderOpacityDark = 0.15;

  // Text
  static const titleLight = Color(0xFF1A2A40);
  static const titleDark = Color(0xFFF0F4F8);
  static const authorLight = Color(0xFF7A94B0);
  static const authorDark = Color(0xFF4D6A88);

  // Badge "Livre terminé"
  static const badgeTextLight = Color(0xFF2E6BB0);
  static const badgeTextDark = Color(0xFF7EB8E8);

  // Stat pills
  static const pillBgLight = Color(0x99FFFFFF); // rgba(255,255,255,0.6)
  static const pillBgDark = Color(0xFF0A1219);
  static const pillBorderLight = Color(0x1F4A90D9); // rgba(74,144,217,0.12)
  static const pillBorderDark = Color(0xFF1A2A3E);
  static const pillValueLight = Color(0xFF1A2A40);
  static const pillValueDark = Color(0xFFC8D8E8);
  static const pillLabelLight = Color(0xFF8A9BB5);
  static const pillLabelDark = Color(0xFF3D5570);

  // Cover glow
  static const glowStartLight = Color(0xFFD6E4F0);
  static const glowEndLight = Color(0xFFC0D4EA);
  static const glowStartDark = Color(0xFF1A2A40);
  static const glowEndDark = Color(0xFF0F1C2E);

  // Checkmark border matches card bg
  static const checkBorderLight = bgLight;
  static const checkBorderDark = bgDark;

  // Like
  static const likeActiveLight = Color(0xFF2E6BB0);
  static const likeActiveDark = Color(0xFF4A90D9);
  static const likeActiveBgLight = Color(0x1F4A90D9);
  static const likeActiveBgDark = Color(0x1F4A90D9);
  static const likeInactiveBgLight = Color(0x99FFFFFF);
  static const likeInactiveBgDark = Color(0xFF0A1219);

  // Secondary text (timestamp etc.)
  static const secondaryLight = Color(0xFF8A9BB5);
  static const secondaryDark = Color(0xFF3D5570);

  // Particles
  static const particleColors = [
    Color(0xFF4A90D9),
    Color(0xFF7EB8E8),
    Color(0xFFB8D4F0),
    Color(0xFF2E6BB0),
    Color(0xFFFFFFFF),
  ];
}

// ---------------------------------------------------------------------------
// Bouncy curve matching cubic-bezier(0.34, 1.56, 0.64, 1)
// ---------------------------------------------------------------------------
const _bouncyCurve = Cubic(0.34, 1.56, 0.64, 1.0);

// ---------------------------------------------------------------------------
// BookFinishedCard — main widget
// ---------------------------------------------------------------------------
class BookFinishedCard extends StatefulWidget {
  final Map<String, dynamic> activity;

  const BookFinishedCard({super.key, required this.activity});

  @override
  State<BookFinishedCard> createState() => _BookFinishedCardState();
}

class _BookFinishedCardState extends State<BookFinishedCard>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final likesService = LikesService();
  final reactionsService = ReactionsService();

  // Like / reaction state
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;
  Map<String, int> _reactionCounts = {};
  List<String> _userReactions = [];
  final GlobalKey _likeButtonKey = GlobalKey();

  // Book info
  String? _bookTitle;
  String? _bookAuthor;
  String? _bookCover;

  // Book stats (loaded for own activities)
  BookReadingStats? _bookStats;
  int? _currentFlow;

  // Animation controllers
  late final AnimationController _borderController;
  late final AnimationController _revealController;
  late final AnimationController _statsController;

  // Entrance animations
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Border rotation: 6s infinite
    _borderController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    // Entrance reveal: 800ms bouncy
    _revealController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: _bouncyCurve),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOut),
    );

    // Stats pills stagger
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _revealController.forward();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _statsController.forward();
    });

    _loadLikeStatus();
    _loadReactions();
    _loadBookInfo();
    _loadBookStats();
  }

  @override
  void dispose() {
    _borderController.dispose();
    _revealController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadBookInfo() async {
    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final bookId = payload['book_id'];
    if (bookId == null) {
      final existingTitle = payload['book_title'] as String?;
      if (existingTitle != null) {
        setState(() {
          _bookTitle = existingTitle;
          _bookAuthor = payload['book_author'] as String?;
          _bookCover = payload['book_cover'] as String?;
        });
      }
      return;
    }

    try {
      final book = await supabase
          .from('books')
          .select('title, author, cover_url, page_count')
          .eq('id', bookId)
          .maybeSingle();
      if (!mounted || book == null) return;
      setState(() {
        _bookTitle = book['title'] as String?;
        _bookAuthor = book['author'] as String?;
        _bookCover = book['cover_url'] as String?;
      });
    } catch (e) {
      debugPrint('Erreur _loadBookInfo: $e');
    }
  }

  Future<void> _loadBookStats() async {
    final authorId = widget.activity['author_id'] as String?;
    final isOwn = authorId == supabase.auth.currentUser?.id;
    if (!isOwn) return;

    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    final bookId = payload?['book_id'];
    if (bookId == null) return;

    try {
      final stats =
          await ReadingSessionService().getBookStats(bookId.toString());
      if (!mounted) return;
      setState(() => _bookStats = stats);
    } catch (e) {
      debugPrint('Erreur _loadBookStats: $e');
    }

    try {
      final flow = await FlowService().getUserFlow();
      if (!mounted) return;
      setState(() => _currentFlow = flow.currentFlow);
    } catch (e) {
      debugPrint('Erreur _loadFlow: $e');
    }
  }

  Future<void> _loadLikeStatus() async {
    try {
      final activityId = widget.activity['id'] as int;
      final likeInfo = await likesService.getActivityLikeInfo(activityId);
      if (!mounted) return;
      setState(() {
        _likeCount = likeInfo['count'] as int;
        _isLiked = likeInfo['hasLiked'] as bool;
      });
    } catch (e) {
      debugPrint('Erreur _loadLikeStatus: $e');
    }
  }

  Future<void> _loadReactions() async {
    try {
      final activityId = widget.activity['id'] as int;
      final data = await reactionsService.getActivityReactions(activityId);
      if (!mounted) return;
      setState(() {
        _reactionCounts = (data['counts'] as Map<String, int>?) ?? {};
        _userReactions = (data['userReactions'] as List<String>?) ?? [];
      });
    } catch (e) {
      debugPrint('Erreur _loadReactions: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Interactions
  // ---------------------------------------------------------------------------

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    final activityId = widget.activity['id'] as int;
    final wasLiked = _isLiked;
    final previousCount = _likeCount;

    setState(() {
      _isLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (wasLiked) {
        await likesService.unlikeActivity(activityId);
      } else {
        await likesService.likeActivity(activityId);
      }
    } catch (e) {
      debugPrint('Erreur toggle like: $e');
      setState(() {
        _isLiked = wasLiked;
        _likeCount = previousCount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onLikeLongPress() {
    if (!FeatureFlags.isUnlocked(context, Feature.advancedReactions)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Les réactions avancées sont réservées aux membres Premium'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final renderBox =
        _likeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    ReactionPicker.show(
      context: context,
      anchorBox: renderBox,
      selectedReactions: _userReactions,
      onReactionSelected: _toggleReaction,
    );
  }

  Future<void> _toggleReaction(String reactionType) async {
    final activityId = widget.activity['id'] as int;
    final wasReacted = _userReactions.contains(reactionType);
    final previousCounts = Map<String, int>.from(_reactionCounts);
    final previousUserReactions = List<String>.from(_userReactions);

    setState(() {
      if (wasReacted) {
        _userReactions.remove(reactionType);
        _reactionCounts[reactionType] =
            (_reactionCounts[reactionType] ?? 1) - 1;
        if ((_reactionCounts[reactionType] ?? 0) <= 0) {
          _reactionCounts.remove(reactionType);
        }
      } else {
        _userReactions.add(reactionType);
        _reactionCounts[reactionType] =
            (_reactionCounts[reactionType] ?? 0) + 1;
      }
    });

    try {
      if (wasReacted) {
        await reactionsService.removeReaction(activityId, reactionType);
      } else {
        await reactionsService.addReaction(activityId, reactionType);
      }
    } catch (e) {
      debugPrint('Erreur toggleReaction: $e');
      setState(() {
        _reactionCounts = previousCounts;
        _userReactions = previousUserReactions;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showShareSheet() async {
    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    var bookId = payload?['book_id'] as int?;

    if (bookId == null && _bookTitle != null) {
      try {
        final userBooks = await BooksService().getUserBooks();
        final match =
            userBooks.where((b) => b.title == _bookTitle).firstOrNull;
        bookId = match?.id;
      } catch (e) {
        debugPrint('Erreur recherche livre par titre: $e');
      }
    }

    if (bookId != null) {
      try {
        final book = await BooksService().getBookById(bookId);
        final stats =
            await ReadingSessionService().getBookStats(bookId.toString());
        if (!mounted) return;
        showBookFinishedShareSheet(
          context: context,
          book: book,
          stats: stats,
        );
        return;
      } catch (e) {
        debugPrint('Erreur chargement livre pour partage: $e');
      }
    }

    // Fallback: text-only share
    final title = _bookTitle ?? 'un livre';
    final author = _bookAuthor != null ? ' de $_bookAuthor' : '';
    final shareText =
        "Je viens de terminer \"$title\"$author ! 📚✨\n\n#Lecture #ReadOn";
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    await Share.share(shareText, sharePositionOrigin: origin);
  }

  void _showDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _ActivityDetailsSheet(activity: widget.activity),
    );
  }

  Future<void> _navigateToBookDetail() async {
    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    Book? book;

    // 1) Try by book_id
    final rawId = payload['book_id'];
    if (rawId != null) {
      try {
        final row = await supabase
            .from('books')
            .select()
            .eq('id', rawId)
            .maybeSingle();
        if (row != null) book = Book.fromJson(row);
      } catch (e) {
        debugPrint('navigateToBookDetail by id failed: $e');
      }
    }

    // 2) Fallback: search by title in user's library
    if (book == null && _bookTitle != null) {
      try {
        final userBooks = await BooksService().getUserBooks();
        book = userBooks.where((b) => b.title == _bookTitle).firstOrNull;
      } catch (e) {
        debugPrint('navigateToBookDetail by title failed: $e');
      }
    }

    if (!mounted || book == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailPage(
          book: book!,
          initialStatus: 'finished',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return 'Récemment';
    try {
      final DateTime activityTime = DateTime.parse(createdAt);
      final Duration difference = DateTime.now().difference(activityTime);
      if (difference.inSeconds < 60) return 'À l\'instant';
      if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
      if (difference.inHours < 24) return 'Il y a ${difference.inHours}h';
      if (difference.inDays < 7) return 'Il y a ${difference.inDays}j';
      return 'Il y a ${(difference.inDays / 7).floor()}sem';
    } catch (e) {
      return 'Récemment';
    }
  }

  String _formatDuration(double? durationMinutes) {
    if (durationMinutes == null || durationMinutes <= 0) return '';
    final hours = (durationMinutes / 60).floor();
    final minutes = (durationMinutes % 60).round();
    if (hours > 0) return '${hours}h${minutes.toString().padLeft(2, '0')}';
    return '$minutes min';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final displayName = widget.activity['author_name'] as String?;
    final userName = displayName ??
        widget.activity['author_email'] as String? ??
        'Un ami';
    final userAvatar = widget.activity['author_avatar'] as String?;
    final authorId = widget.activity['author_id'] as String?;
    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    final createdAt = widget.activity['created_at'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwn = authorId == supabase.auth.currentUser?.id;

    final durationMinutes =
        (payload?['duration_minutes'] as num?)?.toDouble();
    final pagesRead = payload?['pages_read'] as int?;
    final endPage = payload?['end_page'] as int?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedBuilder(
        animation: _borderController,
        builder: (context, child) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: _AnimatedBorderPainter(
                angle: _borderController.value * 2 * pi,
                isDark: isDark,
              ),
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.all(2), // space for the border stroke
          decoration: BoxDecoration(
            color: isDark ? _BFColors.bgDark : _BFColors.bgLight,
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _revealController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _fadeAnim.value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Stack(
              children: [
                // Floating particles behind content
                Positioned.fill(
                  child: _FloatingParticlesWidget(isDark: isDark),
                ),

                // Main content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- Header ---
                      _buildHeader(
                        context,
                        userName: userName,
                        userAvatar: userAvatar,
                        authorId: authorId,
                        createdAt: createdAt,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 16),

                      // --- Badge pill ---
                      // --- Tappable zone: badge + hero + stats ---
                      GestureDetector(
                        onTap: _navigateToBookDetail,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? _BFColors.badgeTextDark.withValues(alpha: 0.12)
                              : _BFColors.badgeTextLight.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '🎉  LIVRE TERMINÉ',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: isDark
                                ? _BFColors.badgeTextDark
                                : _BFColors.badgeTextLight,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Hero zone: cover + glow + checkmark
                            SizedBox(
                              width: 130,
                              height: 170,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Radial glow behind cover
                                  Container(
                                    width: 130,
                                    height: 170,
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: isDark
                                            ? [
                                                _BFColors.glowStartDark
                                                    .withValues(alpha: 0.5),
                                                _BFColors.glowEndDark
                                                    .withValues(alpha: 0.0),
                                              ]
                                            : [
                                                _BFColors.glowStartLight
                                                    .withValues(alpha: 0.6),
                                                _BFColors.glowEndLight
                                                    .withValues(alpha: 0.0),
                                              ],
                                      ),
                                    ),
                                  ),

                                  // Book cover
                                  CachedBookCover(
                                    imageUrl: _bookCover,
                                    width: 100,
                                    height: 150,
                                    borderRadius: BorderRadius.circular(12),
                                  ),

                                  // Checkmark
                                  Positioned(
                                    top: 2,
                                    right: 6,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A90D9),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? _BFColors.checkBorderDark
                                              : _BFColors.checkBorderLight,
                                          width: 3,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Title
                            if (_bookTitle != null)
                              Text(
                                _bookTitle!,
                                style: GoogleFonts.libreBaskerville(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? _BFColors.titleDark
                                      : _BFColors.titleLight,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                            if (_bookAuthor != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _bookAuthor!,
                                style: GoogleFonts.libreBaskerville(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? _BFColors.authorDark
                                      : _BFColors.authorLight,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                      const SizedBox(height: 20),

                      // Stats pills
                      _buildStatsPills(
                        isDark: isDark,
                        durationMinutes: durationMinutes,
                        pagesRead: pagesRead,
                        endPage: endPage,
                        isOwn: isOwn,
                      ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // --- Footer ---
                      _buildFooter(context, isDark: isDark, isOwn: isOwn),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(
    BuildContext context, {
    required String userName,
    required String? userAvatar,
    required String? authorId,
    required String? createdAt,
    required bool isDark,
  }) {
    final secondary =
        isDark ? _BFColors.secondaryDark : _BFColors.secondaryLight;

    return Row(
      children: [
        GestureDetector(
          onTap: authorId != null
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FriendProfilePage(
                        userId: authorId,
                        initialName: userName,
                        initialAvatar: userAvatar,
                      ),
                    ),
                  )
              : null,
          child: CachedProfileAvatar(
            imageUrl: userAvatar,
            userName: userName,
            radius: 22,
            backgroundColor:
                const Color(0xFF4A90D9).withValues(alpha: 0.15),
            textColor: const Color(0xFF4A90D9),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDark ? _BFColors.titleDark : _BFColors.titleLight,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'a terminé un livre · ${_getTimeAgo(createdAt).toLowerCase()}',
                style: TextStyle(fontSize: 12, color: secondary),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _showDetails,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.more_horiz, size: 22, color: secondary),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Stats pills
  // ---------------------------------------------------------------------------

  Widget _buildStatsPills({
    required bool isDark,
    required double? durationMinutes,
    required int? pagesRead,
    required int? endPage,
    required bool isOwn,
  }) {
    final pills = <_StatPillData>[];

    // Total reading time
    if (isOwn && _bookStats != null && _bookStats!.totalMinutesRead > 0) {
      pills.add(_StatPillData(
        icon: Icons.timer_outlined,
        value: _formatDuration(_bookStats!.totalMinutesRead.toDouble()),
        label: 'total',
      ));
    } else if (durationMinutes != null && durationMinutes > 0) {
      pills.add(_StatPillData(
        icon: Icons.timer_outlined,
        value: _formatDuration(durationMinutes),
        label: 'durée',
      ));
    }

    // Pages
    if (isOwn && _bookStats != null && _bookStats!.totalPagesRead > 0) {
      pills.add(_StatPillData(
        icon: Icons.auto_stories_outlined,
        value: '${_bookStats!.totalPagesRead}',
        label: 'pages',
      ));
    } else if (endPage != null && endPage > 0) {
      pills.add(_StatPillData(
        icon: Icons.auto_stories_outlined,
        value: '$endPage',
        label: 'pages',
      ));
    } else if (pagesRead != null && pagesRead > 0) {
      pills.add(_StatPillData(
        icon: Icons.auto_stories_outlined,
        value: '$pagesRead',
        label: 'pages',
      ));
    }

    // Sessions (own only)
    if (isOwn && _bookStats != null && _bookStats!.sessionsCount > 0) {
      pills.add(_StatPillData(
        icon: Icons.repeat,
        value: '${_bookStats!.sessionsCount}',
        label: 'sessions',
      ));
    }

    // Streak / flow (own only)
    if (isOwn && _currentFlow != null && _currentFlow! > 0) {
      pills.add(_StatPillData(
        icon: Icons.local_fire_department_outlined,
        value: '$_currentFlow',
        label: 'jours',
      ));
    }

    if (pills.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _statsController,
      builder: (context, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(pills.length, (i) {
            final t = Interval(
              (i * 0.15).clamp(0.0, 0.7),
              ((i * 0.15) + 0.4).clamp(0.0, 1.0),
              curve: Curves.easeOut,
            ).transform(_statsController.value);
            return Transform.translate(
              offset: Offset(0, 10 * (1 - t)),
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: _StatPill(
                  icon: pills[i].icon,
                  value: pills[i].value,
                  label: pills[i].label,
                  isDark: isDark,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------------

  Widget _buildFooter(BuildContext context,
      {required bool isDark, required bool isOwn}) {
    final likeColor =
        isDark ? _BFColors.likeActiveDark : _BFColors.likeActiveLight;
    final secondary =
        isDark ? _BFColors.secondaryDark : _BFColors.secondaryLight;
    final btnBg = _isLiked
        ? (isDark ? _BFColors.likeActiveBgDark : _BFColors.likeActiveBgLight)
        : (isDark
            ? _BFColors.likeInactiveBgDark
            : _BFColors.likeInactiveBgLight);

    return Row(
      children: [
        // Like button
        GestureDetector(
          key: _likeButtonKey,
          onTap: _toggleLike,
          onLongPress: _onLikeLongPress,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: btnBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: _isLiked ? likeColor : secondary,
                ),
                if (_likeCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$_likeCount',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isLiked ? likeColor : secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Share button (own activity only)
        if (isOwn) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showShareSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? _BFColors.likeInactiveBgDark
                    : _BFColors.likeInactiveBgLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.share_outlined, size: 18, color: secondary),
            ),
          ),
        ],

        const Spacer(),

        if (_reactionCounts.isNotEmpty)
          ReactionSummary(
            reactionCounts: _reactionCounts,
            userReactions: _userReactions,
          ),
      ],
    );
  }
}

// =============================================================================
// Animated border painter (rotating conic gradient)
// =============================================================================
class _AnimatedBorderPainter extends CustomPainter {
  final double angle;
  final bool isDark;

  _AnimatedBorderPainter({required this.angle, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(25), // slightly larger than inner 24
    );

    final gradient = SweepGradient(
      colors: _BFColors.borderColors,
      transform: GradientRotation(angle),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.saveLayer(rect, Paint());
    canvas.drawRRect(rrect, paint);

    // Apply opacity
    final opacityPaint = Paint()
      ..color = Color.fromRGBO(
          0,
          0,
          0,
          isDark
              ? _BFColors.borderOpacityDark
              : _BFColors.borderOpacityLight);
    canvas.drawRect(rect, opacityPaint..blendMode = BlendMode.dstIn);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnimatedBorderPainter old) =>
      old.angle != angle || old.isDark != isDark;
}

// =============================================================================
// Floating particles
// =============================================================================
class _ParticleData {
  final double x; // 0..1 relative position
  final double y;
  final double size;
  final double opacity;
  final double phaseX;
  final double phaseY;
  final double amplitudeX;
  final double amplitudeY;
  final double speed; // period in seconds
  final int colorIndex;

  const _ParticleData({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.phaseX,
    required this.phaseY,
    required this.amplitudeX,
    required this.amplitudeY,
    required this.speed,
    required this.colorIndex,
  });
}

class _FloatingParticlesWidget extends StatefulWidget {
  final bool isDark;
  const _FloatingParticlesWidget({required this.isDark});

  @override
  State<_FloatingParticlesWidget> createState() =>
      _FloatingParticlesWidgetState();
}

class _FloatingParticlesWidgetState extends State<_FloatingParticlesWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ParticleData> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 7),
      vsync: this,
    )..repeat();

    final rng = Random(42); // deterministic seed for consistent layout
    _particles = List.generate(20, (i) {
      return _ParticleData(
        x: rng.nextDouble(),
        y: 0.15 + rng.nextDouble() * 0.55, // hero zone area
        size: 2.0 + rng.nextDouble() * 3.0,
        opacity: 0.15 + rng.nextDouble() * 0.45,
        phaseX: rng.nextDouble() * 2 * pi,
        phaseY: rng.nextDouble() * 2 * pi,
        amplitudeX: 2.0 + rng.nextDouble() * 2.0,
        amplitudeY: 5.0 + rng.nextDouble() * 5.0,
        speed: 3.0 + rng.nextDouble() * 4.0,
        colorIndex: rng.nextInt(_BFColors.particleColors.length),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            painter: _ParticlesPainter(
              particles: _particles,
              progress: _controller.value,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_ParticleData> particles;
  final double progress;

  _ParticlesPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = progress * (7.0 / p.speed) + p.phaseY;
      final dx = sin(t * 2 * pi + p.phaseX) * p.amplitudeX;
      final dy = sin(t * 2 * pi) * p.amplitudeY;

      final cx = p.x * size.width + dx;
      final cy = p.y * size.height + dy;

      final color =
          _BFColors.particleColors[p.colorIndex].withValues(alpha: p.opacity);
      final paint = Paint()..color = color;
      canvas.drawCircle(Offset(cx, cy), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) =>
      old.progress != progress;
}

// =============================================================================
// Stat pill
// =============================================================================
class _StatPillData {
  final IconData icon;
  final String value;
  final String label;
  const _StatPillData(
      {required this.icon, required this.value, required this.label});
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? _BFColors.pillBgDark : _BFColors.pillBgLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isDark ? _BFColors.pillBorderDark : _BFColors.pillBorderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? _BFColors.pillLabelDark : _BFColors.pillLabelLight,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color:
                  isDark ? _BFColors.pillValueDark : _BFColors.pillValueLight,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color:
                  isDark ? _BFColors.pillLabelDark : _BFColors.pillLabelLight,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Activity details sheet (reused from FriendActivityCard pattern)
// =============================================================================
class _ActivityDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityDetailsSheet({required this.activity});

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = activity['author_name'] as String?;
    final userName =
        displayName ?? activity['author_email'] as String? ?? 'Un ami';
    final payload = activity['payload'] as Map<String, dynamic>?;
    final pagesRead = payload?['pages_read'] as int?;
    final durationMinutes =
        (payload?['duration_minutes'] as num?)?.toDouble();
    final startPage = payload?['start_page'] as int?;
    final endPage = payload?['end_page'] as int?;
    final bookTitle = payload?['book_title'] as String?;
    final bookAuthor = payload?['book_author'] as String?;
    final createdAt = activity['created_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Détails',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DetailStatCard(
                  icon: Icons.menu_book,
                  value: '${pagesRead ?? 0}',
                  label: 'pages',
                  color: const Color(0xFF4A90D9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailStatCard(
                  icon: Icons.schedule,
                  value: durationMinutes != null
                      ? '${durationMinutes.round()}min'
                      : '-',
                  label: 'durée',
                  color: const Color(0xFF4A90D9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _InfoRow(icon: Icons.person, label: 'Lecteur', value: userName),
          const SizedBox(height: 12),
          if (bookTitle != null)
            _InfoRow(icon: Icons.book, label: 'Livre', value: bookTitle),
          if (bookAuthor != null) ...[
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.edit, label: 'Auteur', value: bookAuthor),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.bookmark,
            label: 'Pages',
            value: startPage != null && endPage != null
                ? 'Page $startPage → $endPage'
                : '-',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.calendar_today,
            label: 'Date',
            value: _formatDateTime(createdAt),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _DetailStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 20,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
