// pages/feed/widgets/friend_activity_card.dart
// Card pour afficher l'activité d'un ami avec likes et détails

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/comments_service.dart';
import '../../../services/likes_service.dart';

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
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLikeStatus();
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
      print('Erreur _loadLikeStatus: $e');
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
      print('Erreur toggle like: $e');
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

  String _getActivityDescription() {
    final activityType = widget.activity['type'] as String?;
    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    
    if (activityType == 'reading_session' && payload != null) {
      final pagesRead = payload['pages_read'] as int?;
      if (pagesRead != null) {
        return 'a lu $pagesRead page${pagesRead > 1 ? 's' : ''}';
      }
    }
    
    return 'a terminé une session de lecture';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.activity['author_name'] as String?;
    final userName = displayName ?? 
                     widget.activity['author_email'] as String? ?? 
                     'Un ami';
    final userAvatar = widget.activity['author_avatar'] as String?;
    final payload = widget.activity['payload'] as Map<String, dynamic>?;
    final bookTitle = payload?['book_title'] as String?;
    final bookAuthor = payload?['book_author'] as String?;
    final bookCover = payload?['book_cover'] as String?;
    final createdAt = widget.activity['created_at'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _showDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar + Nom + Temps
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.deepPurple.shade100,
                    backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                        ? NetworkImage(userAvatar)
                        : null,
                    child: userAvatar == null || userAvatar.isEmpty
                        ? Text(
                            userName[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getTimeAgo(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Description
              Text(
                _getActivityDescription(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              
              // Détails du livre
              if (bookTitle != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      // Couverture du livre
                      if (bookCover != null && bookCover.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            bookCover,
                            width: 50,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 70,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.book, size: 30),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          width: 50,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.book, size: 30),
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
                                  color: Colors.grey.shade600,
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
              
              // Actions: Like + Commenter + Voir détails
              Row(
                children: [
                  // Bouton Like
                  InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: _isLiked ? Colors.red : Colors.grey.shade600,
                          ),
                          if (_likeCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$_likeCount',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Bouton Commenter
                  InkWell(
                    onTap: _showComments,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.comment_outlined, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Commenter',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Bouton Voir plus
                  TextButton.icon(
                    onPressed: _showDetails,
                    icon: Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                    label: Text(
                      'Détails',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.deepPurple.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.deepPurple.shade700,
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
        color: color.withOpacity(0.1),
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
              color: Colors.grey.shade600,
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
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
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
                color: Colors.deepPurple,
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
            backgroundColor: Colors.deepPurple.shade100,
            backgroundImage: comment.authorAvatar != null && comment.authorAvatar!.isNotEmpty
                ? NetworkImage(comment.authorAvatar!)
                : null,
            child: comment.authorAvatar == null || comment.authorAvatar!.isEmpty
                ? Text(
                    comment.displayName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
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
}