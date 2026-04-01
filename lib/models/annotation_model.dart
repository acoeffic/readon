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
  final String? audioPath;
  final String? aiSummary;
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
    this.audioPath,
    this.aiSummary,
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
      audioPath: json['audio_path'] as String?,
      aiSummary: json['ai_summary'] as String?,
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
      'audio_path': audioPath,
      'ai_summary': aiSummary,
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
    String? audioPath,
    String? aiSummary,
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
      audioPath: audioPath ?? this.audioPath,
      aiSummary: aiSummary ?? this.aiSummary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
