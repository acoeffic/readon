// lib/models/annotation_model.dart

enum AnnotationType {
  text,
  photo,
  voice,

  /// Surlignage importé depuis le Kindle de l'utilisateur
  /// (scraping de read.amazon.com/notebook par le sync auto).
  kindle;

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

  /// Note personnelle attachée au surlignage (import Kindle uniquement).
  final String? note;

  /// Clé de déduplication des passages importés (voir migration
  /// 20260820_kindle_highlights_annotations). NULL pour les annotations
  /// créées dans l'app.
  final String? sourceKey;
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
    this.note,
    this.sourceKey,
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
      note: json['note'] as String?,
      sourceKey: json['source_key'] as String?,
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
      'note': note,
      'source_key': sourceKey,
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
    String? note,
    String? sourceKey,
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
      note: note ?? this.note,
      sourceKey: sourceKey ?? this.sourceKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
