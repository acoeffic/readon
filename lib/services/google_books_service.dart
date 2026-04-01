// lib/services/google_books_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';

class GoogleBooksService {
  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';
  static String get _apiKey => Env.googleBooksApiKey;

  /// Clé SharedPreferences pour le cache persistant ISBN → coverUrl
  static const String _coverCacheKey = 'google_books_cover_cache';

  /// Cache en mémoire : ISBN → GoogleBook (évite les appels API répétés)
  static final Map<String, GoogleBook> _isbnCache = {};

  /// Cache persistant : ISBN → coverUrl (survit au redémarrage)
  static Map<String, String>? _persistentCoverCache;

  /// Charge le cache persistant depuis SharedPreferences
  static Future<void> loadPersistentCache() async {
    if (_persistentCoverCache != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_coverCacheKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _persistentCoverCache = decoded.map((k, v) => MapEntry(k, v as String));
      } else {
        _persistentCoverCache = {};
      }
    } catch (e) {
      debugPrint('Erreur chargement cache couvertures: $e');
      _persistentCoverCache = {};
    }
  }

  /// Sauvegarde le cache persistant
  static Future<void> _savePersistentCache() async {
    if (_persistentCoverCache == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_coverCacheKey, jsonEncode(_persistentCoverCache));
    } catch (e) {
      debugPrint('Erreur sauvegarde cache couvertures: $e');
    }
  }

  /// Retourne la coverUrl en cache pour un ISBN (persistant), ou null
  String? getCachedCoverUrl(String isbn) {
    return _persistentCoverCache?[isbn];
  }

  /// Vide le cache (utile pour les tests ou un refresh forcé)
  static void clearCache() {
    _isbnCache.clear();
    _persistentCoverCache?.clear();
    _savePersistentCache();
  }

  /// Rechercher des livres via Google Books API (1 seul appel)
  Future<List<GoogleBook>> searchBooks(String query, {bool langRestrict = false}) async {
    try {
      final langParam = langRestrict ? '&langRestrict=fr' : '';
      final uri = Uri.parse('$_baseUrl?q=${Uri.encodeComponent(query)}&maxResults=10$langParam&key=$_apiKey');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>?;

        if (items == null || items.isEmpty) return [];
        return items.map((item) => GoogleBook.fromJson(item)).toList();
      } else {
        debugPrint('Erreur Google Books API: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Erreur searchBooks: $e');
      return [];
    }
  }

  /// Rechercher par ISBN (1 appel, pas de restriction de langue).
  /// Les résultats sont cachés en mémoire et la coverUrl est persistée sur disque.
  Future<GoogleBook?> searchByISBN(String isbn) async {
    // Vérifier le cache mémoire d'abord
    if (_isbnCache.containsKey(isbn)) {
      return _isbnCache[isbn];
    }

    try {
      final uri = Uri.parse('$_baseUrl?q=isbn:${Uri.encodeComponent(isbn)}&maxResults=1&key=$_apiKey');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>?;
        if (items == null || items.isEmpty) return null;
        final book = GoogleBook.fromJson(items.first);
        _isbnCache[isbn] = book;
        _persistCoverUrl(isbn, book.coverUrl);
        return book;
      }
      return null;
    } catch (e) {
      debugPrint('Erreur searchByISBN: $e');
      return null;
    }
  }

  /// Met en cache un GoogleBook pour un ISBN donné (utile après un fallback).
  void cacheBook(String isbn, GoogleBook book) {
    _isbnCache[isbn] = book;
    _persistCoverUrl(isbn, book.coverUrl);
  }

  /// Persiste la coverUrl sur disque
  void _persistCoverUrl(String isbn, String? coverUrl) {
    if (coverUrl == null || _persistentCoverCache == null) return;
    _persistentCoverCache![isbn] = coverUrl;
    _savePersistentCache();
  }

  /// Rechercher par titre et auteur (1 appel)
  Future<List<GoogleBook>> searchByTitleAuthor(String title, String author) async {
    final query = 'intitle:$title+inauthor:$author';
    return searchBooks(query);
  }
}

class GoogleBook {
  final String id;
  final String title;
  final List<String> authors;
  final String? publisher;
  final String? publishedDate;
  final String? description;
  final int? pageCount;
  final String? coverUrl;
  final List<String> isbns;
  final String? language;
  final List<String> categories;

  GoogleBook({
    required this.id,
    required this.title,
    required this.authors,
    this.publisher,
    this.publishedDate,
    this.description,
    this.pageCount,
    this.coverUrl,
    required this.isbns,
    this.language,
    this.categories = const [],
  });

