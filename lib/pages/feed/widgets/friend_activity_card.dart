import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/likes_service.dart';
import '../../../services/reactions_service.dart';
import '../../../models/feature_flags.dart';
import '../../../providers/subscription_provider.dart';
import '../../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../widgets/reaction_picker.dart';
import '../../../widgets/reaction_summary.dart';
import '../../../widgets/cached_book_cover.dart';
import '../../../widgets/cached_profile_avatar.dart';
import '../../friends/friend_profile_page.dart';
import '../../../models/book.dart';
import '../../../models/reading_session.dart';
import '../../../services/books_service.dart';
import '../../../services/reading_session_service.dart';
import '../../reading/book_finished_share_service.dart';
import '../../sessions/session_detail_page.dart';
import '../../reading/book_completed_summary_page.dart';

class FriendActivityCard extends StatefulWidget {
  final Map<String, dynamic> activity;

  const FriendActivityCard({
    super.key,
    required this.activity,
  });

  @override
  State<FriendActivityCard> createState() => _FriendActivityCardState();
}

class _FriendActivityCardState extends State<FriendActivityCard> {
  final supabase = Supabase.instance.client;
  final likesService = LikesService();
  final reactionsService = ReactionsService();
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;

  Map<String, int> _reactionCounts = {};
  List<String> _userReactions = [];
  final GlobalKey _likeButtonKey = GlobalKey();

  String? _bookTitle;
  String? _bookAuthor;
  String? _bookCover;
  int? _bookPageCount;

