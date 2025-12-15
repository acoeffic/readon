import 'dart:convert';
import 'package:http/http.dart' as http;

class KindleApiService {
  static const String baseUrl = 'https://kindle-backend-clean-production.up.railway.app/api';
  
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur health check: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>> syncKindle(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur sync: ${response.body}');
      }
    } catch (e) {
      print('Erreur syncKindle: $e');
      rethrow;
    }
  }
  
  Future<List<Book>> getBooks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/books'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> booksJson = data['books'];
        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        throw Exception('Erreur getBooks: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getBooks: $e');
      return [];
    }
  }
  
  Future<ReadingStats?> getStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stats'));
      
      if (response.statusCode == 200) {
        return ReadingStats.fromJson(jsonDecode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      print('Erreur getStats: $e');
      return null;
    }
  }
}

class Book {
  final String id;
  final String title;
  final String author;
  final String cover;
  final List<Highlight> highlights;
  final int highlightCount;
  final String scrapedAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.cover,
    required this.highlights,
    required this.highlightCount,
    required this.scrapedAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown',
      author: json['author'] ?? 'Unknown',
      cover: json['cover'] ?? '',
      highlights: (json['highlights'] as List<dynamic>?)
              ?.map((h) => Highlight.fromJson(h))
              .toList() ??
          [],
      highlightCount: json['highlightCount'] ?? 0,
      scrapedAt: json['scrapedAt'] ?? '',
    );
  }
}

class Highlight {
  final String text;
  final String location;
  final String? note;

  Highlight({
    required this.text,
    required this.location,
    this.note,
  });

  factory Highlight.fromJson(Map<String, dynamic> json) {
    return Highlight(
      text: json['text'] ?? '',
      location: json['location'] ?? '',
      note: json['note'],
    );
  }
}

class ReadingStats {
  final int totalBooks;
  final int totalHighlights;
  final String averageHighlightsPerBook;
  final Book? mostHighlightedBook;

  ReadingStats({
    required this.totalBooks,
    required this.totalHighlights,
    required this.averageHighlightsPerBook,
    this.mostHighlightedBook,
  });

  factory ReadingStats.fromJson(Map<String, dynamic> json) {
    return ReadingStats(
      totalBooks: json['totalBooks'] ?? 0,
      totalHighlights: json['totalHighlights'] ?? 0,
      averageHighlightsPerBook: json['averageHighlightsPerBook'] ?? '0',
      mostHighlightedBook: json['mostHighlightedBook'] != null
          ? Book.fromJson(json['mostHighlightedBook'])
          : null,
    );
  }
}