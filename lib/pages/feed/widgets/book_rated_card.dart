// lib/pages/feed/widgets/book_rated_card.dart
//
// Carte feed pour les activités 'book_rated' : un ami a noté un livre.
// Payload attendu (émis par le trigger sync_book_rated_activity) :
//   rating_id, book_id, book_title, book_author, book_cover, book_isbn,
//   book_google_id, rating (num 0.5-5), review_text, emotion_tags (array),
//   would_recommend (bool?)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/book.dart';
import '../../../providers/subscription_provider.dart';
import '../../../services/books_service.dart';
import '../../../services/comments_service.dart';
import '../../../services/reaction_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_book_cover.dart';
import '../../../widgets/cached_profile_avatar.dart';
import '../../../widgets/rate_book_sheet.dart';
import '../../../widgets/reaction_picker.dart';
import '../../../widgets/reactions_bar.dart';
import '../../../widgets/require_account_sheet.dart';
import '../../../widgets/star_rating.dart';
import '../../books/user_books_page.dart';
import '../../friends/friend_profile_page.dart';
import 'comments_sheet.dart';

class BookRatedCard extends StatefulWidget {
  final Map<String, dynamic> activity;

  const BookRatedCard({
    super.key,
    required this.activity,
  });

  @override
  State<BookRatedCard> createState() => _BookRatedCardState();
}

class _BookRatedCardState extends State<BookRatedCard> {
  final supabase = Supabase.instance.client;
  final reactionService = ReactionService();
  final commentsService = CommentsService();

  Map<String, int> _reactionCounts = {};
  String? _userEmoji;
  int _commentCount = 0;
  bool _userHasCommented = false;

  int get _activityId =>
      (widget.activity['activity_id'] ?? widget.activity['id']) as int;

