// lib/models/reading_session.dart

class ReadingSession {
  final String id;
  final String userId;
  final String bookId;
  
  final int startPage;
  final int? endPage;
  
  final DateTime startTime;
  final DateTime? endTime;
  
  final String? startImagePath;
  final String? endImagePath;
  
  // Computed fields
  int get pagesRead => endPage != null ? endPage! - startPage : 0;
  
  int get durationMinutes {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes;
  }
  
  bool get isActive => endPage == null;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  ReadingSession({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.startPage,
    this.endPage,
    required this.startTime,
    this.endTime,
    this.startImagePath,
    this.endImagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      startPage: json['start_page'] as int,
      endPage: json['end_page'] as int?,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String).toLocal()
          : null,
      startImagePath: json['start_image_path'] as String?,
      endImagePath: json['end_image_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'start_page': startPage,
      'end_page': endPage,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'start_image_path': startImagePath,
      'end_image_path': endImagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ReadingSession copyWith({
    String? id,
    String? userId,
    String? bookId,
    int? startPage,
    int? endPage,
    DateTime? startTime,
    DateTime? endTime,
    String? startImagePath,
    String? endImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReadingSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startImagePath: startImagePath ?? this.startImagePath,
      endImagePath: endImagePath ?? this.endImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Model for book reading statistics
class BookReadingStats {
  final int totalPagesRead;
  final int totalMinutesRead;
  final int? currentPage;
  final int sessionsCount;
  final double avgPagesPerSession;
  final double avgMinutesPerPage;

  BookReadingStats({
    required this.totalPagesRead,
    required this.totalMinutesRead,
    this.currentPage,
    required this.sessionsCount,
    required this.avgPagesPerSession,
    required this.avgMinutesPerPage,
  });

  double get avgPagesPerMinute {
    if (totalMinutesRead == 0) return 0;
    return totalPagesRead / totalMinutesRead;
  }

  String get readingPaceDescription {
    if (avgMinutesPerPage < 1) return 'Rapide';
    if (avgMinutesPerPage < 2) return 'Moyen';
    return 'Posé';
  }
}