  factory GoogleBook.fromJson(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>? ?? {};
    
    // Extract ISBNs
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
    final isbns = identifiers?.map((id) => id['identifier'] as String).toList() ?? [];
    
    // Extract cover image
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    String? coverUrl;
    if (imageLinks != null) {
      // Prefer larger images
      coverUrl = imageLinks['extraLarge'] ??
                 imageLinks['large'] ??
                 imageLinks['medium'] ??
                 imageLinks['small'] ??
                 imageLinks['thumbnail'] ??
                 imageLinks['smallThumbnail'];

      // Replace http with https for security
      if (coverUrl != null && coverUrl.startsWith('http:')) {
        coverUrl = coverUrl.replaceFirst('http:', 'https:');
      }
    }

    // NOTE: Open Library fallback removed — CoverUrlService handles fallback
    // chain at display time (Google Books API → Open Library → placeholder).
    
    // Extract categories
    final categories = (volumeInfo['categories'] as List<dynamic>?)
        ?.map((c) => c as String)
        .toList() ?? [];

    return GoogleBook(
      id: json['id'] as String,
      title: volumeInfo['title'] as String? ?? 'Titre inconnu',
      authors: (volumeInfo['authors'] as List<dynamic>?)
          ?.map((a) => a as String)
          .toList() ?? ['Auteur inconnu'],
      publisher: volumeInfo['publisher'] as String?,
      publishedDate: volumeInfo['publishedDate'] as String?,
      description: volumeInfo['description'] as String?,
      pageCount: volumeInfo['pageCount'] as int?,
      coverUrl: coverUrl,
      isbns: isbns,
      language: volumeInfo['language'] as String?,
      categories: categories,
    );
  }
  
  String get authorsString => authors.join(', ');

  /// Retourne le genre mappé depuis les catégories Google Books
  String? get genre {
    if (categories.isEmpty) return null;
    // Joindre toutes les catégories pour chercher les mots-clés
    final raw = categories.join(' / ').toLowerCase();
    return mapGoogleBooksCategory(raw);
  }

  String? get isbn13 {
    if (isbns.isEmpty) return null;
    final match = isbns.cast<String?>().firstWhere(
      (isbn) => isbn != null && isbn.length == 13,
      orElse: () => null,
    );
    return match ?? isbns.first;
  }
}

