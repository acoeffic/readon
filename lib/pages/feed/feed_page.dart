// pages/feed/feed_page.dart
// Page principale du flux (Feed) avec activités des amis et contenu communautaire

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
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
import '../../services/feed_cache.dart';
import '../../services/feed_cache_service.dart';
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
import '../curated_lists/prize_list_detail_page.dart';
import '../../models/prize_list.dart';
import '../../services/prize_list_service.dart';
import '../../widgets/prize_lists_carousel.dart';
import '../books/user_books_page.dart';
import 'widgets/active_readers_card.dart';
import 'widgets/community_badge_unlock_card.dart';
import '../friends/friend_profile_page.dart';
import '../../widgets/feed_skeleton_list.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  /// Notifier incrémenté quand la liste d'amis change (ajout/suppression).
  /// Le feed écoute ce notifier pour se rafraîchir automatiquement.
  static final friendsChanged = ValueNotifier<int>(0);

  /// Appeler après avoir accepté/ajouté un ami pour rafraîchir le feed.
  static void notifyFriendsChanged() => friendsChanged.value++;

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
  final prizeListService = PrizeListService();
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _feedChannel;

  List<Map<String, dynamic>> friendActivities = [];
  ReadingFlow? currentFlow;
  Map<String, dynamic>? currentReadingBook;
  List<BookSuggestion> suggestions = [];
  bool loading = true;

  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _revalidating = false;
  static const int _pageSize = 15;

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

  // Listes prix littéraires
  List<PrizeList> prizeLists = [];

  // Ordre aléatoire des sections du feed
  // 0 = sessions, 1 = suggestions, 2 = trending books, 3 = lecteurs actifs, 4 = badges
  List<int> _feedSectionOrder = [0, 1, 2, 3, 4];

  @override
  void initState() {
    super.initState();
    _feedSectionOrder = [0, 1, 2, 3, 4]..shuffle(Random());
    _scrollController.addListener(_onScroll);
    _subscribeToFeed();
    FeedPage.friendsChanged.addListener(_onFriendsChanged);
    loadFeed();
  }

  @override
  void dispose() {
    if (_feedChannel != null) {
      supabase.removeChannel(_feedChannel!);
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    FeedPage.friendsChanged.removeListener(_onFriendsChanged);
    super.dispose();
  }

  void _onFriendsChanged() {
    FeedCache.invalidate();
    FeedCacheService.clear();
    loadFeed();
  }

  void _subscribeToFeed() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Fan-out on write : écouter les insertions dans feed_items
    // filtrées par owner_id = user courant (le feed pré-calculé)
    _feedChannel = supabase
        .channel('feed_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'feed_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'owner_id',
            value: user.id,
          ),
          callback: (payload) {
            _onNewFeedItem(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _onNewFeedItem(Map<String, dynamic> record) {
    // feed_items contient déjà toutes les données dénormalisées
    // Pas besoin de faire un fetch supplémentaire pour le profil auteur
    if (mounted) {
      setState(() {
        friendActivities.insert(0, record);
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.7 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Cursor-based pagination par created_at (tri chronologique correct,
      // même pour les activités rétro-insérées lors de l'ajout d'ami).
      final lastCreatedAt = friendActivities.isNotEmpty
          ? friendActivities.last['created_at']
          : null;

      final more = await supabase.rpc('get_feed_v2', params: {
        'p_limit': _pageSize,
        if (lastCreatedAt != null) 'p_cursor': lastCreatedAt,
      });

      setState(() {
        friendActivities.addAll(List<Map<String, dynamic>>.from(more ?? []));
        _hasMore = (more as List?)?.length == _pageSize;
        _isLoadingMore = false;
      });

      // Mettre à jour les caches avec la liste complète
      final updatedCache = FeedCacheData(
        friendActivities: friendActivities,
        currentFlow: currentFlow,
        currentReadingBook: currentReadingBook,
        suggestions: suggestions,
        friendCount: friendCount,
        feedTier: feedTier,
        trendingBooks: trendingBooks,
        communitySessions: communitySessions,
        activeReaders: activeReaders,
        badgeUnlocks: badgeUnlocks,
        curatedReaderCounts: curatedReaderCounts,
        savedCuratedListIds: savedCuratedListIds,
        prizeLists: prizeLists,
        hasMore: _hasMore,
      );
      FeedCache.store(updatedCache);
      FeedCacheService.saveFeed(updatedCache); // fire-and-forget
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  /// Pull-to-refresh : invalide les caches et recharge depuis le réseau
  Future<void> _refreshFeed() async {
    FeedCache.invalidate();
    await FeedCacheService.clear();
    await _fetchFromNetwork(showLoading: false);
  }

  /// Applique un FeedCacheData au state
  void _applyCacheData(FeedCacheData c, {List<int>? sectionOrder}) {
    friendActivities = c.friendActivities;
    currentFlow = c.currentFlow;
    currentReadingBook = c.currentReadingBook;
    suggestions = c.suggestions;
    friendCount = c.friendCount;
    feedTier = c.feedTier;
    trendingBooks = c.trendingBooks;
    communitySessions = c.communitySessions;
    activeReaders = c.activeReaders;
    badgeUnlocks = c.badgeUnlocks;
    curatedReaderCounts = c.curatedReaderCounts;
    savedCuratedListIds = c.savedCuratedListIds;
    prizeLists = c.prizeLists;
    _hasMore = c.hasMore;
    if (sectionOrder != null) _feedSectionOrder = sectionOrder;
    loading = false;
  }

  Future<void> loadFeed() async {
    // 1️⃣ Cache mémoire (instantané, < 5 min)
    if (FeedCache.isValid) {
      setState(() => _applyCacheData(FeedCache.data!));
      return;
    }

    // 2️⃣ Cache Hive persistant (stale-while-revalidate)
    final hiveCached = await FeedCacheService.getLastFeed();
    if (hiveCached != null && mounted) {
      // Afficher les données cachées immédiatement
      setState(() => _applyCacheData(hiveCached));
      // Revalider en arrière-plan
      _revalidateFromNetwork();
      return;
    }

    // 3️⃣ Pas de cache → skeleton + fetch réseau
    await _fetchFromNetwork(showLoading: true);
  }

  /// Revalide en arrière-plan (indicateur discret, pas de skeleton)
  Future<void> _revalidateFromNetwork() async {
    if (_revalidating) return;
    setState(() => _revalidating = true);
    try {
      await _fetchFromNetwork(showLoading: false);
    } finally {
      if (mounted) setState(() => _revalidating = false);
    }
  }

  /// Fetch réseau complet + mise à jour du state et des caches
  Future<void> _fetchFromNetwork({required bool showLoading}) async {
    if (showLoading) {
      setState(() {
        loading = true;
        _hasMore = true;
      });
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (showLoading) setState(() => loading = false);
        return;
      }

      // 4 appels parallèles au lieu de 12 :
      // - get_feed_bundle : combine feed + trending + community + friends + curated + prizes
      // - getUserFlow, getCurrentReadingBook, getPersonalizedSuggestions : logique Dart complexe
      final curatedIds = kCuratedLists.map((l) => l.id).toList();
      final results = await Future.wait([
        flowService.getUserFlow(),                                        // 0
        booksService.getCurrentReadingBook(),                             // 1
        suggestionsService.getPersonalizedSuggestions(limit: 5),          // 2
        supabase.rpc('get_feed_bundle', params: {                         // 3
          'p_feed_limit': _pageSize,
          'p_trending_limit': 5,
          'p_sessions_limit': 10,
          'p_readers_limit': 10,
          'p_badges_limit': 8,
          'p_prizes_limit': 10,
          'p_curated_ids': curatedIds,
        }),
      ]);

      final flow = results[0] as ReadingFlow?;
      final currentBook = results[1] as Map<String, dynamic>?;
      final suggestionsRes = results[2] as List<BookSuggestion>;
      final bundle = Map<String, dynamic>.from(results[3] as Map);

      final fCount = bundle['friend_count'] as int? ?? 0;
      final tier = trendingService.determineFeedTier(fCount);

      // Extraire les données du bundle
      final readerCountsRaw = bundle['curated_reader_counts'] as Map<String, dynamic>? ?? {};
      final readerCountsRes = readerCountsRaw.map(
        (k, v) => MapEntry(int.parse(k), v as int),
      );
      final savedListIdsRes = (bundle['saved_curated_ids'] as List<dynamic>? ?? [])
          .map((e) => e as int)
          .toSet();
      final prizeListsRes = (bundle['prize_lists'] as List<dynamic>? ?? [])
          .map((e) => PrizeList.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      // Utiliser les données selon le tier
      List<Map<String, dynamic>> activities = [];
      List<Map<String, dynamic>> trending = [];
      List<Map<String, dynamic>> community = [];
      List<Map<String, dynamic>> readers = [];
      List<Map<String, dynamic>> unlocks = [];

      if (tier == FeedTier.friendsOnly || tier == FeedTier.mixed) {
        activities = List<Map<String, dynamic>>.from(
          (bundle['feed'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }

      if (tier == FeedTier.mixed || tier == FeedTier.trending) {
        trending = List<Map<String, dynamic>>.from(
          (bundle['trending_books'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        community = List<Map<String, dynamic>>.from(
          (bundle['community_sessions'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        readers = List<Map<String, dynamic>>.from(
          (bundle['active_readers'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        unlocks = List<Map<String, dynamic>>.from(
          (bundle['badge_unlocks'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }

      if (!mounted) return;

      // Mélanger l'ordre des sections du feed
      final random = Random();
      final newOrder = [0, 1, 2, 3, 4]..shuffle(random);
      debugPrint('Feed tier: $tier, section order: $newOrder');

      final hasMore = activities.length >= _pageSize;

      final cacheData = FeedCacheData(
        friendActivities: activities,
        currentFlow: flow,
        currentReadingBook: currentBook,
        suggestions: suggestionsRes,
        friendCount: fCount,
        feedTier: tier,
        trendingBooks: trending,
        communitySessions: community,
        activeReaders: readers,
        badgeUnlocks: unlocks,
        curatedReaderCounts: readerCountsRes,
        savedCuratedListIds: savedListIdsRes,
        prizeLists: prizeListsRes,
        hasMore: hasMore,
      );

      // Stocker dans les deux caches (mémoire + Hive)
      FeedCache.store(cacheData);
      FeedCacheService.saveFeed(cacheData); // fire-and-forget

      setState(() => _applyCacheData(cacheData, sectionOrder: newOrder));
    } catch (e) {
      debugPrint('Erreur loadFeed: $e');
      if (!mounted) return;
      if (showLoading) setState(() => loading = false);

      if (mounted && showLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorGeneric(e.toString()))),
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
    final text = AppLocalizations.of(context).shareInviteText;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    Share.share(text, sharePositionOrigin: origin);
  }

  Widget _buildSuggestionsSection() {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.xl),
        Text(
          AppLocalizations.of(context).suggestionsForYou,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpace.s),
        SuggestionsCarousel(
          suggestions: suggestions,
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
            AppLocalizations.of(context).recentSessions,
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

  /// Construit la section des prix littéraires
  List<Widget> _buildPrizeListsSection() {
    if (prizeLists.isEmpty) return [];
    return [
      PrizeListsCarousel(
        lists: prizeLists,
        onListTap: _navigateToPrizeListDetail,
      ),
      const SizedBox(height: AppSpace.l),
    ];
  }

  void _navigateToPrizeListDetail(PrizeList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrizeListDetailPage(prizeList: list),
      ),
    );
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
            AppLocalizations.of(context).recentBadges,
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
            AppLocalizations.of(context).recentBadges,
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
      ..._buildPrizeListsSection(),
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
            AppLocalizations.of(context).recentSessions,
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
            AppLocalizations.of(context).friendsActivity,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (friendActivities.isNotEmpty)
            TextButton(
              onPressed: loadFeed,
              child: Text(AppLocalizations.of(context).refresh),
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
                  AppLocalizations.of(context).friendsNotReadToday,
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
        ..._buildPrizeListsSection(),
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
            AppLocalizations.of(context).friendsActivity,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (friendActivities.isNotEmpty)
            TextButton(
              onPressed: loadFeed,
              child: Text(AppLocalizations.of(context).refresh),
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
                  AppLocalizations.of(context).noActivityYet,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).addFriendsToSeeActivity,
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
        ..._buildPrizeListsSection(),
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
            if (_revalidating)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshFeed,
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
              if (!loading && currentFlow != null)
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
                const FeedSkeletonList()
              else
                ..._buildFeedContent(),

              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
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
