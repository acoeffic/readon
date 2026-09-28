import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book.dart';
import '../../theme/app_theme.dart';
import '../../navigation/main_navigation.dart';
import '../../services/analytics_service.dart';
import '../../services/books_service.dart';
import '../../services/push_notification_service.dart';
import '../../l10n/app_localizations.dart';
import '../reading/start_reading_session_page_unified.dart';

import 'widgets/onboarding_dots.dart';
import 'widgets/step_welcome.dart';
import 'widgets/step_reading_habit.dart';
import 'widgets/step_manual_add.dart';
import 'widgets/step_first_session.dart';
import 'widgets/step_suggested_readers.dart';
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
        'suggested_readers',
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

    // Suggested readers step
    steps.add(
      StepSuggestedReaders(
        readingHabit: _readingHabit,
        onNext: _goToNext,
        onSkip: () {
          _trackStepSkipped();
          _goToNext();
        },
      ),
    );

    // Final step
    steps.add(
      StepFirstSession(
        selectedBook: _selectedBook,
        onStartSession: _startFirstSession,
        onSkip: () {
          _trackStepSkipped();
          _skipFirstSession();
        },
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

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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

  /// Sortie « Pas maintenant » de l'écran final, avec un livre choisi.
  ///
  /// Diagnostic du 02/09 : les inscrits qui ne lisent pas dans cette première
  /// ouverture ne reviennent jamais — et comme la popup notifications n'est
  /// demandée qu'après la première session, on n'avait aucun canal pour les
  /// rappeler. On dépense donc ici la cartouche notifications, précédée d'un
  /// pré-prompt honnête (un seul rappel, pour CE livre). Ceux qui refusent
  /// le pré-prompt gardent la popup système intacte pour plus tard.
  Future<void> _skipFirstSession() async {
    final book = _selectedBook;
    if (book != null) {
      try {
        final push = PushNotificationService();
        if (await push.canStillAskPermission() && mounted) {
          final wantsReminder = await _askReminderPrePrompt(book);
          unawaited(AnalyticsService().track(
            AnalyticsEvent.onboardingReminderPrompt,
            properties: {'answer': wantsReminder ? 'yes' : 'no'},
          ));
          if (wantsReminder) {
            await push.promptPermissionAndRegister();
          }
        }
      } catch (e) {
        debugPrint('Onboarding reminder pre-prompt error: $e');
      }
    }
    await _completeOnboarding();
  }

  Future<bool> _askReminderPrePrompt(Book book) async {
    final l10n = AppLocalizations.of(context);
    final answer = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.l, AppSpace.l, AppSpace.l, AppSpace.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.notifications_active_rounded,
                  size: 40, color: AppColors.primary),
              const SizedBox(height: AppSpace.m),
              Text(
                l10n.onboardingReminderTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                l10n.onboardingReminderBody(book.title),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: AppSpace.l),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpace.m),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  l10n.onboardingReminderYes,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  l10n.onboardingReminderNo,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return answer == true;
  }

  Future<void> _completeOnboarding() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Mark book as reading if selected
    if (_selectedBook != null) {
      try {
        await _booksService.updateBookStatus(_selectedBook!.id, 'reading');
      } catch (_) {}
    }

    await Supabase.instance.client.from('profiles').update({
      'onboarding_completed': true,
      'reading_habit': _readingHabit,
    }).eq('id', userId);

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

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Mark book as reading
    try {
      await _booksService.updateBookStatus(book.id, 'reading');
    } catch (_) {}

    // Mark onboarding complete
    await Supabase.instance.client.from('profiles').update({
      'onboarding_completed': true,
      'reading_habit': _readingHabit,
    }).eq('id', userId);

    _trackOnboardingCompleted(startedFirstSession: true);

    if (!mounted) return;

    // Go to main nav then push reading session
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StartReadingSessionPageUnified(book: book),
      ),
    );
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
