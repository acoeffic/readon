// lib/models/book_suggestion.dart

import 'book.dart';

/// Type de suggestion
enum SuggestionType {
  friendsReading, // Livres que tes amis lisent
  sameAuthor, // Même auteur que tes livres
  similarGenre, // Genre similaire
  googleBooks, // Suggestion Google Books API
  trending, // Tendances générales
}

class BookSuggestion {
  final Book book;
  final SuggestionType type;
  final String reason; // Explication de la suggestion
  final double? score; // Score de pertinence (0-1)
  final Map<String, dynamic>? metadata; // Données supplémentaires (ex: amis qui lisent)

  BookSuggestion({
    required this.book,
    required this.type,
    required this.reason,
    this.score,
    this.metadata,
  });

  /// Obtenir une icône basée sur le type
  String get iconEmoji {
    switch (type) {
      case SuggestionType.friendsReading:
        return '👥';
      case SuggestionType.sameAuthor:
        return '✍️';
      case SuggestionType.similarGenre:
        return '📚';
      case SuggestionType.googleBooks:
        return '🔍';
      case SuggestionType.trending:
        return '🔥';
    }
  }

  /// Obtenir un titre court pour le type
  String get typeLabel {
    switch (type) {
      case SuggestionType.friendsReading:
        return 'Populaire chez tes amis';
      case SuggestionType.sameAuthor:
        return 'Du même auteur';
      case SuggestionType.similarGenre:
        return 'Genre similaire';
      case SuggestionType.googleBooks:
        return 'Recommandé';
      case SuggestionType.trending:
        return 'Tendance';
    }
  }

  factory BookSuggestion.fromJson(Map<String, dynamic> json) {
    return BookSuggestion(
      book: Book.fromJson(json['book']),
      type: SuggestionType.values.firstWhere(
        (t) => t.toString() == 'SuggestionType.${json['type']}',
        orElse: () => SuggestionType.googleBooks,
      ),
      reason: json['reason'] as String,
      score: json['score'] as double?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book': book.toJson(),
      'type': type.toString().split('.').last,
      'reason': reason,
      'score': score,
      'metadata': metadata,
    };
  }
}
