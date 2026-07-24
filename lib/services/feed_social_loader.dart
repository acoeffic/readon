// services/feed_social_loader.dart
// Chargement des sections sociales du feed (discover + PYMK + amis communs +
// relations existantes), factorisé pour être partagé entre la page feed et le
// FeedPrefetcher. Aucune dépendance au state d'un widget : la fonction renvoie
// un FeedSocialData self-contained que l'appelant applique comme il veut.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contacts_service.dart';
import 'mutual_friends_service.dart';
import 'people_you_may_know_service.dart';

/// Snapshot des sections sociales du feed.
@immutable
class FeedSocialData {
  final List<Map<String, dynamic>> discoverReaders;
  final List<PeopleYouMayKnow> peopleYouMayKnow;
  final Map<String, MutualFriendsSummary> discoverMutuals;

  /// Ids des suggestions pour lesquelles une relation existe déjà
  /// (demande envoyée / amitié) → la carte affiche l'état "demandé".
  final Set<String> requestedIds;

  const FeedSocialData({
    required this.discoverReaders,
    required this.peopleYouMayKnow,
    required this.discoverMutuals,
    required this.requestedIds,
  });

  static const empty = FeedSocialData(
    discoverReaders: [],
    peopleYouMayKnow: [],
    discoverMutuals: {},
    requestedIds: {},
  );
}

class FeedSocialLoader {
  /// Charge l'ensemble des données sociales du feed.
  ///
  /// [discoverFuture]/[pymkFuture] peuvent être passés déjà lancés (la page
  /// feed les démarre avant le first-paint, en parallèle du bundle) ; sinon
  /// ils sont démarrés ici (cas du prefetcher).
  static Future<FeedSocialData> load({
    Future<dynamic>? discoverFuture,
    Future<List<PeopleYouMayKnow>>? pymkFuture,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return FeedSocialData.empty;

    try {
      discoverFuture ??=
          supabase.rpc('get_suggested_readers', params: {'p_limit': 8});
      pymkFuture ??= PeopleYouMayKnowService().getSuggestions(limit: 10);

      final results = await Future.wait([discoverFuture, pymkFuture]);

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

      // Mutual friends + relations existantes en parallèle.
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
            : MutualFriendsService().getSummariesBatch(discoverIds),
        suggestedIds.isEmpty
            ? Future.value(<String>{})
            : ContactsService().getExistingRelationUserIds(suggestedIds),
      ]);

      return FeedSocialData(
        discoverReaders: discoverReadersList,
        peopleYouMayKnow: pymkList,
        discoverMutuals: social[0] as Map<String, MutualFriendsSummary>,
        requestedIds: social[1] as Set<String>,
      );
    } catch (e) {
      debugPrint('FeedSocialLoader.load error: $e');
      return FeedSocialData.empty;
    }
  }

  /// Fallback : profils publics quelconques pour compléter les suggestions
  /// quand PYMK + popular n'en remontent pas assez.
  static Future<List<Map<String, dynamic>>> _fetchAnyPublicProfilesFallback({
    int limit = 10,
  }) async {
    try {
      final supabase = Supabase.instance.client;
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
                'display_name': e['display_name']?.toString() ?? 'Un lecteur',
                'avatar_url': e['avatar_url']?.toString(),
                'books_finished': 0,
                'current_flow': 0,
              })
          .where((m) => (m['user_id'] as String).isNotEmpty)
          .toList();
      return list;
    } catch (e) {
      debugPrint('FeedSocialLoader fallback profiles error: $e');
      return [];
    }
  }
}
