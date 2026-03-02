// lib/models/annotation_model.dart

enum AnnotationType {
  text,
  photo,
  voice;

  static AnnotationType fromString(String value) {
    return AnnotationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AnnotationType.text,
    );
  }
}

class Annotation {
  final String id;
  final String userId;
  final String bookId;
  final String? sessionId;
  final String content;
  final int? pageNumber;
  final AnnotationType type;
  final String? imagePath;
  final String? aiSummary;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  Annotation({
    required this.id,
    required this.userId,
    required this.bookId,
    this.sessionId,
    required this.content,
    this.pageNumber,
    this.type = AnnotationType.text,
    this.imagePath,
    this.aiSummary,
    this.isPublic = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      sessionId: json['session_id'] as String?,
      content: json['content'] as String,
      pageNumber: json['page_number'] as int?,
      type: AnnotationType.fromString(json['type'] as String? ?? 'text'),
      imagePath: json['image_path'] as String?,
      aiSummary: json['ai_summary'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'session_id': sessionId,
      'content': content,
      'page_number': pageNumber,
      'type': type.name,
      'image_path': imagePath,
      'ai_summary': aiSummary,
      'is_public': isPublic,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Annotation copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? sessionId,
    String? content,
    int? pageNumber,
    AnnotationType? type,
    String? imagePath,
    String? aiSummary,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      sessionId: sessionId ?? this.sessionId,
      content: content ?? this.content,
      pageNumber: pageNumber ?? this.pageNumber,
      type: type ?? this.type,
      imagePath: imagePath ?? this.imagePath,
      aiSummary: aiSummary ?? this.aiSummary,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
