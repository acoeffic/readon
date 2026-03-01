// pages/feed/feed_page.dart
// Page principale du flux (Feed) avec activités des amis et contenu communautaire

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_content.dart';
import '../feed/widgets/feed_header.dart';
import 'widgets/friend_activity_card.dart';
import 'widgets/book_finished_card.dart';
import '../feed/widgets/flow_card.dart';
import '../../services/flow_service.dart';
import '../../models/reading_flow.dart';
import 'flow_detail_page.dart';
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
import '../../models/reading_session.dart';
import '../sessions/session_detail_page.dart';
import 'widgets/find_friends_cta.dart';
import 'widgets/invite_friends_banner.dart';
import '../friends/search_users_page.dart';
import 'widgets/curated_lists_carousel.dart';
import '../../models/curated_list.dart';
import '../../services/curated_lists_service.dart';
import '../../data/curated_lists_data.dart';
import '../curated_lists/curated_list_detail_page.dart';
import '../curated_lists/all_curated_lists_page.dart';
import '../books/user_books_page.dart';
import 'widgets/active_readers_card.dart';
import 'widgets/community_badge_unlock_card.dart';
import '../friends/friend_profile_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final supabase = Supabase.instance.client;
  final flowService = FlowService();
  final booksService = BooksService();
  final suggestionsService = SuggestionsService();
  final trendingService = TrendingService();
  final curatedListsService = CuratedListsService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> friendActivities = [];
  ReadingFlow? currentFlow;
  Map<String, dynamic>? currentReadingBook;
  List<BookSuggestion> suggestions = [];
  bool loading = true;

  // Pagination des activités
  bool _isLoadingMoreActivities = false;
  bool _hasMoreActivities = true;
  int _activitiesOffset = 0;
  static const int _activitiesPageSize = 20;

  // Contenu communautaire
  int friendCount = 0;
  FeedTier feedTier = FeedTier.friendsOnly;
  List<Map<String, dynamic>> trendingBooks = [];
  List<Map<String, dynamic>> communitySessions = [];
  List<Map<String, dynamic>> activeReaders = [];
  List<Map<String, dynamic>> badgeUnlocks = [];

  // Listes curatées
  Map<int, int> curatedReaderCounts = {};
  Set<int> savedCuratedListIds = {};

  // Ordre aléatoire des sections du feed
  // 0 = sessions, 1 = suggestions, 2 = trending books, 3 = lecteurs actifs, 4 = badges
  List<int> _feedSectionOrder = [0, 1, 2, 3, 4];

  @override
  void initState() {
    super.initState();
    _feedSectionOrder = [0, 1, 2, 3, 4]..shuffle(Random());
    _scrollController.addListener(_onScroll);
    loadFeed();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreActivities();
    }
  }

  Future<void> _loadMoreActivities() async {
    if (_isLoadingMoreActivities || !_hasMoreActivities) return;
    if (feedTier == FeedTier.trending) return; // Pas d'activités amis

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoadingMoreActivities = true);

    try {
      final activitiesRes = await supabase.rpc('get_feed', params: {
        'p_user_id': user.id,
        'p_limit': _activitiesPageSize,
        'p_offset': _activitiesOffset,
      });
      final newActivities = List<Map<String, dynamic>>.from(activitiesRes ?? []);

      setState(() {
        friendActivities.addAll(newActivities);
        _isLoadingMoreActivities = false;
        _hasMoreActivities = newActivities.length >= _activitiesPageSize;
        _activitiesOffset += newActivities.length;
      });
    } catch (e) {
      debugPrint('Erreur _loadMoreActivities: $e');
      setState(() => _isLoadingMoreActivities = false);
    }
  }

  Future<void> loadFeed() async {
    setState(() {
      loading = true;
      _activitiesOffset = 0;
      _hasMoreActivities = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => loading = false);
        return;
      }

      // Charger en parallele : flow, livre en cours, nombre d'amis, suggestions, curated lists
      final results = await Future.wait([
        flowService.getUserFlow(),
        booksService.getCurrentReadingBook(),
        trendingService.getAcceptedFriendCount(),
        suggestionsService.getPersonalizedSuggestions(limit: 5),
        curatedListsService.getReaderCounts(
            kCuratedLists.map((l) => l.id).toList()),
        curatedListsService.getSavedListIds(),
      ]);

      final flow = results[0] as ReadingFlow?;
      final currentBook = results[1] as Map<String, dynamic>?;
      final fCount = results[2] as int;
      final suggestionsRes = results[3] as List<BookSuggestion>;
      final readerCountsRes = results[4] as Map<int, int>;
      final savedListIdsRes = results[5] as Set<int>;
      final tier = trendingService.determineFeedTier(fCount);

      // Charger conditionnellement selon le tier
      List<Map<String, dynamic>> activities = [];
      List<Map<String, dynamic>> trending = [];
      List<Map<String, dynamic>> community = [];
      List<Map<String, dynamic>> readers = [];
      List<Map<String, dynamic>> unlocks = [];

      if (tier == FeedTier.friendsOnly || tier == FeedTier.mixed) {
        final activitiesRes = await supabase.rpc('get_feed', params: {
          'p_user_id': user.id,
          'p_limit': _activitiesPageSize,
          'p_offset': 0,
        });
        activities = List<Map<String, dynamic>>.from(activitiesRes ?? []);
      }

      if (tier == FeedTier.mixed || tier == FeedTier.trending) {
        final trendingResults = await Future.wait([
          trendingService.getTrendingBooks(limit: 5, forceRefresh: false),
          trendingService.getCommunitySessions(limit: 10, forceRefresh: false),
          trendingService.getActiveReaders(limit: 10, forceRefresh: false),
          trendingService.getCommunityBadgeUnlocks(limit: 8, forceRefresh: false),
        ]);
        trending = trendingResults[0];
        community = trendingResults[1];
        readers = trendingResults[2];
        unlocks = trendingResults[3];
      }

      if (!mounted) return;

      // Mélanger l'ordre des sections du feed
      final random = Random();
      final newOrder = [0, 1, 2, 3, 4]..shuffle(random);
      debugPrint('Feed tier: $tier, section order: $newOrder');

      setState(() {
        currentFlow = flow;
        currentReadingBook = currentBook;
        friendCount = fCount;
        feedTier = tier;
        friendActivities = activities;
        trendingBooks = trending;
        communitySessions = community;
        activeReaders = readers;
        badgeUnlocks = unlocks;
        suggestions = suggestionsRes;
        curatedReaderCounts = readerCountsRes;
        savedCuratedListIds = savedListIdsRes;
        _feedSectionOrder = newOrder;
        loading = false;
        _hasMoreActivities = activities.length >= _activitiesPageSize;
        _activitiesOffset = activities.length;
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

  void _openCommunitySession(Map<String, dynamic> data) {
    final session = ReadingSession(
      id: (data['id'] ?? '').toString(),
      userId: (data['user_id'] ?? '').toString(),
      bookId: (data['book_id'] ?? '').toString(),
      startPage: data['start_page'] as int? ?? 0,
      endPage: data['end_page'] as int?,
      startTime: data['start_time'] != null
          ? DateTime.parse(data['start_time'] as String).toLocal()
          : DateTime.now(),
      endTime: data['end_time'] != null
          ? DateTime.parse(data['end_time'] as String).toLocal()
          : null,
      createdAt: data['session_created_at'] != null
          ? DateTime.parse(data['session_created_at'] as String).toLocal()
          : DateTime.now(),
      updatedAt: data['session_created_at'] != null
          ? DateTime.parse(data['session_created_at'] as String).toLocal()
          : DateTime.now(),
    );

    final bookId = data['book_id'];
    final book = data['book_title'] != null
        ? Book(
            id: bookId is int ? bookId : 0,
            title: data['book_title'] as String,
            author: data['book_author'] as String?,
            coverUrl: data['book_cover'] as String?,
          )
        : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailPage(
          session: session,
          book: book,
          isOwn: false,
        ),
      ),
    );
  }

  Future<void> _openTrendingBook(Map<String, dynamic> data) async {
    final bookId = data['book_id'] as int?;
    if (bookId == null) return;

    try {
      final book = await booksService.getBookById(bookId);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookDetailPage(book: book),
        ),
      );
    } catch (e) {
      debugPrint('Erreur _openTrendingBook: $e');
    }
  }

  void _navigateToSearchUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchUsersPage()),
    );
  }

  void _shareInviteLink() {
    final text = '\u{1F4D6} Rejoins-moi sur LexDay !\n\n'
        'Tu lis quoi en ce moment ? \u{1F440}\n'
        'lexday.app';
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    Share.share(text, sharePositionOrigin: origin);
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

  /// Construit la section des sessions communautaires
  List<Widget> _buildCommunitySessionsSection() {
    if (communitySessions.isEmpty) return [];
    return [
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
      ...communitySessions.map(
        (session) => CommunitySessionCard(
              session: session,
              onTap: () => _openCommunitySession(session),
            ),
      ),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Construit la section des livres tendances
  List<Widget> _buildTrendingBooksSection() {
    if (trendingBooks.isEmpty) return [];
    return [
      TrendingBooksCard(
        books: trendingBooks,
        onBookTap: _openTrendingBook,
      ),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Construit la section des listes curatées
  List<Widget> _buildCuratedListsSection() {
    return [
      CuratedListsCarousel(
        lists: kCuratedLists,
        readerCounts: curatedReaderCounts,
        savedListIds: savedCuratedListIds,
        onToggleSave: _toggleCuratedListSave,
        onSeeAll: _navigateToAllCuratedLists,
        onListTap: _navigateToCuratedListDetail,
      ),
      const SizedBox(height: AppSpace.l),
    ];
  }

  void _toggleCuratedListSave(int listId, bool save) async {
    // Optimistic update
    setState(() {
      if (save) {
        savedCuratedListIds.add(listId);
      } else {
        savedCuratedListIds.remove(listId);
      }
    });

    try {
      if (save) {
        await curatedListsService.saveList(listId);
      } else {
        await curatedListsService.unsaveList(listId);
      }
    } catch (e) {
      // Rollback
      if (mounted) {
        setState(() {
          if (save) {
            savedCuratedListIds.remove(listId);
          } else {
            savedCuratedListIds.add(listId);
          }
        });
      }
    }
  }

  void _navigateToAllCuratedLists() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllCuratedListsPage()),
    );
  }

  void _navigateToCuratedListDetail(CuratedList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CuratedListDetailPage(list: list),
      ),
    );
  }

  /// Construit la section suggestions avec espacement
  List<Widget> _buildSuggestionsSectionWithSpacing() {
    if (suggestions.isEmpty) return [];
    return [
      _buildSuggestionsSection(),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Naviguer vers le profil d'un lecteur communautaire
  void _openReaderProfile(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendProfilePage(userId: userId),
      ),
    );
  }

  /// Construit la section des lecteurs actifs
  List<Widget> _buildActiveReadersSection() {
    if (activeReaders.isEmpty) return [];
    return [
      ActiveReadersCard(
        readers: activeReaders,
        onReaderTap: _openReaderProfile,
      ),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Construit la section des badges communautaires
  List<Widget> _buildBadgeUnlocksSection() {
    if (badgeUnlocks.isEmpty) return [];
    return [
      Row(
        children: [
          const Text('🏅', style: TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpace.s),
          Text(
            'Badges récents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
      const SizedBox(height: AppSpace.s),
      ...badgeUnlocks.map(
        (unlock) => CommunityBadgeUnlockCard(
          unlock: unlock,
          onTap: () => _openReaderProfile(unlock),
        ),
      ),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Construit la section des badges communautaires (limitée pour feed mixte)
  List<Widget> _buildBadgeUnlocksSectionLimited() {
    if (badgeUnlocks.isEmpty) return [];
    return [
      Row(
        children: [
          const Text('🏅', style: TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpace.s),
          Text(
            'Badges récents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
      const SizedBox(height: AppSpace.s),
      ...badgeUnlocks.take(3).map(
        (unlock) => CommunityBadgeUnlockCard(
          unlock: unlock,
          onTap: () => _openReaderProfile(unlock),
        ),
      ),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Feed tier 3 : 0 amis — contenu tendances communauté
  List<Widget> _buildTrendingFeed() {
    // Construire les sections dans l'ordre aléatoire
    // 0 = sessions, 1 = suggestions, 2 = trending books, 3 = lecteurs actifs, 4 = badges
    final sections = <List<Widget>>[];
    final order = _feedSectionOrder.isNotEmpty ? _feedSectionOrder : [0, 1, 2, 3, 4];
    for (final index in order) {
      switch (index) {
        case 0:
          sections.add(_buildCommunitySessionsSection());
          break;
        case 1:
          sections.add(_buildSuggestionsSectionWithSpacing());
          break;
        case 2:
          sections.add(_buildTrendingBooksSection());
          break;
        case 3:
          sections.add(_buildActiveReadersSection());
          break;
        case 4:
          sections.add(_buildBadgeUnlocksSection());
          break;
      }
    }

    return [
      // Bannière d'invitation (toujours en premier)
      InviteFriendsBanner(
        onShare: _shareInviteLink,
        onFindFriends: _navigateToSearchUsers,
      ),
      const SizedBox(height: AppSpace.l),

      // Listes curatées (position fixe)
      ..._buildCuratedListsSection(),

      // Sections dans l'ordre aléatoire
      ...sections.expand((s) => s),

      // CTA trouver des amis (toujours en dernier)
      FindFriendsCta(onFindFriends: _navigateToSearchUsers),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Construit la section des sessions communautaires (limitée pour feed mixte)
  List<Widget> _buildCommunitySessionsSectionLimited() {
    if (communitySessions.isEmpty) return [];
    return [
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
        (session) => CommunitySessionCard(
              session: session,
              onTap: () => _openCommunitySession(session),
            ),
      ),
      const SizedBox(height: AppSpace.l),
    ];
  }

  /// Feed tier 2 : 1-2 amis — mixte amis + communauté
  List<Widget> _buildMixedFeed() {
    // Construire les sections dans l'ordre aléatoire
    // 0 = sessions, 1 = suggestions, 2 = trending books, 3 = lecteurs actifs, 4 = badges
    final sections = <List<Widget>>[];
    final order = _feedSectionOrder.isNotEmpty ? _feedSectionOrder : [0, 1, 2, 3, 4];
    for (final index in order) {
      switch (index) {
        case 0:
          sections.add(_buildCommunitySessionsSectionLimited());
          break;
        case 1:
          sections.add(_buildSuggestionsSectionWithSpacing());
          break;
        case 2:
          sections.add(_buildTrendingBooksSection());
          break;
        case 3:
          sections.add(_buildActiveReadersSection());
          break;
        case 4:
          sections.add(_buildBadgeUnlocksSectionLimited());
          break;
      }
    }

    return [
      // Bannière d'invitation (en haut du feed mixte)
      InviteFriendsBanner(
        onShare: _shareInviteLink,
        onFindFriends: _navigateToSearchUsers,
      ),
      const SizedBox(height: AppSpace.l),

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
      else ...[
        // 5 premières activités
        ...friendActivities.take(5).map(_buildActivityCard),
        // Listes curatées après 5 activités
        ..._buildCuratedListsSection(),
        // Activités restantes
        ...friendActivities.skip(5).map(_buildActivityCard),
      ],

      const SizedBox(height: AppSpace.l),

      // Séparateur communauté
      const CommunitySectionSeparator(),

      // Sections dans l'ordre aléatoire
      ...sections.expand((s) => s),

      // CTA trouver des amis (toujours en dernier)
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
        // 5 premières activités
        ...friendActivities.take(5).map(_buildActivityCard),
        // Listes curatées après 5 activités
        ..._buildCuratedListsSection(),
        // Suggestions
        if (suggestions.isNotEmpty) ...[
          _buildSuggestionsSection(),
          const SizedBox(height: AppSpace.l),
        ],
        // Activités restantes
        ...friendActivities.skip(5).map(_buildActivityCard),
      ],
    ];
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['type'] as String?;
    final payload = activity['payload'] as Map<String, dynamic>?;
    final isBookFinished =
        type == 'book_finished' || payload?['book_finished'] == true;
    if (isBookFinished) return BookFinishedCard(activity: activity);
    return FriendActivityCard(activity: activity);
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
                child: ConstrainedContent(
                  child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
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

              // 👉 Flow de lecture
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (currentFlow != null)
                FlowCard(
                  flow: currentFlow!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FlowDetailPage(
                          initialFlow: currentFlow!,
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

              // Loading indicator pour pagination
              if (!loading && (_isLoadingMoreActivities || _hasMoreActivities))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: _isLoadingMoreActivities
                        ? const CircularProgressIndicator()
                        : const SizedBox.shrink(),
                  ),
                ),

                  ],
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
