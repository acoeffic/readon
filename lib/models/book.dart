// lib/models/book.dart
// Modèle unifié pour TOUS les livres (Kindle + personnels)
import '../services/google_books_service.dart';

class Book {
  final int id; // bigint dans Supabase
  final String? googleId;
  final String title;
  final String? author;
  final String? description;
  final String? coverUrl;
  final int? pageCount;
  final String? publishedDate;
  final String? isbn;
  final String? externalId; // ASIN Kindle ou autre ID externe
  final String source; // 'kindle', 'google_books', 'manual', 'scan'
  final String? publisher;
  final String language;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Book({
    required this.id,
    this.googleId,
    required this.title,
    this.author,
    this.description,
    this.coverUrl,
    this.pageCount,
    this.publishedDate,
    this.isbn,
    this.externalId,
    this.source = 'manual',
    this.publisher,
    this.language = 'fr',
    this.createdAt,
    this.updatedAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as int,
      googleId: json['google_id'] as String?,
      title: json['title'] as String,
      author: json['author'] as String?,
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      pageCount: json['page_count'] as int?,
      publishedDate: json['published_date'] as String?,
      isbn: json['isbn'] as String?,
      externalId: json['external_id'] as String?,
      source: json['source'] as String? ?? 'manual',
      publisher: json['publisher'] as String?,
      language: json['language'] as String? ?? 'fr',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'google_id': googleId,
      'title': title,
      'author': author,
      'description': description,
      'cover_url': coverUrl,
      'page_count': pageCount,
      'published_date': publishedDate,
      'isbn': isbn,
      'external_id': externalId,
      'source': source,
      'publisher': publisher,
      'language': language,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Créer un Book depuis GoogleBook (pour les livres scannés)
  factory Book.fromGoogleBook(GoogleBook googleBook) {
    return Book(
      id: 0, // Sera assigné par Supabase
      googleId: googleBook.id,
      title: googleBook.title,
      author: googleBook.authorsString,
      description: googleBook.description,
      coverUrl: googleBook.coverUrl,
      pageCount: googleBook.pageCount,
      publishedDate: googleBook.publishedDate,
      isbn: googleBook.isbn13,
      source: 'google_books',
      publisher: googleBook.publisher,
      language: googleBook.language ?? 'fr',
    );
  }

  /// Map pour INSERT dans Supabase (sans id, created_at, updated_at)
  Map<String, dynamic> toInsert() {
    return {
      'google_id': googleId,
      'title': title,
      'author': author,
      'description': description,
      'cover_url': coverUrl,
      'page_count': pageCount,
      'published_date': publishedDate,
      'isbn': isbn,
      'external_id': externalId,
      'source': source,
      'publisher': publisher,
      'language': language,
    };
  }

  bool get isKindle => source == 'kindle';
  bool get isPersonal => source != 'kindle';
  bool get isFromGoogleBooks => source == 'google_books';
}
