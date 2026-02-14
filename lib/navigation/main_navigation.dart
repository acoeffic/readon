// navigation/main_navigation.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/feed/feed_page.dart';
import '../pages/books/user_books_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/groups/groups_page.dart';
import '../widgets/global_reading_session_fab.dart';
import '../theme/app_theme.dart';
import '../providers/subscription_provider.dart';
import '../features/badges/services/anniversary_service.dart';
import '../features/badges/widgets/anniversary_unlock_overlay.dart';
import '../services/kindle_auto_sync_service.dart';
import '../services/monthly_notification_service.dart';
import '../widgets/kindle_auto_sync_widget.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _showKindleAutoSync = false;

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
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAnniversary();
      _checkKindleAutoSync();
      MonthlyNotificationService().scheduleNextMonthlyNotification();
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
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          if (_showKindleAutoSync)
            KindleAutoSyncWidget(
              onCompleted: _onKindleAutoSyncCompleted,
              onSyncSuccess: _onKindleAutoSyncSuccess,
            ),
        ],
      ),
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