/// Mappe une catégorie brute Google Books vers un genre lisible en français.
/// Les catégories Google Books sont en anglais ou en français, souvent sous forme
/// "Category / Subcategory / Detail" (ex: "Fiction / Science Fiction / General").
/// L'ordre des vérifications est important : les plus spécifiques d'abord.
String? mapGoogleBooksCategory(String raw) {
  final lower = raw.toLowerCase();

  // --- Science-Fiction & Fantasy ---
  if (lower.contains('science fiction') || lower.contains('science-fiction')) return 'Science-Fiction';
  if (lower.contains('fantasy')) return 'Fantasy';
  if (lower.contains('dystopi')) return 'Science-Fiction'; // dystopia, dystopian

  // --- Policier / Thriller / Suspense ---
  if (lower.contains('thriller')) return 'Thriller';
  if (lower.contains('suspense')) return 'Thriller';
  if (lower.contains('mystery') || lower.contains('mystère')) return 'Policier';
  if (lower.contains('detective') || lower.contains('détective')) return 'Policier';
  if (lower.contains('crime')) return 'Policier';
  if (lower.contains('true crime')) return 'Policier';
  if (lower.contains('polar')) return 'Policier';
  if (lower.contains('policier')) return 'Policier';
  if (lower.contains('enquête')) return 'Policier';

  // --- Horreur ---
  if (lower.contains('horror') || lower.contains('horreur')) return 'Horreur';
  if (lower.contains('ghost') || lower.contains('fantôme')) return 'Horreur';
  if (lower.contains('occult') || lower.contains('occulte')) return 'Horreur';
  if (lower.contains('épouvante')) return 'Horreur';

  // --- Romance ---
  if (lower.contains('romance')) return 'Romance';
  if (lower.contains('erotica') || lower.contains('érotique')) return 'Romance';
  if (lower.contains('love') || lower.contains('amour')) return 'Romance';
  if (lower.contains('sentimental')) return 'Romance';

  // --- Biographie & Autobiographie ---
  if (lower.contains('biograph') || lower.contains('biograph')) return 'Biographie'; // biography, biographical, biographie
  if (lower.contains('autobiograph')) return 'Biographie'; // autobiography, autobiographie
  if (lower.contains('memoir') || lower.contains('mémoire')) return 'Biographie';
  if (lower.contains('témoignage')) return 'Biographie';
  if (lower.contains('récit personnel')) return 'Biographie';
  if (lower.contains('récit de vie')) return 'Biographie';
  if (lower.contains('portrait')) return 'Biographie';

  // --- Histoire ---
  if (lower.contains('history') || lower.contains('histoire')) return 'Histoire';
  if (lower.contains('historical') || lower.contains('historique')) return 'Historique';

  // --- Philosophie ---
  if (lower.contains('philosoph')) return 'Philosophie'; // philosophy, philosophie

  // --- Psychologie / Développement personnel ---
  if (lower.contains('self-help') || lower.contains('self help')) return 'Développement personnel';
  if (lower.contains('développement personnel')) return 'Développement personnel';
  if (lower.contains('personal growth') || lower.contains('croissance personnelle')) return 'Développement personnel';
  if (lower.contains('motivation')) return 'Développement personnel';
  if (lower.contains('coaching')) return 'Développement personnel';
  if (lower.contains('psycholog')) return 'Psychologie'; // psychology, psychologie

  // --- Sciences ---
  if (lower.contains('mathématique') || lower.contains('mathematics')) return 'Sciences';
  if (lower.contains('physics') || lower.contains('physique')) return 'Sciences';
  if (lower.contains('chemistry') || lower.contains('chimie')) return 'Sciences';
  if (lower.contains('biology') || lower.contains('biologie')) return 'Sciences';
  if (lower.contains('evolution') || lower.contains('évolution')) return 'Sciences';
  if (lower.contains('science') && !lower.contains('fiction') && !lower.contains('political') && !lower.contains('politique')) {
    return 'Sciences';
  }

  // --- Informatique / Technologie ---
  if (lower.contains('computer') || lower.contains('informatique') || lower.contains('ordinateur')) return 'Informatique';
  if (lower.contains('programming') || lower.contains('programmation')) return 'Informatique';
  if (lower.contains('software') || lower.contains('logiciel')) return 'Informatique';
  if (lower.contains('technology') || lower.contains('technologie')) return 'Technologie';

  // --- Business / Économie ---
  if (lower.contains('business') || lower.contains('affaires')) return 'Business';
  if (lower.contains('economics') || lower.contains('économie')) return 'Économie';
  if (lower.contains('finance')) return 'Business';
  if (lower.contains('entrepreneur')) return 'Business';
  if (lower.contains('management') || lower.contains('gestion')) return 'Business';

  // --- Politique / Société ---
  if (lower.contains('politic') || lower.contains('politique')) return 'Politique';
  if (lower.contains('social science') || lower.contains('sciences sociales')) return 'Société';
  if (lower.contains('sociolog') || lower.contains('société')) return 'Société'; // sociology, sociologie

  // --- Religion / Spiritualité ---
  if (lower.contains('religion')) return 'Religion';
  if (lower.contains('spiritual') || lower.contains('spiritualité')) return 'Spiritualité';
  if (lower.contains('body, mind') || lower.contains('mind & body') || lower.contains('bien-être')) return 'Bien-être';

  // --- Art / Musique / Cinéma ---
  if (lower.contains('musique') || lower.contains('music')) return 'Musique';
  if (lower.contains('film') || lower.contains('cinéma')) return 'Cinéma';
  if (lower.contains('photography') || lower.contains('photographie')) return 'Art';
  if (lower.contains('architecture')) return 'Art';
  if (lower.contains('art') || lower.contains('beaux-arts')) return 'Art';

  // --- Cuisine / Lifestyle ---
  if (lower.contains('cooking') || lower.contains('cuisine') || lower.contains('gastronomie')) return 'Cuisine';
  if (lower.contains('food') || lower.contains('recette')) return 'Cuisine';
  if (lower.contains('health') || lower.contains('santé')) return 'Santé';
  if (lower.contains('fitness')) return 'Santé';
  if (lower.contains('travel') || lower.contains('voyage')) return 'Voyage';
  if (lower.contains('nature')) return 'Nature';
  if (lower.contains('garden') || lower.contains('jardin')) return 'Nature';

  // --- Sport ---
  if (lower.contains('sport')) return 'Sport';

  // --- Éducation / Référence ---
  if (lower.contains('education') || lower.contains('éducation') || lower.contains('enseignement')) return 'Éducation';
  if (lower.contains('reference') || lower.contains('référence')) return 'Référence';
  if (lower.contains('study') || lower.contains('étude')) return 'Éducation';
  if (lower.contains('language') || lower.contains('langue')) return 'Langues';

  // --- Jeunesse ---
  if (lower.contains('juvenile') || lower.contains('jeunesse')) return 'Jeunesse';
  if (lower.contains('young adult')) return 'Young Adult';
  if (lower.contains('children') || lower.contains('enfant')) return 'Jeunesse';

  // --- Bande dessinée / Comics ---
  if (lower.contains('comic') || lower.contains('bande dessinée') || lower.contains('bd')) return 'BD / Comics';
  if (lower.contains('graphic novel') || lower.contains('roman graphique')) return 'BD / Comics';
  if (lower.contains('manga')) return 'Manga';

  // --- Poésie / Théâtre ---
  if (lower.contains('poetry') || lower.contains('poésie')) return 'Poésie';
  if (lower.contains('drama') || lower.contains('théâtre')) return 'Théâtre';

  // --- Humour ---
  if (lower.contains('humor') || lower.contains('humour')) return 'Humour';
  if (lower.contains('comedy') || lower.contains('comédie')) return 'Humour';

  // --- Essai (FR spécifique, avant fiction générique) ---
  if (lower.contains('essai')) return 'Non-fiction';

  // --- Fiction générique (en dernier car très large) ---
  if (lower.contains('literary fiction') || lower.contains('fiction littéraire')) return 'Roman littéraire';
  if (lower.contains('roman')) return 'Roman';
  if (lower.contains('fiction')) return 'Roman';
  if (lower.contains('novel') || lower.contains('nouvelle')) return 'Roman';
  if (lower.contains('conte')) return 'Roman';
  if (lower.contains('récit')) return 'Roman';

  // --- Non-fiction générique ---
  if (lower.contains('nonfiction') || lower.contains('non-fiction')) return 'Non-fiction';

  return null;
}

