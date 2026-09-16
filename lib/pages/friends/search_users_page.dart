import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book.dart';
import '../../services/books_service.dart';
import '../../services/google_books_service.dart';
import '../../services/trending_books_service.dart';
import '../../services/mutual_friends_service.dart';
import '../../services/people_you_may_know_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/author_result_card.dart';
import '../../widgets/back_header.dart';
import '../../widgets/google_book_preview_sheet.dart';
import '../../widgets/google_book_result_card.dart';
import '../../widgets/require_account_sheet.dart';
import '../../widgets/mutual_friends_badge.dart';
import '../../widgets/user_search_card.dart';
import '../../models/reading_group.dart';
import '../../models/user_search_result.dart';
import '../books/author_books_page.dart';
import '../groups/group_detail_page.dart';
import 'friend_profile_page.dart';
import 'people_you_may_know_page.dart';
import '../../widgets/constrained_content.dart';
import '../../services/referral_service.dart';

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final _controller = TextEditingController();
  final _booksService = BooksService();
  final _mutualFriendsService = MutualFriendsService();
  final _peopleService = PeopleYouMayKnowService();
  final _googleBooksService = GoogleBooksService();
  final _trendingService = TrendingBooksService();
  List<UserSearchResult> _userResults = [];
  List<ReadingGroup> _groupResults = [];
  Map<String, bool> _pendingRequests = {}; // user_id -> isPending
  Map<String, MutualFriendsSummary> _mutuals = {};
  // Suggestions affichées quand le champ de recherche est vide.
  List<UserSearchResult> _suggestions = [];
  bool _loadingSuggestions = true;
  bool _loading = false;
  int _selectedTab = 0; // 0 = Amis, 1 = Groupes, 2 = Livres
  Book? _currentReadingBook;

  // ── Onglet Livres (Google Books, même moteur que la recherche manuelle)
  Timer? _bookDebounce;
  int _bookSearchSeq = 0;
  List<GoogleBook> _bookResults = [];
  String? _detectedAuthor;
  String _lastBookQuery = '';
  // google_id des livres déjà dans la bibliothèque → coche + bouton grisé.
  final Set<String> _libraryGoogleIds = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentBook();
    _loadSuggestions();
    _loadLibraryGoogleIds();
  }

  Future<void> _loadLibraryGoogleIds() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('user_books')
          .select('books(google_id)')
          .eq('user_id', userId);
      if (!mounted) return;
      final ids = <String>{};
      for (final row in (data as List)) {
        final gid = (row['books'] as Map?)?['google_id'] as String?;
        if (gid != null && gid.isNotEmpty) ids.add(gid);
      }
      setState(() => _libraryGoogleIds.addAll(ids));
    } catch (e) {
      debugPrint('Erreur _loadLibraryGoogleIds: $e');
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final pymk = await _peopleService.getSuggestions(limit: 15);
      if (!mounted) return;

      // Conversion vers UserSearchResult pour réutiliser _buildSimpleUserItem.
      // Les profils renvoyés par la RPC sont publics (la fonction filtre).
      final converted = pymk
          .map((p) => UserSearchResult(
                id: p.userId,
                displayName: p.displayName,
                avatarUrl: p.avatarUrl,
                isProfilePrivate: false,
                booksFinished: p.booksFinished,
                currentFlow: p.currentFlow,
              ))
          .toList();

      // Les amis communs sont déjà inclus dans le payload PYMK : on évite
      // un round-trip à MutualFriendsService.
      final mutualsFromPymk = {
        for (final p in pymk) p.userId: p.mutualSummary,
      };

      setState(() {
        _suggestions = converted;
        _mutuals = {..._mutuals, ...mutualsFromPymk};
        _loadingSuggestions = false;
      });

      // En revanche on a besoin de connaître l'état "demande déjà envoyée"
      // pour griser le bouton « Ajouter » à l'ouverture du modal.
      await _checkPendingRequests(converted.map((u) => u.id).toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _loadCurrentBook() async {
    final data = await _booksService.getCurrentReadingBook();
    if (!mounted || data == null) return;
    setState(() => _currentReadingBook = data['book'] as Book?);
  }

  void _shareApp() {
    final l = AppLocalizations.of(context);
    final bookTitle = _currentReadingBook?.title;
    final text = bookTitle != null
        ? '\u{1F4D6} Je suis en train de lire $bookTitle\n\n'
            'Tu lis quoi en ce moment ? \u{1F440}\n'
            '$ReferralService.shareUrl'
        : l.shareInviteText;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    Share.share(text, sharePositionOrigin: origin);
  }

  Future<void> _search(String term) async {
    if (_selectedTab == 2) {
      _onBookQueryChanged(term);
      return;
    }
    final query = term.trim();
    if (query.length < 2) {
      setState(() {
        _userResults = [];
        _groupResults = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    final supabase = Supabase.instance.client;
    final pattern = '%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';

    try {
      if (_selectedTab == 0) {
        // Recherche par nom uniquement (jamais par email → anti-énumération).
        // RPC `search_users_by_name` applique unaccent() côté DB pour matcher
        // "voge" → "Vögel" / "Vogel" / "Vogél" sans exiger les accents exacts.
        final basicData = await supabase.rpc(
          'search_users_by_name',
          params: {'p_term': query, 'p_limit': 20},
        );

        if (!mounted) return;

        // Récupérer les données enrichies pour chaque utilisateur
        final enrichedUsers = <UserSearchResult>[];
        for (final user in (basicData as List)) {
          try {
            final userId = user['id'] as String;
            final displayName = user['display_name'] as String? ?? 'Utilisateur';

            debugPrint('🔍 Récupération données pour: $displayName ($userId)');

            final enrichedData = await supabase.rpc(
              'get_user_search_data',
              params: {'p_user_id': userId},
            );

            debugPrint('📦 Données reçues pour $displayName: $enrichedData');

            if (enrichedData != null) {
              final userResult = UserSearchResult.fromJson(
                Map<String, dynamic>.from(enrichedData as Map),
              );
              debugPrint('✅ $displayName - isPrivate: ${userResult.isProfilePrivate}');
              enrichedUsers.add(userResult);
            } else {
              debugPrint('⚠️ enrichedData est NULL pour $displayName');
            }
          } catch (e, stackTrace) {
            debugPrint('❌ Erreur enrichissement utilisateur: $e');
            debugPrint('📍 Stack trace: $stackTrace');
            // En cas d'erreur, ajouter avec les données de base uniquement
            enrichedUsers.add(UserSearchResult(
              id: user['id'] as String,
              displayName: user['display_name'] as String? ?? 'Utilisateur',
              isProfilePrivate: true, // Par défaut, traiter comme privé en cas d'erreur
            ));
          }
        }

        // Vérifier les demandes d'amitié existantes
        await _checkPendingRequests(enrichedUsers.map((u) => u.id).toList());

        // Charger les amis communs en batch
        final mutuals = await _mutualFriendsService.getSummariesBatch(
          enrichedUsers.map((u) => u.id).toList(),
        );

        if (!mounted) return;
        setState(() {
          _userResults = enrichedUsers;
          _mutuals = mutuals;
          _loading = false;
        });
      } else {
        final data = await supabase
            .from('reading_groups')
            .select('*, group_members(count)')
            .or('name.ilike.$pattern,description.ilike.$pattern')
            .eq('is_private', false)
            .limit(20);

        if (!mounted) return;
        setState(() {
          _groupResults = (data as List).map((json) {
            final memberCount = json['group_members'] != null
                ? (json['group_members'] as List).length
                : 0;
            return ReadingGroup.fromJson({
              ...Map<String, dynamic>.from(json as Map),
              'member_count': memberCount,
            });
          }).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorDuringSearch)),
      );
    }
  }

  // ── Livres ─────────────────────────────────────────────────────────

  void _onBookQueryChanged(String value) {
    _bookDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _bookSearchSeq++;
      setState(() {
        _bookResults = [];
        _detectedAuthor = null;
        _lastBookQuery = '';
        _loading = false;
      });
      return;
    }
    if (trimmed.length < 3) {
      setState(() => _loading = false);
      return;
    }
    _bookDebounce = Timer(const Duration(milliseconds: 350), () {
      _runBookSearch(trimmed);
    });
  }

  bool _looksLikeIsbn(String query) {
    final clean = query.replaceAll(RegExp(r'[\s\-]'), '');
    if (clean.length == 13 &&
        (clean.startsWith('978') || clean.startsWith('979'))) {
      return true;
    }
    return clean.length == 10 && RegExp(r'^\d{9}[\dXx]$').hasMatch(clean);
  }

  Future<void> _runBookSearch(String query) async {
    final seq = ++_bookSearchSeq;
    setState(() {
      _loading = true;
      _lastBookQuery = query;
    });
    try {
      List<GoogleBook> results;
      if (_looksLikeIsbn(query)) {
        final clean = query.replaceAll(RegExp(r'[\s\-]'), '');
        final book = await _googleBooksService.searchByISBN(clean);
        results =
            book != null ? [book] : await _googleBooksService.searchBooks(clean);
      } else {
        results = await _googleBooksService.searchBooksRanked(query);
        if (results.length > 1) {
          final popularity = await _trendingService.getPopularity(results);
          if (seq == _bookSearchSeq) {
            results =
                TrendingBooksService.boostByPopularity(results, popularity);
          }
        }
      }
      if (!mounted || seq != _bookSearchSeq) return;
      setState(() {
        _bookResults = results;
        _detectedAuthor = _looksLikeIsbn(query)
            ? null
            : GoogleBooksService.detectAuthorQuery(query, results);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _bookSearchSeq) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorGoogleBooks)),
      );
    }
  }

  /// Ajout direct à la bibliothèque (statut « à lire »), comme la fiche
  /// de recherche manuelle.
  Future<void> _addBookToLibrary(GoogleBook googleBook) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await showRequireAccountSheet(context, source: 'search_books');
      return;
    }
    if (_libraryGoogleIds.contains(googleBook.id)) return;
    setState(() => _libraryGoogleIds.add(googleBook.id));
    try {
      await _booksService.addBookFromGoogleBooks(googleBook);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context).bookAddedToLibrary(googleBook.title)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Erreur _addBookToLibrary: $e');
      if (!mounted) return;
      setState(() => _libraryGoogleIds.remove(googleBook.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).errorGeneric(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openBookSheet(GoogleBook googleBook) {
    showGoogleBookPreviewSheet(
      context,
      googleBook: googleBook,
      isAdded: _libraryGoogleIds.contains(googleBook.id),
      onAdd: () => _addBookToLibrary(googleBook),
      addButtonLabel: AppLocalizations.of(context).addToMyLibrary,
    );
  }

  Future<void> _openAuthorBooks(String author) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthorBooksPage(
          author: author,
          existingGoogleIds: _libraryGoogleIds,
        ),
      ),
    );
    // Un livre a pu être ajouté depuis la page auteur.
    _loadLibraryGoogleIds();
  }

  Future<void> _checkPendingRequests(List<String> userIds) async {
    if (userIds.isEmpty) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final client = Supabase.instance.client;

      // Construire la requête OR pour tous les utilisateurs
      final orConditions = userIds.map((userId) =>
        'and(requester_id.eq.${currentUser.id},addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.${currentUser.id})'
      ).join(',');

      final existing = await client
          .from('friends')
          .select('addressee_id, requester_id, status')
          .or(orConditions);

      final pendingMap = <String, bool>{};
      for (final friendship in (existing as List)) {
        final addresseeId = friendship['addressee_id'] as String;
        final requesterId = friendship['requester_id'] as String;
        final status = friendship['status'] as String?;

        final friendId = addresseeId == currentUser.id ? requesterId : addresseeId;
        pendingMap[friendId] = status == 'pending' || status == 'accepted';
      }

      setState(() => _pendingRequests = pendingMap);
    } catch (e) {
      debugPrint('Erreur _checkPendingRequests: $e');
    }
  }

  Future<void> _addFriend(UserSearchResult user) async {
    final l = AppLocalizations.of(context);
    final currentUser = Supabase.instance.client.auth.currentUser;
    final targetId = user.id;

    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.connectToAddFriend)),
      );
      return;
    }
    if (targetId == currentUser.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.invalidUser)),
      );
      return;
    }

    try {
      final client = Supabase.instance.client;

      final existing = await client
          .from('friends')
          .select('id, status')
          .or(
            'and(requester_id.eq.${currentUser.id},addressee_id.eq.$targetId),and(requester_id.eq.$targetId,addressee_id.eq.${currentUser.id})',
          )
          .limit(1);

      if ((existing as List).isNotEmpty) {
        final status = (existing.first as Map)['status'] as String? ?? 'en attente';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.relationAlreadyExists(status))),
        );
        return;
      }

      await client.from('friends').insert({
        'requester_id': currentUser.id,
        'addressee_id': targetId,
        'status': 'pending',
      });

      setState(() => _pendingRequests[targetId] = true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.invitationSentShort)),
      );
    } catch (e) {
      debugPrint('Erreur _addFriend: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.cannotAddFriend)),
      );
    }
  }

  Future<void> _cancelFriendRequest(UserSearchResult user) async {
    final l = AppLocalizations.of(context);
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      await Supabase.instance.client
          .from('friends')
          .delete()
          .eq('requester_id', currentUser.id)
          .eq('addressee_id', user.id)
          .eq('status', 'pending');

      setState(() => _pendingRequests.remove(user.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.requestCancelled)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.cannotCancelRequest)),
      );
    }
  }

  void _switchTab(int index) {
    if (index == _selectedTab) return;
    _bookDebounce?.cancel();
    _bookSearchSeq++;
    setState(() {
      _selectedTab = index;
      _userResults = [];
      _groupResults = [];
      _bookResults = [];
      _detectedAuthor = null;
      _lastBookQuery = '';
      _loading = false;
    });
    final text = _controller.text.trim();
    if (index == 2) {
      if (text.length >= 3) _runBookSearch(text);
    } else if (text.length >= 2) {
      _search(_controller.text);
    }
  }

  @override
  void dispose() {
    _bookDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ConstrainedContent(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackHeader(
                title: l.searchLabel,
                titleColor: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: AppSpace.m),

              // Tab toggle
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTab(0, l.friends),
                    _buildTab(1, l.groups),
                    _buildTab(2, l.books),
                  ],
                ),
              ),

              const SizedBox(height: AppSpace.m),

              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _controller,
                decoration: InputDecoration(
                  hintText: switch (_selectedTab) {
                    0 => l.searchByName,
                    1 => l.groupName,
                    _ => l.searchBookHint,
                  },
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _search,
              ),

              const SizedBox(height: AppSpace.m),
              if (_loading) const LinearProgressIndicator(),

              Expanded(
                child: switch (_selectedTab) {
                  0 => _buildUserResults(l),
                  1 => _buildGroupResults(l),
                  _ => _buildBookResults(l),
                },
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookResults(AppLocalizations l) {
    if (_bookResults.isEmpty && !_loading) {
      return Center(
        child: Text(
          _lastBookQuery.isNotEmpty ? l.noResult : l.searchBookHint,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final hasAuthorCard = _detectedAuthor != null;
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _bookResults.length + (hasAuthorCard ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasAuthorCard && index == 0) {
          return AuthorResultCard(
            authorName: _detectedAuthor!,
            padding: const EdgeInsets.only(bottom: AppSpace.s),
            onTap: () => _openAuthorBooks(_detectedAuthor!),
          );
        }
        final googleBook = _bookResults[hasAuthorCard ? index - 1 : index];
        return GoogleBookResultCard(
          googleBook: googleBook,
          isAdded: _libraryGoogleIds.contains(googleBook.id),
          onAdd: () => _addBookToLibrary(googleBook),
          onTap: () => _openBookSheet(googleBook),
        );
      },
    );
  }

  Widget _buildUserResults(AppLocalizations l) {
    final hasQuery = _controller.text.trim().length >= 2;

    // Pas de recherche en cours → CTA en tête, puis suggestions multi-signal
    // (ou un état vide) — le tout dans un seul fil scrollable.
    if (!hasQuery && _userResults.isEmpty && !_loading) {
      if (_loadingSuggestions) {
        return _buildScrollWithCtas(
          l,
          ctasFirst: true,
          children: const [
            SizedBox(height: AppSpace.xl),
            Center(child: CircularProgressIndicator()),
          ],
        );
      }
      if (_suggestions.isNotEmpty) {
        return _buildSuggestionsList(l);
      }
      return _buildScrollWithCtas(
        l,
        ctasFirst: true,
        children: [_buildEmptyText(l.typeMin2Chars)],
      );
    }

    // Cas standard : champ rempli, résultats en premier, CTA en fin de fil.
    if (_userResults.isEmpty && !_loading) {
      return _buildScrollWithCtas(
        l,
        ctasFirst: false,
        children: [_buildEmptyText(hasQuery ? l.noResult : l.typeMin2Chars)],
      );
    }

    return _buildScrollWithCtas(
      l,
      ctasFirst: false,
      children: [
        for (var i = 0; i < _userResults.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.xs),
          _buildSimpleUserItem(
            _userResults[i],
            _pendingRequests[_userResults[i].id] ?? false,
            l,
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: Center(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  /// Fil unique : les CTA « inviter » / « découvrir » scrollent avec le
  /// contenu, en tête (`ctasFirst`) ou en pied.
  Widget _buildScrollWithCtas(
    AppLocalizations l, {
    required bool ctasFirst,
    required List<Widget> children,
  }) {
    final ctas = _ctaItems(l);
    return ListView(
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: ctasFirst
          ? [...ctas, const SizedBox(height: AppSpace.m), ...children]
          : [...children, const SizedBox(height: AppSpace.l), ...ctas],
    );
  }

  Widget _buildSuggestionsList(AppLocalizations l) {
    return _buildScrollWithCtas(
      l,
      ctasFirst: true,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            bottom: AppSpace.s,
            top: AppSpace.xs,
          ),
          child: Text(
            l.suggestionsForYou,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ),
        for (var i = 0; i < _suggestions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.xs),
          _buildSimpleUserItem(
            _suggestions[i],
            _pendingRequests[_suggestions[i].id] ?? false,
            l,
          ),
        ],
      ],
    );
  }

  /// Carte « Invite tes amis à lire » (partage de l'app).
  Widget _buildInviteCard(AppLocalizations l) {
    return GestureDetector(
      onTap: _shareApp,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.feedHeader,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.feedHeader.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.share, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.inviteToRead,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.shareWhatYouRead,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  /// Les deux CTA (inviter + découvrir) qui vivent DANS le fil scrollable,
  /// au-dessus des suggestions sans recherche, sous les résultats avec.
  List<Widget> _ctaItems(AppLocalizations l) => [
        _buildInviteCard(l),
        const SizedBox(height: AppSpace.s),
        _buildDiscoverReadersCta(l),
      ];

  Widget _buildDiscoverReadersCta(AppLocalizations l) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PeopleYouMayKnowPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.travel_explore,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.discoverReadersTitle,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.discoverReadersSubtitle,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleUserItem(UserSearchResult user, bool isPending, AppLocalizations l) {
    final mutual = _mutuals[user.id] ?? MutualFriendsSummary.empty;
    return GestureDetector(
      onTap: () => _showUserDetailsModal(user, isPending),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpace.m),

            // Nom + indicateur privé + amis en commun
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user.isProfilePrivate) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.lock, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          l.privateProfileLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Trust signals : livres terminés + streak actuel
                    if ((user.booksFinished ?? 0) > 0 ||
                        (user.currentFlow ?? 0) > 0) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if ((user.booksFinished ?? 0) > 0) ...[
                            const Text('📖',
                                style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 3),
                            Text(
                              '${user.booksFinished} livre${(user.booksFinished ?? 0) > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                          if ((user.booksFinished ?? 0) > 0 &&
                              (user.currentFlow ?? 0) > 0)
                            const SizedBox(width: 8),
                          if ((user.currentFlow ?? 0) > 0) ...[
                            const Text('🔥',
                                style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 3),
                            Text(
                              '${user.currentFlow}j',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                  if (!mutual.isEmpty) ...[
                    const SizedBox(height: 4),
                    MutualFriendsBadge(summary: mutual),
                  ],
                ],
              ),
            ),

            // Flèche pour indiquer qu'on peut cliquer
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showUserDetailsModal(UserSearchResult user, bool isPending) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre de fermeture
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Carte détaillée
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.l),
                child: UserSearchCard(
                  user: user,
                  isRequestPending: isPending,
                  mutualFriends:
                      _mutuals[user.id] ?? MutualFriendsSummary.empty,
                  onAddFriend: () {
                    _addFriend(user);
                    Navigator.pop(context);
                  },
                  onCancelRequest: () {
                    _cancelFriendRequest(user);
                    Navigator.pop(context);
                  },
                  onViewProfile: () {
                    Navigator.pop(context);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(
                        builder: (_) => FriendProfilePage(userId: user.id),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupResults(AppLocalizations l) {
    if (_groupResults.isEmpty && !_loading) {
      return Center(
        child: Text(
          l.typeMin2Chars,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      itemCount: _groupResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s),
      itemBuilder: (context, index) {
        final group = _groupResults[index];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailPage(groupId: group.id),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(AppSpace.m),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: group.coverUrl != null
                      ? NetworkImage(group.coverUrl!)
                      : null,
                  child: group.coverUrl == null
                      ? const Icon(Icons.group, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: AppSpace.m),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (group.description != null) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          group.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        l.memberCount(group.memberCount ?? 0),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}
