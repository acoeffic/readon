// lib/services/trending_books_service.dart
//
// Livres "tendances" pour la recherche manuelle :
//   - livres les plus ajoutés par la communauté LexDay sur 30 jours,
//   - complétés par une liste curée de best-sellers (table `trending_curated`,
//     gérée côté serveur), via la RPC `get_trending_books_for_search`.
//
// La RPC exclut déjà les livres présents dans la bibliothèque de l'utilisateur
// et déduplique communauté / best-sellers.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'google_books_service.dart';

/// Un livre tendance renvoyé par `get_trending_books_for_search`.
class TrendingBook {
  final int? bookId;
  final String? googleId;
  final String title;
  final String author;
  final String? coverUrl;
  final String? isbn;
  final int? pageCount;
  final String? publishedDate;
  final String? description;
  final int readersCount;

  /// `community` (ajouts récents des lecteurs) ou `bestseller` (liste curée).
  final String source;

  const TrendingBook({
    required this.bookId,
    required this.googleId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.isbn,
    required this.pageCount,
    required this.publishedDate,
    required this.description,
    required this.readersCount,
    required this.source,
  });

  bool get isCommunity => source == 'community';

  factory TrendingBook.fromJson(Map<String, dynamic> json) {
    return TrendingBook(
      bookId: (json['book_id'] as num?)?.toInt(),
      googleId: json['google_id'] as String?,
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      isbn: json['isbn'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt(),
      publishedDate: json['published_date'] as String?,
      description: json['description'] as String?,
      readersCount: (json['readers_count'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? 'bestseller',
    );
  }

  /// Convertit en [GoogleBook] pour le flux d'ajout existant.
  /// Ne pas appeler si [googleId] est null (voir [TrendingBooksService.resolve]).
  GoogleBook toGoogleBook() {
    return GoogleBook(
      id: googleId!,
      title: title,
      authors: author.isEmpty ? const ['Auteur inconnu'] : [author],
      publishedDate: publishedDate,
      description: description,
      pageCount: (pageCount != null && pageCount! > 0) ? pageCount : null,
      coverUrl: coverUrl,
      isbns: isbn != null && isbn!.isNotEmpty ? [isbn!] : const [],
    );
  }
}

class TrendingBooksService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleBooksService _googleBooks = GoogleBooksService();

  /// Cache mémoire simple (la liste bouge peu pendant une session).
  static List<TrendingBook>? _cache;
  static DateTime? _cacheAt;
  static const _cacheTtl = Duration(minutes: 30);

  /// Livres tendances (communauté + best-sellers), best-effort.
  Future<List<TrendingBook>> getTrendingBooks({int limit = 12}) async {
    final cached = _cache;
    if (cached != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return cached;
    }
    try {
      final response = await _supabase.rpc(
        'get_trending_books_for_search',
        params: {'p_limit': limit},
      );
      if (response == null) return const [];
      final list = (response as List)
          .map((row) => TrendingBook.fromJson(row as Map<String, dynamic>))
          .where((b) => b.title.isNotEmpty)
          .toList();
      _cache = list;
      _cacheAt = DateTime.now();
      return list;
    } catch (e) {
      debugPrint('Erreur getTrendingBooks: $e');
      return const [];
    }
  }

  /// Résout un [TrendingBook] en [GoogleBook] complet.
  /// - avec google_id : conversion directe (aucun appel réseau) ;
  /// - sinon : recherche Google Books par ISBN puis titre+auteur.
  /// Retourne null si rien de fiable n'est trouvé.
  Future<GoogleBook?> resolve(TrendingBook book) async {
    if (book.googleId != null && book.googleId!.isNotEmpty) {
      return book.toGoogleBook();
    }
    try {
      if (book.isbn != null && book.isbn!.isNotEmpty) {
        final byIsbn = await _googleBooks.searchByISBN(book.isbn!);
        if (byIsbn != null) return byIsbn;
      }
      final results =
          await _googleBooks.searchByTitleAuthor(book.title, book.author);
      if (results.isNotEmpty) return results.first;
    } catch (e) {
      debugPrint('Erreur resolve trending: $e');
    }
    return null;
  }

  /// Nombre de lecteurs LexDay par livre, pour booster le tri des résultats
  /// de recherche. Clés = google_id et isbn. Best-effort (map vide si erreur).
  Future<Map<String, int>> getPopularity(List<GoogleBook> books) async {
    if (books.isEmpty) return const {};
    final googleIds = books.map((b) => b.id).where((s) => s.isNotEmpty).toList();
    final isbns = books
        .map((b) => b.isbn13)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    if (googleIds.isEmpty && isbns.isEmpty) return const {};
    try {
      final response = await _supabase.rpc(
        'get_books_popularity',
        params: {'p_google_ids': googleIds, 'p_isbns': isbns},
      ).timeout(const Duration(milliseconds: 1500));
      if (response == null) return const {};
      final map = <String, int>{};
      for (final row in response as List) {
        final r = row as Map<String, dynamic>;
        final count = (r['readers_count'] as num?)?.toInt() ?? 0;
        final gid = r['google_id'] as String?;
        final isbn = r['isbn'] as String?;
        if (gid != null && gid.isNotEmpty) map[gid] = count;
        if (isbn != null && isbn.isNotEmpty) map[isbn] = count;
      }
      return map;
    } catch (e) {
      debugPrint('Erreur getPopularity: $e');
      return const {};
    }
  }

  /// Tri stable : les livres déjà lus par la communauté remontent en premier
  /// (par nombre de lecteurs), l'ordre de pertinence Google est conservé
  /// pour le reste.
  static List<GoogleBook> boostByPopularity(
    List<GoogleBook> results,
    Map<String, int> popularity,
  ) {
    if (popularity.isEmpty) return results;
    int scoreOf(GoogleBook b) {
      final byGid = popularity[b.id];
      if (byGid != null) return byGid;
      final isbn = b.isbn13;
      if (isbn != null) return popularity[isbn] ?? 0;
      return 0;
    }

    final indexed = results.asMap().entries.toList();
    indexed.sort((a, b) {
      final diff = scoreOf(b.value).compareTo(scoreOf(a.value));
      if (diff != 0) return diff;
      return a.key.compareTo(b.key); // stable : ordre Google conservé
    });
    return indexed.map((e) => e.value).toList();
  }
}
