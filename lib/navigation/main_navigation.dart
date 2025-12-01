// navigation/main_navigation.dart
// Extraction depuis votre fichier monolithique

import 'package:flutter/material.dart';
import '../pages/feed/feed_page.dart';
import '../pages/books/add_book_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/feed/feed_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/books/user_books_page.dart';
import '../pages/friends/friends_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/welcome/welcome_page.dart';
import '../pages/books/start_reading_page.dart';
import '../pages/feed/widgets/feed_header.dart';
import '../pages/stats/stats_page.dart';
import '../pages/sessions/sessions_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    FeedPage(),
    SessionsPage(),
    BibliothequePage(),
    StatsPage(),
    ProfilPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Bibliothèque',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}