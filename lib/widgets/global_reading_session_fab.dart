// lib/widgets/global_reading_session_fab.dart - LIQUID GLASS DESIGN

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/books_service.dart';
import '../services/reading_session_service.dart';
import '../pages/reading/start_reading_session_page_unified.dart';
import '../pages/reading/active_reading_session_page.dart';
import '../pages/reading/add_past_session_page.dart';
import '../pages/reading/end_reading_session_page.dart';
import '../pages/books/scan_book_cover_page.dart';
import '../pages/reading/capture_passage_flow.dart';
import '../pages/books/user_books_page.dart';
import '../services/google_books_service.dart';
import '../models/book.dart';
import 'active_session_dialog.dart';
import 'cached_book_cover.dart';
import 'require_account_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../pages/chat/ai_conversations_page.dart';
import '../l10n/app_localizations.dart';

final _supabase = Supabase.instance.client;

/// FloatingActionButton global pour démarrer une session de lecture
class GlobalReadingSessionFAB extends StatelessWidget {
  const GlobalReadingSessionFAB({super.key});

  /// Scan d'une couverture puis ajout en bibliothèque.
  /// Renvoie le livre créé, ou `null` si l'utilisateur a annulé le scan ou si
  /// l'ajout a échoué. Extrait de `_scanAndStartSession` pour servir aussi de
  /// porte de sortie aux états « bibliothèque vide ».
  Future<Book?> _scanAndAddBook(BuildContext context) async {
    final GoogleBook? googleBook = await Navigator.push<GoogleBook>(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanBookCoverPage(),
      ),
    );

    if (googleBook == null || !context.mounted) return null;

    final booksService = BooksService();

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final book = await booksService.addBookFromGoogleBooks(googleBook);

