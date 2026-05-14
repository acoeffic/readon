// lib/pages/friends/people_you_may_know_page.dart
//
// Page dédiée listant en vertical toutes les suggestions multi-signal
// avec breakdown détaillé par carte. Accessible depuis le feed (lien
// "Voir tout" du carrousel) ou depuis la page Amis.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/contacts_service.dart';
import '../../services/mutual_friends_service.dart';
import '../../services/people_you_may_know_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_profile_avatar.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/mutual_friends_badge.dart';
import '../feed/widgets/discover_readers_section.dart';
import '../feed/widgets/people_you_may_know_section.dart';
import 'friend_profile_page.dart';

class PeopleYouMayKnowPage extends StatefulWidget {
  const PeopleYouMayKnowPage({super.key});

  @override
  State<PeopleYouMayKnowPage> createState() => _PeopleYouMayKnowPageState();
}

class _PeopleYouMayKnowPageState extends State<PeopleYouMayKnowPage> {
  final _service = PeopleYouMayKnowService();
  final _contactsService = ContactsService();
  final _supabase = Supabase.instance.client;

  List<PeopleYouMayKnow> _suggestions = [];
  List<Map<String, dynamic>> _popularReaders = [];
  bool _loading = true;
  final Set<String> _requested = {};
  final Set<String> _processing = {};

  static const int _carouselSize = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<dynamic> _fetchPopularReaders() async {
    return await _supabase
        .rpc('get_suggested_readers', params: {'p_limit': 10});
  }

  /// Dernier filet de sécurité : on interroge `profiles` sans filtre
  /// d'activité. Garantit qu'on a quelque chose à afficher tant qu'il existe
  /// au moins un profil public en base, indépendamment des sessions récentes.
  Future<List<Map<String, dynamic>>> _fetchAnyPublicProfiles({
    int limit = 10,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];
      // is_profile_private peut être NULL → on accepte NULL ou FALSE
      final res = await _supabase
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
      debugPrint('🔎 PYMK page fallback fetched: ${list.length}');
      return list;
    } catch (e) {
      debugPrint('❌ PYMK page fallback error: $e');
      return [];
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getSuggestions(limit: 30),
        _fetchPopularReaders(),
      ]);
      final pymk = results[0] as List<PeopleYouMayKnow>;
      final readersRaw = results[1];
      var readers = readersRaw is List
          ? readersRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];

      // Top-up : on vise au moins ~5 suggestions visibles. Si PYMK + popular
      // en remontent moins, on complète avec des profils publics quelconques
      // (dédupliqués contre les ids déjà connus).
      const minSuggestions = 5;
      final knownIds = <String>{
        ...pymk.map((p) => p.userId),
        ...readers
            .map((r) => r['user_id'] as String? ?? '')
            .where((id) => id.isNotEmpty),
      };
      if (pymk.length + readers.length < minSuggestions) {
        final fallback = await _fetchAnyPublicProfiles(limit: 10);
        final dedup = fallback
            .where((f) => !knownIds.contains(f['user_id'] as String? ?? ''))
            .toList();
        readers = [...readers, ...dedup];
      }

      // De-duplicate popular readers from PYMK to avoid showing the same
      // person twice on the page.
      final pymkIds = pymk.map((p) => p.userId).toSet();
      final filteredReaders = readers
          .where((r) => !pymkIds.contains(r['user_id'] as String? ?? ''))
          .toList();

      if (!mounted) return;
      setState(() {
        _suggestions = pymk;
        _popularReaders = filteredReaders;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _follow(String userId) async {
    if (_requested.contains(userId) || _processing.contains(userId)) return;
    setState(() => _processing.add(userId));
    final ok = await _contactsService.sendFriendRequest(userId);
    if (!mounted) return;
    setState(() {
      _processing.remove(userId);
      if (ok) _requested.add(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPymk = _suggestions.isNotEmpty;
    final hasPopular = _popularReaders.isNotEmpty;
    final pymkCarouselItems = _suggestions.take(_carouselSize).toList();
    final pymkRestItems = _suggestions.skip(_carouselSize).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('À découvrir'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (!hasPymk && !hasPopular)
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          // Carrousel principal
                          if (hasPymk)
                            PeopleYouMayKnowSection(
                              suggestions: pymkCarouselItems,
                              requestedIds: _requested,
                              processingIds: _processing,
                              onFollow: _follow,
                            )
                          else
                            DiscoverReadersSection(
                              readers: _popularReaders,
                              mutuals: const {},
                            ),

                          // Liste détaillée PYMK (avec reasons) au-delà du carrousel
                          ...pymkRestItems.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PymkRow(
                                suggestion: s,
                                isRequested: _requested.contains(s.userId),
                                isProcessing:
                                    _processing.contains(s.userId),
                                onFollow: () => _follow(s.userId),
                              ),
                            ),
                          ),

                          // Section "Lecteurs populaires" en complément quand
                          // PYMK fournit déjà le carrousel principal.
                          if (hasPymk && hasPopular) ...[
                            const SizedBox(height: AppSpace.l),
                            DiscoverReadersSection(
                              readers: _popularReaders,
                              mutuals: const {},
                            ),
                          ],
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucune suggestion pour l\'instant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Lis quelques livres, rejoins un club ou ajoute des amis pour qu\'on puisse te suggérer des lecteurs avec des affinités.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PymkRow extends StatelessWidget {
  final PeopleYouMayKnow suggestion;
  final bool isRequested;
  final bool isProcessing;
  final VoidCallback onFollow;

  const _PymkRow({
    required this.suggestion,
    required this.isRequested,
    required this.isProcessing,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutual = suggestion.mutualSummary;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FriendProfilePage(
            userId: suggestion.userId,
            initialName: suggestion.displayName,
            initialAvatar: suggestion.avatarUrl,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedProfileAvatar(
              imageUrl: suggestion.avatarUrl,
              userName: suggestion.displayName,
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              textColor: AppColors.primary,
              fontSize: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Stats : livres + streak
                  if (suggestion.booksFinished > 0 ||
                      suggestion.currentFlow > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          if (suggestion.booksFinished > 0) ...[
                            const Text('📖',
                                style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 3),
                            Text(
                              '${suggestion.booksFinished} livres',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                          if (suggestion.booksFinished > 0 &&
                              suggestion.currentFlow > 0)
                            const SizedBox(width: 10),
                          if (suggestion.currentFlow > 0) ...[
                            const Text('🔥',
                                style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 3),
                            Text(
                              '${suggestion.currentFlow}j',
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
                    ),
                  // Reasons en chips empilées
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestion.reasons
                        .map((r) => _ReasonChip(reason: r))
                        .toList(),
                  ),
                  if (!mutual.isEmpty) ...[
                    const SizedBox(height: 6),
                    MutualFriendsBadge(
                      summary: mutual,
                      fontSize: 11.5,
                      avatarRadius: 8,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: isRequested ? null : onFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRequested
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                            : AppColors.primary,
                        foregroundColor:
                            isRequested ? Colors.grey.shade700 : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        isRequested ? 'Envoyé' : '+ Suivre',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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

class _ReasonChip extends StatelessWidget {
  final PymkReason reason;

  const _ReasonChip({required this.reason});

  IconData get _icon {
    switch (reason.type) {
      case PymkReasonType.mutualFriends:
        return Icons.people_outline_rounded;
      case PymkReasonType.commonBooks:
        return Icons.menu_book_rounded;
      case PymkReasonType.commonGroups:
        return Icons.groups_rounded;
      case PymkReasonType.commonGenres:
        return Icons.bookmark_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            reason.label(),
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
