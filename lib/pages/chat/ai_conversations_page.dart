import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../models/ai_conversation.dart';
import '../../models/feature_flags.dart';
import '../../services/chat_service.dart';
import '../../providers/subscription_provider.dart';
import 'ai_chat_page.dart';
import '../../widgets/constrained_content.dart';

/// Palette du héros "Muse" — vert forêt profond, indépendante du thème
/// (le bloc reste sombre en clair comme en sombre).
const Color _heroBg = Color(0xFF22332B);
const Color _heroPanel = Color(0xFF2D4339);
const Color _heroCream = Color(0xFFF4EFE7);

class AiConversationsPage extends StatefulWidget {
  const AiConversationsPage({super.key});

  @override
  State<AiConversationsPage> createState() => _AiConversationsPageState();
}

class _AiConversationsPageState extends State<AiConversationsPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _composerController = TextEditingController();

  List<AiConversation> _conversations = [];
  String? _recentPreview;
  bool _loading = true;
  int _remaining = 0;
  bool _searchMode = false;
  bool _showAllConversations = false;

  static const int _conversationsPreviewCount = 4;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _chatService.getConversations(),
      _chatService.getRemainingMessages(),
    ]);
    final conversations = results[0] as List<AiConversation>;

    // Aperçu du dernier message de la conversation la plus récente,
    // pour la carte "RÉCENTE" (le modèle ne stocke ni couverture ni citation).
    String? preview;
    if (conversations.isNotEmpty) {
      final messages = await _chatService.getMessages(conversations.first.id);
      if (messages.isNotEmpty) {
        preview = messages.last.content.trim().replaceAll('\n', ' ');
      }
    }

    if (mounted) {
      setState(() {
        _conversations = conversations;
        _recentPreview = preview;
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

  void _startWithMessage(String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => AiChatPage(initialMessage: text),
        ))
        .then((_) => _loadConversations());
  }

  void _submitComposer() {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    final l = AppLocalizations.of(context);
    final message = _searchMode ? l.museSearchPrefix(text) : text;
    _composerController.clear();
    _startWithMessage(message);
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
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteConversation),
        content: Text(l.deleteConversationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l.deleteButton),
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
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Le héros est un en-tête FIXE (il ne défile pas) : sinon le titre
      // glisse sous la Dynamic Island quand on scrolle. Seul le contenu
      // sous le héros défile.
      body: ConstrainedContent(
        child: Column(
          children: [
            _buildHero(context, topInset),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadConversations,
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (!isPremium && !_loading) _buildRemainingBanner(isDark),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_conversations.isEmpty)
                      _buildEmptyHint(context, isDark)
                    else ...[
                      _buildRecentCard(context, isDark),
                      _buildConversationsSection(context, isDark),
                    ],
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Héros
  // ---------------------------------------------------------------------------

  Widget _buildHero(BuildContext context, double topInset) {
    final l = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpace.l,
        topInset + AppSpace.xs,
        AppSpace.l,
        AppSpace.m,
      ),
      decoration: const BoxDecoration(
        color: _heroBg,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _circleIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    color: _heroCream, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                l.museAssistantLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          // Titre + sous-titre sur une ligne de base commune pour un héros
          // plus compact et équilibré.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Muse',
                style: TextStyle(
                  color: _heroCream,
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.museHeroSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _heroCream.withValues(alpha: 0.65),
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s),
          _buildComposer(context),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              l.museComposerSubhint,
              style: TextStyle(
                color: _heroCream.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          _buildModeToggle(context),
        ],
      ),
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _heroCream.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _heroCream, size: 20),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _heroPanel,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: _heroCream.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bouton "+" : nouvelle conversation vierge
          InkWell(
            onTap: _startNewConversation,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: _heroBg, size: 22),
            ),
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: TextField(
              controller: _composerController,
              minLines: 1,
              maxLines: 4,
              cursorColor: AppColors.primary,
              style: const TextStyle(color: _heroCream, fontSize: 15),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitComposer(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: l.museComposerHint,
                hintStyle: TextStyle(
                  color: _heroCream.withValues(alpha: 0.45),
                  fontSize: 15,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s),
          InkWell(
            onTap: _submitComposer,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: _heroCream,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward, color: _heroBg, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        _modeSegment(
          icon: Icons.chat_bubble_outline,
          label: l.museModeChat,
          selected: !_searchMode,
          onTap: () => setState(() => _searchMode = false),
        ),
        const SizedBox(width: AppSpace.s),
        _modeSegment(
          icon: Icons.search,
          label: l.museModeSearch,
          selected: _searchMode,
          onTap: () => setState(() => _searchMode = true),
        ),
      ],
    );
  }

  Widget _modeSegment({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _heroCream : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? _heroCream
                : _heroCream.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? _heroBg : _heroCream.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? _heroBg : _heroCream.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bannière quota (free)
  // ---------------------------------------------------------------------------

  Widget _buildRemainingBanner(bool isDark) {
    final l = AppLocalizations.of(context);
    final used = FeatureFlags.maxFreeAiMessages - _remaining;
    final limitReached = _remaining <= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpace.m, AppSpace.m, AppSpace.m, 0),
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
                  ? l.unlimitedChatbot
                  : l.messagesUsedCount(used, FeatureFlags.maxFreeAiMessages),
              style: const TextStyle(
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

  // ---------------------------------------------------------------------------
  // Section "Récente"
  // ---------------------------------------------------------------------------

  Widget _sectionLabel(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.m, AppSpace.l, AppSpace.m, AppSpace.s),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildRecentCard(BuildContext context, bool isDark) {
    final l = AppLocalizations.of(context);
    final conv = _conversations.first;
    final timeAgo = _formatTimeAgo(conv.updatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('${l.museSectionRecent} • $timeAgo'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
          child: Material(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.l),
            child: InkWell(
              onTap: () => _openConversation(conv),
              borderRadius: BorderRadius.circular(AppRadius.l),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_stories,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: AppSpace.m),
                        Expanded(
                          child: Text(
                            conv.title ?? 'Conversation',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_recentPreview != null &&
                        _recentPreview!.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.m),
                      Text(
                        '« ${_recentPreview!} »',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13.5,
                          height: 1.4,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.m),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => _openConversation(conv),
                        style: TextButton.styleFrom(
                          backgroundColor: _heroBg,
                          foregroundColor: _heroCream,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l.museContinueConversation,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section "Conversations"
  // ---------------------------------------------------------------------------

  Widget _buildConversationsSection(BuildContext context, bool isDark) {
    final l = AppLocalizations.of(context);
    final rest = _conversations.skip(1).toList();
    if (rest.isEmpty) return const SizedBox.shrink();

    final hasMore = rest.length > _conversationsPreviewCount;
    final visible = (hasMore && !_showAllConversations)
        ? rest.take(_conversationsPreviewCount).toList()
        : rest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(
          l.museSectionConversations,
          trailing: hasMore
              ? GestureDetector(
                  onTap: () => setState(
                      () => _showAllConversations = !_showAllConversations),
                  child: Text(
                    l.museSeeAll,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0,
                    ),
                  ),
                )
              : null,
        ),
        ...visible.map((conv) => _buildConversationTile(conv, isDark)),
      ],
    );
  }

  Widget _buildEmptyHint(BuildContext context, bool isDark) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.l, AppSpace.xl, AppSpace.l, AppSpace.l),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpace.m),
          Text(
            l.noConversation,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            l.startConversationMuse,
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
    );
  }

  Widget _buildConversationTile(AiConversation conv, bool isDark) {
    final timeAgo = _formatTimeAgo(conv.updatedAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.m, 0, AppSpace.m, AppSpace.s),
      child: Dismissible(
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
          return false; // Suppression gérée manuellement
        },
        child: Material(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpace.m,
              vertical: AppSpace.xs,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
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
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => _openConversation(conv),
          ),
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
