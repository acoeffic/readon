import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/comments_service.dart';
import '../../../services/moderation_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_profile_avatar.dart';
import '../../../widgets/report_sheet.dart';
import '../../../widgets/require_account_sheet.dart';

class CommentsSheet extends StatefulWidget {
  final int activityId;

  const CommentsSheet({super.key, required this.activityId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentsService = CommentsService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  Comment? _replyingTo;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final comments = await _commentsService.getComments(widget.activityId);
    if (!mounted) return;
    setState(() {
      _comments = _sortThreaded(comments);
      _isLoading = false;
    });
  }

  /// Ordonne les commentaires en threads : les commentaires racine par ordre
  /// chronologique, chacun suivi de ses réponses (chronologiques).
  List<Comment> _sortThreaded(List<Comment> comments) {
    final byId = {for (final c in comments) c.id: c};

    String rootOf(Comment c) {
      var current = c;
      final seen = <String>{};
      while (current.parentId != null &&
          byId.containsKey(current.parentId) &&
          seen.add(current.id)) {
        current = byId[current.parentId]!;
      }
      return current.id;
    }

    final grouped = <String, List<Comment>>{};
    final rootOrder = <String>[];
    for (final c in comments) {
      final root = rootOf(c);
      if (!grouped.containsKey(root)) {
        grouped[root] = [];
        rootOrder.add(root);
      }
      grouped[root]!.add(c);
    }
    return [for (final root in rootOrder) ...grouped[root]!];
  }

  Future<void> _sendComment() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await showRequireAccountSheet(context);
      return;
    }
    final content = _controller.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final comment = await _commentsService.addComment(
      activityId: widget.activityId,
      content: content,
      parentId: _replyingTo?.id,
    );

    if (!mounted) return;

    if (comment != null) {
      _controller.clear();
      setState(() {
        _comments = _sortThreaded([..._comments, comment]);
        _replyingTo = null;
        _isSending = false;
      });
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.commentBeingValidated),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _isSending = false);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a ${weeks}sem';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    l10n.comments,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_comments.where((c) => c.isApproved).isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${_comments.where((c) => c.isApproved).length}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // Comments list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? _buildEmptyState(l10n)
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            return _buildCommentTile(_comments[index], isDark, l10n);
                          },
                        ),
            ),

            // Bandeau "Réponse à X"
            if (_replyingTo != null) _buildReplyBanner(isDark, l10n),

            // Input bar
            _buildInputBar(isDark, l10n),
            SizedBox(height: keyboardHeight),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noCommentsYet,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.beFirstToComment,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Comment comment, bool isDark, AppLocalizations l10n) {
    final isOwnPending =
        comment.isPending && comment.authorId == _currentUserId;
    final isOwn = comment.authorId == _currentUserId;

    return InkWell(
      // Long-press → menu modération (Apple §1.2). Désactivé pour ses
      // propres commentaires (rien à signaler).
      onLongPress: isOwn ? null : () => _showCommentActions(comment, l10n),
      child: Padding(
      padding: EdgeInsets.only(
        left: comment.isReply ? 52 : 16,
        right: 16,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedProfileAvatar(
            imageUrl: comment.authorAvatar,
            userName: comment.displayName,
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            textColor: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getTimeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    if (isOwnPending) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.commentPending,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
                if (comment.isApproved) ...[
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () {
                      setState(() => _replyingTo = comment);
                      _focusNode.requestFocus();
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 2),
                      child: Text(
                        l10n.replyAction,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _showCommentActions(Comment comment, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: Text(l10n.reportCommentAction),
              onTap: () {
                Navigator.pop(ctx);
                showReportSheet(
                  context,
                  targetType: ReportTargetType.comment,
                  targetId: comment.id.toString(),
                  targetUserId: comment.authorId,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text(l10n.blockUserAction),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await ModerationService().blockUser(comment.authorId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? l10n.userBlockedMessage
                        : l10n.blockUserErrorMessage),
                    backgroundColor:
                        ok ? AppColors.primary : Colors.red.shade700,
                  ),
                );
                if (ok) {
                  setState(() {
                    _comments.removeWhere((c) => c.authorId == comment.authorId);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.cancel),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBanner(bool isDark, AppLocalizations l10n) {
    final replyingTo = _replyingTo;
    if (replyingTo == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.replyingTo(replyingTo.displayName),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => setState(() => _replyingTo = null),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, AppLocalizations l10n) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: l10n.writeComment,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor:
                      isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
                maxLines: 3,
                minLines: 1,
                maxLength: 500,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        required maxLength}) =>
                    null,
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            IconButton(
              onPressed: _isSending ? null : _sendComment,
              icon: Icon(
                Icons.send_rounded,
                color: _isSending
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