      if (!context.mounted) return null;
      Navigator.pop(context); // Fermer le loading
      return book;
    } catch (e) {
      if (!context.mounted) return null;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  Future<void> _scanAndStartSession(BuildContext context) async {
    final book = await _scanAndAddBook(context);
    if (book == null || !context.mounted) return;
    await _startSession(context, book);
  }

  Future<void> _selectFromLibraryAndStart(BuildContext context) async {
    final booksService = BooksService();

    try {
      // Trié par lecture récente : le livre en cours apparaît en premier.
      final allBooks = await booksService.getUserBooksByLastRead();

      if (!context.mounted) return;

      if (allBooks.isEmpty) {
        // Bibliothèque vide : le snackbar « votre bibliothèque est vide »
        // n'offrait aucune action et le parcours mourait là. La seule suite
        // possible étant d'ajouter un livre, on y va directement.
        final book = await _scanAndAddBook(context);
        if (book == null || !context.mounted) return;
        await _startSession(context, book);
        return;
      }

      final selectedBook = await showModalBottomSheet<Book>(
        context: context,
        builder: (context) => _UnifiedBookSelectorSheet(books: allBooks),
      );

      if (selectedBook != null && context.mounted) {
        await _startSession(context, selectedBook);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _startSession(BuildContext context, Book book) async {
    // Naviguer vers StartReadingSessionPage qui prend la photo de début
    final session = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StartReadingSessionPageUnified(book: book),
      ),
    );

    if (session != null && context.mounted) {
      // Session créée, naviguer vers la page de chronomètre
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveReadingSessionPage(
            activeSession: session,
            book: book,
          ),
        ),
      );
    }
  }

  /// « J'ai lu » : saisie a posteriori d'une lecture déjà effectuée,
  /// téléphone en main APRÈS la lecture — jamais pendant. Même niveau que
  /// le démarrage de session : c'est un mode d'enregistrement à part
  /// entière, pas un mode de secours.
  ///
  /// Volontairement PAS bloqué par une session active globale : une
  /// session en cours sur un autre livre n'empêche pas de logger une
  /// lecture passée (le conflit par livre est géré dans
  /// AddPastSessionPage via _hasActiveSessionOnBook).
  Future<void> _selectBookAndLogPastRead(BuildContext context) async {
    final booksService = BooksService();

    try {
      // Trié par lecture récente : le livre en cours apparaît en premier.
      final allBooks = await booksService.getUserBooksByLastRead();

      if (!context.mounted) return;

      if (allBooks.isEmpty) {
        // Cul-de-sac : le snackbar n'offrait aucune suite. On propose
        // l'action qui débloque réellement — ajouter un livre.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).libraryEmpty),
            action: SnackBarAction(
              label: AppLocalizations.of(context).scanBookCta,
              onPressed: () async {
                final added = await _scanAndAddBook(context);
                if (added == null || !context.mounted) return;
                await _selectBookAndLogPastRead(context);
              },
            ),
          ),
        );
        return;
      }

      final selectedBook = await showModalBottomSheet<Book>(
        context: context,
        builder: (context) => _UnifiedBookSelectorSheet(books: allBooks),
      );

      if (selectedBook == null || !context.mounted) return;

      // Pré-remplir la page de départ avec la dernière page connue,
      // comme dans user_books_page (_addPastSession).
      final stats = await ReadingSessionService()
          .getBookStats(selectedBook.id.toString());

      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddPastSessionPage(
            book: selectedBook,
            initialStartPage: stats.currentPage,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ExpandableFAB(
      onCapturePassagePressed: () => capturePassage(context, source: 'fab'),
      onScanPressed: () => _handleScan(context),
      onLibraryPressed: () => _handleLibrary(context),
      onLogPastReadPressed: () => _handleLogPastRead(context),
      onAiChatPressed: () => _handleAiChat(context),
      checkActiveSession: () => _checkActiveSession(context),
    );
  }

  Future<bool> _checkActiveSession(BuildContext context) async {
    final sessionService = ReadingSessionService();

    try {
      final activeSessions = await sessionService.getAllActiveSessions();

      if (!context.mounted) return false;

      if (activeSessions.isNotEmpty) {
        final activeSession = activeSessions.first;

        // `onCancel` est un VoidCallback appelé juste après le pop du dialog :
        // on capture le Future qu'il lance pour pouvoir l'attendre ici. Sans
        // ça, abandonner la session tuait aussi l'action demandée (scanner /
        // choisir un livre) — il fallait tout recommencer depuis le FAB.
        Future<bool>? cancelFuture;

        await showDialog(
          context: context,
          builder: (context) => ActiveSessionDialog(
            activeSession: activeSession,
            onResume: () async {
              try {
                final bookId = activeSession.bookId;
                final bookData = await _supabase
                    .from('books')
                    .select()
                    .eq('id', int.parse(bookId))
                    .single();

                final book = Book.fromJson(bookData);

                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveReadingSessionPage(
                        activeSession: activeSession,
                        book: book,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            onCancel: () {
              cancelFuture = _cancelActiveSession(
                context,
                sessionService,
                activeSession.id.toString(),
              );
            },
            // Changer de livre ne devrait pas coûter la session en cours :
            // on offre de la terminer proprement, ce qui conserve le temps lu.
            onEndSession: () async {
              try {
                final bookData = await _supabase
                    .from('books')
                    .select()
                    .eq('id', int.parse(activeSession.bookId))
                    .single();
                final book = Book.fromJson(bookData);
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EndReadingSessionPage(
                      activeSession: activeSession,
                      book: book,
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        );

        // Session abandonnée : plus rien ne bloque, l'appelant poursuit.
        if (cancelFuture != null) {
          final cancelled = await cancelFuture!;
          return !cancelled;
        }
        return true; // Session active trouvée
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vérification session: $e'), backgroundColor: Colors.red),
        );
      }
      return true; // Erreur, bloquer l'action
    }

    return false; // Pas de session active
  }

  /// Abandonne la session en cours. Renvoie `true` si elle a bien été
  /// supprimée — auquel cas l'action demandée par l'utilisateur peut reprendre.
  Future<bool> _cancelActiveSession(
    BuildContext context,
    ReadingSessionService sessionService,
    String sessionId,
  ) async {
    try {
      await sessionService.cancelSession(sessionId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionAbandoned),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<void> _handleScan(BuildContext context) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await showRequireAccountSheet(context, source: 'fab_scan');
      return;
    }
    if (await _checkActiveSession(context)) return;
    if (!context.mounted) return;
    await _scanAndStartSession(context);
  }

  Future<void> _handleLibrary(BuildContext context) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await showRequireAccountSheet(context, source: 'fab_library');
      return;
    }
    if (await _checkActiveSession(context)) return;
    if (!context.mounted) return;
    await _selectFromLibraryAndStart(context);
  }

  Future<void> _handleLogPastRead(BuildContext context) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await showRequireAccountSheet(context, source: 'fab_log_past_read');
      return;
    }
    await _selectBookAndLogPastRead(context);
  }

  void _handleAiChat(BuildContext context) {
    if (Supabase.instance.client.auth.currentUser == null) {
      showRequireAccountSheet(context, source: 'fab_ai_chat');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiConversationsPage()),
    );
  }
}

