import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/ai_message.dart';
import '../../models/feature_flags.dart';
import '../../services/chat_service.dart';
import '../profile/upgrade_page.dart';

class AiChatPage extends StatefulWidget {
  final int? conversationId;
  final String? initialTitle;
  final String? initialMessage;

  const AiChatPage({
    super.key,
    this.conversationId,
    this.initialTitle,
    this.initialMessage,
  });

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<AiMessage> _messages = [];
  int? _conversationId;
  bool _loadingHistory = true;
  bool _isSending = false;
  String? _error;
  int _remainingMessages = FeatureFlags.maxFreeAiMessages;
  bool _isPremium = false;
  bool _limitReached = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _loadMessageQuota();
    if (_conversationId != null) {
      _loadMessages();
    } else {
      _loadingHistory = false;
      // Envoyer automatiquement le message initial si fourni
      if (widget.initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _sendMessage(widget.initialMessage);
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;

    final messages = await _chatService.getMessages(_conversationId!);
    if (mounted) {
      setState(() {
        _messages = messages;
        _loadingHistory = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadMessageQuota() async {
    final remaining = await _chatService.getRemainingMessages();
    if (mounted) {
      setState(() {
        _isPremium = remaining == -1;
        _remainingMessages = remaining == -1 ? 0 : remaining;
        _limitReached = !_isPremium && _remainingMessages <= 0;
      });
    }
  }

  Future<void> _sendMessage([String? prefilled]) async {
    final text = (prefilled ?? _controller.text).trim();
    if (text.isEmpty || _isSending || _limitReached) return;

    _controller.clear();
    setState(() {
      _isSending = true;
      _error = null;
      _messages.add(AiMessage(
        id: -1,
        conversationId: _conversationId ?? -1,
        role: 'user',
        content: text,
        createdAt: DateTime.now(),
      ));
    });
    _scrollToBottom();

    try {
      final result = await _chatService.sendMessage(
        conversationId: _conversationId,
        message: text,
      );

      if (mounted) {
        final newConvId = result['conversation_id'] as int?;
        final aiResponse = result['message'] as String? ?? '';

        setState(() {
          _conversationId = newConvId ?? _conversationId;
          _messages.add(AiMessage(
            id: -2,
            conversationId: _conversationId ?? -1,
            role: 'assistant',
            content: aiResponse,
            createdAt: DateTime.now(),
          ));
          _isSending = false;
        });
        _scrollToBottom();
        _loadMessageQuota();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isSending = false;
          if (_messages.isNotEmpty && _messages.last.role == 'user') {
            _messages.removeLast();
          }
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _loadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(AppSpace.m),
                          itemCount: _messages.length + (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return _buildTypingIndicator(isDark);
                            }
                            return _buildMessageBubble(
                                _messages[index], isDark);
                          },
                        ),
            ),
            if (!_isPremium) _buildMessageCounter(),
            if (_error != null) _buildErrorBanner(),
            if (_limitReached) _buildUpgradeBanner(isDark) else _buildInputBar(isDark),
          ],
        ),
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
          Expanded(
            child: Text(
              widget.initialTitle ?? 'Muse',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
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
            // Bulle d'accueil de Muse
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.m,
                vertical: AppSpace.s + 2,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.l),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                'Salut, je suis Muse, ta conseillère lecture. Qu\'as-tu envie de lire ?',
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpace.l),
            Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('Recommande-moi un roman'),
                _buildSuggestionChip('Un livre similaire à mon dernier'),
                _buildSuggestionChip('Un classique à découvrir'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 13)),
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      onPressed: () => _sendMessage(text),
    );
  }

  Widget _buildMessageBubble(AiMessage message, bool isDark) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.m,
          vertical: AppSpace.s + 2,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary
              : isDark
                  ? AppColors.surfaceDark
                  : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: [
            if (!isUser)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : isDark
                    ? AppColors.textPrimaryDark
                    : Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        child: SizedBox(
          width: 48,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1.0),
                duration: Duration(milliseconds: 600 + index * 200),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, size: 16, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCounter() {
    final used = FeatureFlags.maxFreeAiMessages - _remainingMessages;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.primary),
          const SizedBox(width: AppSpace.xs),
          Text(
            '$used/${FeatureFlags.maxFreeAiMessages} messages utilisés ce mois-ci',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeBanner(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const UpgradePage(highlightedFeature: Feature.aiChat),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          border: Border(
            top: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Text(
                'Utilisation illimitée du chatbot, abonnez-vous',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
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
                hintText: 'Demande une recommandation...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? AppColors.bgDark : AppColors.bgLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.m + 4,
                  vertical: AppSpace.s + 2,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              maxLines: 4,
              minLines: 1,
            ),
          ),
          const SizedBox(width: AppSpace.s),
          IconButton(
            onPressed: _isSending ? null : () => _sendMessage(),
            icon: Icon(
              Icons.send_rounded,
              color: _isSending
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
