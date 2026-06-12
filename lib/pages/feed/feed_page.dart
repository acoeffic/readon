// pages/feed/feed_page.dart
// Page principale du flux (Feed) avec activités des amis et contenu communautaire

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/guest_mode_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/require_account_sheet.dart';
import '../feed/widgets/feed_header.dart';
import 'widgets/friend_activity_card.dart';
import 'widgets/book_finished_card.dart';
import '../feed/widgets/flow_card.dart';
import '../../services/contacts_service.dart';
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
import '../../services/goals_service.dart';
import '../../models/reading_goal.dart';
import '../profile/reading_goals_page.dart';
import 'widgets/goals_progress_card.dart';
import '../../widgets/suggestion_card.dart';
import '../../services/trending_service.dart';
import '../../services/groups_service.dart';
import '../../models/reading_group.dart';
import '../groups/group_detail_page.dart';
import '../../widgets/generated_club_cover.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/feed_cache.dart';
import '../../services/feed_cache_service.dart';
import '../../services/mutual_friends_service.dart';
import '../../services/people_you_may_know_service.dart';
import 'widgets/trending_welcome_card.dart';
import 'widgets/trending_books_card.dart';
import 'widgets/community_session_card.dart';
import 'widgets/community_section_separator.dart';
import '../../models/reading_session.dart';
import '../sessions/session_detail_page.dart';
import 'widgets/discover_readers_section.dart';
import 'widgets/find_friends_cta.dart';
import 'widgets/people_you_may_know_section.dart';
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
import '../../services/wrapped_banner_service.dart';
import '../../features/wrapped/monthly/monthly_wrapped_screen.dart';
import 'widgets/wrapped_banner.dart';

class FeedPage extends StatefulWidget {
  /// GlobalKey utilisé par le tutoriel pour highlighter le header du feed.
  final GlobalKey? headerShowcaseKey;
  final GlobalKey? feedContentShowcaseKey;

  const FeedPage({
    super.key,
    this.headerShowcaseKey,
    this.feedContentShowcaseKey,
  });

  /// Notifier incrémenté quand la liste d'amis change (ajout/suppression).
  /// Le feed écoute ce notifier pour se rafraîchir automatiquement.
  static final friendsChanged = ValueNotifier<int>(0);

  /// Appeler après avoir accepté/ajouté un ami pour rafraîchir le feed.
  static void notifyFriendsChanged() => friendsChanged.value++;

  /// Notifier incrémenté quand on demande au feed de scroller en haut.
  /// Déclenché par MainNavigation quand l'utilisateur retape sur l'onglet
  /// feed alors qu'il est déjà sélectionné.
  static final scrollToTopRequested = ValueNotifier<int>(0);

  /// Appeler pour demander au feed de remonter tout en haut.
  static void notifyScrollToTop() => scrollToTopRequested.value++;

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

  // Objectifs de lecture (hors cache feed, hydratés en arrière-plan)
  final goalsService = GoalsService();
  List<ReadingGoal> activeGoals = [];
  bool _goalsLoaded = false;

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

  // "Lecteurs à découvrir" — section permanente de discovery
  List<Map<String, dynamic>> discoverReaders = [];
  Map<String, MutualFriendsSummary> discoverMutuals = {};
  final MutualFriendsService _mutualFriendsService = MutualFriendsService();

  // "Tu pourrais connaître" — multi-signal (Phase 2). Prioritaire sur
  // discoverReaders quand non-vide ; fallback sur discoverReaders sinon.
  List<PeopleYouMayKnow> peopleYouMayKnow = [];
  final PeopleYouMayKnowService _pymkService = PeopleYouMayKnowService();
  // État partagé entre toutes les instances de PeopleYouMayKnowSection
  // injectées dans le feed (pour qu'une demande envoyée dans un carrousel
  // se reflète dans les autres).
  final Set<String> _pymkRequested = {};
  final Set<String> _pymkProcessing = {};
  final ContactsService _pymkContactsService = ContactsService();

