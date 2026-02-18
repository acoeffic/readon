// lib/services/books_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import 'google_books_service.dart';
import 'kindle_webview_service.dart';

class BooksService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleBooksService _googleBooksService = GoogleBooksService();

  /// Ajouter un livre depuis Google Books
  Future<Book> addBookFromGoogleBooks(GoogleBook googleBook) async {
    try {
      // Vérifier si le livre existe déjà (par Google ID)
      final existingByGoogle = await _supabase
          .from('books')
          .select()
          .eq('google_id', googleBook.id)
          .maybeSingle();

      if (existingByGoogle != null) {
        final book = Book.fromJson(existingByGoogle);
        // Ajouter à user_books si pas déjà présent
        await _addToUserBooks(book.id);
        return book;
      }

      // Vérifier par titre + auteur
      final existingByTitle = await _supabase
          .rpc('check_duplicate_book_by_title_author', params: {
            'p_title': googleBook.title,
            'p_author': googleBook.authorsString,
          });

      if (existingByTitle != null && existingByTitle > 0) {
        final book = await getBookById(existingByTitle as int);
        await _addToUserBooks(book.id);
        return book;
      }

      // Créer le nouveau livre
      final bookData = Book.fromGoogleBook(googleBook).toInsert();
      
      final response = await _supabase
          .from('books')
          .insert(bookData)
          .select()
          .single();

      final book = Book.fromJson(response);

      // Ajouter à user_books
      await _addToUserBooks(book.id);

      return book;
    } catch (e) {
      debugPrint('Erreur addBookFromGoogleBooks: $e');
      rethrow;
    }
  }

  /// Ajouter un livre manuellement
  Future<Book> addBookManually({
    required String title,
    required String author,
    String? isbn,
    String? coverUrl,
    int? pageCount,
    String? description,
  }) async {
    try {
      // Vérifier doublon
      final existingId = await _supabase
          .rpc('check_duplicate_book_by_title_author', params: {
            'p_title': title,
            'p_author': author,
          });

      if (existingId != null && existingId > 0) {
        final book = await getBookById(existingId as int);
        await _addToUserBooks(book.id);
        return book;
      }

      // Créer le livre
      final response = await _supabase
          .from('books')
          .insert({
            'title': title,
            'author': author,
            'isbn': isbn,
            'cover_url': coverUrl,
            'page_count': pageCount,
            'description': description,
            'source': 'manual',
          })
          .select()
          .single();

      final book = Book.fromJson(response);
      await _addToUserBooks(book.id);
      return book;
    } catch (e) {
      debugPrint('Erreur addBookManually: $e');
      rethrow;
    }
  }

  /// Ajouter un livre à la bibliothèque de l'utilisateur
  Future<void> _addToUserBooks(int bookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      // Vérifier si déjà présent
      final existing = await _supabase
          .from('user_books')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .maybeSingle();

      if (existing != null) {
        return; // Déjà dans la bibliothèque
      }

      // Ajouter
      await _supabase.from('user_books').insert({
        'user_id': userId,
        'book_id': bookId,
        'status': 'to_read', // ou 'reading', 'finished'
      });
    } catch (e) {
      debugPrint('Erreur _addToUserBooks: $e');
      rethrow;
    }
  }

  /// Trouver ou créer un livre dans la table books, sans l'ajouter à la bibliothèque (user_books)
  Future<Book> findOrCreateBook(GoogleBook googleBook) async {
    try {
      // Vérifier par Google ID
      final existingByGoogle = await _supabase
          .from('books')
          .select()
          .eq('google_id', googleBook.id)
          .maybeSingle();

      if (existingByGoogle != null) {
        return Book.fromJson(existingByGoogle);
      }

      // Vérifier par titre + auteur
      final existingByTitle = await _supabase
          .rpc('check_duplicate_book_by_title_author', params: {
            'p_title': googleBook.title,
            'p_author': googleBook.authorsString,
          });

      if (existingByTitle != null && existingByTitle > 0) {
        return await getBookById(existingByTitle as int);
      }

      // Créer le livre
      final bookData = Book.fromGoogleBook(googleBook).toInsert();
      final response = await _supabase
          .from('books')
          .insert(bookData)
          .select()
          .single();

      return Book.fromJson(response);
    } catch (e) {
      debugPrint('Erreur findOrCreateBook: $e');
      rethrow;
    }
  }

  /// Récupérer un livre par ID
  Future<Book> getBookById(int bookId) async {
    try {
      final response = await _supabase
          .from('books')
          .select()
          .eq('id', bookId)
          .single();

      return Book.fromJson(response);
    } catch (e) {
      debugPrint('Erreur getBookById: $e');
      rethrow;
    }
  }

  /// Récupérer tous les livres de l'utilisateur (Kindle + personnels)
  Future<List<Book>> getUserBooks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      final response = await _supabase
          .from('user_books')
          .select('book_id, books(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Book.fromJson(item['books']))
          .toList();
    } catch (e) {
      debugPrint('Erreur getUserBooks: $e');
      return [];
    }
  }

  /// Récupérer les livres de l'utilisateur avec pagination
  /// [limit] : nombre de livres par page (défaut 20)
  /// [offset] : décalage pour la pagination (défaut 0)
  Future<List<Map<String, dynamic>>> getUserBooksWithStatusPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');
      // Limiter à 100 max pour éviter les abus
      final clampedLimit = limit.clamp(1, 100);

      final response = await _supabase
          .from('user_books')
          .select('book_id, status, is_hidden, books(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + clampedLimit - 1);

      return (response as List).map((item) {
        return {
          'book': Book.fromJson(item['books']),
          'status': item['status'] as String? ?? 'to_read',
          'is_hidden': item['is_hidden'] as bool? ?? false,
        };
      }).toList();
    } catch (e) {
      debugPrint('Erreur getUserBooksWithStatusPaginated: $e');
      return [];
    }
  }

  /// Récupérer tous les livres de l'utilisateur avec leur statut
  /// DEPRECATED: Utiliser getUserBooksWithStatusPaginated pour de meilleures performances
  Future<List<Map<String, dynamic>>> getUserBooksWithStatus() async {
    return getUserBooksWithStatusPaginated(limit: 500, offset: 0);
  }

  /// Récupérer le statut d'un livre pour l'utilisateur courant
  Future<String?> getBookStatus(int bookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('user_books')
          .select('status')
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .maybeSingle();

      return response?['status'] as String?;
    } catch (e) {
      debugPrint('Erreur getBookStatus: $e');
      return null;
    }
  }

  /// Rechercher un livre via Google Books
  Future<List<GoogleBook>> searchGoogleBooks(String query) async {
    return await _googleBooksService.searchBooks(query);
  }

  /// Supprimer un livre de la bibliothèque
  Future<void> removeBookFromLibrary(int bookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await _supabase
          .from('user_books')
          .delete()
          .eq('user_id', userId)
          .eq('book_id', bookId);
    } catch (e) {
      debugPrint('Erreur removeBookFromLibrary: $e');
      rethrow;
    }
  }

  /// Masquer ou afficher un livre vis-à-vis des autres utilisateurs
  Future<void> toggleBookHidden(int bookId, bool isHidden) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');
      await _supabase
          .from('user_books')
          .update({'is_hidden': isHidden})
          .eq('user_id', userId)
          .eq('book_id', bookId);
    } catch (e) {
      debugPrint('Erreur toggleBookHidden: $e');
      rethrow;
    }
  }

  /// Mettre à jour le statut d'un livre
  Future<void> updateBookStatus(int bookId, String status) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      // Vérifier si l'entrée user_books existe
      final existing = await _supabase
          .from('user_books')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .maybeSingle();

      if (existing != null) {
        // Mettre à jour l'entrée existante
        await _supabase
            .from('user_books')
            .update({'status': status})
            .eq('user_id', userId)
            .eq('book_id', bookId);
      } else {
        // Créer une nouvelle entrée avec le statut
        await _supabase.from('user_books').insert({
          'user_id': userId,
          'book_id': bookId,
          'status': status,
        });
      }
    } catch (e) {
      debugPrint('Erreur updateBookStatus: $e');
      rethrow;
    }
  }

  /// Récupérer le dernier livre en cours avec sa progression
  /// Exclut les livres marqués comme "finished"
  Future<Map<String, dynamic>?> getCurrentReadingBook() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      // Récupérer les livres terminés (status = 'finished') pour les exclure
      final finishedBooks = await _supabase
          .from('user_books')
          .select('book_id')
          .eq('user_id', userId)
          .eq('status', 'finished');

      final finishedBookIds = (finishedBooks as List)
          .map((item) => item['book_id'].toString())
          .toSet();

      // Récupérer les dernières sessions terminées
      final sessions = await _supabase
          .from('reading_sessions')
          .select('book_id, end_page')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .order('created_at', ascending: false)
          .limit(10);

      if ((sessions as List).isEmpty) return null;

      // Trouver la première session dont le livre n'est pas terminé
      for (final session in sessions) {
        final bookIdStr = session['book_id'] as String?;
        if (bookIdStr == null) continue;

        // Vérifier si ce livre est terminé
        if (finishedBookIds.contains(bookIdStr)) continue;

        // Récupérer les infos du livre séparément
        final bookId = int.tryParse(bookIdStr);
        if (bookId == null) continue;

        final bookData = await _supabase
            .from('books')
            .select('id, title, author, cover_url, page_count, google_id, genre, isbn, description, publisher, published_date, language, source')
            .eq('id', bookId)
            .maybeSingle();

        if (bookData == null) {
          debugPrint('Erreur: livre non trouvé pour book_id: $bookIdStr');
          continue;
        }

        final currentPage = (session['end_page'] as num?)?.toInt() ?? 0;
        final book = Book.fromJson(bookData);

        return {
          'book': book,
          'current_page': currentPage,
          'total_pages': book.pageCount,
        };
      }

      // Aucun livre en cours trouvé
      return null;
    } catch (e) {
      debugPrint('Erreur getCurrentReadingBook: $e');
      return null;
    }
  }

  /// Importer les livres depuis l'extraction Kindle dans la bibliothèque
  /// Enrichit chaque livre avec les métadonnées de Google Books (couverture, description)
  /// Si [isFirstSync] est true, tous les livres sauf les 2 premiers (plus récents)
  /// sont marqués comme terminés avec kindle_auto_finished = true
  Future<int> importKindleBooks(List<KindleBookProgress> kindleBooks, {bool isFirstSync = false}) async {
    int imported = 0;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    for (final kindleBook in kindleBooks) {
      try {
        // Vérifier si le livre existe déjà (par titre + source kindle)
        final existing = await _supabase
            .from('books')
            .select('id, cover_url, author')
            .eq('title', kindleBook.title)
            .eq('source', 'kindle')
            .maybeSingle();

        int bookId;
        if (existing != null) {
          bookId = existing['id'] as int;
          // Toujours mettre à jour avec la couverture Kindle si disponible (priorité sur Google Books)
          if (kindleBook.coverUrl != null) {
            await _supabase.rpc('update_book_metadata', params: {'p_book_id': bookId, 'p_cover_url': kindleBook.coverUrl});
          } else if (existing['cover_url'] == null) {
            // Pas de couverture Kindle ni existante -> enrichir via Google Books
            await _enrichBookWithGoogleBooks(bookId, _cleanBookTitle(kindleBook.title), kindleAuthor: kindleBook.author);
          }
          // Ré-enrichir les livres existants sans auteur
          if (existing['author'] == null) {
            await _enrichBookWithGoogleBooks(bookId, _cleanBookTitle(kindleBook.title), kindleAuthor: kindleBook.author);
          }
        } else {
          // Chercher les métadonnées sur Google Books (titre nettoyé + auteur Kindle si disponible)
          final cleanTitle = _cleanBookTitle(kindleBook.title);
          final metadata = await _fetchGoogleBooksMetadata(cleanTitle, kindleAuthor: kindleBook.author);

          // Utiliser la couverture Kindle en priorité, sinon Google Books
          final coverUrl = kindleBook.coverUrl ?? metadata?['cover_url'];

          // Si on a un google_id, vérifier qu'il n'existe pas déjà
          String? googleIdToUse = metadata?['google_id'];
          if (googleIdToUse != null) {
            final existingByGoogleId = await _supabase
                .from('books')
                .select('id')
                .eq('google_id', googleIdToUse)
                .maybeSingle();

            if (existingByGoogleId != null) {
              // Un livre avec ce google_id existe déjà, mettre à jour la couverture Kindle si disponible
              bookId = existingByGoogleId['id'] as int;
              if (kindleBook.coverUrl != null) {
                await _supabase.rpc('update_book_metadata', params: {'p_book_id': bookId, 'p_cover_url': kindleBook.coverUrl});
              }
            } else {
              // Créer le livre avec métadonnées et google_id
              final response = await _supabase
                  .from('books')
                  .insert({
                    'title': kindleBook.title,
                    'author': metadata?['author'] ?? kindleBook.author,
                    'source': 'kindle',
                    'cover_url': coverUrl,
                    'description': metadata?['description'],
                    'page_count': metadata?['page_count'],
                    'google_id': googleIdToUse,
                    'genre': metadata?['genre'],
                  })
                  .select()
                  .single();
              bookId = response['id'] as int;
            }
          } else {
            // Pas de google_id, créer sans
            final response = await _supabase
                .from('books')
                .insert({
                  'title': kindleBook.title,
                  'author': metadata?['author'] ?? kindleBook.author,
                  'source': 'kindle',
                  'cover_url': coverUrl,
                  'description': metadata?['description'],
                  'page_count': metadata?['page_count'],
                  'genre': metadata?['genre'],
                })
                .select()
                .single();
            bookId = response['id'] as int;
          }
        }

        // Déterminer le statut depuis la progression
        String? newStatus;
        bool autoFinished = false;

        if (isFirstSync) {
          // Premier sync : les 2 premiers livres (les plus récents) restent en "reading",
          // tous les autres sont auto-marqués comme "finished"
          final index = kindleBooks.indexOf(kindleBook);
          if (index < 2) {
            newStatus = 'reading';
          } else {
            newStatus = 'finished';
            autoFinished = true;
          }
        } else {
          // Sync normal : basé sur la progression Kindle
          if (kindleBook.percentComplete == 100) {
            newStatus = 'finished';
          } else if (kindleBook.percentComplete != null && kindleBook.percentComplete! > 0) {
            newStatus = 'reading';
          }
        }

        // Ajouter ou mettre à jour user_books
        final existingUserBook = await _supabase
            .from('user_books')
            .select('status')
            .eq('user_id', userId)
            .eq('book_id', bookId)
            .maybeSingle();

        if (existingUserBook == null) {
          await _supabase.from('user_books').insert({
            'user_id': userId,
            'book_id': bookId,
            'status': newStatus ?? 'to_read',
            if (autoFinished) 'kindle_auto_finished': true,
          });
          imported++;
        } else if (newStatus != null) {
          // Mettre à jour le statut si on a une info de progression
          final currentStatus = existingUserBook['status'] as String?;
          // Ne pas rétrograder un livre "finished" vers "reading"
          if (currentStatus != 'finished' || newStatus == 'finished') {
            await _supabase
                .from('user_books')
                .update({
                  'status': newStatus,
                  if (autoFinished) 'kindle_auto_finished': true,
                })
                .eq('user_id', userId)
                .eq('book_id', bookId);
          }
        }
      } catch (e) {
        debugPrint('Erreur import livre Kindle "${kindleBook.title}": $e');
      }
    }
    return imported;
  }

  /// Marquer les livres comme terminés à partir des titres trouvés sur Reading Insights
  /// Ces livres apparaissent dans la section "titles read" d'Amazon
  /// Utilise une recherche floue car les titres peuvent différer entre les sources
  /// (ex: "Ma vie sans gravité" vs "Ma vie sans gravité (French Edition)")
  Future<int> markBooksAsFinished(List<KindleBookProgress> finishedBooks) async {
    int updated = 0;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    for (final kindleBook in finishedBooks) {
      try {
        // Nettoyer le titre pour la recherche (enlever les suffixes d'édition)
        final cleanTitle = _cleanBookTitle(kindleBook.title);

        // Chercher le livre par titre exact d'abord
        var book = await _supabase
            .from('books')
            .select('id')
            .eq('title', kindleBook.title)
            .eq('source', 'kindle')
            .maybeSingle();

        // Si pas trouvé, chercher par correspondance partielle
        // (le titre stocké contient le titre de Reading Insights)
        if (book == null && cleanTitle.length > 5) {
          final results = await _supabase
              .from('books')
              .select('id, title')
              .eq('source', 'kindle')
              .ilike('title', '%$cleanTitle%')
              .limit(1);

          if ((results as List).isNotEmpty) {
            book = results[0];
          }
        }

        if (book == null) continue;
        final bookId = book['id'] as int;

        // Mettre à jour le statut dans user_books
        final existing = await _supabase
            .from('user_books')
            .select('status')
            .eq('user_id', userId)
            .eq('book_id', bookId)
            .maybeSingle();

        if (existing != null && existing['status'] != 'finished') {
          await _supabase
              .from('user_books')
              .update({'status': 'finished'})
              .eq('user_id', userId)
              .eq('book_id', bookId);
          updated++;
        }
      } catch (e) {
        debugPrint('Erreur markBooksAsFinished "${kindleBook.title}": $e');
      }
    }
    return updated;
  }

  /// Mettre à jour le genre d'un livre
  Future<void> updateBookGenre(int bookId, String genre) async {
    try {
      await _supabase
          .from('books')
          .update({'genre': genre})
          .eq('id', bookId);
    } catch (e) {
      debugPrint('Erreur updateBookGenre: $e');
      rethrow;
    }
  }

  /// Enrichir les auteurs manquants pour tous les livres de l'utilisateur
  /// Retourne le nombre de livres mis à jour
  Future<int> enrichMissingAuthors() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('user_books')
          .select('book_id, books(id, title, author)')
          .eq('user_id', userId);

      final booksWithoutAuthor = (response as List).where((item) {
        final book = item['books'] as Map<String, dynamic>?;
        if (book == null) return false;
        final author = book['author'] as String?;
        return author == null || author.isEmpty || author == 'Auteur inconnu';
      }).toList();

      if (booksWithoutAuthor.isEmpty) return 0;

      int updated = 0;
      for (final item in booksWithoutAuthor) {
        final book = item['books'] as Map<String, dynamic>;
        final bookId = book['id'] as int;
        final title = book['title'] as String;

        try {
          final metadata = await _fetchGoogleBooksMetadata(
            _cleanBookTitle(title),
          );
          final author = metadata?['author'] as String?;

          if (author != null) {
            await _supabase
                .from('books')
                .update({'author': author})
                .eq('id', bookId);
            updated++;
          }
        } catch (e) {
          debugPrint('Erreur enrichissement auteur pour "$title": $e');
        }
      }

      return updated;
    } catch (e) {
      debugPrint('Erreur enrichMissingAuthors: $e');
      return 0;
    }
  }

  /// Enrichir les descriptions manquantes pour tous les livres de l'utilisateur
  /// Retourne le nombre de livres mis à jour
  Future<int> enrichMissingDescriptions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('user_books')
          .select('book_id, books(id, title, author, description)')
          .eq('user_id', userId);

      final booksWithoutDescription = (response as List).where((item) {
        final book = item['books'] as Map<String, dynamic>?;
        if (book == null) return false;
        final description = book['description'] as String?;
        return description == null || description.isEmpty;
      }).toList();

      if (booksWithoutDescription.isEmpty) return 0;

      int updated = 0;
      for (final item in booksWithoutDescription) {
        final book = item['books'] as Map<String, dynamic>;
        final bookId = book['id'] as int;
        final title = book['title'] as String;
        final author = book['author'] as String?;

        try {
          final metadata = await _fetchGoogleBooksMetadata(
            _cleanBookTitle(title),
            kindleAuthor: author,
          );
          final description = metadata?['description'] as String?;

          if (description != null && description.isNotEmpty) {
            await _supabase
                .from('books')
                .update({'description': description})
                .eq('id', bookId);
            updated++;
          }
        } catch (e) {
          debugPrint('Erreur enrichissement description pour "$title": $e');
        }
      }

      return updated;
    } catch (e) {
      debugPrint('Erreur enrichMissingDescriptions: $e');
      return 0;
    }
  }

  /// Enrichir les couvertures manquantes pour tous les livres de l'utilisateur
  /// Retourne le nombre de livres mis à jour
  Future<int> enrichMissingCovers() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('user_books')
          .select('book_id, books(id, title, author, cover_url)')
          .eq('user_id', userId);

      final booksWithoutCover = (response as List).where((item) {
        final book = item['books'] as Map<String, dynamic>?;
        if (book == null) return false;
        final coverUrl = book['cover_url'] as String?;
        return coverUrl == null || coverUrl.isEmpty;
      }).toList();

      if (booksWithoutCover.isEmpty) return 0;

      int updated = 0;
      for (final item in booksWithoutCover) {
        final book = item['books'] as Map<String, dynamic>;
        final bookId = book['id'] as int;
        final title = book['title'] as String;
        final author = book['author'] as String?;

        try {
          final metadata = await _fetchGoogleBooksMetadata(
            _cleanBookTitle(title),
            kindleAuthor: author,
          );
          final coverUrl = metadata?['cover_url'] as String?;

          if (coverUrl != null && coverUrl.isNotEmpty) {
            await _supabase
                .from('books')
                .update({'cover_url': coverUrl})
                .eq('id', bookId);
            updated++;
          }
        } catch (e) {
          debugPrint('Erreur enrichissement couverture pour "$title": $e');
        }
      }

      return updated;
    } catch (e) {
      debugPrint('Erreur enrichMissingCovers: $e');
      return 0;
    }
  }

  /// Enrichir les genres manquants pour tous les livres de l'utilisateur
  /// Retourne le nombre de livres mis à jour
  Future<int> enrichMissingGenres() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      // Récupérer les livres de l'utilisateur sans genre
      final response = await _supabase
          .from('user_books')
          .select('book_id, books(id, title, author, google_id, genre)')
          .eq('user_id', userId);

      final booksWithoutGenre = (response as List).where((item) {
        final book = item['books'] as Map<String, dynamic>?;
        return book != null && book['genre'] == null;
      }).toList();

      if (booksWithoutGenre.isEmpty) return 0;

      int updated = 0;
      for (final item in booksWithoutGenre) {
        final book = item['books'] as Map<String, dynamic>;
        final bookId = book['id'] as int;
        final title = book['title'] as String;
        final author = book['author'] as String?;

        try {
          final metadata = await _fetchGoogleBooksMetadata(
            _cleanBookTitle(title),
            kindleAuthor: author,
          );
          final genre = metadata?['genre'] as String?;

          if (genre != null) {
            await _supabase
                .from('books')
                .update({'genre': genre})
                .eq('id', bookId);
            updated++;
          }
        } catch (e) {
          debugPrint('Erreur enrichissement genre pour "$title": $e');
        }
      }

      return updated;
    } catch (e) {
      debugPrint('Erreur enrichMissingGenres: $e');
      return 0;
    }
  }

  /// Nettoyer un titre de livre en enlevant les suffixes d'édition courants
  String _cleanBookTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s*\(French Edition\)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Kindle Edition\)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Edition française\)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(édition française\)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(English Edition\)\s*', caseSensitive: false), '')
        .trim();
  }

  /// Chercher les métadonnées d'un livre sur Google Books par titre (et auteur optionnel)
  Future<Map<String, dynamic>?> _fetchGoogleBooksMetadata(String title, {String? kindleAuthor}) async {
    try {
      List<GoogleBook> results;

      // Stratégie 1 : Si on a l'auteur Kindle, chercher avec titre + auteur
      if (kindleAuthor != null && kindleAuthor.isNotEmpty) {
        results = await _googleBooksService.searchByTitleAuthor(title, kindleAuthor);
        if (results.isNotEmpty) {
          return _googleBookToMetadata(results.first);
        }
      }

      // Stratégie 2 : Chercher avec intitle: pour un matching plus précis
      results = await _googleBooksService.searchBooks('intitle:$title');
      if (results.isNotEmpty) {
        return _googleBookToMetadata(results.first);
      }

      // Stratégie 3 : Chercher avec le titre brut (plus large)
      results = await _googleBooksService.searchBooks(title);
      if (results.isNotEmpty) {
        return _googleBookToMetadata(results.first);
      }

      return null;
    } catch (e) {
      debugPrint('Erreur Google Books metadata pour "$title": $e');
      return null;
    }
  }

  /// Convertir un GoogleBook en map de métadonnées
  Map<String, dynamic> _googleBookToMetadata(GoogleBook book) {
    final author = book.authorsString;
    return {
      'author': (author != 'Auteur inconnu') ? author : null,
      'cover_url': book.coverUrl,
      'description': book.description,
      'page_count': book.pageCount,
      'google_id': book.id,
      'genre': book.genre,
    };
  }

  /// Enrichir un livre existant avec les métadonnées Google Books
  Future<void> _enrichBookWithGoogleBooks(int bookId, String title, {String? kindleAuthor}) async {
    try {
      final metadata = await _fetchGoogleBooksMetadata(title, kindleAuthor: kindleAuthor);
      if (metadata == null) return;

      final updates = <String, dynamic>{};
      if (metadata['cover_url'] != null) updates['cover_url'] = metadata['cover_url'];
      if (metadata['description'] != null) updates['description'] = metadata['description'];
      if (metadata['page_count'] != null) updates['page_count'] = metadata['page_count'];
      if (metadata['author'] != null) updates['author'] = metadata['author'];
      if (metadata['genre'] != null) updates['genre'] = metadata['genre'];

      // Vérifier que le google_id n'est pas déjà utilisé par un autre livre
      if (metadata['google_id'] != null) {
        final existingWithGoogleId = await _supabase
            .from('books')
            .select('id')
            .eq('google_id', metadata['google_id'])
            .maybeSingle();

        if (existingWithGoogleId == null) {
          updates['google_id'] = metadata['google_id'];
        }
      }

      if (updates.isNotEmpty) {
        await _supabase.rpc('update_book_metadata', params: {
          'p_book_id': bookId,
          if (updates.containsKey('cover_url')) 'p_cover_url': updates['cover_url'],
          if (updates.containsKey('description')) 'p_description': updates['description'],
          if (updates.containsKey('page_count')) 'p_page_count': updates['page_count'],
          if (updates.containsKey('author')) 'p_author': updates['author'],
          if (updates.containsKey('genre')) 'p_genre': updates['genre'],
          if (updates.containsKey('google_id')) 'p_google_id': updates['google_id'],
        });
      }
    } catch (e) {
      debugPrint('Erreur enrichissement livre $bookId: $e');
    }
  }
}