  Map<String, dynamic>? get _payload =>
      widget.activity['payload'] as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    _loadReactions();
    _loadCommentCount();
  }

  Future<void> _loadReactions() async {
    try {
      final data = await reactionService.getReactions(_activityId);
      if (!mounted) return;
      setState(() {
        _reactionCounts = (data['counts'] as Map<String, int>?) ?? {};
        _userEmoji = data['userEmoji'] as String?;
      });
    } catch (e) {
      debugPrint('Erreur _loadReactions: $e');
    }
  }

  Future<void> _loadCommentCount() async {
    final results = await Future.wait([
      commentsService.getCommentCount(_activityId),
      commentsService.hasUserCommented(_activityId),
    ]);
    if (!mounted) return;
    setState(() {
      _commentCount = results[0] as int;
      _userHasCommented = results[1] as bool;
    });
  }

  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsSheet(activityId: _activityId),
    ).then((_) => _loadCommentCount());
  }

  Future<void> _openReactionPicker() async {
    if (supabase.auth.currentUser == null) {
      await showRequireAccountSheet(context);
      return;
    }
    final sub = context.read<SubscriptionProvider>();
    final selectedEmoji = await ReactionPicker.show(
      context: context,
      currentEmoji: _userEmoji,
      isPremium: sub.isPremium,
    );
    if (selectedEmoji != null) {
      _toggleReaction(selectedEmoji);
    }
  }

  Future<void> _toggleReaction(String emoji) async {
    if (supabase.auth.currentUser == null) {
      await showRequireAccountSheet(context);
      return;
    }
    final previousCounts = Map<String, int>.from(_reactionCounts);
    final previousUserEmoji = _userEmoji;

    if (ReactionService.isPremiumEmoji(emoji)) {
      final sub = context.read<SubscriptionProvider>();
      if (!sub.isPremium) return;
    }

    setState(() {
      if (_userEmoji == emoji) {
        _reactionCounts[emoji] = (_reactionCounts[emoji] ?? 1) - 1;
        if ((_reactionCounts[emoji] ?? 0) <= 0) {
          _reactionCounts.remove(emoji);
        }
        _userEmoji = null;
      } else {
        if (_userEmoji != null) {
          _reactionCounts[_userEmoji!] = (_reactionCounts[_userEmoji!] ?? 1) - 1;
          if ((_reactionCounts[_userEmoji!] ?? 0) <= 0) {
            _reactionCounts.remove(_userEmoji!);
          }
        }
        _reactionCounts[emoji] = (_reactionCounts[emoji] ?? 0) + 1;
        _userEmoji = emoji;
      }
    });

    try {
      await reactionService.toggleReaction(_activityId, emoji,
          currentUserEmoji: previousUserEmoji);
    } catch (e) {
      debugPrint('Erreur toggleReaction: $e');
      if (mounted) {
        setState(() {
          _reactionCounts = previousCounts;
          _userEmoji = previousUserEmoji;
        });
      }
    }
  }

  Future<void> _navigateToBookDetail() async {
    final payload = _payload;
    if (payload == null) return;

    Book? book;
    final rawId = payload['book_id'];
    if (rawId != null) {
      try {
        final row =
            await supabase.from('books').select().eq('id', rawId).maybeSingle();
        if (row != null) book = Book.fromJson(row);
      } catch (e) {
        debugPrint('navigateToBookDetail by id failed: $e');
      }
    }

    if (book == null && payload['book_title'] != null) {
      try {
        final userBooks = await BooksService().getUserBooks();
        book = userBooks
            .where((b) => b.title == payload['book_title'])
            .firstOrNull;
      } catch (e) {
        debugPrint('navigateToBookDetail by title failed: $e');
      }
    }

    if (!mounted || book == null) return;

    final authorId = widget.activity['author_id'] as String?;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailPage(
          book: book!,
          sharedByUserId: authorId,
        ),
      ),
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
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays}j';
      } else {
        return 'Il y a ${(difference.inDays / 7).floor()}sem';
      }
    } catch (e) {
      return 'Récemment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payload = _payload;
    final userName = widget.activity['author_name'] as String? ??
        widget.activity['author_email'] as String? ??
        'Un ami';
    final userAvatar = widget.activity['author_avatar'] as String?;
    final authorId = widget.activity['author_id'] as String?;
    final createdAt = widget.activity['created_at'] as String?;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bookTitle = payload?['book_title'] as String?;
    final bookAuthor = payload?['book_author'] as String?;
    final rating = (payload?['rating'] as num?)?.toDouble();
    final reviewText = payload?['review_text'] as String?;
    final emotionTags = (payload?['emotion_tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final wouldRecommend = payload?['would_recommend'] as bool?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header : avatar + nom + description + temps
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
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    textColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${l10n.feedRatedBook} · ${_getTimeAgo(createdAt).toLowerCase()}',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Livre + note
            if (bookTitle != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _navigateToBookDetail,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CachedBookCover(
                      imageUrl: payload?['book_cover'] as String?,
                      isbn: payload?['book_isbn'] as String?,
                      googleId: payload?['book_google_id'] as String?,
                      title: bookTitle,
                      author: bookAuthor,
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
                              style: TextStyle(fontSize: 14, color: muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (rating != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                StarRating(rating: rating, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  rating.toStringAsFixed(
                                      rating.truncateToDouble() == rating
                                          ? 0
                                          : 1),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (wouldRecommend == true) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.thumb_up_alt_outlined,
                                      size: 13, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.feedRecommendedBadge,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Avis texte
            if (reviewText != null && reviewText.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '« ${reviewText.trim()} »',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.85),
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // Tags émotionnels
            if (emotionTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: emotionTags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(
                      emotionTagLabel(l10n, tag),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // Réactions + commentaires
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ReactionsBar(
                    reactionCounts: _reactionCounts,
                    userEmoji: _userEmoji,
                    onOpenPicker: _openReactionPicker,
                    onToggleReaction: _toggleReaction,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showCommentsSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _userHasCommented
                          ? (isDark
                              ? const Color(0xFFFFB300).withValues(alpha: 0.22)
                              : const Color(0xFFFFF3D6))
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                      border: _userHasCommented
                          ? Border.all(
                              color: const Color(0xFFFFB300)
                                  .withValues(alpha: 0.45),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _userHasCommented
                              ? Icons.chat_bubble
                              : Icons.chat_bubble_outline,
                          size: 18,
                          color: _userHasCommented
                              ? const Color(0xFFB87900)
                              : muted,
                        ),
                        if (_commentCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$_commentCount',
                            style: TextStyle(
                              fontSize: 13,
                              color: _userHasCommented
                                  ? const Color(0xFFB87900)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
