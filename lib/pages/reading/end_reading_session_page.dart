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
import '../../services/push_notification_service.dart';
import '../../widgets/rate_book_sheet.dart';

/// Timeout des appels réseau post-session (badges, contacts…) : sans ça, une
/// requête qui pend (Wi-Fi « connecté sans internet ») bloque le spinner de
/// fin de session pour toujours. Fix 2026-08-11.
const _kPostSessionTimeout = Duration(seconds: 6);

/// Durée plancher de l'écran de confetti « livre terminé ». Fix 2026-09-26 :
/// avant, un `Future.delayed` de 2s bloquait tout appel réseau derrière un
/// écran figé, PUIS les vérifications de badges s'enchaînaient en
/// séquentiel (jusqu'à 3 × 6s de timeout) avant le premier dialogue de
/// récompense. Le confetti démarre maintenant en même temps que l'appel
/// serveur ; cette constante garantit juste que l'animation n'est pas
/// coupée net si la réponse arrive très vite.
const _kFinishBookAnimMinDuration = Duration(milliseconds: 1400);

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

  /// Fix 2026-09-22 (diagnostic fcm_token) : la popup système de permission
  /// notifications n'était jusqu'ici redemandée qu'au prochain cold-start de
  /// l'app (MainNavigation._runValueGatedPrompts), qui peut n'arriver que des
  /// jours plus tard — alors que l'activation est quasi exclusivement jour 0.
  /// On la déclenche donc aussi ici, immédiatement après la toute première
  /// session de lecture terminée (le moment où la valeur de l'app vient
  /// d'être délivrée). `canStillAskPermission()` garantit qu'on ne la
  /// présente jamais deux fois.
  Future<void> _maybeAskPushPermissionAfterFirstSession() async {
    try {
      final push = PushNotificationService();
      if (!await push.canStillAskPermission()) return;
      if (!mounted) return;
      await push.promptPermissionAndRegister();
    } catch (e) {
      debugPrint('Erreur _maybeAskPushPermissionAfterFirstSession: $e');
    }
  }

  Future<void> _takePicture() async {
    try {
      setState(() {
        _errorMessage = null;
        _detectedPageNumber = null;
      });

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        // Résolution haute : l'OCR du numéro de page a besoin de pixels.
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );

      if (photo == null) return;

      await _processImage(photo);
    } catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
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

      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = AppLocalizations.of(context)!.ocrError(e.toString());
      });
    }
  }

  /// Affiche les récompenses débloquées à la fin d'une session.
  ///
  /// Avant le 28/09/2026, chaque badge (standard, secret, palier de flow)
  /// ouvrait sa propre modale plein écran, enchaînées une par une à coups de
  /// `await` — jusqu'à 6 dismiss avant même la note du livre ou la
  /// proposition Muse (9 au total sur un livre terminé). Personne ne
  /// convertit mieux à la 4e modale qu'à la 1re ; on ne montre donc que la
  /// plus significative tout de suite, et on résume le reste en un mot.
  Future<void> _showUnlockedRewards({
    required List<UserBadge> badges,
    required List<UserBadge> secretBadges,
    required List<FlowBadgeLevel> flowBadges,
  }) async {
    final total = badges.length + secretBadges.length + flowBadges.length;
    if (total == 0 || !mounted) return;

    if (badges.isNotEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BadgeUnlockedDialog(badge: badges.first),
      );
    } else if (secretBadges.isNotEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BadgeUnlockedDialog(badge: secretBadges.first),
      );
    } else {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _FlowBadgeDialog(badgeLevel: flowBadges.first),
      );
    }

    final remaining = total - 1;
    if (remaining > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remaining == 1
                ? '+1 autre récompense débloquée — à retrouver dans ton profil'
                : '+$remaining autres récompenses débloquées — à retrouver dans ton profil',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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

      // Vérifier et attribuer les badges (non bloquant).
      // Fix 2026-08-11 : timeout sur tous les appels post-session — sans ça,
      // une requête qui pend (Wi-Fi « connecté sans internet ») bloquait la
      // page sur le spinner pour toujours.
      // Fix 2026-09-26 : les 3 appels étaient auparavant awaités l'un après
      // l'autre (jusqu'à 3 × 6s de timeout bout à bout avant le premier
      // dialogue de récompense). On les déclenche tous en même temps — le
      // temps d'attente réel devient le plus lent des trois, pas leur somme.
      final badgesFuture =
          _badgesService.checkAndAwardBadges().timeout(_kPostSessionTimeout);
      final secretBadgesFuture = _badgesService
          .checkSecretBadges(
            sessionId: completedSession.id,
            bookFinished: false,
          )
          .timeout(_kPostSessionTimeout);
      final flowBadgesFuture =
          _flowService.checkAndAwardFlowBadges().timeout(_kPostSessionTimeout);

      // Mettre à jour le widget iOS (non bloquant)
      WidgetService().updateWidget().catchError((_) {});

      List<UserBadge> newBadges = [];
      try {
        newBadges = await badgesFuture;
      } catch (e) {
        debugPrint('Erreur checkAndAwardBadges (non bloquante): $e');
      }

      List<UserBadge> newSecretBadges = [];
      try {
        newSecretBadges = await secretBadgesFuture;
      } catch (e) {
        debugPrint('Erreur checkSecretBadges (non bloquante): $e');
      }

      List<FlowBadgeLevel> newFlowBadges = [];
      try {
        newFlowBadges = await flowBadgesFuture;
      } catch (e) {
        debugPrint('Erreur checkAndAwardFlowBadges (non bloquante): $e');
      }

      // Afficher les récompenses débloquées (une seule modale, cf.
      // _showUnlockedRewards).
      await _showUnlockedRewards(
        badges: newBadges,
        secretBadges: newSecretBadges,
        flowBadges: newFlowBadges,
      );

      // Vérifier si c'est la première session → afficher suggestion contacts
      if (mounted) {
        final contactsService = ContactsService();
        // Timeout + fallback : ne jamais bloquer la navigation vers le résumé.
        bool hasCompleted = true;
        bool hasSeen = true;
        try {
          // `null` = information indisponible : on garde le défaut `true`,
          // c'est-à-dire « ne pas pousser la page de suggestion de contacts ».
          hasCompleted = await contactsService
                  .hasCompletedFirstSession()
                  .timeout(_kPostSessionTimeout) ??
              true;
          hasSeen = await contactsService
              .hasSeenContactsPrompt()
              .timeout(_kPostSessionTimeout);
        } catch (e) {
          debugPrint('Erreur checks contacts (non bloquante): $e');
        }

        if (!hasCompleted && !hasSeen) {
          await contactsService.markFirstSessionCompleted().timeout(_kPostSessionTimeout).catchError((_) {});
          await _maybeAskPushPermissionAfterFirstSession();
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
          if (!hasCompleted) {
            await contactsService.markFirstSessionCompleted().timeout(_kPostSessionTimeout).catchError((_) {});
            await _maybeAskPushPermissionAfterFirstSession();
          }
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
      // Déclencher l'animation ET démarrer le travail réel en même temps.
      // Fix 2026-09-26 : avant, un `Future.delayed(2000ms)` bloquait tout
      // appel réseau derrière un écran figé — 2s de pure attente ajoutées
      // par-dessus la latence serveur, avant même le premier octet envoyé.
      setState(() {
        _showFinishBookAnimation = true;
        _isProcessing = true;
      });

      try {
        // Utiliser le pageCount du livre si aucune page n'a été saisie.
        // _book est chargé async par _loadBook() ; widget.book n'est passé
        // que dans certains call sites — on retombe sur _book sinon.
        // ⚠️ page_count peut valoir 0 (inconnu) : on garantit toujours
        // end_page >= start_page, sinon la contrainte CHECK
        // reading_sessions_check (end_page >= start_page) échoue et la
        // session ne peut pas être terminée.
        final startPage = widget.activeSession.startPage;
        var pageNumber = _detectedPageNumber
            ?? _manualPageNumber
            ?? _book?.pageCount
            ?? widget.book?.pageCount
            ?? startPage;
        if (pageNumber < startPage) pageNumber = startPage;

        // Terminer la session avec le livre marqué comme terminé. L'appel
        // réseau part immédiatement ; on n'attend que le plus lent entre lui
        // et la durée plancher du confetti, au lieu de les mettre bout à
        // bout.
        final sessionFuture = _sessionService.endSession(
          sessionId: widget.activeSession.id,
          imagePath: _imageFile?.path,
          manualPageNumber: pageNumber,
        );
        await Future.wait<Object?>([
          sessionFuture,
          Future<void>.delayed(_kFinishBookAnimMinDuration),
        ]);
        final completedSession = await sessionFuture;

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

        // Vérifier et attribuer badges standard / secrets / flow — les 3
        // appels partent en même temps (voir fix 2026-09-26 dans
        // _endSession) plutôt que bout à bout derrière l'écran de confetti.
        final badgesFuture = _badgesService
            .checkAndAwardBadges()
            .timeout(_kPostSessionTimeout);
        final secretBadgesFuture = _badgesService
            .checkSecretBadges(
              sessionId: completedSession.id,
              bookFinished: true,
            )
            .timeout(_kPostSessionTimeout);
        final flowBadgesFuture = _flowService
            .checkAndAwardFlowBadges()
            .timeout(_kPostSessionTimeout);

        // Mettre à jour le widget iOS (non bloquant)
        WidgetService().updateWidget().catchError((_) {});

        List<UserBadge> newBadges = [];
        try {
          newBadges = await badgesFuture;
        } catch (e) {
          debugPrint('Erreur checkAndAwardBadges (non bloquante): $e');
        }

        List<UserBadge> newSecretBadges = [];
        try {
          newSecretBadges = await secretBadgesFuture;
        } catch (e) {
          debugPrint('Erreur checkSecretBadges (non bloquante): $e');
        }

        List<FlowBadgeLevel> newFlowBadges = [];
        try {
          newFlowBadges = await flowBadgesFuture;
        } catch (e) {
          debugPrint('Erreur checkAndAwardFlowBadges (non bloquante): $e');
        }

        if (!mounted) return;

        // Masquer l'animation de fin de livre
        setState(() => _showFinishBookAnimation = false);

        // Afficher les récompenses débloquées (une seule modale, cf.
        // _showUnlockedRewards).
        await _showUnlockedRewards(
          badges: newBadges,
          secretBadges: newSecretBadges,
          flowBadges: newFlowBadges,
        );

        // Récupérer le livre pour la page de résumé
        Book? book = widget.book;
        if (book == null && bookIdInt != null) {
          try {
            book = await _booksService.getBookById(bookIdInt);
          } catch (e) {
            debugPrint('Erreur récupération livre: $e');
          }
        }

        // Proposer de noter le livre (skippable)
        if (mounted && bookIdInt != null) {
          try {
            await showRateBookSheet(
              context,
              bookId: bookIdInt,
              bookTitle: book?.title,
            );
          } catch (e) {
            debugPrint('Erreur showRateBookSheet (non bloquante): $e');
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
        // Timeout + fallback : ne jamais bloquer la navigation vers le résumé.
        bool hasCompleted = true;
        bool hasSeen = true;
        try {
          // `null` = information indisponible : on garde le défaut `true`,
          // c'est-à-dire « ne pas pousser la page de suggestion de contacts ».
          hasCompleted = await contactsService
                  .hasCompletedFirstSession()
                  .timeout(_kPostSessionTimeout) ??
              true;
          hasSeen = await contactsService
              .hasSeenContactsPrompt()
              .timeout(_kPostSessionTimeout);
        } catch (e) {
          debugPrint('Erreur checks contacts (non bloquante): $e');
        }

        if (!hasCompleted && !hasSeen) {
          await contactsService.markFirstSessionCompleted().timeout(_kPostSessionTimeout).catchError((_) {});
          await _maybeAskPushPermissionAfterFirstSession();
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
          if (!hasCompleted) {
            await contactsService.markFirstSessionCompleted().timeout(_kPostSessionTimeout).catchError((_) {});
            await _maybeAskPushPermissionAfterFirstSession();
          }
          if (!mounted) return;
          // La session est déjà terminée côté serveur ; si le livre n'a pas pu
          // être récupéré, on retombe sur le résumé de session classique plutôt
          // que de crasher sur un force-unwrap (book!).
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => book != null
                  ? BookCompletedSummaryPage(
                      book: book,
                      lastSession: completedSession,
                    )
                  : ReadingSessionSummaryPage(
                      session: completedSession,
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
