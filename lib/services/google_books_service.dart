// lib/services/google_books_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleBooksService {
  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';
  
  /// Rechercher des livres via Google Books API
  Future<List<GoogleBook>> searchBooks(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl?q=${Uri.encodeComponent(query)}&maxResults=10&langRestrict=fr');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>?;
        
        if (items == null || items.isEmpty) {
          return [];
        }
        
        return items.map((item) => GoogleBook.fromJson(item)).toList();
      } else {
        print('Erreur Google Books API: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Erreur searchBooks: $e');
      return [];
    }
  }
  
  /// Rechercher par ISBN
  Future<GoogleBook?> searchByISBN(String isbn) async {
    try {
      final books = await searchBooks('isbn:$isbn');
      return books.isNotEmpty ? books.first : null;
    } catch (e) {
      print('Erreur searchByISBN: $e');
      return null;
    }
  }
  
  /// Rechercher par titre et auteur
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
    );
  }
  
  String get authorsString => authors.join(', ');
  
  String? get isbn13 {
    return isbns.firstWhere(
      (isbn) => isbn.length == 13,
      orElse: () => isbns.isNotEmpty ? isbns.first : '',
    );
  }
}