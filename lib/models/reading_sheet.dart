class ReadingSheetTheme {
  final String title;
  final String description;

  const ReadingSheetTheme({required this.title, required this.description});

  factory ReadingSheetTheme.fromJson(Map<String, dynamic> json) {
    return ReadingSheetTheme(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class ReadingSheetQuote {
  final String text;
  final int? page;
  final String comment;

  const ReadingSheetQuote({
    required this.text,
    this.page,
    required this.comment,
  });

  factory ReadingSheetQuote.fromJson(Map<String, dynamic> json) {
    return ReadingSheetQuote(
      text: json['text'] as String? ?? '',
      page: json['page'] as int?,
      comment: json['comment'] as String? ?? '',
    );
  }
}

class ReadingSheet {
  final List<ReadingSheetTheme> themes;
  final List<ReadingSheetQuote> quotes;
  final String progression;
  final String synthesis;
  final int annotationCount;
  final DateTime? generatedAt;

  const ReadingSheet({
    required this.themes,
    required this.quotes,
    required this.progression,
    required this.synthesis,
    required this.annotationCount,
    this.generatedAt,
  });

  factory ReadingSheet.fromJson(Map<String, dynamic> json, {DateTime? generatedAt}) {
    return ReadingSheet(
      themes: (json['themes'] as List<dynamic>?)
              ?.map((e) => ReadingSheetTheme.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      quotes: (json['quotes'] as List<dynamic>?)
              ?.map((e) => ReadingSheetQuote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      progression: json['progression'] as String? ?? '',
      synthesis: json['synthesis'] as String? ?? '',
      annotationCount: json['annotation_count'] as int? ?? 0,
      generatedAt: generatedAt,
    );
  }
}
