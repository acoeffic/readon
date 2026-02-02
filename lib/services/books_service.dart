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
      final userId = _supabase.auth.currentUser!.id;

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
      final userId = _supabase.auth.currentUser!.id;

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

  /// Récupérer tous les livres de l'utilisateur avec leur statut
  Future<List<Map<String, dynamic>>> getUserBooksWithStatus() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('user_books')
          .select('book_id, status, is_hidden, books(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        return {
          'book': Book.fromJson(item['books']),
          'status': item['status'] as String? ?? 'to_read',
          'is_hidden': item['is_hidden'] as bool? ?? false,
        };
      }).toList();
    } catch (e) {
      debugPrint('Erreur getUserBooksWithStatus: $e');
      return [];
    }
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
      final userId = _supabase.auth.currentUser!.id;

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
      final userId = _supabase.auth.currentUser!.id;
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
      final userId = _supabase.auth.currentUser!.id;

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
          .limit(10); // Prendre les 10 dernières pour trouver un livre non terminé

      if ((sessions as List).isEmpty) return null;

      // Trouver la première session dont le livre n'est pas terminé
      for (final session in sessions) {
        final bookIdStr = session['book_id'] as String?;
        if (bookIdStr == null) continue;

        // Vérifier si ce livre est terminé
        if (finishedBookIds.contains(bookIdStr)) continue;

        final bookId = int.tryParse(bookIdStr);
        if (bookId == null) {
          debugPrint('Erreur: bookId invalide: $bookIdStr');
          continue;
        }

        final currentPage = (session['end_page'] as num?)?.toInt() ?? 0;

        // Récupérer les infos du livre
        final book = await getBookById(bookId);

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
            await _supabase.from('books').update({'cover_url': kindleBook.coverUrl}).eq('id', bookId);
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
                await _supabase.from('books').update({'cover_url': kindleBook.coverUrl}).eq('id', bookId);
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
        await _supabase.from('books').update(updates).eq('id', bookId);
      }
    } catch (e) {
      debugPrint('Erreur enrichissement livre $bookId: $e');
    }
  }
}