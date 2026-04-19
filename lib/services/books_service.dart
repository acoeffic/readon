// lib/services/books_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import 'google_books_service.dart';
import 'kindle_webview_service.dart';

class BooksService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleBooksService _googleBooksService = GoogleBooksService();

  /// Insérer un livre via la RPC sécurisée (gère doublons et validation).
  /// Retourne l'ID du livre (existant ou nouveau).
  Future<int> _insertBookRpc({
    required String title,
    String? author,
    String? isbn,
    String? coverUrl,
    int? pageCount,
    String? description,
    String? googleId,
    String source = 'manual',
    String? publisher,
    String language = 'fr',
    String? genre,
    String? publishedDate,
    String? externalId,
  }) async {
    final result = await _supabase.rpc('insert_book_if_not_exists', params: {
      'p_title': title,
      'p_author': author,
      'p_isbn': isbn,
      'p_cover_url': coverUrl,
      'p_page_count': pageCount,
      'p_description': description,
      'p_google_id': googleId,
      'p_source': source,
      'p_publisher': publisher,
      'p_language': language,
      'p_genre': genre,
      'p_published_date': publishedDate,
      'p_external_id': externalId,
    });
    return result as int;
  }

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
        await _enrichExistingBook(book, googleBook);
        await _addToUserBooks(book.id);
        return await getBookById(book.id);
      }

      // Vérifier par titre + auteur
      final existingByTitle = await _supabase
          .rpc('check_duplicate_book_by_title_author', params: {
            'p_title': googleBook.title,
            'p_author': googleBook.authorsString,
          });

      if (existingByTitle != null && existingByTitle > 0) {
        final book = await getBookById(existingByTitle as int);
        await _enrichExistingBook(book, googleBook);
        await _addToUserBooks(book.id);
        return await getBookById(book.id);
      }

      // Créer le nouveau livre via RPC sécurisée
      final gb = Book.fromGoogleBook(googleBook);
      final bookId = await _insertBookRpc(
        title: gb.title,
        author: gb.author,
        isbn: gb.isbn,
        coverUrl: gb.coverUrl,
        pageCount: gb.pageCount,
        description: gb.description,
        googleId: gb.googleId,
        source: gb.source,
        publisher: gb.publisher,
        language: gb.language,
        genre: gb.genre,
        publishedDate: gb.publishedDate,
        externalId: gb.externalId,
      );

      final book = await getBookById(bookId);

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

      // Créer le livre via RPC sécurisée
      final bookId = await _insertBookRpc(
        title: title,
        author: author,
        isbn: isbn,
        coverUrl: coverUrl,
        pageCount: pageCount,
        description: description,
        source: 'manual',
      );

      final book = await getBookById(bookId);
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

      // Créer le livre via RPC sécurisée
      final gb = Book.fromGoogleBook(googleBook);
      final bookId = await _insertBookRpc(
        title: gb.title,
        author: gb.author,
        isbn: gb.isbn,
        coverUrl: gb.coverUrl,
        pageCount: gb.pageCount,
        description: gb.description,
        googleId: gb.googleId,
        source: gb.source,
        publisher: gb.publisher,
        language: gb.language,
        genre: gb.genre,
        publishedDate: gb.publishedDate,
        externalId: gb.externalId,
      );

      return await getBookById(bookId);
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

      // Récupérer les dernières sessions terminées (sans join vers books)
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
        final bookIdRaw = session['book_id'];
        if (bookIdRaw == null) continue;
        final bookIdStr = bookIdRaw.toString();

        // Vérifier si ce livre est terminé
        if (finishedBookIds.contains(bookIdStr)) continue;

        // Récupérer les infos du livre séparément
        final bookIdInt = int.tryParse(bookIdStr);
        if (bookIdInt == null) continue;

        try {
          final bookData = await _supabase
              .from('books')
              .select()
              .eq('id', bookIdInt)
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
        } catch (e) {
          debugPrint('Erreur récupération livre $bookIdStr: $e');
          continue;
        }
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
        bool needsCoverUpdate = false;
        bool needsEnrichment = false;

        if (existing != null) {
          bookId = existing['id'] as int;
          // Marquer les mises à jour à faire APRÈS l'ajout à user_books
          needsCoverUpdate = kindleBook.coverUrl != null && !_isPromotionalImageUrl(kindleBook.coverUrl!);
          needsEnrichment = (existing['cover_url'] == null && !needsCoverUpdate) || existing['author'] == null;
        } else {
          // Chercher les métadonnées sur Google Books (titre nettoyé + auteur Kindle si disponible)
          // Skip if circuit breaker is open — unreliable results would pollute the DB.
          final cleanTitle = _cleanBookTitle(kindleBook.title);
          final metadata = GoogleBooksService.isCircuitOpen
              ? null
              : await _fetchGoogleBooksMetadata(cleanTitle, kindleAuthor: kindleBook.author);

          // Utiliser la couverture Kindle en priorité, sinon Google Books
          // Ignorer les URLs Kindle qui pointent vers des images promotionnelles
          final kindleCover = kindleBook.coverUrl;
          final isPromotionalImage = kindleCover != null && _isPromotionalImageUrl(kindleCover);
          final coverUrl = (kindleCover != null && !isPromotionalImage) ? kindleCover : metadata?['cover_url'];

          // Si on a un google_id, vérifier qu'il n'existe pas déjà
          String? googleIdToUse = metadata?['google_id'];
          if (googleIdToUse != null) {
            final existingByGoogleId = await _supabase
                .from('books')
                .select('id')
                .eq('google_id', googleIdToUse)
                .maybeSingle();

            if (existingByGoogleId != null) {
              bookId = existingByGoogleId['id'] as int;
              needsCoverUpdate = kindleBook.coverUrl != null && !_isPromotionalImageUrl(kindleBook.coverUrl!);
            } else {
              // Créer le livre avec métadonnées et google_id via RPC
              bookId = await _insertBookRpc(
                title: kindleBook.title,
                author: metadata?['author'] as String? ?? kindleBook.author,
                source: 'kindle',
                coverUrl: coverUrl,
                description: metadata?['description'] as String?,
                pageCount: metadata?['page_count'] as int?,
                googleId: googleIdToUse,
                genre: metadata?['genre'] as String?,
                isbn: metadata?['isbn'] as String?,
              );
            }
          } else {
            // Pas de google_id, créer via RPC
            bookId = await _insertBookRpc(
              title: kindleBook.title,
              author: metadata?['author'] as String? ?? kindleBook.author,
              source: 'kindle',
              coverUrl: coverUrl,
              description: metadata?['description'] as String?,
              pageCount: metadata?['page_count'] as int?,
              genre: metadata?['genre'] as String?,
              isbn: metadata?['isbn'] as String?,
            );
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

        // Ajouter ou mettre à jour user_books EN PREMIER
        // (nécessaire avant update_book_metadata qui vérifie l'appartenance)
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

        // Mettre à jour les métadonnées APRÈS l'ajout à user_books
        // (update_book_metadata vérifie que le livre est dans user_books)
        try {
          if (needsCoverUpdate) {
            await _supabase.rpc('update_book_metadata', params: {'p_book_id': bookId, 'p_cover_url': kindleBook.coverUrl});
          }
          if (needsEnrichment) {
            await _enrichBookWithGoogleBooks(bookId, _cleanBookTitle(kindleBook.title), kindleAuthor: kindleBook.author);
          }
        } catch (e) {
          debugPrint('Erreur enrichissement livre Kindle "${kindleBook.title}": $e');
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

  /// Rafraîchir les couvertures de TOUS les livres de l'utilisateur
  /// en cherchant via Google Books, iTunes, Open Library et BnF.
  /// Retourne le nombre de livres mis à jour.
  Future<int> refreshAllCovers() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('user_books')
          .select('book_id, books(id, title, author, cover_url, isbn)')
          .eq('user_id', userId);

      final allBooks = (response as List).where((item) {
        final book = item['books'] as Map<String, dynamic>?;
        return book != null;
      }).toList();

      if (allBooks.isEmpty) return 0;

      int updated = 0;
      for (final item in allBooks) {
        final book = item['books'] as Map<String, dynamic>;
        final bookId = book['id'] as int;
        final title = book['title'] as String;
        final author = book['author'] as String?;
        final isbn = book['isbn'] as String?;
        final currentUrl = book['cover_url'] as String?;

        try {
          String? newCoverUrl;

          // 1. Google Books API (by ISBN, then by title/author)
          final metadata = await _fetchGoogleBooksMetadata(
            _cleanBookTitle(title),
            kindleAuthor: author,
            isbn: isbn,
          );
          newCoverUrl = metadata?['cover_url'] as String?;

          // 2. iTunes / Apple Books (by ISBN, then by title/author)
          if (newCoverUrl == null || newCoverUrl.isEmpty) {
            newCoverUrl = await _fetchItunesCover(isbn, title, author);
          }

          // 3. Open Library (by ISBN)
          if ((newCoverUrl == null || newCoverUrl.isEmpty) &&
              isbn != null && isbn.isNotEmpty) {
            newCoverUrl = await _fetchOpenLibraryCover(isbn);
          }

          // 4. BnF — excellent for French-published books
          if ((newCoverUrl == null || newCoverUrl.isEmpty) &&
              isbn != null && isbn.isNotEmpty) {
            newCoverUrl = await _fetchBnfCover(isbn);
          }

          if (newCoverUrl != null &&
              newCoverUrl.isNotEmpty &&
              newCoverUrl != currentUrl) {
            await _supabase
                .from('books')
                .update({'cover_url': newCoverUrl})
                .eq('id', bookId);
            updated++;
          }
        } catch (e) {
          debugPrint('Erreur rafraîchissement couverture pour "$title": $e');
        }
      }

      return updated;
    } catch (e) {
      debugPrint('Erreur refreshAllCovers: $e');
      return 0;
    }
  }

  /// Fetch a book cover from iTunes / Apple Books by ISBN or title+author.
  Future<String?> _fetchItunesCover(String? isbn, String title, String? author) async {
    // Try by ISBN first
    if (isbn != null && isbn.isNotEmpty) {
      for (final country in ['fr', 'us']) {
        try {
          final uri = Uri.parse(
            'https://itunes.apple.com/search'
            '?term=${Uri.encodeComponent(isbn)}&media=ebook&limit=1&country=$country',
          );
          final response = await http.get(uri).timeout(const Duration(seconds: 4));
          if (response.statusCode != 200) continue;
          final data = jsonDecode(response.body);
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final artwork = results.first['artworkUrl100'] as String?;
            if (artwork != null) {
              return artwork.replaceAll('100x100bb', '600x600bb');
            }
          }
        } catch (_) {}
      }
    }
    // Try by title + author
    final query = '$title ${author ?? ''}'.trim();
    for (final country in ['fr', 'us']) {
      try {
        final uri = Uri.parse(
          'https://itunes.apple.com/search'
          '?term=${Uri.encodeComponent(query)}&media=ebook&limit=3&country=$country',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results == null || results.isEmpty) continue;
        final normalizedTitle = _normalizeForComparison(title);
        for (final r in results) {
          final trackName = (r['trackName'] ?? r['collectionName'] ?? '') as String;
          if (_titleSimilarity(normalizedTitle, _normalizeForComparison(trackName)) > 0.4) {
            final artwork = r['artworkUrl100'] as String?;
            if (artwork != null) {
              return artwork.replaceAll('100x100bb', '600x600bb');
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Fetch a book cover from Open Library by ISBN (with placeholder detection).
  Future<String?> _fetchOpenLibraryCover(String isbn) async {
    try {
      final cleanIsbn = isbn.replaceAll(RegExp(r'[\s-]'), '');
      final url = 'https://covers.openlibrary.org/b/isbn/$cleanIsbn-L.jpg?default=false';
      final headResp = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (headResp.statusCode != 200) return null;
      final length = int.tryParse(headResp.headers['content-length'] ?? '') ?? 0;
      if (length > 0 && length < 1500) return null; // Placeholder
      if (length >= 1500) return url;
      // content-length missing — do a GET
      final getResp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (getResp.statusCode != 200) return null;
      return getResp.bodyBytes.length >= 1500 ? url : null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch a book cover from BnF (Bibliothèque nationale de France) by ISBN.
  Future<String?> _fetchBnfCover(String isbn) async {
    try {
      final cleanIsbn = isbn.replaceAll(RegExp(r'[\s-]'), '');
      final sruUrl =
          'https://catalogue.bnf.fr/api/SRU?version=1.2'
          '&operation=searchRetrieve'
          '&query=bib.isbn%20adj%20%22$cleanIsbn%22'
          '&maximumRecords=1';
      final resp = await http.get(Uri.parse(sruUrl)).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;

      final arkMatch = RegExp(r'ark:/12148/cb\d+[a-z]?').firstMatch(resp.body);
      if (arkMatch == null) return null;

      final coverUrl =
          'https://catalogue.bnf.fr/couverture'
          '?&appName=NE&idArk=${arkMatch.group(0)!}&couession=1';

      final head = await http.head(Uri.parse(coverUrl)).timeout(const Duration(seconds: 4));
      if (head.statusCode != 200) return null;
      final length = int.tryParse(head.headers['content-length'] ?? '') ?? 0;
      if (length > 0 && length < 2000) return null; // Placeholder
      return coverUrl;
    } catch (_) {
      return null;
    }
  }

  /// Enrichir les couvertures manquantes ou de mauvaise qualité (Open Library)
  /// pour tous les livres de l'utilisateur.
  /// Retourne le nombre de livres mis à jour.
  /// Max books to enrich per call to avoid burning the API quota.
  /// With up to 4 API calls per book, 5 books = max 20 API calls.
  static const int _maxEnrichPerSession = 5;

  Future<int> enrichMissingCovers({int maxBooks = _maxEnrichPerSession}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('user_books')
          .select('book_id, books(id, title, author, cover_url, isbn, google_id)')
          .eq('user_id', userId);

      final booksToUpdate = (response as List).where((item) {
        final book = item['books'] as Map<String, dynamic>?;
        if (book == null) return false;
        final coverUrl = book['cover_url'] as String?;
        final googleId = book['google_id'] as String?;
        // Mettre à jour si :
        // - pas de couverture OU couverture Open Library (basse qualité)
        // - OU pas de google_id (empêche le fallback déterministe)
        return coverUrl == null ||
            coverUrl.isEmpty ||
            coverUrl.contains('covers.openlibrary.org') ||
            googleId == null ||
            googleId.isEmpty;
      }).toList();

      if (booksToUpdate.isEmpty) return 0;

      int updated = 0;
      final capped = booksToUpdate.take(maxBooks);
      for (final item in capped) {
        final book = item['books'] as Map<String, dynamic>;
        final bookId = book['id'] as int;
        final title = book['title'] as String;
        final author = book['author'] as String?;
        final isbn = book['isbn'] as String?;
        final currentUrl = book['cover_url'] as String?;

        try {
          final metadata = await _fetchGoogleBooksMetadata(
            _cleanBookTitle(title),
            kindleAuthor: author,
            isbn: isbn,
          );
          final newCoverUrl = metadata?['cover_url'] as String?;
          final newGoogleId = metadata?['google_id'] as String?;
          final newIsbn = metadata?['isbn'] as String?;

          // Build update map with all available metadata
          final updates = <String, dynamic>{};

          // Always update google_id and isbn if found and currently missing
          if (newGoogleId != null && newGoogleId.isNotEmpty) {
            final currentGoogleId = book['google_id'] as String?;
            if (currentGoogleId == null || currentGoogleId.isEmpty) {
              updates['google_id'] = newGoogleId;
            }
          }
          if (newIsbn != null && newIsbn.isNotEmpty) {
            final currentIsbn = book['isbn'] as String?;
            if (currentIsbn == null || currentIsbn.isEmpty) {
              updates['isbn'] = newIsbn;
            }
          }

          // N'update la couverture que si on a trouvé une meilleure (pas Open Library)
          if (newCoverUrl != null &&
              newCoverUrl.isNotEmpty &&
              !newCoverUrl.contains('covers.openlibrary.org')) {
            updates['cover_url'] = newCoverUrl;
          } else if ((currentUrl == null || currentUrl.isEmpty) &&
              newCoverUrl != null &&
              newCoverUrl.isNotEmpty) {
            // Si toujours pas de couverture, on met au moins l'Open Library
            updates['cover_url'] = newCoverUrl;
          }

          if (updates.isNotEmpty) {
            await _supabase
                .from('books')
                .update(updates)
                .eq('id', bookId);
            if (updates.containsKey('cover_url')) updated++;
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

  /// Re-enrichit les livres dont les métadonnées semblent incorrectes :
  ///  - description trop courte (< 80 caractères) → probablement une fiche d'analyse
  ///  - couverture manquante ET google_id présent → le HEAD-check a échoué
  ///  - ISBN manquant alors qu'un google_id existe
  ///
  /// Utilise SharedPreferences pour ne lancer qu'une seule fois par version
  /// de l'algorithme (incrémentez [_reEnrichVersion] pour relancer).
  static const int _reEnrichVersion = 4;
  static const String _reEnrichKey = 'books_re_enrich_version';

  Future<int> reEnrichSuspiciousBooks({int maxBooks = _maxEnrichPerSession}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    // Vérifier si cette version a déjà été exécutée
    final prefs = await SharedPreferences.getInstance();
    final doneVersion = prefs.getInt(_reEnrichKey) ?? 0;
    if (doneVersion >= _reEnrichVersion) return 0;

    try {
      final response = await _supabase
          .from('user_books')
          .select('book_id, books(id, title, author, cover_url, description, isbn, google_id)')
          .eq('user_id', userId);

      final suspicious = (response as List).where((item) {
        final book = item['books'] as Map<String, dynamic>?;
        if (book == null) return false;
        final desc = book['description'] as String?;
        final coverUrl = book['cover_url'] as String?;
        final isbn = book['isbn'] as String?;
        final googleId = book['google_id'] as String?;

        final shortDescription = desc != null && desc.isNotEmpty && desc.length < 80;
        final missingCoverWithGoogleId = (coverUrl == null || coverUrl.isEmpty) && googleId != null;
        final missingIsbnWithGoogleId = (isbn == null || isbn.isEmpty) && googleId != null;
        final missingGoogleId = googleId == null || googleId.isEmpty;
        final olCover = coverUrl != null && coverUrl.contains('covers.openlibrary.org');

        // Detect garbage ISBNs (OCLC numbers, library catalog IDs like UCSC:...)
        final garbageIsbn = isbn != null &&
            isbn.isNotEmpty &&
            !RegExp(r'^\d{9}[\dXx]$|^\d{13}$').hasMatch(isbn.replaceAll(RegExp(r'[\s-]'), ''));

        // Detect mismatched cover: imageUrl points to a different Google Books
        // volume than the stored googleId — one of them is wrong.
        final coverGbId = coverUrl != null && coverUrl.contains('books.google.com')
            ? RegExp(r'[?&]id=([^&]+)').firstMatch(coverUrl)?.group(1)
            : null;
        final mismatchedCover = coverGbId != null &&
            googleId != null &&
            coverGbId != googleId;

        return shortDescription ||
            missingCoverWithGoogleId ||
            missingIsbnWithGoogleId ||
            missingGoogleId ||
            olCover ||
            garbageIsbn ||
            mismatchedCover;
      }).toList();

      if (suspicious.isEmpty) {
        await prefs.setInt(_reEnrichKey, _reEnrichVersion);
        return 0;
      }

      int updated = 0;
      final capped = suspicious.take(maxBooks).toList();
      for (final item in capped) {
        final book = item['books'] as Map<String, dynamic>;
        final bookId = book['id'] as int;
        final title = book['title'] as String;
        final author = book['author'] as String?;
        final isbn = book['isbn'] as String?;
        final currentCover = book['cover_url'] as String?;
        final currentDesc = book['description'] as String?;

        try {
          final metadata = await _fetchGoogleBooksMetadata(
            _cleanBookTitle(title),
            kindleAuthor: author,
            isbn: isbn,
          );
          if (metadata == null) continue;

          final updates = <String, dynamic>{};
          final currentGoogleId = book['google_id'] as String?;

          // Check if ISBN is garbage (OCLC, library catalog, etc.)
          final isGarbageIsbn = isbn != null &&
              isbn.isNotEmpty &&
              !RegExp(r'^\d{9}[\dXx]$|^\d{13}$').hasMatch(isbn.replaceAll(RegExp(r'[\s-]'), ''));

          // Check if coverUrl and googleId point to different volumes
          final coverGbId = currentCover != null && currentCover.contains('books.google.com')
              ? RegExp(r'[?&]id=([^&]+)').firstMatch(currentCover)?.group(1)
              : null;
          final isMismatchedCover = coverGbId != null &&
              currentGoogleId != null &&
              coverGbId != currentGoogleId;

          // Remplacer la description si elle est trop courte et qu'on en a une meilleure
          final newDesc = metadata['description'] as String?;
          if (newDesc != null &&
              newDesc.length > 80 &&
              (currentDesc == null || currentDesc.length < 80)) {
            updates['description'] = newDesc;
          }

          // Ajouter ou remplacer la couverture
          final newCover = metadata['cover_url'] as String?;
          if (newCover != null && newCover.isNotEmpty) {
            final shouldReplaceCover = currentCover == null ||
                currentCover.isEmpty ||
                currentCover.contains('covers.openlibrary.org') ||
                isMismatchedCover;
            if (shouldReplaceCover) {
              updates['cover_url'] = newCover;
            }
          }

          // Ajouter ou remplacer l'ISBN si manquant ou invalide
          final newIsbn = metadata['isbn'] as String?;
          if (newIsbn != null && newIsbn.isNotEmpty) {
            if (isbn == null || isbn.isEmpty || isGarbageIsbn) {
              updates['isbn'] = newIsbn;
            }
          }

          // Ajouter ou remplacer le google_id
          final newGoogleId = metadata['google_id'] as String?;
          if (newGoogleId != null && newGoogleId.isNotEmpty) {
            // Replace if missing, or if there's a cover/googleId mismatch
            // (the new googleId from a fresh search is more trustworthy)
            if (currentGoogleId == null || currentGoogleId.isEmpty || isMismatchedCover) {
              updates['google_id'] = newGoogleId;
            }
          }

          if (updates.isNotEmpty) {
            await _supabase
                .from('books')
                .update(updates)
                .eq('id', bookId);
            updated++;
          }
        } catch (e) {
          debugPrint('Erreur re-enrichissement pour "$title": $e');
        }
      }

      // Only mark as fully done when all suspicious books have been processed
      if (capped.length >= suspicious.length) {
        await prefs.setInt(_reEnrichKey, _reEnrichVersion);
      }
      return updated;
    } catch (e) {
      debugPrint('Erreur reEnrichSuspiciousBooks: $e');
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
          var genre = metadata?['genre'] as String?;

          // Fallback : inférer le genre depuis le titre si Google Books n'a rien
          genre ??= inferGenreFromTitle(title, author);

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

  /// Vérifie si une URL d'image Kindle pointe vers une image promotionnelle
  /// (badges app store, bannières "Download", etc.) plutôt qu'une couverture de livre
  bool _isPromotionalImageUrl(String url) {
    final lower = url.toLowerCase();
    // Patterns typiques d'images promotionnelles Amazon
    return lower.contains('badge') ||
        lower.contains('banner') ||
        lower.contains('button') ||
        lower.contains('app-store') ||
        lower.contains('google-play') ||
        lower.contains('windows-store') ||
        lower.contains('download') ||
        lower.contains('get-it-on') ||
        lower.contains('available-on') ||
        lower.contains('platform') ||
        lower.contains('promo');
  }

  /// Nettoyer un titre de livre en enlevant les suffixes d'édition courants
  /// et les sous-titres génériques français (": récit", ": roman", etc.)
  String _cleanBookTitle(String title) {
    var cleaned = title
        .replaceAll(RegExp(r'\s*\(French Edition\)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Kindle Edition\)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Edition française\)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(édition française\)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(English Edition\)\s*', caseSensitive: false), '')
        .trim();

    // Retirer les sous-titres génériques français qui polluent la recherche
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*:\s*(récit|roman|essai|nouvelles?|témoignage|document|enquête|chronique|mémoires?)\s*$', caseSensitive: false),
      '',
    );

    return cleaned.trim();
  }

  /// Chercher les métadonnées d'un livre sur Google Books par titre (et auteur/ISBN optionnels)
  Future<Map<String, dynamic>?> _fetchGoogleBooksMetadata(String title, {String? kindleAuthor, String? isbn}) async {
    try {
      List<GoogleBook> results;

      // Stratégie 0 : Chercher par ISBN (le plus fiable)
      if (isbn != null && isbn.isNotEmpty) {
        final book = await _googleBooksService.searchByISBN(isbn);
        if (book != null && book.coverUrl != null) {
          return _googleBookToMetadata(book);
        }
      }

      // Stratégie 1 : Si on a l'auteur Kindle, chercher avec titre + auteur
      if (kindleAuthor != null && kindleAuthor.isNotEmpty) {
        results = await _googleBooksService.searchByTitleAuthor(title, kindleAuthor);
        final match = _bestMatch(results, title, expectedAuthor: kindleAuthor);
        if (match != null) return _googleBookToMetadata(match);
      }

      // Stratégie 2 : Chercher avec intitle: pour un matching plus précis
      results = await _googleBooksService.searchBooks('intitle:$title');
      final match2 = _bestMatch(results, title, expectedAuthor: kindleAuthor);
      if (match2 != null) return _googleBookToMetadata(match2);

      // Stratégie 3 : Chercher avec le titre brut (plus large)
      results = await _googleBooksService.searchBooks(title);
      final match3 = _bestMatch(results, title, expectedAuthor: kindleAuthor);
      if (match3 != null) return _googleBookToMetadata(match3);

      return null;
    } catch (e) {
      debugPrint('Erreur Google Books metadata pour "$title": $e');
      return null;
    }
  }

  /// Enrichir un livre existant avec les données d'un GoogleBook (comble les champs manquants)
  Future<void> _enrichExistingBook(Book existing, GoogleBook googleBook) async {
    final updates = <String, dynamic>{};
    if ((existing.coverUrl == null || existing.coverUrl!.isEmpty) && googleBook.coverUrl != null) {
      updates['cover_url'] = googleBook.coverUrl;
    }
    if ((existing.description == null || existing.description!.isEmpty) && googleBook.description != null) {
      updates['description'] = googleBook.description;
    }
    if (existing.pageCount == null && googleBook.pageCount != null) {
      updates['page_count'] = googleBook.pageCount;
    }
    if (existing.googleId == null && googleBook.id.isNotEmpty) {
      updates['google_id'] = googleBook.id;
    }
    if (updates.isNotEmpty) {
      await _supabase.from('books').update(updates).eq('id', existing.id);
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
      'isbn': book.isbn13,
    };
  }

  /// Sélectionne le meilleur résultat Google Books dont le titre correspond
  /// suffisamment au titre recherché. Retourne null si aucun résultat n'est
  /// assez proche (seuil de similarité > 0.55).
  ///
  /// Quand [expectedAuthor] est fourni, un bonus est accordé aux résultats
  /// dont l'auteur correspond, et une pénalité aux résultats dont l'auteur
  /// ne correspond pas du tout, afin d'éviter les faux positifs.
  GoogleBook? _bestMatch(List<GoogleBook> results, String searchTitle, {String? expectedAuthor}) {
    if (results.isEmpty) return null;
    final normalizedSearch = _normalizeForComparison(searchTitle);
    final normalizedAuthor = expectedAuthor != null && expectedAuthor.isNotEmpty
        ? _normalizeForComparison(expectedAuthor)
        : null;
    GoogleBook? best;
    double bestScore = 0;
    for (final r in results) {
      var score = _titleSimilarity(normalizedSearch, _normalizeForComparison(r.title));

      // Bonus/malus auteur : favoriser les bons auteurs, pénaliser les mauvais
      if (normalizedAuthor != null) {
        final resultAuthor = _normalizeForComparison(r.authorsString);
        final authorScore = _titleSimilarity(normalizedAuthor, resultAuthor);
        if (authorScore > 0.5) {
          score += 0.15; // Bon auteur → bonus
        } else if (authorScore < 0.2) {
          score -= 0.20; // Auteur très différent → pénalité
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    }
    return bestScore > 0.55 ? best : null;
  }

  /// Normalise un titre pour la comparaison : minuscules, sans accents, sans ponctuation.
  static String _normalizeForComparison(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp('[\\s\\-–—:,;.!?\x27\x22«»()]+'), ' ')
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e').replaceAll('ë', 'e')
        .replaceAll('à', 'a').replaceAll('â', 'a').replaceAll('ä', 'a')
        .replaceAll('ù', 'u').replaceAll('û', 'u').replaceAll('ü', 'u')
        .replaceAll('ô', 'o').replaceAll('ö', 'o')
        .replaceAll('î', 'i').replaceAll('ï', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('œ', 'oe').replaceAll('æ', 'ae')
        .trim();
  }

  /// Score de similarité entre deux titres normalisés (0.0 à 1.0).
  /// Utilise l'indice de Jaccard (intersection / union) pour une mesure
  /// bidirectionnelle — évite les faux positifs quand un titre est court.
  static double _titleSimilarity(String a, String b) {
    final wordsA = a.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final wordsB = b.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) {
      return a == b ? 1.0 : 0.0;
    }
    final common = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    return common / union;
  }

  /// Enrichir un livre existant avec les métadonnées Google Books
  Future<void> _enrichBookWithGoogleBooks(int bookId, String title, {String? kindleAuthor}) async {
    try {
      final metadata = await _fetchGoogleBooksMetadata(title, kindleAuthor: kindleAuthor);
      if (metadata == null) return;

      // Lire l'état actuel du livre pour ne pas écraser les champs déjà remplis
      final current = await _supabase
          .from('books')
          .select('cover_url, description, page_count, author, genre, isbn')
          .eq('id', bookId)
          .maybeSingle();

      final updates = <String, dynamic>{};
      if (metadata['cover_url'] != null && (current?['cover_url'] == null || (current!['cover_url'] as String).isEmpty)) {
        updates['cover_url'] = metadata['cover_url'];
      }
      if (metadata['description'] != null && (current?['description'] == null || (current!['description'] as String).isEmpty)) {
        updates['description'] = metadata['description'];
      }
      if (metadata['page_count'] != null && current?['page_count'] == null) {
        updates['page_count'] = metadata['page_count'];
      }
      if (metadata['author'] != null && (current?['author'] == null || (current!['author'] as String).isEmpty)) {
        updates['author'] = metadata['author'];
      }
      if (metadata['genre'] != null && (current?['genre'] == null || (current!['genre'] as String).isEmpty)) {
        updates['genre'] = metadata['genre'];
      }
      if (metadata['isbn'] != null && (current?['isbn'] == null || (current!['isbn'] as String).isEmpty)) {
        updates['isbn'] = metadata['isbn'];
      }

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
          if (updates.containsKey('isbn')) 'p_isbn': updates['isbn'],
        });
      }
    } catch (e) {
      debugPrint('Erreur enrichissement livre $bookId: $e');
    }
  }
}