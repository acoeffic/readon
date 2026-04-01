// lib/services/suggestions_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import '../models/book_suggestion.dart';
import 'google_books_service.dart';
import 'books_service.dart';

class SuggestionsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleBooksService _googleBooksService = GoogleBooksService();
  final BooksService _booksService = BooksService();

  /// Générer des suggestions personnalisées (approche hybride)
  ///
  /// Combine plusieurs sources :
  /// - Livres populaires chez les amis
  /// - Livres du même auteur
  /// - Suggestions Google Books basées sur l'historique
  Future<List<BookSuggestion>> getPersonalizedSuggestions({
    int limit = 10,
    Book? basedOnBook, // Pour suggestions après avoir fini un livre
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Lancer toutes les sources de suggestions en parallèle
      final List<Future<List<BookSuggestion>>> futures = [
        _getSuggestionsFromFriends(userId, limit: 3),
      ];

      if (basedOnBook != null && basedOnBook.author != null) {
        futures.add(_getSuggestionsFromSameAuthor(
          basedOnBook.author!,
          excludeBookId: basedOnBook.id,
          limit: 2,
        ));
        futures.add(_getGoogleBooksSuggestions(
          basedOnBook: basedOnBook,
          limit: 3,
        ));
      } else {
        futures.add(_getSuggestionsFromHistory(userId, limit: 5));
      }

      futures.add(_getSuggestionsFromGenre(userId, limit: 3));
      futures.add(_getSuggestionsFromAI(limit: 3));

      // Charger les livres utilisateur en parallèle avec les suggestions
      final userBooksFuture = _booksService.getUserBooks();

      final results = await Future.wait(futures);
      List<BookSuggestion> suggestions = results.expand((s) => s).toList();

      // Dédupliquer par book ID
      final seen = <int>{};
      suggestions = suggestions.where((s) {
        if (seen.contains(s.book.id)) return false;
        seen.add(s.book.id);
        return true;
      }).toList();

      // Exclure les livres déjà dans la bibliothèque (déjà chargés en parallèle)
      try {
        final userBooks = await userBooksFuture;
        final userBookIds = userBooks.map((b) => b.id).toSet();
        suggestions = suggestions.where((s) => !userBookIds.contains(s.book.id)).toList();
      } catch (e) {
        debugPrint('Erreur filtrage user books: $e');
      }

      // Limiter au nombre demandé
      if (suggestions.length > limit) {
        suggestions = suggestions.take(limit).toList();
      }

      // Enrichir les couvertures manquantes via Google Books
      suggestions = await _enrichMissingCovers(suggestions);

      return suggestions;
    } catch (e) {
      debugPrint('Erreur getPersonalizedSuggestions: $e');
      return [];
    }
  }

  /// Enrichit les suggestions dont le livre n'a pas de coverUrl
  /// en cherchant sur Google Books par ISBN ou titre+auteur.
  Future<List<BookSuggestion>> _enrichMissingCovers(
    List<BookSuggestion> suggestions,
  ) async {
    final needsEnrichment = <int, BookSuggestion>{};
    for (int i = 0; i < suggestions.length; i++) {
      final book = suggestions[i].book;
      if (book.coverUrl == null || book.coverUrl!.isEmpty) {
        // Vérifier le cache persistant d'abord
        if (book.isbn != null && book.isbn!.isNotEmpty) {
          final cached = _googleBooksService.getCachedCoverUrl(book.isbn!);
          if (cached != null) {
            suggestions[i] = BookSuggestion(
              book: book.copyWith(coverUrl: cached),
              type: suggestions[i].type,
              reason: suggestions[i].reason,
              score: suggestions[i].score,
              metadata: suggestions[i].metadata,
            );
            continue;
          }
        }
        needsEnrichment[i] = suggestions[i];
      }
    }

    if (needsEnrichment.isEmpty) return suggestions;

    // Lancer les lookups en parallèle
    final entries = needsEnrichment.entries.toList();
    final results = await Future.wait(
      entries.map((entry) {
        final book = entry.value.book;
        if (book.isbn != null && book.isbn!.isNotEmpty) {
          return _googleBooksService.searchByISBN(book.isbn!);
        }
        if (book.title.isNotEmpty) {
          return _googleBooksService
              .searchByTitleAuthor(book.title, book.author ?? '')
              .then((list) => list.isNotEmpty ? list.first : null);
        }
        return Future.value(null);
      }),
    );

    for (int i = 0; i < entries.length; i++) {
      final googleBook = results[i];
      if (googleBook?.coverUrl != null) {
        final idx = entries[i].key;
        final s = suggestions[idx];
        suggestions[idx] = BookSuggestion(
          book: s.book.copyWith(coverUrl: googleBook!.coverUrl),
          type: s.type,
          reason: s.reason,
          score: s.score,
          metadata: s.metadata,
        );
      }
    }

    return suggestions;
  }

  /// Suggestions basées sur les livres que les amis lisent
  Future<List<BookSuggestion>> _getSuggestionsFromFriends(
    String userId, {
    int limit = 3,
  }) async {
    try {
      // Récupérer les livres que les amis ont récemment lus/lisent
      final response = await _supabase.rpc('get_friends_popular_books', params: {
        'p_user_id': userId,
        'p_limit': limit,
      });

      if (response == null) return [];

      final books = (response as List).map((item) {
        final book = Book.fromJson(item['book']);
        final friendCount = item['friend_count'] as int;
        final friendNames = (item['friend_names'] as List?)
            ?.map((e) => e.toString())
            .toList() ?? [];

        String reason;
        if (friendCount == 1 && friendNames.isNotEmpty) {
          reason = '${friendNames.first} lit ce livre';
        } else if (friendCount > 1) {
          reason = '$friendCount de tes amis lisent ce livre';
        } else {
          reason = 'Populaire chez tes amis';
        }

        return BookSuggestion(
          book: book,
          type: SuggestionType.friendsReading,
          reason: reason,
          score: friendCount / 10.0, // Score basé sur popularité
          metadata: {
            'friend_count': friendCount,
            'friend_names': friendNames,
          },
        );
      }).toList();

      return books;
    } catch (e) {
      debugPrint('Erreur _getSuggestionsFromFriends: $e');
      return [];
    }
  }

  /// Suggestions du même auteur
  Future<List<BookSuggestion>> _getSuggestionsFromSameAuthor(
    String author, {
    required int excludeBookId,
    int limit = 2,
  }) async {
    try {
      final response = await _supabase
          .from('books')
          .select()
          .ilike('author', '%$author%')
          .neq('id', excludeBookId)
          .limit(limit);

      return (response as List).map((item) {
        final book = Book.fromJson(item);
        return BookSuggestion(
          book: book,
          type: SuggestionType.sameAuthor,
          reason: 'Du même auteur que ton dernier livre',
          score: 0.8,
        );
      }).toList();
    } catch (e) {
      debugPrint('Erreur _getSuggestionsFromSameAuthor: $e');
      return [];
    }
  }

  /// Suggestions via Google Books API basées sur un livre
  Future<List<BookSuggestion>> _getGoogleBooksSuggestions({
    required Book basedOnBook,
    int limit = 3,
  }) async {
    try {
      // Construire une requête de recherche basée sur le livre
      String query = basedOnBook.title;

      // Ajouter l'auteur si disponible
      if (basedOnBook.author != null && basedOnBook.author!.isNotEmpty) {
        query += ' ${basedOnBook.author}';
      }

      final googleBooks = await _googleBooksService.searchBooks(query);

      // Filtrer pour éviter le livre exact
      final filtered = googleBooks.where((gb) {
        return gb.id != basedOnBook.googleId &&
            gb.title.toLowerCase() != basedOnBook.title.toLowerCase();
      }).take(limit).toList();

      return filtered.map((googleBook) {
        return BookSuggestion(
          book: Book.fromGoogleBook(googleBook),
          type: SuggestionType.googleBooks,
          reason: 'Suggéré car tu as aimé "${basedOnBook.title}"',
          score: 0.7,
          metadata: {
            'based_on_book_id': basedOnBook.id,
            'based_on_title': basedOnBook.title,
          },
        );
      }).toList();
    } catch (e) {
      debugPrint('Erreur _getGoogleBooksSuggestions: $e');
      return [];
    }
  }

  /// Suggestions basées sur l'historique de lecture
  Future<List<BookSuggestion>> _getSuggestionsFromHistory(
    String userId, {
    int limit = 5,
  }) async {
    try {
      // Récupérer les derniers livres terminés
      final finishedBooks = await _supabase
          .from('user_books')
          .select('books(*)')
          .eq('user_id', userId)
          .eq('status', 'finished')
          .order('updated_at', ascending: false)
          .limit(3);

      if ((finishedBooks as List).isEmpty) {
        // Si pas d'historique, retourner des suggestions générales
        return _getTrendingSuggestions(limit: limit);
      }

      // Lancer toutes les recherches en parallèle
      final List<Future<List<BookSuggestion>>> futures = [];

      for (final item in (finishedBooks as List).take(2)) {
        final book = Book.fromJson(item['books']);

        if (book.author != null && book.author!.isNotEmpty) {
          futures.add(_getSuggestionsFromSameAuthor(
            book.author!,
            excludeBookId: book.id,
            limit: 1,
          ));
        }

        futures.add(_getGoogleBooksSuggestions(
          basedOnBook: book,
          limit: 2,
        ));
      }

      final results = await Future.wait(futures);
      return results.expand((s) => s).take(limit).toList();
    } catch (e) {
      debugPrint('Erreur _getSuggestionsFromHistory: $e');
      return [];
    }
  }

  /// Suggestions de livres tendances (fallback)
  Future<List<BookSuggestion>> _getTrendingSuggestions({int limit = 5}) async {
    try {
      // Récupérer les livres les plus ajoutés récemment
      final response = await _supabase
          .rpc('get_trending_books', params: {'p_limit': limit});

      if (response == null) return [];

      return (response as List).map((item) {
        final book = Book.fromJson(item['book']);
        final userCount = item['user_count'] as int;

        return BookSuggestion(
          book: book,
          type: SuggestionType.trending,
          reason: '$userCount lecteurs ont ajouté ce livre',
          score: userCount / 100.0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Erreur _getTrendingSuggestions: $e');
      return [];
    }
  }

  /// Suggestions basées sur les genres favoris de l'utilisateur
  Future<List<BookSuggestion>> _getSuggestionsFromGenre(
    String userId, {
    int limit = 3,
  }) async {
    try {
      // Récupérer les livres terminés avec leur genre
      final finishedBooks = await _supabase
          .from('user_books')
          .select('books(genre)')
          .eq('user_id', userId)
          .eq('status', 'finished')
          .order('updated_at', ascending: false)
          .limit(20);

      if ((finishedBooks as List).isEmpty) return [];

      // Compter la fréquence de chaque genre
      final genreCounts = <String, int>{};
      for (final item in finishedBooks) {
        final genre = item['books']?['genre'] as String?;
        if (genre != null && genre.isNotEmpty) {
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
      }

      if (genreCounts.isEmpty) return [];

      // Trier les genres par fréquence (les plus lus d'abord)
      final sortedGenres = genreCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Prendre les 2 genres les plus lus
      final topGenres = sortedGenres.take(2).map((e) => e.key).toList();

      // Lancer les recherches Google Books en parallèle pour chaque genre
      final genreSubjects = <MapEntry<String, String>>[];
      for (final genre in topGenres) {
        final subject = _genreToGoogleSubject(genre);
        if (subject != null) {
          genreSubjects.add(MapEntry(genre, subject));
        }
      }

      final googleResults = await Future.wait(
        genreSubjects.map((e) => _googleBooksService.searchBooks('subject:${e.value}')),
      );

      List<BookSuggestion> suggestions = [];
      for (int i = 0; i < genreSubjects.length; i++) {
        final genre = genreSubjects[i].key;
        final subject = genreSubjects[i].value;
        final genreSuggestions = googleResults[i]
            .take(limit)
            .map((googleBook) => BookSuggestion(
                  book: Book.fromGoogleBook(googleBook),
                  type: SuggestionType.similarGenre,
                  reason: 'Parce que tu aimes le genre $genre',
                  score: 0.75,
                  metadata: {'genre': genre, 'subject': subject},
                ))
            .toList();
        suggestions.addAll(genreSuggestions);
      }

      return suggestions.take(limit).toList();
    } catch (e) {
      debugPrint('Erreur _getSuggestionsFromGenre: $e');
      return [];
    }
  }

  /// Suggestions générées par IA (ChatGPT) basées sur l'historique complet
  Future<List<BookSuggestion>> _getSuggestionsFromAI({
    int limit = 3,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-suggest-books',
        body: {'limit': limit},
      );

      final data = response.data;
      final Map<String, dynamic> parsed;
      if (data is Map<String, dynamic>) {
        parsed = data;
      } else if (data is String) {
        parsed = jsonDecode(data) as Map<String, dynamic>;
      } else {
        return [];
      }

      if (parsed.containsKey('error')) return [];

      final aiSuggestions = parsed['suggestions'] as List<dynamic>? ?? [];

      // Lancer tous les lookups Google Books en parallèle
      final validItems = aiSuggestions
          .where((item) => (item['title'] as String? ?? '').isNotEmpty)
          .toList();

      final googleResults = await Future.wait(
        validItems.map((item) => _googleBooksService.searchByTitleAuthor(
          item['title'] as String? ?? '',
          item['author'] as String? ?? '',
        )),
      );

      final List<BookSuggestion> results = [];
      for (int i = 0; i < validItems.length; i++) {
        final item = validItems[i];
        final title = item['title'] as String? ?? '';
        final author = item['author'] as String? ?? '';
        final reason = item['reason'] as String? ?? '';
        final googleBooks = googleResults[i];

        if (googleBooks.isNotEmpty) {
          results.add(BookSuggestion(
            book: Book.fromGoogleBook(googleBooks.first),
            type: SuggestionType.aiRecommended,
            reason: reason.isNotEmpty ? reason : 'Recommandé par l\'IA',
            score: 0.85,
            metadata: {'source': 'ai', 'ai_title': title, 'ai_author': author},
          ));
        } else {
          results.add(BookSuggestion(
            book: Book(
              id: 0,
              title: title,
              author: author,
              source: 'manual',
            ),
            type: SuggestionType.aiRecommended,
            reason: reason.isNotEmpty ? reason : 'Recommandé par l\'IA',
            score: 0.85,
            metadata: {'source': 'ai', 'ai_title': title, 'ai_author': author},
          ));
        }
      }

      return results;
    } catch (e) {
      debugPrint('Erreur _getSuggestionsFromAI: $e');
      return [];
    }
  }

  /// Mappe un genre français vers un subject Google Books API
  static String? _genreToGoogleSubject(String genre) {
    const mapping = {
      'Jeunesse': 'juvenile fiction',
      'Young Adult': 'young adult fiction',
      'Science-Fiction': 'science fiction',
      'Fantasy': 'fantasy',
      'Thriller': 'thriller',
      'Policier': 'mystery',
      'Horreur': 'horror',
      'Romance': 'romance',
      'Biographie': 'biography',
      'Histoire': 'history',
      'Historique': 'historical fiction',
      'Philosophie': 'philosophy',
      'Développement personnel': 'self-help',
      'Psychologie': 'psychology',
      'Sciences': 'science',
      'Informatique': 'computers',
      'Technologie': 'technology',
      'Business': 'business',
      'Économie': 'economics',
      'Politique': 'political science',
      'Société': 'social science',
      'Religion': 'religion',
      'Spiritualité': 'spirituality',
      'Bien-être': 'body mind spirit',
      'Art': 'art',
      'Musique': 'music',
      'Cinéma': 'performing arts',
      'Cuisine': 'cooking',
      'Santé': 'health',
      'Voyage': 'travel',
      'Nature': 'nature',
      'Sport': 'sports',
      'Éducation': 'education',
      'BD / Comics': 'comics graphic novels',
      'Manga': 'manga',
      'Poésie': 'poetry',
      'Théâtre': 'drama',
      'Humour': 'humor',
      'Roman littéraire': 'literary fiction',
      'Roman': 'fiction',
      'Non-fiction': 'nonfiction',
    };
    return mapping[genre];
  }

  /// Ajouter un livre suggéré à la bibliothèque
  Future<bool> addSuggestedBookToLibrary(BookSuggestion suggestion) async {
    try {
      final book = suggestion.book;

      // Si le livre n'a pas d'ID (vient de Google Books), l'ajouter d'abord
      if (book.id == 0 && book.googleId != null) {
        // Convertir en GoogleBook puis ajouter
        final googleBook = GoogleBook(
          id: book.googleId!,
          title: book.title,
          authors: book.author != null ? [book.author!] : ['Auteur inconnu'],
          publisher: book.publisher,
          publishedDate: book.publishedDate,
          description: book.description,
          pageCount: book.pageCount,
          coverUrl: book.coverUrl,
          isbns: book.isbn != null ? [book.isbn!] : [],
          language: book.language,
        );

        await _booksService.addBookFromGoogleBooks(googleBook);
      } else if (book.id > 0) {
        // Le livre existe déjà dans la DB, juste l'ajouter à user_books
        await _supabase.from('user_books').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'book_id': book.id,
          'status': 'to_read',
        });
      }

      return true;
    } catch (e) {
      debugPrint('Erreur addSuggestedBookToLibrary: $e');
      return false;
    }
  }
}
