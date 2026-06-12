// lib/pages/reading/end_reading_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/reading_session_service.dart';
import '../../services/ocr_service.dart';
import '../../services/books_service.dart';
import 'package:lexday/features/badges/services/badges_service.dart';
import '../../services/flow_service.dart';
import '../../services/lexday_sync_service.dart';
import '../../models/reading_session.dart';
import '../../models/reading_flow.dart';
import 'package:lexday/features/badges/widgets/badge_unlocked_dialog.dart';
import '../../widgets/cached_book_cover.dart';
import '../../models/book.dart';
import 'reading_session_summary_page.dart';
import 'book_completed_summary_page.dart';
import '../../theme/app_theme.dart';
import '../../services/contacts_service.dart';
import '../../providers/connectivity_provider.dart';
import '../friends/contacts_suggestion_page.dart';
import '../chat/ai_chat_page.dart';
import '../../services/widget_service.dart';
import '../../widgets/constrained_content.dart';

const _kBgColor = Color(0xFFFAF3E8);
const _kSageGreen = Color(0xFF6B988D);
const _kGold = Color(0xFFC6A85A);
const _kFallbackHeroColor = Color(0xFF2a3a5a);
const _kBackBtnColor = Color(0xFFF0E8D8);

class EndReadingSessionPage extends StatefulWidget {
  final ReadingSession activeSession;
  final Book? book; // Optionnel, pour la page de résumé

  const EndReadingSessionPage({
    super.key,
    required this.activeSession,
    this.book,
  });

  @override
  State<EndReadingSessionPage> createState() => _EndReadingSessionPageState();
}

class _EndReadingSessionPageState extends State<EndReadingSessionPage> {
  final ReadingSessionService _sessionService = ReadingSessionService();
  final BooksService _booksService = BooksService();
  final BadgesService _badgesService = BadgesService();
  final FlowService _flowService = FlowService();
  final ImagePicker _picker = ImagePicker();

  XFile? _imageFile;
  int? _detectedPageNumber;
  bool _isProcessing = false;
  String? _errorMessage;
  int? _manualPageNumber;
  bool _showFinishBookAnimation = false;
  final TextEditingController _manualPageController = TextEditingController();
  final FocusNode _pageFocusNode = FocusNode();
  Book? _book;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    if (_book == null) {
      _loadBook();
    }
    _pageFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadBook() async {
    try {
      final bookId = int.tryParse(widget.activeSession.bookId);
      if (bookId == null) return;
      final bookData = await Supabase.instance.client
          .from('books')
          .select()
          .eq('id', bookId)
          .maybeSingle();
      if (!mounted || bookData == null) return;
      setState(() => _book = Book.fromJson(bookData));
    } catch (_) {}
  }

  @override
  void dispose() {
    _sessionService.dispose();
    _manualPageController.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      setState(() {
        _errorMessage = null;
        _detectedPageNumber = null;
      });

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo == null) return;

