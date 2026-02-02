// lib/services/google_books_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GoogleBooksService {
  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';
  static const String _apiKey = 'AIzaSyBfeOIQFzc9nGtinVmBGQoAB0fpyOCsBgg';

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

  /// Rechercher par ISBN (1 appel, pas de restriction de langue)
  Future<GoogleBook?> searchByISBN(String isbn) async {
    try {
      final uri = Uri.parse('$_baseUrl?q=isbn:${Uri.encodeComponent(isbn)}&maxResults=1&key=$_apiKey');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>?;
        if (items == null || items.isEmpty) return null;
        return GoogleBook.fromJson(items.first);
      }
      return null;
    } catch (e) {
      debugPrint('Erreur searchByISBN: $e');
      return null;
    }
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
      coverUrl = imageLinks['large'] ?? 
                 imageLinks['medium'] ?? 
                 imageLinks['thumbnail'];
      
      // Replace http with https for security
      if (coverUrl != null && coverUrl.startsWith('http:')) {
        coverUrl = coverUrl.replaceFirst('http:', 'https:');
      }
    }
    
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
    return isbns.firstWhere(
      (isbn) => isbn.length == 13,
      orElse: () => isbns.isNotEmpty ? isbns.first : '',
    );
  }
}

/// Mappe une catégorie brute Google Books vers un genre lisible en français.
/// Les catégories Google Books sont en anglais, souvent sous forme
/// "Category / Subcategory / Detail" (ex: "Fiction / Science Fiction / General").
/// L'ordre des vérifications est important : les plus spécifiques d'abord.
String? mapGoogleBooksCategory(String raw) {
  final lower = raw.toLowerCase();

  // --- Science-Fiction & Fantasy ---
  if (lower.contains('science fiction')) return 'Science-Fiction';
  if (lower.contains('fantasy')) return 'Fantasy';
  if (lower.contains('dystopi')) return 'Science-Fiction'; // dystopia, dystopian

  // --- Policier / Thriller / Suspense ---
  if (lower.contains('thriller')) return 'Thriller';
  if (lower.contains('suspense')) return 'Thriller';
  if (lower.contains('mystery')) return 'Policier';
  if (lower.contains('detective')) return 'Policier';
  if (lower.contains('crime')) return 'Policier';
  if (lower.contains('true crime')) return 'Policier';

  // --- Horreur ---
  if (lower.contains('horror')) return 'Horreur';
  if (lower.contains('ghost')) return 'Horreur';
  if (lower.contains('occult')) return 'Horreur';

  // --- Romance ---
  if (lower.contains('romance')) return 'Romance';
  if (lower.contains('erotica')) return 'Romance';
  if (lower.contains('love')) return 'Romance';

  // --- Biographie & Autobiographie ---
  if (lower.contains('biography')) return 'Biographie';
  if (lower.contains('autobiography')) return 'Biographie';
  if (lower.contains('memoir')) return 'Biographie';

  // --- Histoire ---
  if (lower.contains('history')) return 'Histoire';
  if (lower.contains('historical')) return 'Historique';

  // --- Philosophie ---
  if (lower.contains('philosophy')) return 'Philosophie';

  // --- Psychologie / Développement personnel ---
  if (lower.contains('self-help')) return 'Développement personnel';
  if (lower.contains('self help')) return 'Développement personnel';
  if (lower.contains('personal growth')) return 'Développement personnel';
  if (lower.contains('motivation')) return 'Développement personnel';
  if (lower.contains('psychology')) return 'Psychologie';

  // --- Sciences ---
  if (lower.contains('mathematics')) return 'Sciences';
  if (lower.contains('physics')) return 'Sciences';
  if (lower.contains('chemistry')) return 'Sciences';
  if (lower.contains('biology')) return 'Sciences';
  if (lower.contains('evolution')) return 'Sciences';
  if (lower.contains('science') && !lower.contains('fiction') && !lower.contains('political')) {
    return 'Sciences';
  }

  // --- Informatique / Technologie ---
  if (lower.contains('computer')) return 'Informatique';
  if (lower.contains('programming')) return 'Informatique';
  if (lower.contains('software')) return 'Informatique';
  if (lower.contains('technology')) return 'Technologie';

  // --- Business / Économie ---
  if (lower.contains('business')) return 'Business';
  if (lower.contains('economics')) return 'Économie';
  if (lower.contains('finance')) return 'Business';
  if (lower.contains('entrepreneur')) return 'Business';
  if (lower.contains('management')) return 'Business';

  // --- Politique / Société ---
  if (lower.contains('politic')) return 'Politique';
  if (lower.contains('social science')) return 'Société';
  if (lower.contains('sociology')) return 'Société';

  // --- Religion / Spiritualité ---
  if (lower.contains('religion')) return 'Religion';
  if (lower.contains('spiritual')) return 'Spiritualité';
  if (lower.contains('body, mind')) return 'Bien-être';
  if (lower.contains('mind & body')) return 'Bien-être';

  // --- Art / Musique / Cinéma ---
  if (lower.contains('art')) return 'Art';
  if (lower.contains('music')) return 'Musique';
  if (lower.contains('film')) return 'Cinéma';
  if (lower.contains('photography')) return 'Art';
  if (lower.contains('architecture')) return 'Art';

  // --- Cuisine / Lifestyle ---
  if (lower.contains('cooking')) return 'Cuisine';
  if (lower.contains('food')) return 'Cuisine';
  if (lower.contains('health')) return 'Santé';
  if (lower.contains('fitness')) return 'Santé';
  if (lower.contains('travel')) return 'Voyage';
  if (lower.contains('nature')) return 'Nature';
  if (lower.contains('garden')) return 'Nature';

  // --- Sport ---
  if (lower.contains('sport')) return 'Sport';

  // --- Éducation / Référence ---
  if (lower.contains('education')) return 'Éducation';
  if (lower.contains('reference')) return 'Référence';
  if (lower.contains('study')) return 'Éducation';
  if (lower.contains('language')) return 'Langues';

  // --- Jeunesse ---
  if (lower.contains('juvenile')) return 'Jeunesse';
  if (lower.contains('young adult')) return 'Young Adult';
  if (lower.contains('children')) return 'Jeunesse';

  // --- Bande dessinée / Comics ---
  if (lower.contains('comic')) return 'BD / Comics';
  if (lower.contains('graphic novel')) return 'BD / Comics';
  if (lower.contains('manga')) return 'Manga';

  // --- Poésie / Théâtre ---
  if (lower.contains('poetry')) return 'Poésie';
  if (lower.contains('drama')) return 'Théâtre';

  // --- Humour ---
  if (lower.contains('humor')) return 'Humour';
  if (lower.contains('comedy')) return 'Humour';

  // --- Fiction générique (en dernier car très large) ---
  if (lower.contains('literary fiction')) return 'Roman littéraire';
  if (lower.contains('fiction')) return 'Roman';
  if (lower.contains('novel')) return 'Roman';

  // --- Non-fiction générique ---
  if (lower.contains('nonfiction') || lower.contains('non-fiction')) return 'Non-fiction';

  return null;
}