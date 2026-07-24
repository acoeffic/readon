// lib/models/book_rating.dart
//
// Note et avis d'un utilisateur sur un livre (table Supabase book_ratings).
// Une ligne par lecture (user_book). Voir NOTATION_LIVRES_SPEC.md.

class BookRating {
  final int id;
  final String userId;
  final int bookId;
  final int userBookId;

  /// Note de 0.5 à 5.0, par pas de 0.5.
  final double rating;

  /// Critères optionnels : {"writing": 1-3, "story": 1-3, "pace": 1-3, "difficulty": 1-3}
  final Map<String, dynamic>? criteria;
  final List<String> emotionTags;
  final String? reviewText;
  final bool? wouldRecommend;
  final bool? wouldReread;
  final bool isPublic;
  final bool abandoned;
  final int? abandonedAtPercent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BookRating({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.userBookId,
    required this.rating,
    this.criteria,
    this.emotionTags = const [],
    this.reviewText,
    this.wouldRecommend,
    this.wouldReread,
    this.isPublic = false,
    this.abandoned = false,
    this.abandonedAtPercent,
    this.createdAt,
    this.updatedAt,
  });

  factory BookRating.fromJson(Map<String, dynamic> json) {
    return BookRating(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as int,
      userBookId: json['user_book_id'] as int,
      rating: (json['rating'] as num).toDouble(),
      criteria: json['criteria'] as Map<String, dynamic>?,
      emotionTags: (json['emotion_tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      reviewText: json['review_text'] as String?,
      wouldRecommend: json['would_recommend'] as bool?,
      wouldReread: json['would_reread'] as bool?,
      isPublic: json['is_public'] as bool? ?? false,
      abandoned: json['abandoned'] as bool? ?? false,
      abandonedAtPercent: json['abandoned_at_percent'] as int?,
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
      'user_id': userId,
      'book_id': bookId,
      'user_book_id': userBookId,
      'rating': rating,
      'criteria': criteria,
      'emotion_tags': emotionTags,
      'review_text': reviewText,
      'would_recommend': wouldRecommend,
      'would_reread': wouldReread,
      'is_public': isPublic,
      'abandoned': abandoned,
      'abandoned_at_percent': abandonedAtPercent,
    };
  }
}