/// Tente d'inférer le genre d'un livre à partir de son titre et/ou auteur.
/// Utilisé en fallback quand Google Books ne retourne aucune catégorie.
/// Retourne null si aucun pattern n'est détecté.
String? inferGenreFromTitle(String title, String? author) {
  final lower = title.toLowerCase();

  // --- Biographie / Autobiographie (patterns très courants) ---
  if (lower.contains('biographie') || lower.contains('autobiography')) return 'Biographie';
  if (lower.contains('autobiographie')) return 'Biographie';
  if (RegExp(r'\bmémoires?\b').hasMatch(lower)) return 'Biographie';
  if (lower.contains('vie de ') || lower.contains('la vie de ')) return 'Biographie';
  if (lower.contains('journal de ') || lower.contains("journal d'")) return 'Biographie';
  if (lower.contains('correspondance')) return 'Biographie';
  if (lower.contains('lettres de ') || lower.contains('lettres à ')) return 'Biographie';
  if (lower.contains('portrait de ') || lower.contains("portrait d'")) return 'Biographie';
  if (lower.contains('témoignage')) return 'Biographie';
  if (lower.contains('confessions')) return 'Biographie';
  if (lower.contains('souvenirs')) return 'Biographie';

  // --- Histoire ---
  if (RegExp(r"\bhistoire (de |du |des |d')").hasMatch(lower)) return 'Histoire';

  // --- Philosophie ---
  if (lower.contains('philosophie') || lower.contains('philosopher')) return 'Philosophie';
  if (RegExp(r'\bessai sur\b').hasMatch(lower)) return 'Non-fiction';

  // --- Développement personnel ---
  if (lower.contains('développement personnel')) return 'Développement personnel';
  if (lower.contains('comment réussir') || lower.contains('les clés de')) return 'Développement personnel';
  if (lower.contains('habitudes') && lower.contains('succès')) return 'Développement personnel';

  // --- Cuisine ---
  if (lower.contains('recettes') || lower.contains('cuisine')) return 'Cuisine';
  if (lower.contains('gastronomie')) return 'Cuisine';

  // --- Guide / Manuel ---
  if (RegExp(r"\bguide (de |du |des |d')").hasMatch(lower)) return 'Non-fiction';
  if (RegExp(r"\bmanuel (de |du |des |d')").hasMatch(lower)) return 'Non-fiction';

  // --- Poésie ---
  if (lower.contains('poèmes') || lower.contains('poésie') || lower.contains('poésies')) return 'Poésie';

  // --- Conte ---
  if (RegExp(r'\bcontes?\b').hasMatch(lower)) return 'Roman';

  return null;
}