  @override
  void initState() {
    super.initState();
    _loadLikeStatus();
    _loadReactions();
    _loadBookInfo();
  }

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
        _bookPageCount = book['page_count'] as int?;
      });
    } catch (e) {
      debugPrint('Erreur _loadBookInfo: $e');
    }
  }

  Future<void> _loadLikeStatus() async {
    try {
      final activityId = widget.activity['id'] as int;
      final likeInfo = await likesService.getActivityLikeInfo(activityId);
      
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

  void _onLikeLongPress() {
    if (!FeatureFlags.isUnlocked(context, Feature.advancedReactions)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les réactions avancées sont réservées aux membres Premium'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final renderBox = _likeButtonKey.currentContext?.findRenderObject() as RenderBox?;
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

    // Optimistic update
    setState(() {
      if (wasReacted) {
        _userReactions.remove(reactionType);
        _reactionCounts[reactionType] = (_reactionCounts[reactionType] ?? 1) - 1;
        if ((_reactionCounts[reactionType] ?? 0) <= 0) {
          _reactionCounts.remove(reactionType);
        }
      } else {
        _userReactions.add(reactionType);
        _reactionCounts[reactionType] = (_reactionCounts[reactionType] ?? 0) + 1;
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
      // Revert on error
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

  Future<void> _toggleLike() async {
    if (_isLoading) return;
    
    final activityId = widget.activity['id'] as int;
    final wasLiked = _isLiked;
    final previousCount = _likeCount;
    
    // Optimistic update (mise à jour immédiate de l'UI)
    setState(() {
      _isLoading = true;
      if (_isLiked) {
        _likeCount--;
        _isLiked = false;
      } else {
        _likeCount++;
        _isLiked = true;
      }
    });

    try {
      if (wasLiked) {
        await likesService.unlikeActivity(activityId);
      } else {
        await likesService.likeActivity(activityId);
      }
    } catch (e) {
      debugPrint('Erreur toggle like: $e');
      // Revert on error
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

  void _showDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ActivityDetailsSheet(activity: widget.activity),
    );
  }

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return 'Récemment';
    
    try {
      final DateTime activityTime = DateTime.parse(createdAt);
      final Duration difference = DateTime.now().difference(activityTime);

      if (difference.inSeconds < 60) {
        return 'À l\'instant';
      } else if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return 'Il y a $minutes min';
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return 'Il y a ${hours}h';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return 'Il y a ${days}j';
      } else {
        final weeks = (difference.inDays / 7).floor();
        return 'Il y a ${weeks}sem';
      }
    } catch (e) {
      return 'Récemment';
    }
  }

  bool _isBookFinished() {
    final activityType = widget.activity['type'] as String?;
    if (activityType == 'book_finished') return true;

    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    return payload?['book_finished'] == true;
  }

  String _getActivityDescription() {
    final activityType = widget.activity['type'] as String?;
    final payload = widget.activity['payload'] as Map<String, dynamic>?;

    if (_isBookFinished()) {
      return 'a terminé un livre';
    }

    if (activityType == 'reading_session' && payload != null) {
      final pagesRead = payload['pages_read'] as int?;
      if (pagesRead != null) {
        return 'a lu $pagesRead page${pagesRead > 1 ? 's' : ''}';
      }
    }

    return 'a terminé une session de lecture';
  }

  String _getShareText(String? bookTitle, String? bookAuthor) {
    final title = bookTitle ?? 'un livre';
    final author = bookAuthor != null ? ' de $bookAuthor' : '';
    if (_isBookFinished()) {
      return "Je viens de terminer \"$title\"$author ! 📚✨\n\n#Lecture #ReadOn";
    }
    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    final pagesRead = payload?['pages_read'] as int?;
    final pages = pagesRead != null ? '$pagesRead pages de ' : '';
    return "Je viens de lire $pages\"$title\"$author 📖\n\n#Lecture #ReadOn";
  }

  Future<void> _showShareSheet(String? bookTitle, String? bookAuthor) async {
    // For book_finished activities, use the rich share card
    if (_isBookFinished()) {
      final payload = widget.activity['payload'] as Map<String, dynamic>?;
      var bookId = payload?['book_id'] as int?;

      // Fallback: search by title in user's library
      if (bookId == null && bookTitle != null) {
        try {
          final userBooks = await BooksService().getUserBooks();
          final match = userBooks.where((b) => b.title == bookTitle).firstOrNull;
          bookId = match?.id;
        } catch (e) {
          debugPrint('Erreur recherche livre par titre: $e');
        }
      }

      if (bookId != null) {
        try {
          final book = await BooksService().getBookById(bookId);
          final stats = await ReadingSessionService()
              .getBookStats(bookId.toString());
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
    }

    // Fallback: text-only share
    final shareText = _getShareText(bookTitle, bookAuthor);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShareBottomSheet(
        shareText: shareText,
        bookTitle: bookTitle,
      ),
    );
  }

  void _navigateToSessionDetail() {
    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    if (payload == null) return;

    final authorId = widget.activity['author_id'] as String?;
    final createdAt = widget.activity['created_at'] as String?;
    final durationMin = (payload['duration_minutes'] as num?)?.toInt() ?? 0;

    DateTime endTime;
    try {
      endTime = createdAt != null ? DateTime.parse(createdAt).toLocal() : DateTime.now();
    } catch (_) {
      endTime = DateTime.now();
    }
    final startTime = endTime.subtract(Duration(minutes: durationMin));

    final session = ReadingSession(
      id: (payload['session_id'] ?? widget.activity['id'] ?? '').toString(),
      userId: authorId ?? '',
      bookId: (payload['book_id'] ?? '').toString(),
      startPage: payload['start_page'] as int? ?? 0,
      endPage: payload['end_page'] as int?,
      startTime: startTime,
      endTime: endTime,
      createdAt: endTime,
      updatedAt: endTime,
    );

    final bookId = payload['book_id'];
    final book = _bookTitle != null
        ? Book(
            id: bookId is int ? bookId : 0,
            title: _bookTitle!,
            author: _bookAuthor,
            coverUrl: _bookCover,
            pageCount: _bookPageCount,
          )
        : null;

    final isOwn = authorId == supabase.auth.currentUser?.id;

    // Si le livre est terminé et qu'on a un Book, ouvrir la page bilan
    if (_isBookFinished() && book != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookCompletedSummaryPage(book: book),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionDetailPage(
            session: session,
            book: book,
            isOwn: isOwn,
          ),
        ),
      );
    }
  }

  String _formatDuration(double? durationMinutes) {
    if (durationMinutes == null || durationMinutes <= 0) return '';
    final hours = (durationMinutes / 60).floor();
    final minutes = (durationMinutes % 60).round();
    if (hours > 0) return '${hours}h${minutes.toString().padLeft(2, '0')}';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.activity['author_name'] as String?;
    final userName = displayName ??
                     widget.activity['author_email'] as String? ??
                     'Un ami';
    final userAvatar = widget.activity['author_avatar'] as String?;
    final authorId = widget.activity['author_id'] as String?;
    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    final bookTitle = _bookTitle;
    final bookAuthor = _bookAuthor;
    final bookCover = _bookCover;
    final bookPageCount = _bookPageCount;
    final createdAt = widget.activity['created_at'] as String?;
    final isBookFinished = _isBookFinished();
    final pagesRead = payload?['pages_read'] as int?;
    final startPage = payload?['start_page'] as int?;
    final endPage = payload?['end_page'] as int?;
    final progressPercent = (bookPageCount != null && bookPageCount > 0 && endPage != null)
        ? (endPage / bookPageCount).clamp(0.0, 1.0)
        : null;
    final durationMinutes = (payload?['duration_minutes'] as num?)?.toDouble();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isBookFinished ? 4 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: isBookFinished
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.shade50,
                    Colors.orange.shade50,
                    Colors.pink.shade50,
                  ],
                ),
                border: Border.all(color: Colors.amber.shade300, width: 2),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBookFinished) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Livre terminé !',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
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
                      backgroundColor: isBookFinished
                          ? Colors.amber.shade100
                          : AppColors.primary.withValues(alpha: 0.15),
                      textColor: isBookFinished
                          ? Colors.amber.shade700
                          : AppColors.primary,
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
                            color: isBookFinished ? Colors.amber.shade900 : null,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${_getActivityDescription()} · ${_getTimeAgo(createdAt).toLowerCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isBookFinished
                                ? Colors.orange.shade700
                                : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showDetails,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.more_horiz, size: 22, color: muted),
                    ),
                  ),
                ],
              ),

              GestureDetector(
                onTap: _navigateToSessionDetail,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bookTitle != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CachedBookCover(
                            imageUrl: bookCover,
                            width: 80,
                            height: 110,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  bookTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    height: 1.2,
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
                                      color: muted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (progressPercent != null) ...[
                            const SizedBox(width: 10),
                            _CircularProgress(
                              percent: progressPercent,
                              color: isBookFinished ? Colors.amber.shade600 : AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ],

                    if (pagesRead != null || durationMinutes != null) ...[
                      const SizedBox(height: 14),
                      _StatsBar(
                        durationText: _formatDuration(durationMinutes),
                        pagesRead: pagesRead,
                        startPage: startPage,
                        endPage: endPage,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  GestureDetector(
                    key: _likeButtonKey,
                    onTap: _toggleLike,
                    onLongPress: _onLikeLongPress,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: _isLiked ? Colors.red : muted,
                          ),
                          if (_likeCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$_likeCount',
                              style: TextStyle(
                                fontSize: 13,
                                color: _isLiked
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (widget.activity['author_id'] == Supabase.instance.client.auth.currentUser?.id) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showShareSheet(bookTitle, bookAuthor),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.share_outlined, size: 18, color: muted),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final String durationText;
  final int? pagesRead;
  final int? startPage;
  final int? endPage;

  const _StatsBar({
    required this.durationText,
    this.pagesRead,
    this.startPage,
    this.endPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final statColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85);
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey.shade50;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.shade200;

    final stats = <Widget>[];

    if (durationText.isNotEmpty) {
      stats.add(_StatCell(
        icon: Icons.timer_outlined,
        value: durationText,
        label: 'durée',
        valueColor: statColor,
        labelColor: muted,
      ));
    }

    if (pagesRead != null && pagesRead! > 0) {
      stats.add(_StatCell(
        icon: Icons.auto_stories_outlined,
        value: '$pagesRead',
        label: 'pages',
        valueColor: statColor,
        labelColor: muted,
      ));
    }

    if (startPage != null && endPage != null) {
      stats.add(_StatCell(
        icon: Icons.bookmark_border,
        value: 'p.$startPage→$endPage',
        label: '',
        valueColor: statColor,
        labelColor: muted,
      ));
    }

    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              Expanded(child: stats[i]),
              if (i < stats.length - 1)
                VerticalDivider(width: 1, thickness: 1, color: dividerColor, indent: 4, endIndent: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: labelColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: labelColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _CircularProgress extends StatelessWidget {
  final double percent;
  final Color color;

  const _CircularProgress({
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayPercent = (percent * 100).round();
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: percent,
              strokeWidth: 3.5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$displayPercent%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final userName = displayName ?? activity['author_email'] as String? ?? 'Un ami';
    final payload = activity['payload'] as Map<String, dynamic>?;
    final pagesRead = payload?['pages_read'] as int?;
    final durationMinutes = (payload?['duration_minutes'] as num?)?.toDouble();
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
                'Détails de la session',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Stats principales
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.menu_book,
                  value: '${pagesRead ?? 0}',
                  label: 'pages',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.schedule,
                  value: durationMinutes != null 
                      ? '${durationMinutes.round()}min' 
                      : '-',
                  label: 'durée',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Infos détaillées
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ShareBottomSheet extends StatelessWidget {
  final String shareText;
  final String? bookTitle;

  const _ShareBottomSheet({
    required this.shareText,
    this.bookTitle,
  });

  Future<void> _shareToWhatsApp(BuildContext context) async {
    final text = Uri.encodeComponent(shareText);
    final url = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _shareToTwitter(BuildContext context) async {
    final text = Uri.encodeComponent(shareText);
    final url = Uri.parse('https://twitter.com/intent/tweet?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _shareToLinkedIn(BuildContext context) async {
    final text = Uri.encodeComponent(shareText);
    final url = Uri.parse('https://www.linkedin.com/sharing/share-offsite/?url=https://readon.app&summary=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _shareToMessages(BuildContext context) async {
    final text = Uri.encodeComponent(shareText);
    final url = Uri.parse('sms:?body=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _shareToMessenger(BuildContext context) async {
    final text = Uri.encodeComponent(shareText);
    final url = Uri.parse('fb-messenger://share?link=https://readon.app&quote=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await Share.share(shareText, sharePositionOrigin: origin);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.share,
                      size: 28,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Partager cette réussite',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (bookTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        bookTitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

              // Options de partage - ligne 1
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ShareOption(
                      icon: Icons.chat,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () => _shareToWhatsApp(context),
                    ),
                    _ShareOption(
                      icon: Icons.close,
                      label: 'X',
                      color: Colors.black,
                      onTap: () => _shareToTwitter(context),
                    ),
                    _ShareOption(
                      icon: Icons.work,
                      label: 'LinkedIn',
                      color: const Color(0xFF0A66C2),
                      onTap: () => _shareToLinkedIn(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Options de partage - ligne 2
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ShareOption(
                      icon: Icons.message,
                      label: 'Messages',
                      color: const Color(0xFF34C759),
                      onTap: () => _shareToMessages(context),
                    ),
                    _ShareOption(
                      icon: Icons.facebook,
                      label: 'Messenger',
                      color: const Color(0xFF0084FF),
                      onTap: () => _shareToMessenger(context),
                    ),
                    _ShareOption(
                      icon: Icons.copy,
                      label: 'Copier',
                      color: Colors.grey.shade600,
                      onTap: () => _copyToClipboard(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Bouton Annuler
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Annuler',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