  /// Fallback ultime quand aucune source de suggestions sociale ne remonte
  /// quoi que ce soit (PYMK vide + RPC popular vide). On lit directement
  /// `profiles` pour avoir au moins quelques visages à afficher.
  Future<List<Map<String, dynamic>>> _fetchAnyPublicProfilesFallback({
    int limit = 10,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];
      // is_profile_private peut être NULL → on accepte NULL ou FALSE,
      // ce que .eq(false) seul n'inclut pas en PostgreSQL.
      final res = await supabase
          .from('profiles')
          .select('id, display_name, avatar_url')
          .or('is_profile_private.is.null,is_profile_private.eq.false')
          .neq('id', user.id)
          .limit(limit);
      final list = (res as List)
          .map((e) => {
                'user_id': e['id']?.toString() ?? '',
                'display_name':
                    e['display_name']?.toString() ?? 'Un lecteur',
                'avatar_url': e['avatar_url']?.toString(),
                'books_finished': 0,
                'current_flow': 0,
              })
          .where((m) => (m['user_id'] as String).isNotEmpty)
          .toList();
      debugPrint('🔎 fallback profiles fetched: ${list.length}');
      return list;
    } catch (e) {
      debugPrint('❌ fallback profiles error: $e');
      return [];
    }
  }

  Future<void> _followPymkUser(String userId) async {
    if (_pymkRequested.contains(userId) ||
        _pymkProcessing.contains(userId)) {
      return;
    }
    setState(() => _pymkProcessing.add(userId));
    final result =
        await _pymkContactsService.sendFriendRequestDetailed(userId);
    if (!mounted) return;
    setState(() {
      _pymkProcessing.remove(userId);
      if (result != SendFriendRequestResult.error) {
        _pymkRequested.add(userId);
      }
    });
    final l = AppLocalizations.of(context);
    if (result == SendFriendRequestResult.sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.invitationSentShort),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (result == SendFriendRequestResult.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.cannotAddFriend),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Listes curatées
  Map<int, int> curatedReaderCounts = {};
  Set<int> savedCuratedListIds = {};

  // Listes prix littéraires
  List<PrizeList> prizeLists = [];

  // Mode invité — clubs publics à découvrir
  final GroupsService _groupsService = GroupsService();
  List<ReadingGroup> publicClubs = [];
  bool _guestLoading = false;

  // Ordre aléatoire des sections du feed
  // 0 = sessions, 1 = suggestions, 2 = trending books, 3 = lecteurs actifs, 4 = badges
  List<int> _feedSectionOrder = [0, 1, 2, 3, 4];

  // Bannière "Wrapped mensuel à voir" — apparaît 24 h après réception de la
  // notification, cliquable pour ré-ouvrir l'écran Wrapped depuis le feed.
  WrappedBannerData? _wrappedBanner;

  @override
  void initState() {
    super.initState();
    _feedSectionOrder = [0, 1, 2, 3, 4]..shuffle(Random());
    _scrollController.addListener(_onScroll);
    _subscribeToFeed();
    FeedPage.friendsChanged.addListener(_onFriendsChanged);
    FeedPage.scrollToTopRequested.addListener(_onScrollToTopRequested);
    WrappedBannerService.changes.addListener(_loadWrappedBanner);
    _loadWrappedBanner();
    loadFeed();
  }

  /// Recharge l'état de la bannière Wrapped depuis SharedPreferences.
  /// Appelé au montage et quand WrappedBannerService.changes notifie.
  Future<void> _loadWrappedBanner() async {
    // Auto-armement : si on est dans les premiers jours du mois, on arme
    // automatiquement pour le mois précédent (au cas où la notif n'aurait
    // pas été tapée ou aurait été désactivée).
    await WrappedBannerService().maybeAutoArmForPreviousMonth();
    final data = await WrappedBannerService().getPending();
    if (!mounted) return;
    setState(() => _wrappedBanner = data);
  }

  void _openWrappedBanner() {
    final data = _wrappedBanner;
    if (data == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MonthlyWrappedScreen(month: data.month, year: data.year),
      ),
    );
  }

  Future<void> _dismissWrappedBanner() async {
    await WrappedBannerService().dismiss();
    // _loadWrappedBanner sera déclenché par le notifier.
  }

  @override
  void dispose() {
    if (_feedChannel != null) {
      supabase.removeChannel(_feedChannel!);
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    FeedPage.friendsChanged.removeListener(_onFriendsChanged);
    FeedPage.scrollToTopRequested.removeListener(_onScrollToTopRequested);
    WrappedBannerService.changes.removeListener(_loadWrappedBanner);
    super.dispose();
  }

  void _onScrollToTopRequested() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onFriendsChanged() async {
    FeedCache.invalidate();
    await FeedCacheService.clear();
    await loadFeed();
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
    if (!mounted) return;
    // Dédup : si l'activité est déjà dans la liste (race entre fetch initial
    // et event realtime), on ne l'insère pas une deuxième fois.
    final id = _activityKey(record);
    if (id != null && friendActivities.any((a) => _activityKey(a) == id)) {
      return;
    }
    setState(() {
      friendActivities.insert(0, record);
    });
  }

  /// Clé d'unicité d'une activité du feed. On préfère `activity_id` (utilisé
  /// par les reactions/comments), avec fallback sur `id`. Retourne null si
  /// aucune clé identifiable n'est présente.
  static Object? _activityKey(Map<String, dynamic> a) =>
      a['activity_id'] ?? a['id'];

  /// Dédoublonne une liste d'activités en gardant l'ordre d'apparition.
  /// Les éléments sans clé identifiable sont conservés tels quels.
  static List<Map<String, dynamic>> _dedupActivities(
    List<Map<String, dynamic>> list,
  ) {
    final seen = <Object>{};
    final out = <Map<String, dynamic>>[];
    for (final a in list) {
      final k = _activityKey(a);
      if (k == null) {
        out.add(a);
        continue;
      }
      if (seen.add(k)) out.add(a);
    }
    return out;
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

      final moreList = List<Map<String, dynamic>>.from(more ?? []);
      setState(() {
        friendActivities = _dedupActivities([...friendActivities, ...moreList]);
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
    // Mode invité : on bypasse le cache amis/perso (qui peut contenir du
    // contenu d'une session précédente) et on charge directement le feed
    // public.
    if (supabase.auth.currentUser == null) {
      await _fetchFromNetwork(showLoading: true);
      return;
    }

    // Objectifs : hors cache feed, hydratés en arrière-plan quel que soit
    // le chemin (cache mémoire, Hive ou réseau).
    _loadGoals();

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

  /// Charge les objectifs actifs avec leur progression (best-effort).
  Future<void> _loadGoals() async {
    try {
      final goals = await goalsService.getActiveGoalsWithProgress();
      if (!mounted) return;
      setState(() {
        activeGoals = goals;
        _goalsLoaded = true;
      });
    } catch (e) {
      debugPrint('Erreur chargement objectifs: $e');
    }
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

  /// Fetch réseau complet + mise à jour du state et des caches.
  ///
  /// Rendu progressif : on affiche le feed dès que `get_feed_bundle` répond
  /// (c'est lui qui porte les activités), puis on hydrate flow / current book /
  /// suggestions / discover / pymk au fur et à mesure que leurs requêtes
  /// arrivent. Le cache (mémoire + Hive) est écrit une fois que tout est en
  /// place.
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
        // Mode invité : on charge le feed public (curated, trending, clubs).
        await _loadGuestFeed();
        if (showLoading) setState(() => loading = false);
        return;
      }

      // Tous les appels sont lancés en parallèle sans Future.wait global :
      // chaque future hydrate son slice de state quand elle se résout.
      final curatedIds = kCuratedLists.map((l) => l.id).toList();
      final bundleFuture = supabase.rpc('get_feed_bundle', params: {
        'p_feed_limit': _pageSize,
        'p_trending_limit': 5,
        'p_sessions_limit': 10,
        'p_readers_limit': 10,
        'p_badges_limit': 8,
        'p_prizes_limit': 10,
        'p_curated_ids': curatedIds,
      });
      final flowFuture = flowService.getUserFlow();
      final currentBookFuture = booksService.getCurrentReadingBook();
      final suggestionsFuture =
          suggestionsService.getPersonalizedSuggestions(limit: 5);
      final discoverFuture =
          supabase.rpc('get_suggested_readers', params: {'p_limit': 8});
      final pymkFuture = _pymkService.getSuggestions(limit: 10);

      // 🚀 First-paint : on attend uniquement le bundle (contient activités
      // + trending + community + readers + badges + curated + prizes).
      final bundleRaw = await bundleFuture;
      if (!mounted) return;

      final bundle = Map<String, dynamic>.from(bundleRaw as Map);
      final fCount = bundle['friend_count'] as int? ?? 0;
      final tier = trendingService.determineFeedTier(fCount);
      final readerCountsRaw =
          bundle['curated_reader_counts'] as Map<String, dynamic>? ?? {};
      final readerCountsRes = readerCountsRaw
          .map((k, v) => MapEntry(int.parse(k), v as int));
      final savedListIdsRes =
          (bundle['saved_curated_ids'] as List<dynamic>? ?? [])
              .map((e) => e as int)
              .toSet();
      final prizeListsRes = (bundle['prize_lists'] as List<dynamic>? ?? [])
          .map((e) => PrizeList.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      List<Map<String, dynamic>> activities = [];
      List<Map<String, dynamic>> trending = [];
      List<Map<String, dynamic>> community = [];
      List<Map<String, dynamic>> readers = [];
      List<Map<String, dynamic>> unlocks = [];

      if (tier == FeedTier.friendsOnly || tier == FeedTier.mixed) {
        activities = _dedupActivities(
          List<Map<String, dynamic>>.from(
            (bundle['feed'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)),
          ),
        );
      }

      if (tier == FeedTier.mixed || tier == FeedTier.trending) {
        trending = List<Map<String, dynamic>>.from(
          (bundle['trending_books'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        community = List<Map<String, dynamic>>.from(
          (bundle['community_sessions'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        readers = List<Map<String, dynamic>>.from(
          (bundle['active_readers'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        unlocks = List<Map<String, dynamic>>.from(
          (bundle['badge_unlocks'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }

      final newOrder = [0, 1, 2, 3, 4]..shuffle(Random());
      final hasMore = activities.length >= _pageSize;
      debugPrint('Feed tier: $tier, section order: $newOrder');

      // 🎨 Premier paint : on rend ce qu'on a déjà.
      setState(() {
        friendActivities = activities;
        friendCount = fCount;
        feedTier = tier;
        trendingBooks = trending;
        communitySessions = community;
        activeReaders = readers;
        badgeUnlocks = unlocks;
        curatedReaderCounts = readerCountsRes;
        savedCuratedListIds = savedListIdsRes;
        prizeLists = prizeListsRes;
        _hasMore = hasMore;
        _feedSectionOrder = newOrder;
        loading = false;
      });

      // 🔄 Updates progressifs : chaque section apparaît dès que sa donnée
      // arrive, sans bloquer le premier rendu.
      final flowHydrated = flowFuture.then((flow) {
        if (!mounted) return;
        setState(() => currentFlow = flow);
      }).catchError((Object e) {
        debugPrint('Erreur flow background: $e');
      });

      final currentBookHydrated = currentBookFuture.then((book) {
        if (!mounted) return;
        setState(() => currentReadingBook = book);
      }).catchError((Object e) {
        debugPrint('Erreur currentBook background: $e');
      });

      final suggestionsHydrated = suggestionsFuture.then((sugg) {
        if (!mounted) return;
        setState(() => suggestions = sugg);
      }).catchError((Object e) {
        debugPrint('Erreur suggestions background: $e');
      });

      // Discover + PYMK : dépendent l'un de l'autre pour la dédup, puis
      // déclenchent en parallèle mutual-friends + relations existantes.
      final socialHydrated = _loadDiscoverAndPymk(
        discoverFuture: discoverFuture,
        pymkFuture: pymkFuture,
      );

      // 💾 Cache (mémoire + Hive) écrit une fois tout résolu — best-effort.
      Future.wait([
        flowHydrated,
        currentBookHydrated,
        suggestionsHydrated,
        socialHydrated,
      ]).then((_) {
        if (!mounted) return;
        final cacheData = FeedCacheData(
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
        FeedCache.store(cacheData);
        FeedCacheService.saveFeed(cacheData); // fire-and-forget
      }).catchError((Object e) {
        debugPrint('Erreur cache write: $e');
      });
    } catch (e) {
      debugPrint('Erreur loadFeed: $e');
      if (!mounted) return;
      if (showLoading) setState(() => loading = false);

      // Mode invité : on n'affiche pas la SnackBar "User not authenticated"
      // qui est attendue (les RPCs gated échouent silencieusement côté UI).
      final isAuthError = e.toString().contains('not authenticated') ||
          e.toString().contains('Non connecté');
      if (mounted && showLoading && !isAuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorGeneric(e.toString()))),
        );
      }
    }
  }

  /// Hydrate les sections sociales (discover + PYMK + mutuals + relations
  /// existantes). Lancée en background depuis [_fetchFromNetwork] après le
  /// first-paint.
  Future<void> _loadDiscoverAndPymk({
    required Future<dynamic> discoverFuture,
    required Future<List<PeopleYouMayKnow>> pymkFuture,
  }) async {
    try {
      final results = await Future.wait([discoverFuture, pymkFuture]);
      if (!mounted) return;

      final discoverReadersRaw = results[0];
      var discoverReadersList = discoverReadersRaw is List
          ? discoverReadersRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      final pymkList = results[1] as List<PeopleYouMayKnow>;

      // Dédupliquer popular contre PYMK.
      final pymkIds = pymkList.map((p) => p.userId).toSet();
      discoverReadersList = discoverReadersList
          .where((r) => !pymkIds.contains(r['user_id'] as String? ?? ''))
          .toList();

      // Top-up : garantir ~5 suggestions sociales en complétant via profils
      // publics si PYMK + popular n'en remontent pas assez.
      const minSuggestions = 5;
      final knownIds = <String>{
        ...pymkIds,
        ...discoverReadersList
            .map((r) => r['user_id'] as String? ?? '')
            .where((id) => id.isNotEmpty),
      };
      if (pymkList.length + discoverReadersList.length < minSuggestions) {
        final fallback = await _fetchAnyPublicProfilesFallback(limit: 10);
        final dedup = fallback
            .where((f) => !knownIds.contains(f['user_id'] as String? ?? ''))
            .toList();
        discoverReadersList = [...discoverReadersList, ...dedup];
      }

      if (!mounted) return;
      setState(() {
        discoverReaders = discoverReadersList;
        peopleYouMayKnow = pymkList;
      });

      // Mutual friends + relations existantes en parallèle (au lieu de
      // séquentiel comme avant).
      final discoverIds = discoverReadersList
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toList();
      final suggestedIds = <String>{
        ...pymkList.map((p) => p.userId),
        ...discoverReadersList
            .map((r) => r['user_id'] as String? ?? '')
            .where((id) => id.isNotEmpty),
      };

      final social = await Future.wait([
        discoverIds.isEmpty
            ? Future.value(<String, MutualFriendsSummary>{})
            : _mutualFriendsService.getSummariesBatch(discoverIds),
        suggestedIds.isEmpty
            ? Future.value(<String>{})
            : _pymkContactsService.getExistingRelationUserIds(suggestedIds),
      ]);
      if (!mounted) return;
      setState(() {
        discoverMutuals = social[0] as Map<String, MutualFriendsSummary>;
        _pymkRequested.addAll(social[1] as Set<String>);
      });
    } catch (e) {
      debugPrint('Erreur discover/pymk background: $e');
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

      // Section sociale à découvrir (PYMK > popular fallback)
      _buildSocialDiscoverSection(),

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

  /// Section sociale "à découvrir" : préfère PYMK (multi-signal), sinon
  /// fallback sur discover_readers (popularité). Retourne SizedBox.shrink
  /// quand aucune des deux n'est dispo.
  Widget _buildSocialDiscoverSection() {
    final hasPymk = peopleYouMayKnow.isNotEmpty;
    final hasDiscover = discoverReaders.isNotEmpty;
    if (!hasPymk && !hasDiscover) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPymk)
          PeopleYouMayKnowSection(
            suggestions: peopleYouMayKnow,
            requestedIds: _pymkRequested,
            processingIds: _pymkProcessing,
            onFollow: _followPymkUser,
          ),
        if (hasPymk && hasDiscover) const SizedBox(height: AppSpace.l),
        if (hasDiscover)
          DiscoverReadersSection(
            readers: discoverReaders,
            mutuals: discoverMutuals,
            onSeeAll: _navigateToSearchUsers,
          ),
      ],
    );
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

      // Section sociale à découvrir (PYMK > popular fallback)
      _buildSocialDiscoverSection(),

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
        // Activités restantes, avec injection PYMK toutes les 10 cartes
        ..._buildActivitiesWithPymk(
          friendActivities.skip(5).toList(),
          startIndex: 5,
        ),
        // Fallback : si l'utilisateur a < 10 activités totales, aucune
        // injection n'a eu lieu — on affiche PYMK une fois en bas.
        if (friendActivities.length < 10) ...[
          const SizedBox(height: AppSpace.l),
          _buildSocialDiscoverSection(),
        ],
      ],
    ];
  }

  /// Render activity cards with a "people you may know" carousel injected
  /// every 10 activities. [startIndex] is the count of activity cards already
  /// rendered before this list (so injection happens at global positions
  /// 10, 20, 30, …).
  List<Widget> _buildActivitiesWithPymk(
    List<Map<String, dynamic>> activities, {
    required int startIndex,
  }) {
    final hasDiscover =
        peopleYouMayKnow.isNotEmpty || discoverReaders.isNotEmpty;
    final result = <Widget>[];
    for (var i = 0; i < activities.length; i++) {
      result.add(_buildActivityCard(activities[i]));
      final globalCount = startIndex + i + 1;
      if (hasDiscover && globalCount % 10 == 0) {
        result.add(const SizedBox(height: AppSpace.l));
        result.add(_buildSocialDiscoverSection());
        result.add(const SizedBox(height: AppSpace.l));
      }
    }
    return result;
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['type'] as String?;
    final payload = activity['payload'] as Map<String, dynamic>?;
    final isBookFinished =
        type == 'book_finished' || payload?['book_finished'] == true;
    if (isBookFinished) return BookFinishedCard(activity: activity);
    return FriendActivityCard(activity: activity);
  }

  // ── Mode invité ──────────────────────────────────────────────────────
  // En mode invité on remplace tout le feed par 3 sections publiques :
  // listes curatées, livres tendances, clubs publics.

  Future<void> _loadGuestFeed() async {
    if (_guestLoading) return;
    _guestLoading = true;
    try {
      final results = await Future.wait([
        trendingService.getTrendingBooks(limit: 10),
        prizeListService.fetchPrizeLists(),
        _groupsService.getPublicGroups(limit: 6),
      ]);
      if (!mounted) return;
      setState(() {
        trendingBooks = results[0] as List<Map<String, dynamic>>;
        prizeLists = results[1] as List<PrizeList>;
        publicClubs = (results[2] as List<ReadingGroup>).take(4).toList();
      });
    } catch (e) {
      debugPrint('Erreur _loadGuestFeed: $e');
    } finally {
      _guestLoading = false;
    }
  }

  List<Widget> _buildGuestFeedContent() {
    final l = AppLocalizations.of(context);
    return [
      // Listes pour toi
      _SectionHeader(emoji: '✨', label: l.feedSectionListsForYou),
      const SizedBox(height: AppSpace.s),
      ..._buildCuratedListsSection(),

      ..._buildPrizeListsSection(),

      // Tendances
      if (trendingBooks.isNotEmpty) ...[
        _SectionHeader(emoji: '🔥', label: l.feedSectionTrending),
        const SizedBox(height: AppSpace.s),
        ..._buildTrendingBooksSection(),
      ],

      // Clubs publics à découvrir
      ..._buildPublicClubsSection(),

      // CTA conversion
      _GuestConversionCta(onTap: () => showRequireAccountSheet(context)),
      const SizedBox(height: AppSpace.l),
    ];
  }

  List<Widget> _buildPublicClubsSection() {
    if (publicClubs.isEmpty) return [];
    final l = AppLocalizations.of(context);
    return [
      _SectionHeader(emoji: '👥', label: l.feedSectionPublicClubs),
      const SizedBox(height: AppSpace.s),
      SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: publicClubs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _PublicClubCard(group: publicClubs[i]),
        ),
      ),
      const SizedBox(height: AppSpace.l),
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
    final isGuest = context.watch<GuestModeProvider>().isGuest;
    final l10n = AppLocalizations.of(context);
    Widget header = const FeedHeader();
    if (widget.headerShowcaseKey != null) {
      header = Showcase(
        key: widget.headerShowcaseKey!,
        title: l10n.tutorialDashboardTitle,
        description: l10n.tutorialDashboardDescription,
        targetBorderRadius: BorderRadius.circular(12),
        targetPadding: const EdgeInsets.all(4),
        tooltipBackgroundColor: AppColors.primary,
        textColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        descTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        child: header,
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            header,
            if (isGuest) const _GuestModeBanner(),
            if (_revalidating)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              ),
            Expanded(
              child: Builder(
                builder: (context) {
                  Widget feedList = RefreshIndicator(
                    onRefresh: _refreshFeed,
                    child: ConstrainedContent.wide(
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpace.l),
                        children: [

              // 👉 Bannière "Wrapped mensuel à voir" (24 h après notif)
              if (_wrappedBanner != null) ...[
                WrappedBanner(
                  month: _wrappedBanner!.month,
                  year: _wrappedBanner!.year,
                  onTap: _openWrappedBanner,
                  onDismiss: _dismissWrappedBanner,
                ),
                const SizedBox(height: AppSpace.l),
              ],

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

              // 👉 Objectifs de lecture
              if (!loading && !isGuest && _goalsLoaded) ...[
                GoalsProgressCard(
                  goals: activeGoals,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReadingGoalsPage(),
                      ),
                    );
                    _loadGoals();
                  },
                ),
              ],

              const SizedBox(height: AppSpace.l),

              // 👉 Contenu du feed (selon le tier)
              if (loading)
                const FeedSkeletonList()
              else if (isGuest)
                ..._buildGuestFeedContent()
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
                  );
                  if (widget.feedContentShowcaseKey != null) {
                    feedList = Showcase(
                      key: widget.feedContentShowcaseKey!,
                      title: l10n.tutorialFeedTitle,
                      description: l10n.tutorialFeedDescription,
                      targetBorderRadius: BorderRadius.circular(12),
                      targetPadding: const EdgeInsets.all(4),
                      tooltipBackgroundColor: AppColors.primary,
                      textColor: Colors.white,
                      titleTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      descTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      child: feedList,
                    );
                  }
                  return feedList;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestModeBanner extends StatelessWidget {
  const _GuestModeBanner();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.appColors;
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => showRequireAccountSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.guestModeBannerTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l.guestModeBannerSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Guest mode helpers ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String label;
  const _SectionHeader({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: AppSpace.s),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PublicClubCard extends StatelessWidget {
  final ReadingGroup group;
  const _PublicClubCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupDetailPage(groupId: group.id),
          ),
        );
      },
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 180,
                height: 110,
                child: group.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: group.coverUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 360,
                        memCacheHeight: 220,
                        errorWidget: (_, __, ___) =>
                            GeneratedClubCover(name: group.name),
                      )
                    : GeneratedClubCover(
                        name: group.name,
                        initialsFontSize: 32,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              group.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${group.memberCount} membres',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestConversionCta extends StatelessWidget {
  final VoidCallback onTap;
  const _GuestConversionCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('📚', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.feedGuestCtaTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.feedGuestCtaSubtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
