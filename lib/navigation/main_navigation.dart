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
import '../services/books_service.dart';
import '../services/kindle_auto_sync_service.dart';
import '../services/monthly_notification_service.dart';
import '../services/onboarding_tutorial_service.dart';
import '../services/paywall_controller.dart';
import '../services/push_notification_service.dart';
import '../services/session_pause_service.dart';
import '../services/freeze_celebration_service.dart';
import '../services/flow_service.dart';
import '../services/wrapped_banner_service.dart';
import '../pages/reading/end_reading_session_page.dart';
import '../features/wrapped/monthly/monthly_wrapped_screen.dart';
import '../widgets/kindle_auto_sync_widget.dart';
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
  DateTime? _lastKindleSyncAttempt;
  static const _kindleSyncCooldown = Duration(minutes: 5);

  // Active session banner state
  ReadingSession? _activeSession;
  Book? _activeSessionBook;
  Timer? _activeSessionTimer;
  Duration _activeSessionElapsed = Duration.zero;

  // Stale session recovery: show modal once per foreground cycle
  bool _staleModalShown = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkAnniversary();
      _checkKindleAutoSync();
      _checkActiveSession();
      _setupSyncListener();
      _enrichMissingCovers();
      _consumePendingNotification();
      _updateHomeWidget();
      // Paywall avant le tutoriel : la sheet native iOS sinon recouvre les
      // overlays showcase et casse leur positionnement à la fermeture.
      await _maybeShowPaywall();
      if (!mounted) return;
      _maybeStartOnboardingTutorial();
      _checkAutoFreezeCelebration();
    });
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

  Future<void> _maybeShowPaywall() async {
    // Pas de paywall en mode invité — on attend qu'un compte soit créé.
    if (!mounted) return;
    final isGuest = context.read<GuestModeProvider>().isGuest;
    if (isGuest) return;

    // Laisse les premiers frames se poser (banners, header) avant de
    // pousser le paywall.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await PaywallController.maybeShowOnAppOpen(context);
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
    _activeSessionTimer?.cancel();
    ReadingSessionService.activeSessionsVersion
        .removeListener(_onActiveSessionsChanged);
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

    // Auto-pause if the session has been running unattended for >= 4 hours
    // and was not already manually paused.
    if (backgroundedAt != null && _activeSession != null) {
      final absence = DateTime.now().difference(backgroundedAt);
      if (absence >= const Duration(hours: 4)) {
        final alreadyPaused = await _pauseService.getPausedAt();
        if (alreadyPaused == null) {
          // Preserve any previously accumulated pause duration — only mark
          // the start of this new auto-pause (backdated to when the app
          // went to background).
          await _pauseService.savePauseStart(backgroundedAt);
        }
      }
    }

    _checkAnniversary();
    _checkKindleAutoSync();
    // Refresh active session, then show recovery modal if needed.
    await _checkActiveSession();
    _maybeShowStaleSessionModal();
    _refreshSubscription();
    MonthlyNotificationService().scheduleNextMonthlyNotification();
    _updateHomeWidget();
  }

  void _maybeShowStaleSessionModal() {
    if (!mounted) return;
    if (_staleModalShown) return;
    if (_activeSession == null || _activeSessionBook == null) return;

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

      final shouldSync = await autoSyncService.shouldAutoSync(
        isPremium: subscriptionProvider.isPremium,
      );

      if (shouldSync && mounted) {
        _lastKindleSyncAttempt = DateTime.now();
        setState(() => _showKindleAutoSync = true);
      }
    } catch (e) {
      debugPrint('Erreur _checkKindleAutoSync: $e');
    }
  }

  void _onKindleAutoSyncCompleted() {
    if (!mounted) return;
    setState(() => _showKindleAutoSync = false);
  }

  void _onKindleAutoSyncSuccess(_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).kindleSyncedAutomatically),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onItemTapped(int index) {
    // Mode invité : Muse (1) et Mon espace (3) nécessitent un compte.
    final isGuest = context.read<GuestModeProvider>().isGuest;
    if (isGuest && (index == 1 || index == 3)) {
      showRequireAccountSheet(context);
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
            onCompleted: _onKindleAutoSyncCompleted,
            onSyncSuccess: _onKindleAutoSyncSuccess,
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
