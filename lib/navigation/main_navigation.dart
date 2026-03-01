// navigation/main_navigation.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/feed/feed_page.dart';
import '../pages/books/user_books_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/groups/groups_page.dart';
import '../pages/reading/active_reading_session_page.dart';
import '../models/reading_session.dart';
import '../models/book.dart';
import '../services/reading_session_service.dart';
import '../widgets/global_reading_session_fab.dart';
import '../widgets/active_session_banner.dart';
import '../theme/app_theme.dart';
import '../providers/subscription_provider.dart';
import '../features/badges/services/anniversary_service.dart';
import '../features/badges/widgets/anniversary_unlock_overlay.dart';
import '../services/kindle_auto_sync_service.dart';
import '../services/monthly_notification_service.dart';
import '../widgets/kindle_auto_sync_widget.dart';
import '../utils/responsive.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _showKindleAutoSync = false;

  // Active session banner state
  ReadingSession? _activeSession;
  Book? _activeSessionBook;
  Timer? _activeSessionTimer;
  Duration _activeSessionElapsed = Duration.zero;

  final List<Widget> _pages = const [
    FeedPage(),
    UserBooksPage(),
    GroupsPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAnniversary();
      _checkKindleAutoSync();
      _checkActiveSession();
    });
  }

  @override
  void dispose() {
    _activeSessionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAnniversary();
      _checkKindleAutoSync();
      _checkActiveSession();
      _refreshSubscription();
      MonthlyNotificationService().scheduleNextMonthlyNotification();
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

    try {
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      final autoSyncService = KindleAutoSyncService();

      final shouldSync = await autoSyncService.shouldAutoSync(
        isPremium: subscriptionProvider.isPremium,
      );

      if (shouldSync && mounted) {
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
      const SnackBar(
        content: Text('Kindle synchronisé automatiquement'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);

    final hasActiveBanner =
        _activeSession != null && _activeSessionBook != null;

    final body = Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: hasActiveBanner ? 44.0 : 0),
          child: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
        ),
        if (hasActiveBanner)
          ActiveSessionBanner(
            session: _activeSession!,
            book: _activeSessionBook!,
            elapsed: _activeSessionElapsed,
            onTap: _navigateToActiveSession,
          ),
        if (_showKindleAutoSync)
          KindleAutoSyncWidget(
            onCompleted: _onKindleAutoSyncCompleted,
            onSyncSuccess: _onKindleAutoSyncSuccess,
          ),
      ],
    );

    if (isTablet) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                indicatorColor: AppColors.primary.withValues(alpha: 0.15),
                selectedIconTheme: const IconThemeData(color: AppColors.primary),
                selectedLabelTextStyle: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                leading: const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 24),
                  child: GlobalReadingSessionFAB(),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Feed'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.library_books_outlined),
                    selectedIcon: Icon(Icons.library_books),
                    label: Text('Biblio'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: Text('Club'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Mon espace'),
                  ),
                ],
              ),
              VerticalDivider(
                thickness: 1,
                width: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, Icons.home_outlined, Icons.home, 'Feed'),
            _buildNavItem(context, 1, Icons.library_books_outlined, Icons.library_books, 'Biblio'),
            const SizedBox(width: 60), // espace pour le notch du FAB
            _buildNavItem(context, 2, Icons.groups_outlined, Icons.groups, 'Club'),
            _buildNavItem(context, 3, Icons.person_outline, Icons.person, 'Mon espace'),
          ],
        ),
      ),
      floatingActionButton: const GlobalReadingSessionFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Padding(
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
        ),
      ),
    );
  }
}