/// FAB Expandable avec design Liquid Glass — utilise un Overlay pour le menu
class _ExpandableFAB extends StatefulWidget {
  final VoidCallback onCapturePassagePressed;
  final VoidCallback onScanPressed;
  final VoidCallback onLibraryPressed;
  final VoidCallback onLogPastReadPressed;
  final VoidCallback onAiChatPressed;
  final Future<bool> Function() checkActiveSession;

  const _ExpandableFAB({
    required this.onCapturePassagePressed,
    required this.onScanPressed,
    required this.onLibraryPressed,
    required this.onLogPastReadPressed,
    required this.onAiChatPressed,
    required this.checkActiveSession,
  });

  @override
  State<_ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends State<_ExpandableFAB> with TickerProviderStateMixin {
  bool _isExpanded = false;
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  // Tooltip state
  static const String _tooltipSeenKey = 'fab_tooltip_seen';
  bool _showTooltip = false;
  late AnimationController _tooltipController;
  late Animation<double> _tooltipAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.addListener(() {
      _overlayEntry?.markNeedsBuild();
    });

    _tooltipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tooltipAnimation = CurvedAnimation(
      parent: _tooltipController,
      curve: Curves.easeOutCubic,
    );
    _maybeShowTooltip();
  }

  Future<void> _maybeShowTooltip() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tooltipSeenKey) == true) return;

    // Wait for the screen to settle before showing
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    setState(() => _showTooltip = true);
    _tooltipController.forward();

    // Auto-dismiss after 4 seconds
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    _dismissTooltip();
  }

  Future<void> _dismissTooltip() async {
    if (!_showTooltip) return;
    await _tooltipController.reverse();
    if (!mounted) return;
    setState(() => _showTooltip = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tooltipSeenKey, true);
  }

  @override
  void dispose() {
    _removeOverlay();
    _animationController.dispose();
    _tooltipController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggle() {
    if (_isExpanded) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    _dismissTooltip();
    setState(() => _isExpanded = true);

    final renderBox = context.findRenderObject() as RenderBox;
    final fabOffset = renderBox.localToGlobal(Offset.zero);
    final fabSize = renderBox.size;

    _overlayEntry = _createOverlayEntry(fabOffset, fabSize);
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
  }

  void _close() {
    if (!_isExpanded) return;
    setState(() => _isExpanded = false);
    _animationController.reverse().then((_) {
      _removeOverlay();
    });
  }

  OverlayEntry _createOverlayEntry(Offset fabOffset, Size fabSize) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    // Le menu se positionne au-dessus du FAB, centré horizontalement
    final fabCenterX = fabOffset.dx + fabSize.width / 2;

    return OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        // Distance du bas de l'écran jusqu'au haut du FAB + marge
        final bottomDistance = screenHeight - fabOffset.dy + 16;

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Blur plein écran + tap pour fermer
              Positioned.fill(
                child: GestureDetector(
                  onTap: _close,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, child) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 5 * _expandAnimation.value,
                          sigmaY: 5 * _expandAnimation.value,
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
              ),
              // Options du menu positionnées au-dessus du FAB
              Positioned(
                bottom: bottomDistance,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLiquidGlassOption(
                      index: 3,
                      label: l10n.newBook,
                      icon: Icons.camera_alt_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                      onTap: () {
                        _close();
                        widget.onScanPressed();
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildLiquidGlassOption(
                      index: 2,
                      label: l10n.myLibraryFab,
                      icon: Icons.menu_book_rounded,
                      accentColor: const Color(0xFF10B981),
                      onTap: () {
                        _close();
                        widget.onLibraryPressed();
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    // « J'ai lu » : en bas du menu (le plus proche du pouce),
                    // au même niveau que le démarrage de session.
                    _buildLiquidGlassOption(
                      index: 1,
                      label: l10n.fabLogPastRead,
                      icon: Icons.check_circle_rounded,
                      accentColor: const Color(0xFFF59E0B),
                      onTap: () {
                        _close();
                        widget.onLogPastReadPressed();
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    // « Garder un passage » : l'action la plus basse, donc la
                    // plus proche du pouce. C'est la seule qui rend quelque
                    // chose à l'utilisateur sans rien lui demander en retour
                    // (ni session, ni numéro de page obligatoire).
                    _buildLiquidGlassOption(
                      index: 0,
                      label: l10n.capturePassageFab,
                      icon: Icons.format_quote_rounded,
                      accentColor: const Color(0xFF2563EB),
                      onTap: () {
                        _close();
                        widget.onCapturePassagePressed();
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    // Le FAB reste toujours 60x60, pas de changement de taille
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tooltip — shown once on first use
        if (_showTooltip)
          FadeTransition(
            opacity: _tooltipAnimation,
            child: SlideTransition(
              position: _tooltipAnimation.drive(
                Tween(begin: const Offset(0, 0.3), end: Offset.zero),
              ),
              child: GestureDetector(
                onTap: _dismissTooltip,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[900],
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    l10n.fabTooltip,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Semantics(
          identifier: 'start_session_fab',
          button: true,
          child: GestureDetector(
            onTap: _toggle,
            child: _buildMainLiquidGlassButton(isDark, context.appColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildMainLiquidGlassButton(bool isDark, Color primary) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  primary.withValues(alpha: 0.25),
                  primary.withValues(alpha: 0.12),
                ]
              : [
                  primary.withValues(alpha: 0.4),
                  primary.withValues(alpha: 0.2),
                ],
        ),
        border: Border.all(
          color: isDark
              ? primary.withValues(alpha: 0.35)
              : primary.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.15 : 0.35),
            blurRadius: 10,
            spreadRadius: -5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primary.withValues(alpha: isDark ? 0.2 : 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.menu_book_rounded,
                size: 28,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidGlassOption({
    required int index,
    required String label,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final delay = index * 0.1;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          ((_expandAnimation.value - delay) / (1.0 - delay)).clamp(0.0, 1.0),
        );

        if (progress <= 0) return const SizedBox.shrink();

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - progress)),
            child: Transform.scale(
              scale: 0.8 + (0.2 * progress),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label avec effet Liquid Glass
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.05),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.7),
                              Colors.white.withValues(alpha: 0.4),
                            ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.6),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Bouton icône avec Liquid Glass + accent coloré
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withValues(alpha: 0.8),
                        accentColor.withValues(alpha: 0.5),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Reflet en haut
                      Positioned(
                        top: 4,
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.5),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet pour sélectionner un livre (Books unifiés)
class _UnifiedBookSelectorSheet extends StatefulWidget {
  final List<Book> books;

  const _UnifiedBookSelectorSheet({required this.books});

  @override
  State<_UnifiedBookSelectorSheet> createState() => _UnifiedBookSelectorSheetState();
}

class _UnifiedBookSelectorSheetState extends State<_UnifiedBookSelectorSheet> {
  String _searchQuery = '';

  List<Book> get _filteredBooks {
    if (_searchQuery.isEmpty) return widget.books;
    return widget.books.where((book) {
      return book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (book.author?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(AppLocalizations.of(context).myLibraryFab, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const UserBooksPage()),
                  );
                },
                icon: const Icon(Icons.arrow_outward_rounded, size: 16),
                label: Text(AppLocalizations.of(context).seeAll),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            identifier: 'book_search_field',
            child: TextField(
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).searchEllipsis,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredBooks.isEmpty
                ? Center(child: Text(AppLocalizations.of(context).noBookFound))
                : ListView.builder(
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = _filteredBooks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CachedBookCover(
                            imageUrl: book.coverUrl,
                            isbn: book.isbn,
                            googleId: book.googleId,
                            title: book.title,
                            author: book.author,
                            width: 40,
                            height: 60,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: book.author != null ? Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => Navigator.pop(context, book),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

