import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/ai_conversation.dart';
import '../../models/feature_flags.dart';
import '../../services/chat_service.dart';
import '../../providers/subscription_provider.dart';
import 'ai_chat_page.dart';

class AiConversationsPage extends StatefulWidget {
  const AiConversationsPage({super.key});

  @override
  State<AiConversationsPage> createState() => _AiConversationsPageState();
}

class _AiConversationsPageState extends State<AiConversationsPage> {
  final ChatService _chatService = ChatService();
  List<AiConversation> _conversations = [];
  bool _loading = true;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _chatService.getConversations(),
      _chatService.getRemainingMessages(),
    ]);
    if (mounted) {
      setState(() {
        _conversations = results[0] as List<AiConversation>;
        _remaining = results[1] as int;
        _loading = false;
      });
    }
  }

  void _startNewConversation() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AiChatPage()))
        .then((_) => _loadConversations());
  }

  void _openConversation(AiConversation conv) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => AiChatPage(
            conversationId: conv.id,
            initialTitle: conv.title,
          ),
        ))
        .then((_) => _loadConversations());
  }

  Future<void> _deleteConversation(AiConversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la conversation'),
        content: const Text('Es-tu sûr de vouloir supprimer cette conversation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatService.deleteConversation(conv.id);
      _loadConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (!isPremium && !_loading) _buildRemainingBanner(isDark),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _conversations.isEmpty
                      ? _buildEmptyState(context)
                      : RefreshIndicator(
                          onRefresh: _loadConversations,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.m,
                              vertical: AppSpace.s,
                            ),
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              return _buildConversationTile(
                                _conversations[index],
                                isDark,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewConversation,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle conversation'),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s,
        vertical: AppSpace.xs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpace.s),
          const Icon(Icons.auto_awesome, color: AppColors.primary),
          const SizedBox(width: AppSpace.s),
          Text(
            'Muse',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingBanner(bool isDark) {
    final used = FeatureFlags.maxFreeAiMessages - _remaining;
    final limitReached = _remaining <= 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.m),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Row(
        children: [
          Icon(
            limitReached ? Icons.lock : Icons.info_outline,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Text(
              limitReached
                  ? 'Utilisation illimitée du chatbot, abonnez-vous'
                  : '$used/${FeatureFlags.maxFreeAiMessages} messages utilisés ce mois-ci',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpace.l),
            Text(
              'Aucune conversation',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s),
            Text(
              'Démarre une conversation avec Muse pour obtenir des recommandations de livres personnalisées.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(AiConversation conv, bool isDark) {
    final timeAgo = _formatTimeAgo(conv.updatedAt);

    return Dismissible(
      key: Key('conv-${conv.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.l),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteConversation(conv);
        return false; // We handle deletion manually
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpace.s),
        elevation: 0,
        color: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.m,
            vertical: AppSpace.xs,
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.chat_bubble_outline,
                color: AppColors.primary, size: 20),
          ),
          title: Text(
            conv.title ?? 'Conversation',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            timeAgo,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _openConversation(conv),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${date.day}/${date.month}/${date.year}';
  }
}
