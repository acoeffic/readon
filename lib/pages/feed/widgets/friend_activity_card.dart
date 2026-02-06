// pages/feed/widgets/friend_activity_card.dart
// Card pour afficher l'activité d'un ami avec likes et détails

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/comments_service.dart';
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

  // Réactions avancées (premium)
  Map<String, int> _reactionCounts = {};
  List<String> _userReactions = [];
  final GlobalKey _likeButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadLikeStatus();
    _loadReactions();
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

/*
  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CommentsSheet(activityId: widget.activity['id'] as int),
    );
  }
*/

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
    return "Je viens de terminer \"$title\"$author ! 📚✨\n\n#Lecture #BookFinished #ReadOn";
  }

  void _showShareSheet(String? bookTitle, String? bookAuthor) {
    final shareText = _getShareText(bookTitle, bookAuthor);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShareBottomSheet(
        shareText: shareText,
        bookTitle: bookTitle,
      ),
    );
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
    final bookTitle = payload?['book_title'] as String?;
    final bookAuthor = payload?['book_author'] as String?;
    final bookCover = payload?['book_cover'] as String?;
    final createdAt = widget.activity['created_at'] as String?;
    final isBookFinished = _isBookFinished();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isBookFinished ? 4 : 1,
      child: Container(
        decoration: isBookFinished
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.shade50,
                    Colors.orange.shade50,
                    Colors.pink.shade50,
                  ],
                ),
                border: Border.all(
                  color: Colors.amber.shade300,
                  width: 2,
                ),
              )
            : null,
        child: InkWell(
          onTap: _showDetails,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge "Livre terminé" si applicable
                if (isBookFinished) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber.shade400, Colors.orange.shade400],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha:0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Livre terminé!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.celebration, color: Colors.amber.shade600, size: 24),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              // Header: Avatar + Nom + Temps
              GestureDetector(
                onTap: authorId != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FriendProfilePage(
                              userId: authorId,
                              initialName: userName,
                              initialAvatar: userAvatar,
                            ),
                          ),
                        );
                      }
                    : null,
                child: Row(
                  children: [
                    Container(
                      decoration: isBookFinished
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.amber.shade400,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha:0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            )
                          : null,
                      child: CachedProfileAvatar(
                        imageUrl: userAvatar,
                        userName: userName,
                        radius: 20,
                        backgroundColor: isBookFinished
                            ? Colors.amber.shade100
                            : AppColors.primary.withValues(alpha: 0.2),
                        textColor: isBookFinished
                            ? Colors.amber.shade700
                            : AppColors.primary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isBookFinished ? Colors.amber.shade900 : null,
                            ),
                          ),
                          Text(
                            _getTimeAgo(createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: isBookFinished
                                  ? Colors.orange.shade700
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),

              // Description
              Row(
                children: [
                  if (isBookFinished)
                    Icon(Icons.auto_awesome, color: Colors.amber.shade700, size: 18),
                  if (isBookFinished) const SizedBox(width: 6),
                  Text(
                    _getActivityDescription(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isBookFinished
                          ? Colors.amber.shade900
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: isBookFinished ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),

              // Détails du livre
              if (bookTitle != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isBookFinished
                        ? Theme.of(context).cardColor
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isBookFinished
                          ? Colors.amber.shade300
                          : Theme.of(context).dividerColor,
                      width: isBookFinished ? 2 : 1,
                    ),
                    boxShadow: isBookFinished
                        ? [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha:0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Couverture du livre
                      CachedBookCover(
                        imageUrl: bookCover,
                        width: 50,
                        height: 70,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Infos du livre
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bookTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (bookAuthor != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                bookAuthor,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (payload != null) ...[
                              const SizedBox(height: 8),
                              _buildSessionDetails(payload),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 12),

              // Réactions avancées (premium)
              if (_reactionCounts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ReactionSummary(
                    reactionCounts: _reactionCounts,
                    userReactions: _userReactions,
                  ),
                ),

              // Actions: Like + Partage + Détails
              Row(
                children: [
                  // Bouton Like (tap = like, long press = réactions premium)
                  GestureDetector(
                    key: _likeButtonKey,
                    onTap: _toggleLike,
                    onLongPress: _onLikeLongPress,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: _isLiked ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          if (_likeCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$_likeCount',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Bouton partage (seulement pour l'auteur de l'activité)
                  if (isBookFinished && widget.activity['author_id'] == Supabase.instance.client.auth.currentUser?.id)
                    InkWell(
                      onTap: () => _showShareSheet(bookTitle, bookAuthor),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(
                          Icons.share_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Bouton Voir plus
                  TextButton.icon(
                    onPressed: _showDetails,
                    icon: Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    label: Text(
                      'Détails',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildSessionDetails(Map<String, dynamic> payload) {
    final pagesRead = payload['pages_read'] as int?;
    final durationMinutes = (payload['duration_minutes'] as num?)?.toDouble();

    final List<Widget> chips = [];

    if (pagesRead != null && pagesRead > 0) {
      chips.add(
        _DetailChip(
          icon: Icons.menu_book,
          label: '$pagesRead page${pagesRead > 1 ? 's' : ''}',
        ),
      );
    }

    if (durationMinutes != null && durationMinutes > 0) {
      final hours = (durationMinutes / 60).floor();
      final minutes = (durationMinutes % 60).round();
      
      String timeText;
      if (hours > 0) {
        timeText = '${hours}h${minutes}min';
      } else {
        timeText = '${minutes}min';
      }
      
      chips.add(
        _DetailChip(
          icon: Icons.schedule,
          label: timeText,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: chips,
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.3)
            : AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.7)
                : AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.7)
                  : AppColors.primary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Bottom Sheet avec détails complets de l'activité
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
    } else {
      // Fallback vers le web
      final webUrl = Uri.parse('https://www.facebook.com/dialog/send?link=https://readon.app&app_id=YOUR_APP_ID&redirect_uri=https://readon.app');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Share.share(shareText);
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

/*
// Bottom sheet pour les commentaires
class _CommentsSheet extends StatefulWidget {
  final int activityId;

  const _CommentsSheet({required this.activityId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentsService = CommentsService();
  final _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    
    try {
      final comments = await _commentsService.getComments(widget.activityId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    setState(() => _isPosting = true);
    
    try {
      final comment = await _commentsService.addComment(
        activityId: widget.activityId,
        content: _commentController.text,
      );
      
      if (comment != null) {
        setState(() {
          _comments.add(comment);
          _commentController.clear();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Commentaires',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          const Divider(),
          
          // Liste des commentaires
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.comment_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun commentaire',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Soyez le premier à commenter!',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _CommentItem(comment: comment);
                        },
                      ),
          ),
          
          const Divider(),
          
          // Input commentaire
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Écrivez un commentaire...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isPosting ? null : _postComment,
                icon: _isPosting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                color: AppColors.primary,
                iconSize: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;

  const _CommentItem({required this.comment});

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: comment.authorAvatar != null && comment.authorAvatar!.isNotEmpty
                ? NetworkImage(comment.authorAvatar!)
                : null,
            child: comment.authorAvatar == null || comment.authorAvatar!.isEmpty
                ? Text(
                    comment.displayName[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}*/
