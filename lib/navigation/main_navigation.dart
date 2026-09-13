// navigation/main_navigation.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/feed/feed_page.dart';
import '../pages/chat/ai_conversations_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/groups/groups_page.dart';
import '../pages/reading/active_reading_session_page.dart';
import '../pages/reading/start_reading_session_page_unified.dart';
import '../models/reading_session.dart';
import '../models/book.dart';
import '../services/reading_session_service.dart';
import '../widgets/global_reading_session_fab.dart';
import '../widgets/active_session_banner.dart';
import '../theme/app_theme.dart';
import '../providers/guest_mode_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/require_account_sheet.dart';
import '../features/badges/services/anniversary_service.dart';
import '../features/badges/widgets/anniversary_unlock_overlay.dart';
import '../pages/notifications/notifications_page.dart';
import '../services/books_service.dart';
import '../services/contacts_service.dart';
import '../services/deep_link_service.dart';
import '../services/kindle_auto_sync_service.dart';
import '../pages/profile/kindle_login_page.dart';
import '../services/monthly_notification_service.dart';
import '../services/onboarding_tutorial_service.dart';
import '../services/paywall_controller.dart';
import '../services/push_notification_service.dart';
import '../services/session_pause_service.dart';
import '../services/freeze_celebration_service.dart';
import '../services/flow_service.dart';
import '../services/watch_control_service.dart';
import '../services/watch_session_draft_service.dart';
import '../widgets/watch_session_catchup_dialog.dart';
import '../services/wrapped_banner_service.dart';
import '../pages/reading/end_reading_session_page.dart';
import '../features/wrapped/monthly/monthly_wrapped_screen.dart';
import '../widgets/choose_display_name_sheet.dart';
import '../widgets/kindle_connect_sheet.dart';
import '../widgets/kindle_auto_sync_widget.dart';
import '../services/kindle_background_sync.dart';
import '../widgets/offline_banner.dart';
import '../utils/responsive.dart';
import '../l10n/app_localizations.dart';
import '../providers/connectivity_provider.dart';
import '../services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _showKindleAutoSync = false;
  KindleSyncMode _kindleSyncMode = KindleSyncMode.full;
  DateTime? _lastKindleSyncAttempt;
  static const _kindleSyncCooldown = Duration(minutes: 5);

  // Active session banner state
  ReadingSession? _activeSession;
  Book? _activeSessionBook;
  Timer? _activeSessionTimer;
  Duration _activeSessionElapsed = Duration.zero;

  // Stale session recovery: show modal once per foreground cycle
  bool _staleModalShown = false;
  // Rattrapage de session Watch : une seule fois par cycle foreground
  bool _watchCatchupShown = false;
  // Ne pas afficher la modale « tu as fini de lire ? » pour une brève sortie
  // (consultation d'une notif, etc.) — seulement après une absence prolongée.
  static const _staleSessionMinAbsence = Duration(minutes: 30);
  final _pauseService = SessionPauseService();

  // Onboarding tutorial (showcase coach marks)
  final _tutorialService = OnboardingTutorialService();
  final GlobalKey _feedShowcaseKey = GlobalKey();
  final GlobalKey _feedContentShowcaseKey = GlobalKey();
  final GlobalKey _museShowcaseKey = GlobalKey();
  final GlobalKey _fabShowcaseKey = GlobalKey();
  final GlobalKey _profileShowcaseKey = GlobalKey();
  // Capturé dans le `builder` de ShowCaseWidget — c'est le seul context
  // qui a ShowCaseWidget comme ancêtre (le `context` du State est au-dessus).
  BuildContext? _showcaseContext;

  late final List<Widget> _pages = [
    FeedPage(
      headerShowcaseKey: _feedShowcaseKey,
      feedContentShowcaseKey: _feedContentShowcaseKey,
    ),
    const AiConversationsPage(),
    const GroupsPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReadingSessionService.activeSessionsVersion
        .addListener(_onActiveSessionsChanged);
    // Dès qu'une session Watch vient d'être terminée (brouillon sauvegardé),
    // proposer le rattrapage des pages immédiatement — sans attendre le
    // prochain retour au premier plan de l'app.
    WatchSessionDraftService.draftVersion.addListener(_onWatchDraftSaved);
    // Connexion Kindle qui vient d'aboutir (KindleLoginPage) : déclencher
    // l'auto-sync tout de suite — c'est lui qui porte la phase surlignages,
    // absente de la synchro de première connexion. Sans ce listener, les
    // highlights n'arrivaient qu'au prochain retour au premier plan.
    KindleAutoSyncService.connectedVersion.addListener(_onKindleConnected);
    // Liens profonds internes (ex: lexday://friends/requests) reçus app
    // ouverte : naviguer immédiatement.
    DeepLinkService.onRoute = _handleDeepLinkRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkAnniversary();
      _checkKindleAutoSync();
      _checkActiveSession();
      _setupSyncListener();
      _enrichMissingCovers();
      _consumePendingNotification();
      _consumePendingDeepLink();
      _updateHomeWidget();
      // Permission push puis paywall, avant le tutoriel : les popups système
      // et la sheet native iOS recouvrent sinon les overlays showcase et
      // cassent leur positionnement à la fermeture.
      await _runValueGatedPrompts();
      if (!mounted) return;
      _maybeStartOnboardingTutorial();
      _checkAutoFreezeCelebration();
      await _maybeShowWatchSessionCatchup();
      // Comptes sans vrai nom (vide ou dérivé de l'email) : proposer une
      // fois par lancement de choisir comment apparaître.
      if (mounted) await maybeShowChooseDisplayNameSheet(context);
    });
  }

  /// Un brouillon de session Watch vient d'être sauvegardé (stop traité par
  /// WatchControlService) : rafraîchir l'état des sessions puis proposer le
  /// rattrapage tout de suite, app déjà au premier plan.
  Future<void> _onWatchDraftSaved() async {
    if (!mounted) return;
    // Le stop vient d'être traité : synchroniser _activeSession avant le
    // garde-fou "session active" du dialogue de rattrapage.
    await _checkActiveSession();
    await _maybeShowWatchSessionCatchup();
  }

  /// Une session terminée depuis l'Apple Watch n'a pas de page de fin fiable
  /// (pas de saisie ni de photo au poignet) : proposer de la compléter ici.
  /// Si l'utilisateur ignore, la session reste valide en "temps seul".
  Future<void> _maybeShowWatchSessionCatchup() async {
    if (_watchCatchupShown) return;
    try {
      final draft = await WatchSessionDraftService().getPending();
      if (draft == null || !mounted) return;
      // Une session est active (relancée depuis la Watch ou l'iPhone) : ne pas
      // empiler avec la bannière/modale de session en cours.
      if (_activeSession != null) return;

      _watchCatchupShown = true;
      await showDialog<void>(
        context: context,
        builder: (_) => WatchSessionCatchupDialog(draft: draft),
      );
      // Le brouillon a été consommé (enregistré ou ignoré) : réautoriser un
      // affichage si une nouvelle session Watch se termine sans passage en
      // arrière-plan entre-temps.
      _watchCatchupShown = false;
      _updateHomeWidget();
    } catch (e) {
      debugPrint('Erreur _maybeShowWatchSessionCatchup: $e');
    }
  }

  /// Si le cron serveur a protégé le streak avec un auto-freeze depuis la
  /// dernière ouverture, on le célèbre — sinon l'utilisateur ne sait jamais
  /// qu'il a été sauvé.
  Future<void> _checkAutoFreezeCelebration() async {
    try {
      final unseen =
          await FreezeCelebrationService().consumeUnseenAutoFreezes();
      if (unseen.isEmpty || !mounted) return;

      // Ne célébrer que si le streak est encore vivant.
      final flow = await FlowService().getUserFlow();
      if (flow.currentFlow <= 0 || !mounted) return;

      final l10n = AppLocalizations.of(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('🧊 ${l10n.autoFreezeUsedTitle}'),
          content: Text(l10n.autoFreezeUsedBody(flow.currentFlow)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.autoFreezeUsedCta),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Erreur _checkAutoFreezeCelebration: $e');
    }
  }

  /// Les deux sollicitations conditionnées à la valeur délivrée : permission
  /// notifications, puis paywall. Aucune des deux n'est présentée avant que
  /// l'utilisateur ait terminé une première session de lecture (audit
  /// entonnoir du 15/08/2026).
  ///
  /// On n'en présente qu'**une seule par lancement** : enchaîner la popup
  /// système de notifications et la sheet native du paywall dans la même
  /// seconde est le meilleur moyen de faire refuser les deux.
  Future<void> _runValueGatedPrompts() async {
    // Rien en mode invité — on attend qu'un compte soit créé.
    if (!mounted) return;
    if (context.read<GuestModeProvider>().isGuest) return;

    // `has_completed_first_session` est écrit à la fin d'une session de
    // lecture (ContactsService.markFirstSessionCompleted), pas à son
    // démarrage : c'est bien le signal « a vu la valeur de l'app ».
    // État inconnu (`null` : réseau, erreur serveur, pas de session) → on ne
    // sollicite rien. Une sollicitation ratée coûte plus cher qu'une
    // sollicitation reportée d'un lancement.
    bool firstSessionDone = false;
    try {
      firstSessionDone =
          await ContactsService().hasCompletedFirstSession() ?? false;
    } catch (e) {
      debugPrint('Erreur lecture has_completed_first_session: $e');
      return;
    }
    if (!firstSessionDone || !mounted) return;

    // Laisse les premiers frames se poser (banners, header).
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // 1. Permission notifications — le canal de relance J1. Prioritaire sur
    //    le paywall : c'est ce qui fait revenir l'utilisateur.
    if (await _maybeAskPushPermission()) return;
    if (!mounted) return;

    // 2. Paywall.
    final paywallShown = await PaywallController.maybeShowOnAppOpen(
      context,
      hasCompletedFirstSession: true,
    );
    if (paywallShown || !mounted) return;

    // 3. Connexion Kindle — uniquement pour les profils « liseuse » / « mix »
    //    qui ne l'ont pas déjà connectée. Sortie de l'onboarding le 15/08 :
    //    proposée ici, une seule fois, plutôt qu'imposée à la 60e seconde.
    await maybeShowKindleConnectSheet(context);
  }

  /// Présente la popup système de notifications si elle ne l'a jamais été.
  /// Retourne `true` si la popup a effectivement été présentée à ce lancement
  /// (auquel cas on ne présente rien d'autre derrière).
  Future<bool> _maybeAskPushPermission() async {
    final push = PushNotificationService();
    try {
      if (!await push.canStillAskPermission()) return false;
      await push.promptPermissionAndRegister();
      return true;
    } catch (e) {
      debugPrint('Erreur _maybeAskPushPermission: $e');
      return false;
    }
  }

  void _onActiveSessionsChanged() {
    if (!mounted) return;
    _checkActiveSession();
  }

  Future<void> _maybeStartOnboardingTutorial() async {
    // Pas de tutoriel en mode invité — on attend qu'un compte existe.
    if (!mounted) return;
    final isGuest = context.read<GuestModeProvider>().isGuest;
    if (isGuest) return;

    final seen = await _tutorialService.hasSeenMainTutorial();
    if (seen || !mounted) return;

    // Laisse le temps aux premiers frames (banners, header) de se poser
    // avant de positionner les overlays.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final ctx = _showcaseContext;
    if (ctx == null || !ctx.mounted) return;

    ShowCaseWidget.of(ctx).startShowCase([
      _feedShowcaseKey,
      _feedContentShowcaseKey,
      _museShowcaseKey,
      _fabShowcaseKey,
      _profileShowcaseKey,
    ]);
  }

  void _setupSyncListener() {
    final connectivity = Provider.of<ConnectivityProvider>(context, listen: false);
    connectivity.onSyncCompleted = () {
      if (!mounted) return;
      final count = connectivity.lastSyncCount;
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).offlineSyncSuccess(count)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Rafraîchir les sessions actives après sync
        _checkActiveSession();
      }
    };
  }

  @override
  void dispose() {
    if (DeepLinkService.onRoute == _handleDeepLinkRoute) {
      DeepLinkService.onRoute = null;
    }
    _activeSessionTimer?.cancel();
    ReadingSessionService.activeSessionsVersion
        .removeListener(_onActiveSessionsChanged);
    WatchSessionDraftService.draftVersion.removeListener(_onWatchDraftSaved);
    KindleAutoSyncService.connectedVersion.removeListener(_onKindleConnected);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppPaused() async {
    // Reset so the modal shows again next time the app comes to the foreground.
    _staleModalShown = false;
    _watchCatchupShown = false;

    if (_activeSession == null) return;

    // Record when the app went to background so we can detect 4h+ absence.
    await _pauseService.saveBackgroundedAt(DateTime.now());

    // Schedule a reminder notification in 4 hours.
    if (mounted) {
      final l = AppLocalizations.of(context);
      await MonthlyNotificationService().scheduleStaleSessionNotification(
        notifTitle: l.staleSessionNotifTitle,
        notifBody: l.staleSessionNotifBody,
      );
    }
  }

  Future<void> _onAppResumed() async {
    // Cancel the stale-session notification — user is back in the app.
    await MonthlyNotificationService().cancelStaleSessionNotification();

    final backgroundedAt = await _pauseService.getBackgroundedAt();
    await _pauseService.clearBackgroundedAt();

    final absence = backgroundedAt != null
        ? DateTime.now().difference(backgroundedAt)
        : null;

    // Auto-pause if the session has been running unattended for >= 4 hours
    // and was not already manually paused.
    if (absence != null && _activeSession != null) {
      if (absence >= const Duration(hours: 4)) {
        final alreadyPaused = await _pauseService.getPausedAt();
        if (alreadyPaused == null) {
          // Preserve any previously accumulated pause duration — only mark
          // the start of this new auto-pause (backdated to when the app
          // went to background).
          await _pauseService.savePauseStart(backgroundedAt!);
        }
      }
    }

    _checkAnniversary();
    _checkKindleAutoSync();
    // Consommer une éventuelle commande Watch en attente (ex. stop reçu
    // pendant que l'app était en arrière-plan) AVANT de lire l'état des
    // sessions : sinon la session paraît encore active, le rattrapage est
    // sauté et le dialogue n'apparaît qu'au prochain retour au premier plan.
    await WatchControlService().pollNow();
    // Refresh active session, then show recovery modal if needed.
    await _checkActiveSession();
    _maybeShowStaleSessionModal(absence);
    _maybeShowWatchSessionCatchup();
    _refreshSubscription();
    MonthlyNotificationService().scheduleNextMonthlyNotification();
    _updateHomeWidget();
  }

  void _maybeShowStaleSessionModal(Duration? absence) {
    if (!mounted) return;
    if (_staleModalShown) return;
    if (_activeSession == null || _activeSessionBook == null) return;
    // Sortie trop brève (ou inconnue) → on laisse la session reprendre
    // silencieusement sans demander « tu as fini de lire ? ».
    if (absence == null || absence < _staleSessionMinAbsence) return;

    _staleModalShown = true;

    final session = _activeSession!;
    final l = AppLocalizations.of(context);
    final colors = context.appColors;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l.staleSessionModalTitle,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          l.staleSessionModalBody,
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l.staleSessionContinueButton,
              style: TextStyle(color: ctx.appColors.primary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EndReadingSessionPage(activeSession: session),
                ),
              ).then((_) => _checkActiveSession());
            },
            child: Text(
              l.staleSessionFinishButton,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enrichMissingCovers() async {
    try {
      // Only run reEnrichSuspiciousBooks (version-gated, runs once per version).
      // enrichMissingCovers is no longer automatic — it runs after Kindle import
      // or manual refresh to avoid burning the shared Google Books API quota.
      final service = BooksService();
      await service.reEnrichSuspiciousBooks();
      // One-time Amazon cover backfill (version-gated). Quota-free.
      await service.enrichCoversWithAmazon();
    } catch (_) {}
  }

  Future<void> _updateHomeWidget() async {
    try {
      await WidgetService().updateWidget();
    } catch (_) {}
  }

  void _consumePendingNotification() {
    final message = PushNotificationService.pendingInitialMessage;
    if (message == null) return;
    PushNotificationService.pendingInitialMessage = null;

    final data = message.data;
    if (data['type'] == 'monthly_wrapped') {
      final month = int.tryParse(data['month'] ?? '');
      final year = int.tryParse(data['year'] ?? '');
      if (month == null || year == null) return;

      // Affiche la bannière dans le feed pendant 24 h (filet de sécurité
      // au cas où la navigation immédiate échouerait).
      WrappedBannerService().setPending(month: month, year: year);

      // Petit délai pour laisser le Scaffold se monter complètement avant
      // de pousser une nouvelle route (sinon la transition peut être ratée).
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MonthlyWrappedScreen(month: month, year: year),
          ),
        );
      });
    }
  }

  /// Cold start via un deep link (ex: lien email « demande d'ami ») : la
  /// route a été mise en attente par DeepLinkService car le splash allait
  /// écraser toute page poussée. On la consomme une fois le Scaffold monté.
  void _consumePendingDeepLink() {
    final route = DeepLinkService.pendingRoute;
    if (route == null) return;
    DeepLinkService.pendingRoute = null;

    // Petit délai pour laisser le Scaffold se monter complètement avant de
    // pousser une nouvelle route (même logique que _consumePendingNotification).
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _handleDeepLinkRoute(route);
    });
  }

  void _handleDeepLinkRoute(String route) {
    if (!mounted) return;
    switch (route) {
      case 'notifications':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
      case 'read':
        _openStartSessionOnCurrentBook();
    }
  }

  /// Route `read` (e-mail de relance) : ouvre l'écran de démarrage de
  /// session sur le livre en cours le plus récent. Sans livre en cours, on
  /// laisse l'utilisateur sur le feed — le FAB reste la porte d'entrée.
  Future<void> _openStartSessionOnCurrentBook() async {
    try {
      if (_activeSession != null) return; // une session tourne déjà
      final books = await BooksService().getUserBooksWithStatus();
      final current = books.firstWhere(
        (b) => b['status'] == 'reading' && b['is_hidden'] != true,
        orElse: () => books.isNotEmpty ? books.first : <String, dynamic>{},
      );
      final book = current['book'];
      if (book is! Book || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StartReadingSessionPageUnified(book: book),
        ),
      );
    } catch (e) {
      debugPrint('Erreur route read: $e');
    }
  }

  Future<void> _checkActiveSession() async {
    if (!mounted) return;

    try {
      final sessions = await ReadingSessionService().getAllActiveSessions();

      if (!mounted) return;

      if (sessions.isNotEmpty) {
        final session = sessions.first;
        final bookData = await Supabase.instance.client
            .from('books')
            .select()
            .eq('id', int.parse(session.bookId))
            .single();
        final book = Book.fromJson(bookData);

        if (!mounted) return;

        setState(() {
          _activeSession = session;
          _activeSessionBook = book;
          _activeSessionElapsed =
              DateTime.now().difference(session.startTime);
        });
        _startActiveSessionTimer();
      } else {
        _activeSessionTimer?.cancel();
        if (mounted) {
          setState(() {
            _activeSession = null;
            _activeSessionBook = null;
            _activeSessionElapsed = Duration.zero;
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur _checkActiveSession: $e');
    }
  }

  void _startActiveSessionTimer() {
    _activeSessionTimer?.cancel();
    _activeSessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _activeSession == null) return;
      setState(() {
        _activeSessionElapsed =
            DateTime.now().difference(_activeSession!.startTime);
      });
    });
  }

  Future<void> _navigateToActiveSession() async {
    if (_activeSession == null || _activeSessionBook == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveReadingSessionPage(
          activeSession: _activeSession!,
          book: _activeSessionBook!,
        ),
      ),
    );

    // Re-check after returning (session may have ended)
    _checkActiveSession();
  }

  Future<void> _refreshSubscription() async {
    if (!mounted) return;
    try {
      await Provider.of<SubscriptionProvider>(context, listen: false)
          .refreshStatus();
    } catch (e) {
      debugPrint('Erreur _refreshSubscription: $e');
    }
  }

  Future<void> _checkAnniversary() async {
    if (!mounted) return;

    try {
      final anniversaryService = AnniversaryService();
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);

      final badge = await anniversaryService.checkAndTriggerAnniversary(
        isPremium: subscriptionProvider.isPremium,
      );

      if (badge != null && mounted) {
        final stats = await anniversaryService.getAnniversaryStats();
        if (!mounted) return;

        await AnniversaryUnlockOverlay.show(
          context,
          badge: badge,
          stats: stats,
        );

        await anniversaryService.markAsSeen(badge.id);
      }
    } catch (e) {
      debugPrint('Erreur _checkAnniversary: $e');
    }
  }

  /// Une connexion Kindle vient d'aboutir : le cooldown mémoire de 5 min ne
  /// doit pas retenir cette vérification-là (une tentative expirée juste
  /// avant la reconnexion l'aurait armé), les cookies sont neufs.
  void _onKindleConnected() {
    _lastKindleSyncAttempt = null;
    _checkKindleAutoSync();
  }

  Future<void> _checkKindleAutoSync() async {
    if (!mounted || _showKindleAutoSync) return;

    // Cooldown: pas de nouvelle tentative si < 5 min depuis la dernière
    if (_lastKindleSyncAttempt != null &&
        DateTime.now().difference(_lastKindleSyncAttempt!) < _kindleSyncCooldown) {
      return;
    }

    try {
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      final autoSyncService = KindleAutoSyncService();

      // Tâche d'arrière-plan (palier 2) : enregistrée dès que Kindle est
      // connecté et l'auto-sync actif, idempotent. Elle vérifie elle-même
      // premium, espacement et cookies à chaque exécution.
      if (subscriptionProvider.isPremium &&
          await autoSyncService.isBackgroundSyncEligible()) {
        unawaited(KindleBackgroundSync.ensureScheduled());
      }

      final shouldSync = await autoSyncService.shouldAutoSync(
        isPremium: subscriptionProvider.isPremium,
      );

      if (shouldSync && mounted) {
        _lastKindleSyncAttempt = DateTime.now();
        setState(() {
          _kindleSyncMode = KindleSyncMode.full;
          _showKindleAutoSync = true;
        });
        return;
      }

      // Pas de sync complet dû : mini-sync progression (« rien à faire » —
      // la lecture Kindle de la veille devient une session à l'ouverture).
      final shouldProgress = await autoSyncService.shouldProgressSync(
        isPremium: subscriptionProvider.isPremium,
      );
      if (shouldProgress && mounted) {
        _lastKindleSyncAttempt = DateTime.now();
        setState(() {
          _kindleSyncMode = KindleSyncMode.progressOnly;
          _showKindleAutoSync = true;
        });
      }
    } catch (e) {
      debugPrint('Erreur _checkKindleAutoSync: $e');
    }
  }

  void _onKindleAutoSyncCompleted() {
    if (!mounted) return;
    setState(() => _showKindleAutoSync = false);
  }

  /// Des sessions viennent d'être créées depuis la progression Kindle :
  /// rafraîchir le feed (le notifier « amis » recharge tout le feed) et le
  /// dire discrètement.
  void _onKindleSessionsCreated(int count) {
    if (!mounted) return;
    FeedPage.notifyFriendsChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).kindleSessionsAdded(count)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onKindleAutoSyncSuccess(_) {
    if (!mounted) return;
    // Sync OK → la session Amazon est valide, on ré-arme la notif d'expiration.
    KindleAutoSyncService().clearExpiredNotified();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).kindleSyncedAutomatically),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _onKindleCookiesExpired() async {
    if (!mounted) return;
    final service = KindleAutoSyncService();
    // Une seule notification par expiration : pas de spam à chaque ouverture.
    if (await service.hasNotifiedExpired()) return;
    await service.markExpiredNotified();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.kindleSessionExpired),
            const SizedBox(height: 6),
            // « Je ne veux plus synchroniser » : coupe l'auto-sync — donc la
            // WebView cachée qui détecte l'expiration — et le bandeau ne
            // revient jamais. Réactivable dans Réglages, et ré-armé
            // automatiquement par une reconnexion Kindle réussie.
            GestureDetector(
              onTap: () async {
                await KindleAutoSyncService().setAutoSyncEnabled(false);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.kindleSyncDisabled),
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
              child: Text(
                l10n.kindleStopSyncing,
                style: const TextStyle(
                  color: Colors.white70,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white70,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: l10n.kindleReconnect,
          onPressed: () {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KindleLoginPage()),
            );
          },
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    // Mode invité : Muse (1) et Mon espace (3) nécessitent un compte.
    final isGuest = context.read<GuestModeProvider>().isGuest;
    if (isGuest && (index == 1 || index == 3)) {
      // Muse et Mon espace sont deux hameçons très différents : on les
      // distingue pour savoir lequel donne envie de créer un compte.
      showRequireAccountSheet(
        context,
        source: index == 1 ? 'tab_muse' : 'tab_profile',
      );
      return;
    }
    // Re-tap sur l'onglet feed déjà sélectionné : remonter en haut.
    if (index == 0 && _selectedIndex == 0) {
      FeedPage.notifyScrollToTop();
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      disableMovingAnimation: true,
      onFinish: _onTutorialFinished,
      builder: (showcaseCtx) {
        _showcaseContext = showcaseCtx;
        return _buildScaffold(showcaseCtx);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final hasActiveBanner =
        _activeSession != null && _activeSessionBook != null;
    final isOffline = !Provider.of<ConnectivityProvider>(context).isOnline;
    final l10n = AppLocalizations.of(context);

    final topPadding = (hasActiveBanner ? 44.0 : 0.0) + (isOffline ? 36.0 : 0.0);

    final body = Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOffline) const OfflineBanner(),
            if (hasActiveBanner)
              ActiveSessionBanner(
                session: _activeSession!,
                book: _activeSessionBook!,
                elapsed: _activeSessionElapsed,
                onTap: _navigateToActiveSession,
              ),
          ],
        ),
        if (_showKindleAutoSync)
          KindleAutoSyncWidget(
            mode: _kindleSyncMode,
            onCompleted: _onKindleAutoSyncCompleted,
            onSyncSuccess: _onKindleAutoSyncSuccess,
            onCookiesExpired: _onKindleCookiesExpired,
            onKindleSessionsCreated: _onKindleSessionsCreated,
          ),
      ],
    );

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, Icons.home_outlined, Icons.home, l10n.navFeed),
            _buildNavItem(
              context,
              1,
              Icons.auto_awesome_outlined,
              Icons.auto_awesome,
              l10n.navMuse,
              showcaseKey: _museShowcaseKey,
              showcaseTitle: l10n.tutorialMuseTitle,
              showcaseDescription: l10n.tutorialMuseDescription,
            ),
            const SizedBox(width: 60), // espace pour le notch du FAB
            _buildNavItem(context, 2, Icons.groups_outlined, Icons.groups, l10n.navClub),
            _buildNavItem(
              context,
              3,
              Icons.person_outline,
              Icons.person,
              l10n.navProfile,
              showcaseKey: _profileShowcaseKey,
              showcaseTitle: l10n.tutorialProfileTitle,
              showcaseDescription: l10n.tutorialProfileDescription,
            ),
          ],
        ),
      ),
      floatingActionButton: Showcase(
        key: _fabShowcaseKey,
        title: l10n.tutorialFabTitle,
        description: l10n.tutorialFabDescription,
        targetShapeBorder: const CircleBorder(),
        targetPadding: const EdgeInsets.all(8),
        tooltipBackgroundColor: context.appColors.primary,
        textColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        descTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        child: const GlobalReadingSessionFAB(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _onTutorialFinished() {
    _tutorialService.markMainTutorialSeen();
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    GlobalKey? showcaseKey,
    String? showcaseTitle,
    String? showcaseDescription,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? context.appColors.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSelected ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );

    if (showcaseKey != null) {
      content = Showcase(
        key: showcaseKey,
        title: showcaseTitle,
        description: showcaseDescription ?? '',
        targetBorderRadius: BorderRadius.circular(AppRadius.m),
        targetPadding: const EdgeInsets.all(2),
        tooltipBackgroundColor: context.appColors.primary,
        textColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        descTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        child: content,
      );
    }

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: content,
      ),
    );
  }
}