      await _processImage(photo);
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.errorCapture(e.toString());
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() {
        _errorMessage = null;
        _detectedPageNumber = null;
      });

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (photo == null) return;

      await _processImage(photo);
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.errorSelection(e.toString());
      });
    }
  }

  Future<void> _processImage(XFile photo) async {
    setState(() {
      _imageFile = photo;
      _isProcessing = true;
    });

    try {
      final ocrService = OCRService();
      final pageNumber = await ocrService.extractPageNumber(photo.path);

      setState(() {
        _detectedPageNumber = pageNumber;
        _isProcessing = false;
        if (pageNumber != null) {
          _manualPageController.text = pageNumber.toString();
          _manualPageNumber = pageNumber;
        }
      });

      if (pageNumber == null) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.pageNotDetected;
        });
      } else if (pageNumber < widget.activeSession.startPage) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.endPageBeforeStartDetailed(pageNumber, widget.activeSession.startPage);
          _detectedPageNumber = null;
          _manualPageNumber = null;
          _manualPageController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = AppLocalizations.of(context)!.ocrError(e.toString());
      });
    }
  }

  Future<void> _endSession() async {
    final pageNumber = _detectedPageNumber ?? _manualPageNumber;

    if (pageNumber == null) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.captureOrEnterPage;
      });
      return;
    }

    if (pageNumber < widget.activeSession.startPage) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.endPageBeforeStart;
      });
      return;
    }

    setState(() => _isProcessing = true);

    final isOffline = !Provider.of<ConnectivityProvider>(context, listen: false).isOnline;

    try {
      final completedSession = await _sessionService.endSession(
        sessionId: widget.activeSession.id,
        imagePath: _imageFile?.path,
        manualPageNumber: pageNumber,
        offlineMode: isOffline,
        activeSession: widget.activeSession,
      );

      if (!mounted) return;

      // En mode offline, aller directement au résumé sans vérifications réseau
      if (isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.sessionSavedOffline),
            backgroundColor: Colors.orange.shade700,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ReadingSessionSummaryPage(
              session: completedSession,
            ),
          ),
          (route) => route.isFirst,
        );
        return;
      }

      // Vérifier et attribuer les badges standard (non bloquant)
      List<dynamic> newBadges = [];
      try {
        newBadges = await _badgesService.checkAndAwardBadges();
      } catch (e) {
        debugPrint('Erreur checkAndAwardBadges (non bloquante): $e');
      }

      // Vérifier les badges secrets (côté serveur via RPC)
      List<dynamic> newSecretBadges = [];
      try {
        newSecretBadges = await _badgesService.checkSecretBadges(
          sessionId: completedSession.id,
          bookFinished: false,
        );
      } catch (e) {
        debugPrint('Erreur checkSecretBadges (non bloquante): $e');
      }

      // Mettre à jour le widget iOS (non bloquant)
      WidgetService().updateWidget().catchError((_) {});

      // Vérifier et attribuer les badges de flow (non bloquant)
      List<FlowBadgeLevel> newFlowBadges = [];
      try {
        newFlowBadges = await _flowService.checkAndAwardFlowBadges();
      } catch (e) {
        debugPrint('Erreur checkAndAwardFlowBadges (non bloquante): $e');
      }

      // Afficher les badges standard débloqués
      if (newBadges.isNotEmpty && mounted) {
        for (final badge in newBadges) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => BadgeUnlockedDialog(badge: badge),
          );
        }
      }

      // Afficher les badges secrets débloqués
      if (newSecretBadges.isNotEmpty && mounted) {
        for (final badge in newSecretBadges) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => BadgeUnlockedDialog(badge: badge),
          );
        }
      }

      // Afficher les badges de flow débloqués
      if (newFlowBadges.isNotEmpty && mounted) {
        for (final badgeLevel in newFlowBadges) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _FlowBadgeDialog(badgeLevel: badgeLevel),
          );
        }
      }

      // Vérifier si c'est la première session → afficher suggestion contacts
      if (mounted) {
        final contactsService = ContactsService();
        final hasCompleted = await contactsService.hasCompletedFirstSession();
        final hasSeen = await contactsService.hasSeenContactsPrompt();

        if (!hasCompleted && !hasSeen) {
          await contactsService.markFirstSessionCompleted();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => ContactsSuggestionPage(
                session: completedSession,
                isBookCompleted: false,
              ),
            ),
            (route) => route.isFirst,
          );
        } else {
          if (!hasCompleted) await contactsService.markFirstSessionCompleted();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => ReadingSessionSummaryPage(
                session: completedSession,
              ),
            ),
            (route) => route.isFirst,
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur _endSession: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = AppLocalizations.of(context)!.endSessionError;
      });
    }
  }

  Future<void> _finishBook() async {
    final l = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber),
            const SizedBox(width: 8),
            Text(l.finishBookTitle),
          ],
        ),
        content: Text(l.finishBookConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: Text(l.yesFinished),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Déclencher l'animation
      setState(() => _showFinishBookAnimation = true);

      // Attendre l'animation
      await Future.delayed(const Duration(milliseconds: 2000));

      setState(() => _isProcessing = true);

      try {
        // Utiliser le pageCount du livre si aucune page n'a été saisie.
        // _book est chargé async par _loadBook() ; widget.book n'est passé
        // que dans certains call sites — on retombe sur _book sinon.
        final pageNumber = _detectedPageNumber
            ?? _manualPageNumber
            ?? _book?.pageCount
            ?? widget.book?.pageCount
            ?? widget.activeSession.startPage;

        // Terminer la session avec le livre marqué comme terminé
        final completedSession = await _sessionService.endSession(
          sessionId: widget.activeSession.id,
          imagePath: _imageFile?.path,
          manualPageNumber: pageNumber,
        );

        // Marquer le livre comme terminé
        final bookIdInt = int.tryParse(widget.activeSession.bookId);
        if (bookIdInt != null) {
          try {
            await _booksService.updateBookStatus(bookIdInt, 'finished');
          } catch (e) {
            debugPrint('Erreur updateBookStatus (non bloquante): $e');
          }

          // Déclencher le pré-render vidéo (fire-and-forget, non bloquant)
          ReadonSyncService.finishBook(bookIdInt);
        }

        // Créer une activité spéciale pour le livre terminé
        try {
          await _createBookFinishedActivity(completedSession);
        } catch (e) {
          debugPrint('Erreur createBookFinishedActivity (non bloquante): $e');
        }

        // Vérifier et attribuer les badges (non bloquant)
        List<dynamic> newBadges = [];
        try {
          newBadges = await _badgesService.checkAndAwardBadges();
        } catch (e) {
          debugPrint('Erreur checkAndAwardBadges (non bloquante): $e');
        }

        // Vérifier les badges secrets (côté serveur via RPC)
        List<dynamic> newSecretBadges = [];
        try {
          newSecretBadges = await _badgesService.checkSecretBadges(
            sessionId: completedSession.id,
            bookFinished: true,
          );
        } catch (e) {
          debugPrint('Erreur checkSecretBadges (non bloquante): $e');
        }

        // Mettre à jour le widget iOS (non bloquant)
        WidgetService().updateWidget().catchError((_) {});

        // Vérifier et attribuer les badges de flow (non bloquant)
        List<dynamic> newFlowBadges = [];
        try {
          newFlowBadges = await _flowService.checkAndAwardFlowBadges();
        } catch (e) {
          debugPrint('Erreur checkAndAwardFlowBadges (non bloquante): $e');
        }

        if (!mounted) return;

        // Masquer l'animation de fin de livre
        setState(() => _showFinishBookAnimation = false);

        // Afficher les nouveaux badges débloqués
        if (newBadges.isNotEmpty) {
          for (final badge in newBadges) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => BadgeUnlockedDialog(badge: badge),
            );
          }
        }

        // Afficher les badges secrets débloqués
        if (newSecretBadges.isNotEmpty && mounted) {
          for (final badge in newSecretBadges) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => BadgeUnlockedDialog(badge: badge),
            );
          }
        }

        // Afficher les badges de flow débloqués
        if (newFlowBadges.isNotEmpty && mounted) {
          for (final badgeLevel in newFlowBadges) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => _FlowBadgeDialog(badgeLevel: badgeLevel as FlowBadgeLevel),
            );
          }
        }

        // Récupérer le livre pour la page de résumé
        Book? book = widget.book;
        if (book == null && bookIdInt != null) {
          try {
            book = await _booksService.getBookById(bookIdInt);
          } catch (e) {
            debugPrint('Erreur récupération livre: $e');
          }
        }

        // Proposer Muse pour la prochaine lecture
        if (mounted) {
          final bookTitle = book?.title ?? 'ce livre';
          final l2 = AppLocalizations.of(context)!;
          final openMuse = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFE49B0F)),
                  SizedBox(width: 8),
                  Text('Muse'),
                ],
              ),
              content: Text(
                l2.museBookFinished(bookTitle),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l2.later),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE49B0F),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l2.chatWithMuse),
                ),
              ],
            ),
          );

          if (openMuse == true && mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AiChatPage(
                  initialMessage:
                      'Je viens de terminer "$bookTitle"${book?.author != null ? " de ${book!.author}" : ""}. '
                      'Qu\'est-ce que tu me conseillerais de lire ensuite ?',
                ),
              ),
            );
          }
        }

        // Vérifier si c'est la première session → afficher suggestion contacts
        if (!mounted) return;
        final contactsService = ContactsService();
        final hasCompleted = await contactsService.hasCompletedFirstSession();
        final hasSeen = await contactsService.hasSeenContactsPrompt();

        if (!hasCompleted && !hasSeen) {
          await contactsService.markFirstSessionCompleted();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => ContactsSuggestionPage(
                session: completedSession,
                book: book,
                isBookCompleted: true,
              ),
            ),
            (route) => route.isFirst,
          );
        } else {
          if (!hasCompleted) await contactsService.markFirstSessionCompleted();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => BookCompletedSummaryPage(
                book: book!,
                lastSession: completedSession,
              ),
            ),
            (route) => route.isFirst,
          );
                }
      } catch (e) {
        debugPrint('Erreur _finishBook: $e');
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _showFinishBookAnimation = false;
          _errorMessage = AppLocalizations.of(context)!.endSessionError;
        });
      }
    }
  }

  Future<void> _createBookFinishedActivity(ReadingSession session) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Récupérer les informations du livre
      final bookIdInt = int.tryParse(session.bookId);
      if (bookIdInt == null) {
        debugPrint('Erreur: bookId invalide: ${session.bookId}');
        return;
      }
      final bookResponse = await Supabase.instance.client
          .from('books')
          .select('title, author, cover_url, isbn, google_id')
          .eq('id', bookIdInt)
          .maybeSingle();

      if (bookResponse == null) return;

      // Créer l'activité avec le flag book_finished
      await Supabase.instance.client.from('activities').insert({
        'author_id': userId,
        'type': 'book_finished',
        'payload': {
          'book_id': bookIdInt,
          'book_title': bookResponse['title'],
          'book_author': bookResponse['author'],
          'book_cover': bookResponse['cover_url'],
          'book_isbn': bookResponse['isbn'],
          'book_google_id': bookResponse['google_id'],
          'pages_read': session.pagesRead,
          'duration_minutes': session.durationMinutes,
          'start_page': session.startPage,
          'end_page': session.endPage,
          'book_finished': true,
        },
      });
    } catch (e) {
      debugPrint('Erreur _createBookFinishedActivity: $e');
      // Ne pas bloquer le flux si l'activité ne peut pas être créée
    }
  }

  String _formatDuration(DateTime startTime) {
    final duration = DateTime.now().difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  int? get _effectivePage => _manualPageNumber ?? _detectedPageNumber;
  bool get _canEndSession =>
      _effectivePage != null &&
      _effectivePage! >= widget.activeSession.startPage;

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final totalPages = book?.pageCount;
    final currentPage = widget.activeSession.startPage;
    final progress = (totalPages != null && totalPages > 0)
        ? (currentPage / totalPages).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: _kBgColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ConstrainedContent(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Header ──
                          Row(
                            children: [
                              _BackButton(onTap: () => Navigator.of(context).pop()),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FIN DE SESSION',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.5,
                                        color: _kSageGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Terminer la lecture',
                                      style: GoogleFonts.cormorantGaramond(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1A1A1A),
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Hero card (book + start page + duration) ──
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _kFallbackHeroColor,
                                  _kFallbackHeroColor.withValues(alpha: 0.85),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _kFallbackHeroColor.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: book?.coverUrl != null
                                            ? CachedBookCover(
                                                imageUrl: book!.coverUrl,
                                                isbn: book.isbn,
                                                googleId: book.googleId,
                                                title: book.title,
                                                author: book.author,
                                                width: 72,
                                                height: 108,
                                                borderRadius: BorderRadius.circular(12),
                                              )
                                            : Container(
                                                width: 72,
                                                height: 108,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Center(
                                                  child: Text('📖',
                                                      style: TextStyle(fontSize: 32)),
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            book?.title ?? 'Livre',
                                            style: GoogleFonts.cormorantGaramond(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              height: 1.2,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (book?.author != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              book!.author!,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 13,
                                                color: Colors.white.withValues(alpha: 0.7),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (totalPages != null && totalPages > 0) ...[
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                                valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
                                                minHeight: 5,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '$currentPage / $totalPages pages',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 12,
                                                color: _kGold.withValues(alpha: 0.9),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Démarrée page $currentPage · ${_formatDuration(widget.activeSession.startTime)}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Page input ──
                          Text(
                            'À QUELLE PAGE AS-TU FINI ?',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: _kSageGreen,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _pageFocusNode.hasFocus
                                    ? _kSageGreen
                                    : const Color(0xFFE2DDD5),
                                width: _pageFocusNode.hasFocus ? 2 : 1.5,
                              ),
                              boxShadow: _pageFocusNode.hasFocus
                                  ? [
                                      BoxShadow(
                                        color: _kSageGreen.withValues(alpha: 0.15),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: TextField(
                              key: const ValueKey('manual_page_input'),
                              controller: _manualPageController,
                              focusNode: _pageFocusNode,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              cursorColor: _kSageGreen,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1A),
                              ),
                              decoration: InputDecoration(
                                hintText: currentPage.toString(),
                                hintStyle: GoogleFonts.cormorantGaramond(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFBDB5A8),
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _manualPageNumber = int.tryParse(value);
                                  _detectedPageNumber = null;
                                  _errorMessage = null;
                                });
                              },
                              onTap: () => setState(() {}),
                            ),
                          ),

                          if (_effectivePage != null &&
                              _effectivePage! >= widget.activeSession.startPage) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_effectivePage! - widget.activeSession.startPage} pages lues',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: _kSageGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // ── Scan buttons ──
                          Row(
                            children: [
                              Expanded(
                                child: _DashedButton(
                                  label: '📷  Scanner la page',
                                  onTap: _isProcessing ? null : _takePicture,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DashedButton(
                                  label: '🖼️  Galerie',
                                  onTap: _isProcessing ? null : _pickFromGallery,
                                ),
                              ),
                            ],
                          ),

                          // ── Processing indicator ──
                          if (_isProcessing) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(_kSageGreen),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    'Analyse en cours…',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // ── Image preview ──
                          if (_imageFile != null && !_isProcessing) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: kIsWeb
                                  ? Image.network(_imageFile!.path,
                                      height: 160, fit: BoxFit.cover)
                                  : Image.file(File(_imageFile!.path),
                                      height: 160, fit: BoxFit.cover),
                            ),
                          ],

                          // ── Error ──
                          if (_errorMessage != null && !_isProcessing) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Bottom action bar ──
                  Container(
                    decoration: const BoxDecoration(
                      color: _kBgColor,
                      border: Border(
                        top: BorderSide(color: Color(0x11000000)),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      MediaQuery.of(context).padding.bottom + 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_canEndSession && !_isProcessing)
                                ? () {
                                    HapticFeedback.mediumImpact();
                                    _endSession();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kSageGreen,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  _kSageGreen.withValues(alpha: 0.35),
                              disabledForegroundColor:
                                  Colors.white.withValues(alpha: 0.7),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Terminer la session 📖',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  _finishBook();
                                },
                          icon: const Text('✨', style: TextStyle(fontSize: 16)),
                          label: Text(
                            'J\'ai terminé le livre',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Confetti overlay ──
          if (_showFinishBookAnimation)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black26,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1500),
                      builder: (context, value, child) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Transform.scale(
                              scale: value,
                              child: const Icon(
                                Icons.celebration,
                                size: 120,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Opacity(
                              opacity: value,
                              child: Text(
                                'Félicitations !',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Opacity(
                              opacity: value,
                              child: Text(
                                'Livre terminé !',
                                style: GoogleFonts.dmSans(
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Widget pour afficher le déblocage d'un badge de flow
class _FlowBadgeDialog extends StatefulWidget {
  final FlowBadgeLevel badgeLevel;

  const _FlowBadgeDialog({required this.badgeLevel});

  @override
  State<_FlowBadgeDialog> createState() => _FlowBadgeDialogState();
}

class _FlowBadgeDialogState extends State<_FlowBadgeDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Color _getBadgeColor() {
    try {
      final colorStr = widget.badgeLevel.color.replaceAll('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (e) {
      return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBadgeColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Confetti
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                final startX = 0.5 + (index % 5 - 2) * 0.15;
                final endX = startX + (index % 3 - 1) * 0.3;
                final endY = 0.8 + (index % 4) * 0.05;

                return Positioned(
                  left: MediaQuery.of(context).size.width *
                      (startX + (endX - startX) * _confettiController.value),
                  top: MediaQuery.of(context).size.height *
                      (-0.1 + endY * _confettiController.value),
                  child: Opacity(
                    opacity: 1.0 - _confettiController.value,
                    child: Text(
                      widget.badgeLevel.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            );
          }),

          // Contenu
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, color: color, size: 28),
                      const SizedBox(width: 8),
                      const Text(
                        'Badge Flow!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Badge animé
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha:0.2),
                        border: Border.all(
                          color: color,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha:0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.badgeLevel.icon,
                          style: const TextStyle(fontSize: 60),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nom du badge
                  Text(
                    widget.badgeLevel.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    widget.badgeLevel.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.badgeLevel.days} jour${widget.badgeLevel.days > 1 ? 's' : ''} consécutifs!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bouton
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Continuer!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _kBackBtnColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: Color(0xFF3A3A3A),
        ),
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _DashedButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFCBC4B8),
            width: 1.5,
          ),
          color: Colors.white.withValues(alpha: 0.5),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6A6A6A),
            ),
          ),
        ),
      ),
    );
  }
}
