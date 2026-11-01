import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../providers/connectivity_provider.dart';
import '../../theme/app_theme.dart';
import '../../navigation/main_navigation.dart';
import '../../services/analytics_service.dart';
import '../../services/books_service.dart';
import '../../services/first_session_reminder_service.dart';
import '../../services/last_page_cache.dart';
import '../../services/reading_session_service.dart';
import '../../services/push_notification_service.dart';
import '../../l10n/app_localizations.dart';
import '../reading/active_reading_session_page.dart';
import '../reading/start_reading_session_page_unified.dart';

import 'widgets/onboarding_dots.dart';
import 'widgets/step_welcome.dart';
import 'widgets/step_reading_habit.dart';
import 'widgets/step_manual_add.dart';
import 'widgets/step_first_session.dart';
import '../../widgets/constrained_content.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final BooksService _booksService = BooksService();

  // Shared state
  String? _readingHabit;
  List<Book> _importedBooks = [];
  Book? _selectedBook;
  int _currentStep = 0;

  /// Noms d'étapes alignés **index par index** sur [_buildSteps]. Les deux
  /// méthodes appliquent volontairement les mêmes conditions de branchement :
  /// toute étape ajoutée à l'une doit l'être à l'autre, sinon les events
  /// PostHog désignent le mauvais écran. L'assertion dans [_stepName] le
  /// détecte en debug.
  List<String> _buildStepNames() => const [
        'welcome',
        'reading_habit',
        'manual_add',
        'first_session',
      ];

  String _stepName(int index) {
    final names = _buildStepNames();
    assert(
      names.length == _buildSteps().length,
      '_buildStepNames() et _buildSteps() ont divergé '
      '(${names.length} noms pour ${_buildSteps().length} écrans)',
    );
    if (index < 0 || index >= names.length) return 'unknown';
    return names[index];
  }

  /// Propriétés communes à tous les events d'onboarding : le nom de l'étape,
  /// son rang, et l'habitude de lecture déclarée. Le parcours est désormais
  /// identique pour tous, mais `reading_habit` reste la dimension qui permet
  /// de comparer le comportement des lecteurs papier et liseuse.
  Map<String, Object> _stepProps(int index) => {
        'step': _stepName(index),
        'step_index': index,
        'reading_habit': _readingHabit ?? 'unset',
      };

  void _trackStepViewed(int index) {
    unawaited(AnalyticsService().track(
      AnalyticsEvent.onboardingStepViewed,
      properties: _stepProps(index),
    ));
  }

  /// À câbler sur chaque callback `onSkip` : un abandon volontaire d'étape
  /// n'est pas la même information qu'un abandon pur et simple de l'app.
  void _trackStepSkipped() {
    unawaited(AnalyticsService().track(
      AnalyticsEvent.onboardingStepSkipped,
      properties: _stepProps(_currentStep),
    ));
  }

  @override
  void initState() {
    super.initState();
    // `onPageChanged` ne se déclenche pas pour la page initiale : sans ceci,
    // l'étape « welcome » — donc le dénominateur de tout l'entonnoir —
    // n'apparaîtrait jamais.
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackStepViewed(0));
  }

  List<Widget> _buildSteps() {
    final steps = <Widget>[
      // Step 1: Welcome
      StepWelcome(onNext: _goToNext),

      // Step 2: Reading habits
      StepReadingHabit(
        selectedHabit: _readingHabit,
        onSelected: (habit) => setState(() => _readingHabit = habit),
        onNext: _goToNext,
      ),
      // Step 3: Add a first book — identique pour tout le monde.
      //
      // La branche Kindle (connect → sync → success) a été retirée le
      // 15/08/2026 : demander un login Amazon dans la première minute
      // activait 2,5 fois moins bien que l'ajout manuel. La connexion est
      // désormais proposée après la première session de lecture terminée
      // (cf. maybeShowKindleConnectSheet) et reste accessible dans les
      // réglages.
      //
      // 28/09/2026 : le bouton « Passer cette étape » a été retiré. Le
      // diagnostic du 02/09 montrait que ~23 % des inscrits terminaient tout
      // l'onboarding sans jamais ajouter de livre (skip ici → onboarding
      // marqué complet plus loin sans aucun livre) et ne revenaient
      // quasiment jamais. Le bouton « Suivant » reste désactivé tant
      // qu'aucun livre n'est ajouté ; il n'y a plus d'échappatoire.
      StepManualAdd(
        addedBooks: _importedBooks,
        onBookAdded: _handleBookAdded,
        onNext: _goToNext,
      ),
    ];

    // 11/10/2026 : l'étape « lecteurs suggérés » (entre l'ajout du livre et le
    // CTA de première session) est retirée. Elle n'a aucune valeur avant la
    // première lecture et ajoutait un écran juste avant le moment décisif.
    // Les suggestions restent disponibles après coup : fil d'actualité,
    // « Découvrir des lecteurs » (onglet Amis) et invite contacts en fin de
    // première session.

    // Final step
    steps.add(
      StepFirstSession(
        selectedBook: _selectedBook,
        onStartSession: _startFirstSession,
        onSkip: () {
          _trackStepSkipped();
          _skipFirstSession();
        },
        onRemind: _scheduleReminder,
      ),
    );

    return steps;
  }

  void _goToNext() {
    final steps = _buildSteps();
    if (_currentStep < steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPrevious() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- Book handlers ---

  void _handleBookAdded(Book book) {
    setState(() {
      if (!_importedBooks.any((b) => b.id == book.id)) {
        _importedBooks.add(book);
      }
      _selectedBook = book;
    });
  }

  // --- Common handlers ---

  /// Fin d'onboarding. `started_first_session` distingue les deux sorties :
  /// « Lire » (l'utilisateur enchaîne sur une session) et « Plus tard » /
  /// « C'est parti » (il arrive sur le feed sans livre en cours). C'est le
  /// ratio le plus révélateur de l'écran final.
  void _trackOnboardingCompleted({required bool startedFirstSession}) {
    unawaited(AnalyticsService().track(
      AnalyticsEvent.onboardingCompleted,
      properties: {
        'reading_habit': _readingHabit ?? 'unset',
        'started_first_session': startedFirstSession,
        'books_added': _importedBooks.length,
      },
    ));
  }

  /// Sortie « je lirai plus tard » de l'écran final : l'utilisateur choisit un
  /// MOMENT (« Ce soir 21h », « Demain matin »…) et on programme un rappel.
  ///
  /// Diagnostic du 02/09 : les inscrits qui ne lisent pas dans cette première
  /// ouverture ne reviennent jamais, et la popup notifications n'était
  /// demandée qu'après la première session — aucun canal pour les rappeler.
  /// Choisir une heure est un geste explicite : la popup système suit
  /// naturellement (plus de pré-prompt oui/non). Refus de la popup ou de la
  /// planification : on termine l'onboarding sans rappel, sans bloquer.
  Future<void> _scheduleReminder(FirstSessionReminderSlot slot) async {
    final book = _selectedBook;
    // Anti double-tap : la popup système ne doit pas être déclenchée deux fois.
    // (Distinct de `_finishing`, que `_completeOnboarding` teste lui-même.)
    if (_finishing || _reminderInFlight) return;
    _reminderInFlight = true;
    var scheduled = false;
    if (book != null) {
      try {
        final push = PushNotificationService();
        if (await push.canStillAskPermission()) {
          await push.promptPermissionAndRegister();
        }
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          scheduled = await FirstSessionReminderService.schedule(
            slot: slot,
            title: l10n.onboardingReminderNotifTitle,
            body: l10n.onboardingReminderNotifBody(book.title),
          );
        }
      } catch (e) {
        debugPrint('Onboarding reminder error: $e');
      }
    }
    unawaited(AnalyticsService().track(
      AnalyticsEvent.onboardingReminderPrompt,
      properties: {
        'answer': slot.analyticsValue,
        'scheduled': scheduled,
      },
    ));
    await _completeOnboarding();
    // Si la fin d'onboarding a échoué (réseau), l'utilisateur doit pouvoir
    // réessayer.
    _reminderInFlight = false;
  }

  /// « Sans rappel » : on quitte sans rien programmer et sans dépenser la
  /// popup système, qui reste disponible pour après la première session.
  Future<void> _skipFirstSession() async {
    unawaited(AnalyticsService().track(
      AnalyticsEvent.onboardingReminderPrompt,
      properties: {'answer': 'none', 'scheduled': false},
    ));
    await _completeOnboarding();
  }

  bool _reminderInFlight = false;

  /// Garde anti double-tap sur les handlers de fin d'onboarding.
  bool _finishing = false;

  /// Marque l'onboarding terminé. Retourne false (et prévient l'utilisateur)
  /// si l'écriture échoue, pour qu'il puisse réessayer au lieu de rester
  /// face à un bouton inerte.
  Future<bool> _markOnboardingCompleted(String userId) async {
    try {
      await Supabase.instance.client.from('profiles').update({
        'onboarding_completed': true,
        'reading_habit': _readingHabit,
      }).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('onboarding_completed update failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorOccurredRetryLater),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _completeOnboarding() async {
    if (_finishing) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _finishing = true;

    // Mark book as reading if selected
    if (_selectedBook != null) {
      try {
        await _booksService.updateBookStatus(_selectedBook!.id, 'reading');
      } catch (_) {}
    }

    if (!await _markOnboardingCompleted(userId)) {
      _finishing = false;
      return;
    }

    // Volontairement : aucun paywall ici. Il est déclenché depuis
    // MainNavigation une fois la première session de lecture terminée
    // (cf. PaywallController) — pas avant que l'utilisateur ait vu la valeur.

    _trackOnboardingCompleted(startedFirstSession: false);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  Future<void> _startFirstSession() async {
    final book = _selectedBook;
    if (book == null) {
      await _completeOnboarding();
      return;
    }

    if (_finishing) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _finishing = true;

    // Mark book as reading
    try {
      await _booksService.updateBookStatus(book.id, 'reading');
    } catch (_) {}

    // Mark onboarding complete
    if (!await _markOnboardingCompleted(userId)) {
      _finishing = false;
      return;
    }

    _trackOnboardingCompleted(startedFirstSession: true);

    if (!mounted) return;

    // 11/10/2026 : « Lire 5 minutes maintenant » lance RÉELLEMENT la lecture.
    // Avant, ce bouton ouvrait l'écran de démarrage (un écran de plus avant le
    // moment décisif) et IGNORAIT la session qu'il renvoyait : l'utilisateur
    // atterrissait sur le fil avec un chrono qui tournait sans qu'il le voie.
    // On démarre donc la session ici — même chemin que l'écran de démarrage
    // sans saisie (page présumée, `page_source = inferred`) — puis on ouvre
    // directement le chrono.
    final navigator = Navigator.of(context);
    final isOnline =
        Provider.of<ConnectivityProvider>(context, listen: false).isOnline;
    final session = await _startSessionDirectly(book, offline: !isOnline);

    // Go to main nav (pour que « retour » depuis le chrono tombe sur le fil),
    // puis la session. Navigator capturé avant l'await : l'écran
    // d'onboarding est démonté par le pushAndRemoveUntil.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );

    if (session != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              ActiveReadingSessionPage(activeSession: session, book: book),
        ),
      );
      return;
    }

    // Démarrage direct impossible (réseau, serveur…) : on retombe sur
    // l'écran de démarrage classique — et, cette fois, on suit la session
    // qu'il renvoie.
    final fallback = await navigator.push<ReadingSession>(
      MaterialPageRoute(
        builder: (_) => StartReadingSessionPageUnified(book: book),
      ),
    );
    if (fallback != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              ActiveReadingSessionPage(activeSession: fallback, book: book),
        ),
      );
    }
  }

  /// Démarre la session sans passer par l'écran de démarrage. Page de départ :
  /// dernière page connue (serveur, sinon cache local), sinon 1 — exactement
  /// ce que fait l'écran de démarrage quand on appuie sur « Lancer » sans
  /// rien saisir. Retourne `null` en cas d'échec (l'appelant bascule alors
  /// sur l'écran de démarrage).
  Future<ReadingSession?> _startSessionDirectly(
    Book book, {
    required bool offline,
  }) async {
    final service = ReadingSessionService();
    try {
      final bookId = book.id.toString();
      int? knownPage;
      try {
        knownPage = (await service.getBookStats(bookId)).currentPage;
      } catch (_) {}
      knownPage ??= await LastPageCache.get(bookId);

      return await service.startSession(
        bookId: bookId,
        manualPageNumber: knownPage ?? 1,
        pageSource: 'inferred',
        offlineMode: offline,
      );
    } catch (e) {
      debugPrint('Onboarding: démarrage direct de la session échoué: $e');
      return null;
    } finally {
      service.dispose();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: ConstrainedContent(
          child: SafeArea(
            child: Column(
              children: [
                // Back button row
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpace.s,
                    top: AppSpace.s,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedOpacity(
                      opacity: _currentStep > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        onPressed:
                            _currentStep > 0 ? _goToPrevious : null,
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentStep = index);
                      _trackStepViewed(index);
                    },
                    children: steps,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.l),
                  child: OnboardingDots(
                    total: steps.length,
                    current: _currentStep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
