// pages/feed/feed_page.dart
// Page principale du flux (Feed) avec activités des amis et contenu communautaire

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../feed/widgets/feed_header.dart';
import 'widgets/friend_activity_card.dart';
import '../feed/widgets/streak_card.dart';
import '../../services/streak_service.dart';
import '../../models/reading_streak.dart';
import 'streak_detail_page.dart';
import 'widgets/continue_reading_card.dart';
import '../../services/books_service.dart';
import '../../models/book.dart';
import '../reading/start_reading_session_page_unified.dart';
import '../reading/active_reading_session_page.dart';
import '../../services/suggestions_service.dart';
import '../../models/book_suggestion.dart';
import '../../widgets/suggestion_card.dart';
import '../../services/trending_service.dart';
import 'widgets/trending_welcome_card.dart';
import 'widgets/trending_books_card.dart';
import 'widgets/community_session_card.dart';
import 'widgets/community_section_separator.dart';
import 'widgets/find_friends_cta.dart';
import '../friends/search_users_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final supabase = Supabase.instance.client;
  final streakService = StreakService();
  final booksService = BooksService();
  final suggestionsService = SuggestionsService();
  final trendingService = TrendingService();

  List<Map<String, dynamic>> friendActivities = [];
  ReadingStreak? currentStreak;
  Map<String, dynamic>? currentReadingBook;
  List<BookSuggestion> suggestions = [];
  bool loading = true;

  // Contenu communautaire
  int friendCount = 0;
  FeedTier feedTier = FeedTier.friendsOnly;
  List<Map<String, dynamic>> trendingBooks = [];
  List<Map<String, dynamic>> communitySessions = [];

  @override
  void initState() {
    super.initState();
    loadFeed();
  }

  Future<void> loadFeed() async {
    setState(() => loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => loading = false);
        return;
      }

      // Charger en parallele : streak, livre en cours, nombre d'amis, suggestions
      final results = await Future.wait([
        streakService.getUserStreak(),
        booksService.getCurrentReadingBook(),
        trendingService.getAcceptedFriendCount(),
        suggestionsService.getPersonalizedSuggestions(limit: 5),
      ]);

      final streak = results[0] as ReadingStreak?;
      final currentBook = results[1] as Map<String, dynamic>?;
      final fCount = results[2] as int;
      final suggestionsRes = results[3] as List<BookSuggestion>;
      final tier = trendingService.determineFeedTier(fCount);

      // Charger conditionnellement selon le tier
      List<Map<String, dynamic>> activities = [];
      List<Map<String, dynamic>> trending = [];
      List<Map<String, dynamic>> community = [];

      if (tier == FeedTier.friendsOnly || tier == FeedTier.mixed) {
        final activitiesRes = await supabase.rpc('get_feed', params: {
          'p_user_id': user.id,
          'p_limit': 20,
          'p_offset': 0,
        });
        activities = List<Map<String, dynamic>>.from(activitiesRes ?? []);
      }

      if (tier == FeedTier.mixed || tier == FeedTier.trending) {
        final trendingResults = await Future.wait([
          trendingService.getTrendingBooks(limit: 5, forceRefresh: false),
          trendingService.getCommunitySessions(limit: 10, forceRefresh: false),
        ]);
        trending = trendingResults[0];
        community = trendingResults[1];
      }

      if (!mounted) return;

      setState(() {
        currentStreak = streak;
        currentReadingBook = currentBook;
        friendCount = fCount;
        feedTier = tier;
        friendActivities = activities;
        trendingBooks = trending;
        communitySessions = community;
        suggestions = suggestionsRes;
        loading = false;
      });
    } catch (e) {
      debugPrint('Erreur loadFeed: $e');
      if (!mounted) return;
      setState(() => loading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _navigateToSearchUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchUsersPage()),
    );
  }

  Widget _buildSuggestionsSection() {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.l),
        Text(
          "Suggestions pour toi",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpace.s),
        SuggestionsCarousel(
          suggestions: suggestions,
          onAddToLibrary: (suggestion) async {
            final success = await suggestionsService.addSuggestedBookToLibrary(suggestion);
            if (!mounted) return;
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${suggestion.book.title} ajouté à votre bibliothèque'),
                  backgroundColor: Colors.green,
                ),
              );
              loadFeed();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Erreur lors de l\'ajout du livre'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  /// Feed tier 3 : 0 amis — contenu tendances communauté
  List<Widget> _buildTrendingFeed() {
    return [
      // Message d'accueil
      const TrendingWelcomeCard(),
      const SizedBox(height: AppSpace.l),

      // Top livres du moment
      if (trendingBooks.isNotEmpty) ...[
        TrendingBooksCard(books: trendingBooks),
        const SizedBox(height: AppSpace.l),
      ],

      // Sessions de la communauté
      if (communitySessions.isNotEmpty) ...[
        Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: AppSpace.s),
            Text(
              'Sessions récentes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s),
        ...communitySessions.take(4).map(
          (session) => CommunitySessionCard(session: session),
        ),
      ],

      // Suggestions
      _buildSuggestionsSection(),

      // Sessions restantes
      if (communitySessions.length > 4) ...[
        const SizedBox(height: AppSpace.s),
        ...communitySessions.skip(4).map(
          (session) => CommunitySessionCard(session: session),
        ),
      ],

      // CTA trouver des amis
      FindFriendsCta(onFindFriends: _navigateToSearchUsers),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Feed tier 2 : 1-2 amis — mixte amis + communauté
  List<Widget> _buildMixedFeed() {
    return [
      // Activités des amis
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Activité de tes amis",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (friendActivities.isNotEmpty)
            TextButton(
              onPressed: loadFeed,
              child: const Text('Rafraîchir'),
            ),
        ],
      ),
      const SizedBox(height: AppSpace.s),

      if (friendActivities.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.schedule, size: 32, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text(
                  'Tes amis n\'ont pas encore lu aujourd\'hui',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        )
      else
        ...friendActivities.map(
          (activity) => FriendActivityCard(activity: activity),
        ),

      // Suggestions
      _buildSuggestionsSection(),

      // Séparateur communauté
      const CommunitySectionSeparator(),

      // Top livres
      if (trendingBooks.isNotEmpty) ...[
        TrendingBooksCard(books: trendingBooks),
        const SizedBox(height: AppSpace.l),
      ],

      // Sessions communauté (limite a 5 pour le feed mixte)
      if (communitySessions.isNotEmpty) ...[
        Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: AppSpace.s),
            Text(
              'Sessions récentes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s),
        ...communitySessions.take(5).map(
          (session) => CommunitySessionCard(session: session),
        ),
      ],

      // CTA trouver des amis (discret)
      FindFriendsCta(onFindFriends: _navigateToSearchUsers),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Feed tier 1 : 3+ amis — comportement actuel
  List<Widget> _buildFriendsOnlyFeed() {
    return [
      // Activité des amis
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Activité de tes amis",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (friendActivities.isNotEmpty)
            TextButton(
              onPressed: loadFeed,
              child: const Text('Rafraîchir'),
            ),
        ],
      ),
      const SizedBox(height: AppSpace.s),

      if (friendActivities.isEmpty) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text(
                  'Pas encore d\'activité',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ajoutez des amis pour voir leurs lectures!',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        _buildSuggestionsSection(),
      ] else ...[
        // 4 premières activités
        ...friendActivities.take(4).map((activity) => FriendActivityCard(activity: activity)),
        // Suggestions après 4 activités
        if (suggestions.isNotEmpty) ...[
          _buildSuggestionsSection(),
          const SizedBox(height: AppSpace.l),
        ],
        // Activités restantes
        ...friendActivities.skip(4).map((activity) => FriendActivityCard(activity: activity)),
      ],
    ];
  }

  List<Widget> _buildFeedContent() {
    switch (feedTier) {
      case FeedTier.trending:
        return _buildTrendingFeed();
      case FeedTier.mixed:
        return _buildMixedFeed();
      case FeedTier.friendsOnly:
        return _buildFriendsOnlyFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const FeedHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: loadFeed,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpace.l),
                  children: [

              // 👉 Continuer la lecture
              if (!loading && currentReadingBook != null) ...[
                ContinueReadingCard(
                  book: currentReadingBook!['book'] as Book,
                  currentPage: (currentReadingBook!['current_page'] as num).toInt(),
                  totalPages: currentReadingBook!['total_pages'] as int?,
                  onTap: () async {
                    final book = currentReadingBook!['book'] as Book;
                    final session = await Navigator.push<dynamic>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StartReadingSessionPageUnified(
                          book: book,
                        ),
                      ),
                    );
                    if (session != null) {
                      if (!context.mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveReadingSessionPage(
                            activeSession: session,
                            book: book,
                          ),
                        ),
                      );
                    }
                    loadFeed();
                  },
                ),
                const SizedBox(height: AppSpace.l),
              ],

              // 👉 Streak de lecture
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (currentStreak != null)
                StreakCard(
                  streak: currentStreak!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StreakDetailPage(
                          initialStreak: currentStreak!,
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: AppSpace.l),

              // 👉 Contenu du feed (selon le tier)
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ..._buildFeedContent(),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
