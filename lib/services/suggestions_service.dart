// lib/services/suggestions_service.dart

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

      List<BookSuggestion> suggestions = [];

      // 1. Suggestions basées sur les amis (max 3)
      final friendsSuggestions = await _getSuggestionsFromFriends(userId, limit: 3);
      suggestions.addAll(friendsSuggestions);

      // 2. Si un livre spécifique est fourni, suggérer du même auteur et via Google Books
      if (basedOnBook != null && basedOnBook.author != null) {
        // Même auteur (max 2)
        final sameAuthorSuggestions = await _getSuggestionsFromSameAuthor(
          basedOnBook.author!,
          excludeBookId: basedOnBook.id,
          limit: 2,
        );
        suggestions.addAll(sameAuthorSuggestions);

        // Google Books similaires (max 3)
        final googleSuggestions = await _getGoogleBooksSuggestions(
          basedOnBook: basedOnBook,
          limit: 3,
        );
        suggestions.addAll(googleSuggestions);
      } else {
        // 3. Suggérer basé sur l'historique de lecture de l'utilisateur
        final historySuggestions = await _getSuggestionsFromHistory(userId, limit: 5);
        suggestions.addAll(historySuggestions);
      }

      // Dédupliquer par book ID
      final seen = <int>{};
      suggestions = suggestions.where((s) {
        if (seen.contains(s.book.id)) return false;
        seen.add(s.book.id);
        return true;
      }).toList();

      // Exclure les livres déjà dans la bibliothèque
      suggestions = await _filterOutUserBooks(userId, suggestions);

      // Limiter au nombre demandé
      if (suggestions.length > limit) {
        suggestions = suggestions.take(limit).toList();
      }

      return suggestions;
    } catch (e) {
      debugPrint('Erreur getPersonalizedSuggestions: $e');
      return [];
    }
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

      List<BookSuggestion> suggestions = [];

      for (final item in (finishedBooks as List).take(2)) {
        final book = Book.fromJson(item['books']);

        // Chercher du même auteur
        if (book.author != null && book.author!.isNotEmpty) {
          final sameAuthor = await _getSuggestionsFromSameAuthor(
            book.author!,
            excludeBookId: book.id,
            limit: 1,
          );
          suggestions.addAll(sameAuthor);
        }

        // Chercher via Google Books
        final google = await _getGoogleBooksSuggestions(
          basedOnBook: book,
          limit: 2,
        );
        suggestions.addAll(google);
      }

      return suggestions.take(limit).toList();
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

  /// Filtrer les livres déjà dans la bibliothèque de l'utilisateur
  Future<List<BookSuggestion>> _filterOutUserBooks(
    String userId,
    List<BookSuggestion> suggestions,
  ) async {
    try {
      final userBooks = await _booksService.getUserBooks();
      final userBookIds = userBooks.map((b) => b.id).toSet();

      return suggestions.where((s) => !userBookIds.contains(s.book.id)).toList();
    } catch (e) {
      debugPrint('Erreur _filterOutUserBooks: $e');
      return suggestions;
    }
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
