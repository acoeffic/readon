import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/ai_message.dart';
import '../../models/feature_flags.dart';
import '../../services/books_service.dart';
import '../../services/chat_service.dart' show ChatService, ChatLimitReachedException;
import '../../services/google_books_service.dart';
import '../../services/user_custom_lists_service.dart';
import '../../models/user_custom_list.dart';
import '../profile/upgrade_page.dart';
import '../curated_lists/create_custom_list_dialog.dart';

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
  final GoogleBooksService _googleBooksService = GoogleBooksService();
  final BooksService _booksService = BooksService();
  final UserCustomListsService _customListsService = UserCustomListsService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  /// Regex pour détecter les mentions de livres : "Titre" de Auteur
  static final RegExp _bookMentionRegex = RegExp(
    r""""([^"]+)"\s+d[e']\s*([^.,;!?\n(]+)""",
  );

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
    } on ChatLimitReachedException {
      if (mounted) {
        setState(() {
          _isSending = false;
          _limitReached = true;
          _remainingMessages = 0;
          if (_messages.isNotEmpty && _messages.last.role == 'user') {
            _messages.removeLast();
          }
        });
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
                  : _limitReached && _messages.isEmpty
                      ? _buildLimitReachedState(context)
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
            if (!_isPremium && !_limitReached) _buildMessageCounter(),
            if (_error != null) _buildErrorBanner(),
            if (!_limitReached) _buildInputBar(isDark),
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

  Widget _buildLimitReachedState(BuildContext context) {
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.l,
                vertical: AppSpace.m,
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
              child: Column(
                children: [
                  Text(
                    'Tu as utilisé tes ${FeatureFlags.maxFreeAiMessages} messages gratuits ce mois-ci',
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s),
                  Text(
                    'Abonne-toi pour discuter sans limite avec Muse !',
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.l),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UpgradePage(highlightedFeature: Feature.aiChat),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: const Text(
                  'Découvrir l\'abonnement',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
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
    final textColor = isUser
        ? Colors.white
        : isDark
            ? AppColors.textPrimaryDark
            : Colors.black87;

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
        child: isUser
            ? Text(
                message.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              )
            : _buildRichMessageText(message.content, textColor),
      ),
    );
  }

  /// Construit un RichText qui rend les mentions de livres ("Titre" de Auteur) cliquables
  Widget _buildRichMessageText(String content, Color textColor) {
    final matches = _bookMentionRegex.allMatches(content).toList();
    if (matches.isEmpty) {
      return Text(
        content,
        style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Texte avant le match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
        ));
      }

      final title = match.group(1)!.trim();
      final author = match.group(2)!.trim();
      final fullMatch = match.group(0)!;

      spans.add(TextSpan(
        text: fullMatch,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary.withValues(alpha: 0.4),
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _onBookMentionTap(title, author),
      ));

      lastEnd = match.end;
    }

    // Texte après le dernier match
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
        children: spans,
      ),
    );
  }

  /// Recherche un livre sur Google Books et affiche le bottom sheet
  void _onBookMentionTap(String title, String author) async {
    // Afficher un loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      GoogleBook? googleBook;

      // 1) Recherche par titre + auteur
      final results = await _googleBooksService.searchByTitleAuthor(title, author);
      if (results.isNotEmpty) googleBook = results.first;

      // 2) Fallback : recherche libre
      if (googleBook == null) {
        final freeResults = await _googleBooksService.searchBooks('$title $author');
        if (freeResults.isNotEmpty) googleBook = freeResults.first;
      }

      // 3) Objet minimal si rien trouvé
      googleBook ??= GoogleBook(
        id: 'chat-${title.hashCode}',
        title: title,
        authors: [author],
        isbns: [],
      );

      if (!mounted) return;
      Navigator.pop(context); // Fermer le loading
      _showBookDetailSheet(googleBook);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fermer le loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de charger le livre : $e')),
        );
      }
    }
  }

  void _showBookDetailSheet(GoogleBook googleBook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (googleBook.coverUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        googleBook.coverUrl!,
                        width: 100,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderCover(),
                      ),
                    )
                  else
                    _buildPlaceholderCover(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          googleBook.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          googleBook.authorsString,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        if (googleBook.pageCount != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${googleBook.pageCount} pages',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                        if (googleBook.genre != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              googleBook.genre!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showAddToListSheet(googleBook);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.playlist_add,
                                    size: 14, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Ajouter à une liste',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (googleBook.description != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  googleBook.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildBuyOption(
                      context: ctx,
                      emoji: '📖',
                      label: 'En librairie',
                      onTap: () {
                        final query = Uri.encodeComponent(
                          '${googleBook.title} ${googleBook.authorsString}'.trim(),
                        );
                        launchUrl(
                          Uri.parse('https://www.leslibraires.fr/recherche?q=$query'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                    Divider(height: 1, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.08)),
                    _buildBuyOption(
                      context: ctx,
                      emoji: '🏪',
                      label: 'Trouver près de moi',
                      onTap: () => _openNearbyBookstores(ctx),
                    ),
                    Divider(height: 1, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.08)),
                    _buildBuyOption(
                      context: ctx,
                      emoji: '📦',
                      label: 'Amazon',
                      onTap: () {
                        final query = Uri.encodeComponent(
                          '${googleBook.title} ${googleBook.authorsString}'.trim(),
                        );
                        launchUrl(
                          Uri.parse('https://www.amazon.fr/s?k=$query&i=stripbooks&tag=lexday-21'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToListSheet(GoogleBook googleBook) async {
    try {
      final book = await _booksService.findOrCreateBook(googleBook);

      final results = await Future.wait([
        _customListsService.getUserLists(),
        _customListsService.getListIdsContainingBook(book.id),
      ]);

      final lists = results[0] as List<UserCustomList>;
      final containingIds = results[1] as Set<int>;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _ChatAddToListSheet(
          lists: lists,
          containingIds: containingIds,
          bookId: book.id,
          service: _customListsService,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openNearbyBookstores(BuildContext parentContext) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(content: Text('Activez la localisation dans les réglages')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(content: Text('Accès à la localisation requis')),
        );
        return;
      }

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final url = Uri.parse(
        'https://www.google.com/maps/search/librairie/@${position.latitude},${position.longitude},14z',
      );
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Geolocation error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text('Erreur localisation: $e')),
      );
    }
  }

  Widget _buildBuyOption({
    required BuildContext context,
    required String emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 20)),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 100,
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.book, size: 32,
          color: AppColors.primary.withValues(alpha: 0.4)),
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

class _ChatAddToListSheet extends StatefulWidget {
  final List<UserCustomList> lists;
  final Set<int> containingIds;
  final int bookId;
  final UserCustomListsService service;

  const _ChatAddToListSheet({
    required this.lists,
    required this.containingIds,
    required this.bookId,
    required this.service,
  });

  @override
  State<_ChatAddToListSheet> createState() => _ChatAddToListSheetState();
}

class _ChatAddToListSheetState extends State<_ChatAddToListSheet> {
  late Set<int> _containingIds;

  @override
  void initState() {
    super.initState();
    _containingIds = Set<int>.from(widget.containingIds);
  }

  Future<void> _toggleList(UserCustomList list) async {
    final wasInList = _containingIds.contains(list.id);
    setState(() {
      if (wasInList) {
        _containingIds.remove(list.id);
      } else {
        _containingIds.add(list.id);
      }
    });

    try {
      if (wasInList) {
        await widget.service.removeBookFromList(list.id, widget.bookId);
      } else {
        await widget.service.addBookToList(list.id, widget.bookId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (wasInList) {
            _containingIds.add(list.id);
          } else {
            _containingIds.remove(list.id);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createNewList() async {
    Navigator.pop(context);
    final result = await showCreateCustomListSheet(context);
    if (result != null) {
      try {
        await widget.service.addBookToList(result.id, widget.bookId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ajouté à "${result.title}"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur ajout à nouvelle liste: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Ajouter à une liste',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (widget.lists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Aucune liste personnelle.',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ...widget.lists.map((list) {
              final isInList = _containingIds.contains(list.id);
              final gradientColors = list.gradientColors;
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(list.icon, size: 18, color: Colors.white),
                ),
                title: Text(list.title),
                trailing: Icon(
                  isInList ? Icons.check_circle : Icons.circle_outlined,
                  color: isInList ? AppColors.primary : null,
                ),
                onTap: () => _toggleList(list),
              );
            }),
          const Divider(),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, size: 18, color: AppColors.primary),
            ),
            title: const Text(
              'Créer une nouvelle liste',
              style: TextStyle(color: AppColors.primary),
            ),
            onTap: _createNewList,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
