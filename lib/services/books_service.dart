// lib/services/books_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import '../models/reading_session.dart';
import '../widgets/cached_book_cover.dart';
import 'analytics_service.dart';
import 'annotation_service.dart';
import 'reading_session_service.dart';
import 'google_books_service.dart';
import 'kindle_webview_service.dart';

class BooksService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleBooksService _googleBooksService = GoogleBooksService();

  /// Insérer un livre via la RPC sécurisée (gère doublons et validation).
  /// Retourne l'ID du livre (existant ou nouveau).
  Future<int> insertBookIfNotExists({
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
    // Saisie manuelle : la page de recherche renvoie un GoogleBook synthétique
    // sans id (le livre n'existe pas au catalogue Google). On ne peut alors ni
    // dédupliquer par google_id ni enrichir la fiche — on bascule sur le
    // chemin manuel, qui déduplique par titre+auteur et pose source='manual'.
    if (googleBook.id.isEmpty) {
      return addBookManually(
        title: googleBook.title,
        author: googleBook.authorsString,
        isbn: googleBook.isbns.isNotEmpty ? googleBook.isbns.first : null,
        coverUrl: googleBook.coverUrl,
        pageCount: googleBook.pageCount,
        description: googleBook.description,
      );
    }

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
      final bookId = await insertBookIfNotExists(
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
      final bookId = await insertBookIfNotExists(
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

      // Point de passage unique de tous les ajouts à la bibliothèque (recherche,
      // scan de couverture, saisie manuelle, import Kindle) : c'est ici qu'on
      // mesure `book_added`, et nulle part ailleurs. Le retour anticipé
      // ci-dessus garantit qu'un livre déjà présent ne compte pas deux fois.
      unawaited(AnalyticsService().track(
        AnalyticsEvent.bookAdded,
        properties: {'book_id': bookId},
      ));
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
      final bookId = await insertBookIfNotExists(
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

  /// Récupérer les livres de l'utilisateur triés par lecture récente :
  /// les livres avec la session de lecture la plus récente en premier,
  /// les livres jamais lus ensuite (dans l'ordre d'ajout).
  Future<List<Book>> getUserBooksByLastRead() async {
    final books = await getUserBooks();
    if (books.length < 2) return books;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return books;

      final sessions = await _supabase
          .from('reading_sessions')
          .select('book_id')
          .eq('user_id', userId)
          .order('start_time', ascending: false)
          .limit(300);

      // Rang de récence : première occurrence = session la plus récente.
      final rank = <String, int>{};
      for (final row in (sessions as List)) {
        final id = row['book_id']?.toString();
        if (id != null && !rank.containsKey(id)) {
          rank[id] = rank.length;
        }
      }
      if (rank.isEmpty) return books;

      // Tri stable : livres lus récemment d'abord,
      // les autres conservent l'ordre de getUserBooks().
      final indexed = books.asMap().entries.toList();
      indexed.sort((a, b) {
        final ra = rank[a.value.id.toString()];
        final rb = rank[b.value.id.toString()];
        if (ra != null && rb != null) return ra.compareTo(rb);
        if (ra != null) return -1;
        if (rb != null) return 1;
        return a.key.compareTo(b.key);
      });
      return indexed.map((e) => e.value).toList();
    } catch (e) {
      debugPrint('Erreur getUserBooksByLastRead: $e');
      return books;
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

      // 2 requêtes en parallèle : livres terminés + dernières sessions
      final results = await Future.wait([
        _supabase
            .from('user_books')
            .select('book_id')
            .eq('user_id', userId)
            .eq('status', 'finished'),
        // Tri par end_time (pas created_at) : une lecture passée saisie
        // manuellement (is_manual, antidatée) ne doit pas devenir la session
        // "courante" et faire reculer la page du livre.
        _supabase
            .from('reading_sessions')
            .select('book_id, end_page, end_time')
            .eq('user_id', userId)
            .not('end_time', 'is', null)
            .order('end_time', ascending: false)
            .limit(10),
      ]);

      final finishedBookIds = (results[0] as List)
          .map((item) => item['book_id'].toString())
          .toSet();
      final sessions = results[1] as List;

      // Candidat Kindle : livre dont la progression Kindle a bougé en dernier.
      // Il l'emporte si sa progression est plus récente que la dernière
      // session LexDay — un lecteur 100 % Kindle a ainsi un « livre en
      // cours » sans rien saisir.
      final kindleCandidate = await _kindleCurrentCandidate(userId);

      // Trouver la première session dont le livre n'est pas terminé
      Map<String, dynamic>? candidate;
      for (final session in sessions) {
        final bookIdRaw = session['book_id'];
        if (bookIdRaw == null) continue;
        final bookIdStr = bookIdRaw.toString();
        if (finishedBookIds.contains(bookIdStr)) continue;
        if (int.tryParse(bookIdStr) == null) continue;
        candidate = session as Map<String, dynamic>;
        break;
      }

      if (kindleCandidate != null) {
        final kindleAt = kindleCandidate['at'] as DateTime;
        final sessionAt = candidate == null
            ? null
            : DateTime.tryParse(candidate['end_time'] as String? ?? '');
        if (candidate == null || sessionAt == null || kindleAt.isAfter(sessionAt)) {
          kindleCandidate.remove('at');
          return kindleCandidate;
        }
      }

      if (candidate == null) return null;

      final bookIdInt = int.parse(candidate['book_id'].toString());
      final bookData = await _supabase
          .from('books')
          .select()
          .eq('id', bookIdInt)
          .maybeSingle();

      if (bookData == null) {
        debugPrint('Erreur: livre non trouvé pour book_id: $bookIdInt');
        return null;
      }

      // Page courante = max des end_page connus pour ce livre (dans la
      // fenêtre récupérée), pas seulement celui de la dernière session par
      // end_time : une lecture passée antidatée (is_manual, horaire par
      // défaut 21:00) peut être plus avancée en pages tout en étant classée
      // avant la dernière session — et inversement, une session antidatée
      // plus ancienne ne doit pas faire reculer la page courante.
      final candidateBookId = candidate['book_id'].toString();
      int currentPage = 0;
      for (final session in sessions) {
        if (session['book_id']?.toString() != candidateBookId) continue;
        final endPage = (session['end_page'] as num?)?.toInt() ?? 0;
        if (endPage > currentPage) currentPage = endPage;
      }
      // Progression Kindle (sync JSON) : la page la plus avancée gagne.
      final kindlePage = await getKindleCurrentPage(candidateBookId);
      if (kindlePage != null && kindlePage > currentPage) currentPage = kindlePage;
      final book = Book.fromJson(bookData);

      return {
        'book': book,
        'current_page': currentPage,
        'total_pages': book.pageCount,
      };
    } catch (e) {
      debugPrint('Erreur getCurrentReadingBook: $e');
      return null;
    }
  }

  /// Enregistre les jours lus sur Kindle (calendrier Amazon) dans
  /// `kindle_read_days` — ils comptent pour la flamme. Idempotent (PK
  /// user_id+day, upsert ignoreDuplicates). Fenêtre : [maxDays] derniers.
  Future<int> upsertKindleReadDays(List<DateTime> days, {int maxDays = 120}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || days.isEmpty) return 0;
    final sorted = [...days]..sort();
    final window = sorted.length > maxDays
        ? sorted.sublist(sorted.length - maxDays)
        : sorted;
    final rows = [
      for (final d in window)
        {
          'user_id': userId,
          'day':
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        },
    ];
    try {
      final res = await _supabase
          .from('kindle_read_days')
          .upsert(rows, onConflict: 'user_id,day', ignoreDuplicates: true)
          .select('day');
      final inserted = (res as List).length;
      if (inserted > 0) {
        debugPrint('upsertKindleReadDays: $inserted nouveau(x) jour(s) Kindle');
      }
      return inserted;
    } catch (e) {
      debugPrint('upsertKindleReadDays KO: $e');
      return 0;
    }
  }

  /// Livre « en cours » côté Kindle : le user_book non terminé avec la
  /// progression Kindle la plus récente. Candidat pour [getCurrentReadingBook]
  /// quand l'utilisateur lit sur Kindle sans session LexDay.
  Future<Map<String, dynamic>?> _kindleCurrentCandidate(String userId) async {
    try {
      final rows = await _supabase
          .from('user_books')
          .select('book_id, kindle_percent, kindle_progress_at, books(*)')
          .eq('user_id', userId)
          .neq('status', 'finished')
          .eq('is_hidden', false)
          .not('kindle_progress_at', 'is', null)
          .gt('kindle_percent', 0)
          .lt('kindle_percent', 100)
          .order('kindle_progress_at', ascending: false)
          .limit(1);
      if ((rows as List).isEmpty) return null;
      final row = rows[0] as Map<String, dynamic>;
      final bookJson = row['books'];
      if (bookJson is! Map<String, dynamic>) return null;
      final at = DateTime.tryParse(row['kindle_progress_at'] as String? ?? '');
      if (at == null) return null;
      final book = Book.fromJson(bookJson);
      final page = kindlePageFromRow({
        'kindle_percent': row['kindle_percent'],
        'books': {'page_count': book.pageCount},
      });
      return {
        'book': book,
        'current_page': page ?? 0,
        'total_pages': book.pageCount,
        'at': at,
      };
    } catch (e) {
      debugPrint('Erreur _kindleCurrentCandidate: $e');
      return null;
    }
  }

  /// Pourcentages Kindle stockés (user_books.kindle_percent) pour [asins].
  Future<Map<String, int>> getKindlePercentsByAsin(List<String> asins) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || asins.isEmpty) return {};
    final rows = await _supabase
        .from('user_books')
        .select('kindle_asin, kindle_percent')
        .eq('user_id', userId)
        .inFilter('kindle_asin', asins);
    final out = <String, int>{};
    for (final r in rows as List) {
      final asin = r['kindle_asin'] as String?;
      final pct = (r['kindle_percent'] as num?)?.toInt();
      if (asin != null && pct != null) out[asin] = pct;
    }
    return out;
  }

  /// ASIN des livres « en cours » côté LexDay : statut reading, ou
  /// progression Kindle connue entre 1 et 99 %. Complète les N livres les
  /// plus récents d'Amazon pour la phase progression : un livre entamé puis
  /// laissé de côté quelques semaines sort du top récence, mais on veut
  /// toujours capter sa reprise.
  Future<List<String>> getKindleAsinsInProgress() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _supabase
        .from('user_books')
        .select('kindle_asin, status, kindle_percent')
        .eq('user_id', userId)
        .not('kindle_asin', 'is', null)
        .neq('status', 'finished');
    final out = <String>[];
    for (final r in rows as List) {
      final asin = r['kindle_asin'] as String?;
      if (asin == null || asin.isEmpty) continue;
      final status = r['status'] as String?;
      final pct = (r['kindle_percent'] as num?)?.toInt();
      if (status == 'reading' || (pct != null && pct > 0 && pct < 100)) {
        out.add(asin);
      }
    }
    return out;
  }

  /// Crée une session de lecture (is_manual, source 'kindle') pour le delta de
  /// progression Kindle [fromPercent] → [toPercent] d'un livre. Décision du
  /// 12/09/2026 : session complète (pages + durée estimée au rythme
  /// personnel, compte pour la flamme, badges, objectifs, feed avec badge
  /// Kindle). Datée au moment du sync — la session est du jour, donc elle
  /// compte pour la flamme (règle is_manual antidatée = exclue).
  ///
  /// Sans `page_count` on ne sait pas convertir un % en pages : pas de session
  /// (la page courante reste gérée par [getKindleCurrentPage]).
  /// Date de fin d'une session Kindle : le dernier jour lu selon le
  /// calendrier Amazon, dans la fenêtre ]dernier sync progression, maintenant].
  /// Ce jour = aujourd'hui (ou calendrier absent) → maintenant. Un jour passé
  /// → 21:00 ce jour-là (même convention que les lectures passées). La session
  /// compte quand même pour la flamme (exemption source 'kindle').
  DateTime _kindleSessionEndTime(
    KindleInsightsCalendar? calendar,
    DateTime? previousProgressAt,
  ) {
    final now = DateTime.now();
    if (calendar == null) return now;
    final day = calendar.lastReadDayBetween(previousProgressAt?.toLocal(), now);
    if (day == null) return now;
    final today = DateTime(now.year, now.month, now.day);
    if (!day.isBefore(today)) return now;
    final at21 = DateTime(day.year, day.month, day.day, 21);
    return at21.isAfter(now) ? now : at21;
  }

  Future<bool> _createKindleSession({
    required int bookId,
    required int fromPercent,
    required int toPercent,
    required String title,
    DateTime? endTime,
  }) async {
    final bookRow = await _supabase
        .from('books')
        .select('page_count')
        .eq('id', bookId)
        .maybeSingle();
    final pageCount = (bookRow?['page_count'] as num?)?.toInt();
    if (pageCount == null || pageCount <= 0) {
      debugPrint(
          'importKindleBooks: pas de page_count pour "$title", session Kindle sautée');
      return false;
    }
    int toPage(int pct) => (pct / 100 * pageCount).round().clamp(0, pageCount).toInt();
    final startPage = toPage(fromPercent);
    final endPage = toPage(toPercent);
    final pages = endPage - startPage;
    if (pages < 1) return false;

    final sessionService = ReadingSessionService();
    final duration = await sessionService.estimateDurationForPages(pages);
    await sessionService.insertPastSession(
      bookId: bookId.toString(),
      startPage: startPage,
      endPage: endPage,
      duration: duration,
      endTime: endTime,
      source: ReadingSession.sourceKindle,
    );
    debugPrint(
      'importKindleBooks: session Kindle "$title" p.$startPage→$endPage '
      '($pages p., ~${duration.inMinutes} min estimées, fin ${endTime ?? 'maintenant'})',
    );
    return true;
  }

  /// Page courante déduite de la progression Kindle pour [bookId], ou `null`
  /// si le livre n'a pas de pourcentage Kindle ou pas de nombre de pages
  /// (impossible de convertir un % en page sans `page_count`).
  ///
  /// Utilisé par les calculs de page courante (`getBookStats`,
  /// `getCurrentReadingBook`) : la page affichée devient
  /// max(sessions, Kindle), dans l'esprit de la règle existante « la page
  /// courante ne recule jamais ».
  Future<int?> getKindleCurrentPage(String bookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final bookIdInt = int.tryParse(bookId);
      if (userId == null || bookIdInt == null) return null;

      final row = await _supabase
          .from('user_books')
          .select('kindle_percent, books(page_count)')
          .eq('user_id', userId)
          .eq('book_id', bookIdInt)
          .maybeSingle();
      if (row == null) return null;
      return kindlePageFromRow(row);
    } catch (e) {
      debugPrint('Erreur getKindleCurrentPage: $e');
      return null;
    }
  }

  /// Conversion pure `% Kindle → page` à partir d'une ligne user_books
  /// jointe à `books(page_count)`. `null` si l'un des deux manque.
  static int? kindlePageFromRow(Map<String, dynamic> row) {
    final percent = (row['kindle_percent'] as num?)?.toInt();
    final book = row['books'];
    final pageCount = book is Map ? (book['page_count'] as num?)?.toInt() : null;
    if (percent == null || percent <= 0) return null;
    if (pageCount == null || pageCount <= 0) return null;
    return (percent / 100 * pageCount).round().clamp(1, pageCount).toInt();
  }

  /// Importer les livres depuis l'extraction Kindle dans la bibliothèque
  /// Enrichit chaque livre avec les métadonnées de Google Books (couverture, description)
  /// Si [isFirstSync] est true, tous les livres sauf les 2 premiers (plus récents)
  /// sont marqués comme terminés avec kindle_auto_finished = true
  /// Renvoie le sous-ensemble des [titles] qui existent déjà comme livres Kindle
  /// dans la bibliothèque (`user_books`) de l'utilisateur courant. Utilisé par
  /// le flow de sync pour calculer la liste des "nouveaux" livres à proposer
  /// dans la page de validation manuelle.
  Future<Set<String>> findExistingKindleTitlesForCurrentUser(
    List<String> titles,
  ) async {
    if (titles.isEmpty) return <String>{};
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return <String>{};

    final books = await _supabase
        .from('books')
        .select('id, title')
        .eq('source', 'kindle')
        .inFilter('title', titles);

    final list = books as List;
    if (list.isEmpty) return <String>{};

    final titleByBookId = <int, String>{
      for (final b in list) b['id'] as int: b['title'] as String,
    };

    final userBooks = await _supabase
        .from('user_books')
        .select('book_id')
        .eq('user_id', userId)
        .inFilter('book_id', titleByBookId.keys.toList());

    return (userBooks as List)
        .map((ub) => titleByBookId[ub['book_id'] as int])
        .whereType<String>()
        .toSet();
  }

  /// Nombre de sessions Kindle créées par le dernier [importKindleBooks] de
  /// cette instance (delta de progression → session). Lu par le widget de
  /// sync pour rafraîchir le feed et prévenir l'utilisateur.
  int kindleSessionsCreated = 0;

  Future<int> importKindleBooks(
    List<KindleBookProgress> kindleBooks, {
    bool isFirstSync = false,
    KindleInsightsCalendar? calendar,
  }) async {
    int imported = 0;
    kindleSessionsCreated = 0;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    // Du moins récent au plus récent (l'API Amazon trie par récence) : le
    // livre le plus récent reçoit ainsi le `kindle_progress_at` le plus
    // tardif, et gagne le rôle de « livre en cours » dès la baseline.
    for (final kindleBook in kindleBooks.reversed) {
      try {
        // Vérifier si le livre existe déjà (par titre + source kindle).
        // `.limit(1)` plutôt que `.maybeSingle()` : deux éditions peuvent
        // partager le même titre, et maybeSingle() jette (PGRST116) dès qu'il y
        // a 2 lignes — le livre était alors purement et simplement sauté.
        final existingRows = await _supabase
            .from('books')
            .select('id, cover_url, author')
            .eq('title', kindleBook.title)
            .eq('source', 'kindle')
            .order('id', ascending: true)
            .limit(1);
        final Map<String, dynamic>? existing =
            existingRows.isNotEmpty ? existingRows[0] : null;

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
              bookId = await insertBookIfNotExists(
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
            bookId = await insertBookIfNotExists(
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
        }

        // Ajouter ou mettre à jour user_books EN PREMIER
        // (nécessaire avant update_book_metadata qui vérifie l'appartenance)
        final existingUserBook = await _supabase
            .from('user_books')
            .select('status, kindle_percent, kindle_asin, kindle_progress_at')
            .eq('user_id', userId)
            .eq('book_id', bookId)
            .maybeSingle();

        final percent = kindleBook.percentComplete;
        final previousPercent =
            (existingUserBook?['kindle_percent'] as num?)?.toInt();
        final progressed =
            percent != null && percent > 0 && percent != previousPercent;

        if (!isFirstSync) {
          // Sync normal : basé sur la progression Kindle.
          if (percent == 100) {
            newStatus = 'finished';
          } else if (percent != null && percent > 0) {
            // « reading » seulement pour un livre NOUVEAU dans la bibliothèque
            // ou dont la progression a bougé depuis le dernier sync : c'est le
            // signe d'une lecture réelle. Sans cette garde, le premier sync
            // JSON (qui rapporte un pourcentage pour TOUS les livres) aurait
            // basculé en « reading » chaque livre entamé un jour puis laissé
            // en « à lire » ou abandonné par l'utilisateur.
            if (existingUserBook == null || progressed) newStatus = 'reading';
          }
        }

        // Colonnes de progression, écrites dès qu'on tient un pourcentage.
        // `kindle_progress_at` ne bouge que si le pourcentage a changé : il
        // sert à dater la dernière lecture Kindle, pas le dernier sync.
        final progressFields = <String, dynamic>{
          if (kindleBook.asin != null &&
              kindleBook.asin != existingUserBook?['kindle_asin'])
            'kindle_asin': kindleBook.asin,
          if (percent != null && percent != previousPercent) ...{
            'kindle_percent': percent,
            'kindle_progress_at': DateTime.now().toUtc().toIso8601String(),
          },
        };

        if (existingUserBook == null) {
          await _supabase.from('user_books').insert({
            'user_id': userId,
            'book_id': bookId,
            'status': newStatus ?? 'to_read',
            if (autoFinished) 'kindle_auto_finished': true,
            ...progressFields,
          });
          imported++;
        } else {
          final currentStatus = existingUserBook['status'] as String?;
          // Ne pas rétrograder un livre "finished" vers "reading"
          final statusChange = newStatus != null &&
                  newStatus != currentStatus &&
                  (currentStatus != 'finished' || newStatus == 'finished')
              ? newStatus
              : null;
          final update = <String, dynamic>{
            if (statusChange != null) 'status': statusChange,
            if (statusChange != null && autoFinished) 'kindle_auto_finished': true,
            ...progressFields,
          };
          if (update.isNotEmpty) {
            await _supabase
                .from('user_books')
                .update(update)
                .eq('user_id', userId)
                .eq('book_id', bookId);
          }

          // Progression Kindle en hausse depuis le sync précédent → session.
          // APRÈS la mise à jour de kindle_percent : si la session échoue on
          // perd un delta (la page courante reste juste), alors que l'inverse
          // créerait un doublon au sync suivant. Premier pourcentage connu
          // (previousPercent null) = baseline, pas de session.
          if (previousPercent != null &&
              percent != null &&
              percent > previousPercent) {
            try {
              final previousAt = DateTime.tryParse(
                  existingUserBook['kindle_progress_at'] as String? ?? '');
              if (await _createKindleSession(
                bookId: bookId,
                fromPercent: previousPercent,
                toPercent: percent,
                title: kindleBook.title,
                endTime: _kindleSessionEndTime(calendar, previousAt),
              )) {
                kindleSessionsCreated++;
              }
            } catch (e) {
              debugPrint(
                  'importKindleBooks: session Kindle "${kindleBook.title}" KO: $e');
            }
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

  /// Échappe les métacaractères LIKE d'un titre avant de l'injecter dans un
  /// `ilike '%…%'`. Sans ça, un titre contenant `%` ou `_` (ex. « 100_% pur »)
  /// se transforme en joker et matche n'importe quel livre.
  String _escapeLikePattern(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// Marquer les livres comme terminés à partir des titres trouvés sur Reading Insights
  /// Ces livres apparaissent dans la section "titles read" d'Amazon
  /// Utilise une recherche floue car les titres peuvent différer entre les sources
  /// (ex: "Ma vie sans gravité" vs "Ma vie sans gravité (French Edition)")
  ///
  /// Le statut posé ici est `kindle_auto_finished` : il vient d'un scraping,
  /// pas d'une session de lecture réelle. Les migrations badges/stats excluent
  /// explicitement ces lignes (voir 20260313_fix_kindle_books_excluded_from_badges),
  /// et ne pas poser le flag faussait le compteur de livres terminés ainsi que
  /// l'attribution des badges.
  Future<int> markBooksAsFinished(List<KindleBookProgress> finishedBooks) async {
    int updated = 0;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    for (final kindleBook in finishedBooks) {
      try {
        // Nettoyer le titre pour la recherche (enlever les suffixes d'édition)
        final cleanTitle = _cleanBookTitle(kindleBook.title);

        // Chercher le livre par titre exact d'abord.
        // `.limit(1)` + `.order` plutôt que `.maybeSingle()` : plusieurs
        // éditions peuvent partager le même titre, et maybeSingle() jette
        // (PGRST116) dès qu'il y a 2 lignes — l'exception faisait alors sauter
        // le livre entier.
        // NB : `ascending` vaut false par DÉFAUT dans postgrest-dart (contrairement
        // à supabase-js). On l'explicite pour prendre la plus ancienne édition.
        final exact = await _supabase
            .from('books')
            .select('id')
            .eq('title', kindleBook.title)
            .eq('source', 'kindle')
            .order('id', ascending: true)
            .limit(1);

        Map<String, dynamic>? book = exact.isNotEmpty ? exact[0] : null;

        // Si pas trouvé, chercher par correspondance partielle
        // (le titre stocké contient le titre de Reading Insights)
        if (book == null && cleanTitle.length > 5) {
          final results = await _supabase
              .from('books')
              .select('id, title')
              .eq('source', 'kindle')
              .ilike('title', '%${_escapeLikePattern(cleanTitle)}%')
              .order('id', ascending: true)
              .limit(1);

          if (results.isNotEmpty) {
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
          // Le flag exclut la ligne des badges et du compteur de livres
          // terminés. Ne le poser que si le livre n'a AUCUNE session de lecture
          // LexDay : sinon on ferait disparaître des stats un livre réellement
          // lu dans l'app, simplement parce qu'Amazon le liste aussi.
          //
          // try/catch local : si ce check échoue, on doit quand même mettre le
          // statut à jour (c'est le comportement d'avant). Repli conservateur
          // `readInApp = true` → pas de flag → le livre reste compté.
          // `reading_sessions.book_id` est de type TEXT, d'où le toString().
          bool readInApp = true;
          try {
            final sessions = await _supabase
                .from('reading_sessions')
                .select('id')
                .eq('user_id', userId)
                .eq('book_id', bookId.toString())
                .limit(1);
            readInApp = (sessions as List).isNotEmpty;
          } catch (e) {
            debugPrint(
                'markBooksAsFinished: check sessions échoué pour $bookId: $e');
          }

          await _supabase
              .from('user_books')
              .update({
                'status': 'finished',
                // Écrit inconditionnellement : un livre flaggé lors d'un sync
                // précédent puis réellement lu dans l'app doit récupérer sa
                // place dans les stats.
                'kindle_auto_finished': !readInApp,
              })
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

  /// Index de la bibliothèque de l'utilisateur pour résoudre les livres
  /// Kindle (surlignages) : par ASIN d'abord, par titre ensuite.
  ///
  /// Remplace l'ancienne résolution par requêtes `books.title` globales
  /// filtrées sur `source = 'kindle'`, qui échouait dès que le livre avait
  /// été dédoublonné à l'import sur un `google_id` existant (ligne `books`
  /// en source 'google'), et qui n'était pas scopée à l'utilisateur (une
  /// correspondance partielle pouvait tomber sur le livre de quelqu'un
  /// d'autre). Construit une fois par import : ~100 lignes.
  Future<_UserLibraryIndex> _loadUserLibraryIndex(String userId) async {
    final rows = await _supabase
        .from('user_books')
        .select('book_id, kindle_asin, books(id, title)')
        .eq('user_id', userId);

    final byAsin = <String, int>{};
    final byTitle = <String, int>{};
    final entries = <MapEntry<String, int>>[];
    for (final row in rows as List) {
      final book = row['books'];
      if (book is! Map) continue;
      final id = (book['id'] as num?)?.toInt();
      final title = book['title'] as String?;
      if (id == null || title == null) continue;
      final asin = row['kindle_asin'] as String?;
      if (asin != null && asin.isNotEmpty) byAsin[asin] = id;
      final key = _titleKey(title);
      if (key.isNotEmpty) {
        byTitle.putIfAbsent(key, () => id);
        entries.add(MapEntry(key, id));
      }
    }
    return _UserLibraryIndex(byAsin: byAsin, byTitle: byTitle, entries: entries);
  }

  /// Clé de comparaison de titres : édition retirée, minuscules, ponctuation
  /// et espaces normalisés. Le notebook et la bibliothèque n'affichent pas
  /// toujours le même libellé pour un même livre.
  String _titleKey(String title) => _cleanBookTitle(title)
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();

  /// Résout un livre du notebook. Ordre : ASIN (exact, posé par
  /// [importKindleBooks] via l'API JSON) → titre normalisé exact → l'un des
  /// deux titres contient l'autre (sous-titre présent d'un seul côté).
  /// Renvoie null si le livre n'est pas dans la bibliothèque de l'utilisateur.
  int? _resolveKindleBookId(
    _UserLibraryIndex index, {
    required String asin,
    required String kindleTitle,
  }) {
    final byAsin = index.byAsin[asin];
    if (byAsin != null) return byAsin;

    final key = _titleKey(kindleTitle);
    if (key.isEmpty) return null;
    final exact = index.byTitle[key];
    if (exact != null) return exact;

    if (key.length <= 5) return null;
    for (final e in index.entries) {
      if (e.key.length <= 5) continue;
      if (e.key.contains(key) || key.contains(e.key)) return e.value;
    }
    return null;
  }

  /// Importe les surlignages Kindle extraits de read.amazon.com/notebook en
  /// annotations de type 'kindle' (le mur « Mes passages »).
  ///
  /// Idempotent : upsert `ignoreDuplicates` sur (user_id, source_key) — le
  /// re-crawl quotidien réinsère les mêmes clés, seules les nouvelles lignes
  /// passent. Le `.select('id')` derrière un `ON CONFLICT DO NOTHING` ne
  /// renvoie QUE les lignes réellement insérées : c'est le compteur exact de
  /// nouveaux passages.
  ///
  /// Les surlignages dont le livre n'est pas résolvable (livre rendu/archivé,
  /// absent de la bibliothèque LexDay) sont sautés — l'import des livres
  /// ([importKindleBooks]) tourne juste avant dans le pipeline, le cas est
  /// donc marginal.
  Future<int> importKindleHighlights(List<KindleHighlight> highlights) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || highlights.isEmpty) return 0;

    // Résoudre chaque livre UNE seule fois : un gros lecteur peut ramener des
    // centaines de surlignages répartis sur quelques dizaines de livres.
    final byAsin = <String, List<KindleHighlight>>{};
    for (final h in highlights) {
      byAsin.putIfAbsent(h.asin, () => []).add(h);
    }

    final _UserLibraryIndex index;
    try {
      index = await _loadUserLibraryIndex(userId);
    } catch (e) {
      debugPrint('importKindleHighlights: index bibliothèque KO: $e');
      return 0;
    }

    int inserted = 0;
    int skippedBooks = 0;
    final skippedTitles = <String>[];
    for (final entry in byAsin.entries) {
      final group = entry.value;
      try {
        final asin = entry.key;
        final bookId = _resolveKindleBookId(
          index,
          asin: asin,
          kindleTitle: group.first.bookTitle,
        );
        if (bookId == null) {
          skippedBooks++;
          skippedTitles.add('${group.first.bookTitle} [$asin]');
          continue;
        }

        // Résolu par titre → mémoriser l'ASIN pour que le prochain sync
        // tombe directement dessus (et pour tout futur usage de l'ASIN).
        if (!index.byAsin.containsKey(asin)) {
          index.byAsin[asin] = bookId;
          try {
            await _supabase
                .from('user_books')
                .update({'kindle_asin': asin})
                .eq('user_id', userId)
                .eq('book_id', bookId)
                .isFilter('kindle_asin', null);
          } catch (e) {
            debugPrint('importKindleHighlights: backfill ASIN $asin KO: $e');
          }
        }

        final rows = group
            .map((h) => <String, dynamic>{
                  'user_id': userId,
                  'book_id': bookId.toString(),
                  'content': h.text,
                  'type': 'kindle',
                  'source_key': h.sourceKey,
                  if (h.page != null) 'page_number': h.page,
                  if (h.note != null && h.note!.isNotEmpty) 'note': h.note,
                })
            .toList();

        final res = await _supabase
            .from('annotations')
            .upsert(rows,
                onConflict: 'user_id,source_key', ignoreDuplicates: true)
            .select('id');
        inserted += (res as List).length;
      } catch (e) {
        debugPrint(
            'importKindleHighlights: échec "${group.first.bookTitle}": $e');
      }
    }
    if (skippedBooks > 0) {
      debugPrint(
          'importKindleHighlights: $skippedBooks livre(s) non résolus, sautés : '
          '${skippedTitles.join(' | ')}');
    }
    // Réveiller le mur Mes passages s'il est déjà construit : l'import arrive
    // en arrière-plan, potentiellement pendant que l'utilisateur regarde
    // l'onglet.
    if (inserted > 0) AnnotationService.notifyChanged();
    return inserted;
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

  /// One-time migration: try Amazon covers (via ISBN-10) for the user's books
  /// that currently lack a cover or rely on Open Library's low-quality one.
  /// Version-gated via SharedPreferences so it runs at most once per user.
  ///
  /// Amazon is quota-free (no API key), but each lookup costs 1 HEAD (+ maybe
  /// 1 GET) so we cap the batch size to keep startup snappy.
  static const int _amazonEnrichVersion = 1;
  static const String _amazonEnrichKey = 'books_amazon_enrich_version';
  static const int _amazonEnrichMaxBooks = 60;

  Future<int> enrichCoversWithAmazon({
    int maxBooks = _amazonEnrichMaxBooks,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final prefs = await SharedPreferences.getInstance();
    final doneVersion = prefs.getInt(_amazonEnrichKey) ?? 0;
    if (doneVersion >= _amazonEnrichVersion) return 0;

    try {
      final response = await _supabase
          .from('user_books')
          .select('book_id, books(id, cover_url, isbn)')
          .eq('user_id', userId);

      // Candidates = missing or Open Library cover, AND a valid-looking ISBN.
      final isbnRegex = RegExp(r'^\d{9}[\dXx]$|^\d{13}$');
      final candidates = (response as List).where((item) {
        final book = item['books'] as Map<String, dynamic>?;
        if (book == null) return false;
        final coverUrl = book['cover_url'] as String?;
        final isbn = book['isbn'] as String?;
        if (isbn == null || isbn.isEmpty) return false;
        final cleanIsbn = isbn.replaceAll(RegExp(r'[\s-]'), '');
        if (!isbnRegex.hasMatch(cleanIsbn)) return false;
        return coverUrl == null ||
            coverUrl.isEmpty ||
            coverUrl.contains('covers.openlibrary.org');
      }).toList();

      if (candidates.isEmpty) {
        await prefs.setInt(_amazonEnrichKey, _amazonEnrichVersion);
        return 0;
      }

      int updated = 0;
      final capped = candidates.take(maxBooks).toList();
      for (final item in capped) {
        final book = item['books'] as Map<String, dynamic>;
        final bookId = book['id'] as int;
        final rawIsbn = book['isbn'] as String;
        final cleanIsbn = rawIsbn.replaceAll(RegExp(r'[\s-]'), '');

        try {
          final amazonUrl = await CachedBookCover.fetchAmazonCover(cleanIsbn);
          if (amazonUrl == null) continue;

          await _supabase
              .from('books')
              .update({'cover_url': amazonUrl})
              .eq('id', bookId);
          updated++;
        } catch (e) {
          debugPrint('Amazon enrichment failed for book $bookId: $e');
        }
      }

      // Mark done only if we processed every candidate.
      if (capped.length >= candidates.length) {
        await prefs.setInt(_amazonEnrichKey, _amazonEnrichVersion);
      }
      return updated;
    } catch (e) {
      debugPrint('Erreur enrichCoversWithAmazon: $e');
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

/// Index en mémoire de la bibliothèque de l'utilisateur, pour la résolution
/// des livres Kindle (voir `BooksService._loadUserLibraryIndex`).
class _UserLibraryIndex {
  final Map<String, int> byAsin;
  final Map<String, int> byTitle;
  final List<MapEntry<String, int>> entries;
  _UserLibraryIndex({
    required this.byAsin,
    required this.byTitle,
    required this.entries,
  });
}
