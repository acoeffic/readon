// lib/services/books_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import 'google_books_service.dart';

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
      print('Erreur addBookFromGoogleBooks: $e');
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
      print('Erreur addBookManually: $e');
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
      print('Erreur _addToUserBooks: $e');
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
      print('Erreur getBookById: $e');
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
      print('Erreur getUserBooks: $e');
      return [];
    }
  }

  /// Récupérer tous les livres de l'utilisateur avec leur statut
  Future<List<Map<String, dynamic>>> getUserBooksWithStatus() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('user_books')
          .select('book_id, status, books(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        return {
          'book': Book.fromJson(item['books']),
          'status': item['status'] as String? ?? 'to_read',
        };
      }).toList();
    } catch (e) {
      print('Erreur getUserBooksWithStatus: $e');
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
      print('Erreur getBookStatus: $e');
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
      print('Erreur removeBookFromLibrary: $e');
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
      print('Erreur updateBookStatus: $e');
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

      if (sessions == null || (sessions as List).isEmpty) return null;

      // Trouver la première session dont le livre n'est pas terminé
      for (final session in sessions) {
        final bookIdStr = session['book_id'] as String?;
        if (bookIdStr == null) continue;

        // Vérifier si ce livre est terminé
        if (finishedBookIds.contains(bookIdStr)) continue;

        final bookId = int.tryParse(bookIdStr);
        if (bookId == null) {
          print('Erreur: bookId invalide: $bookIdStr');
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
      print('Erreur getCurrentReadingBook: $e');
      return null;
    }
  }
}