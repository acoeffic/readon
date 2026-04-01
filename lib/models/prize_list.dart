class PrizeList {
  final String id;
  final String title;
  final String? description;
  final String prizeName;
  final String prizeWikidataId;
  final String listType;
  final int? year;
  final String? coverUrl;
  final bool isActive;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;

  // Loaded separately
  final List<PrizeListBook> books;

  PrizeList({
    required this.id,
    required this.title,
    this.description,
    required this.prizeName,
    required this.prizeWikidataId,
    required this.listType,
    this.year,
    this.coverUrl,
    this.isActive = true,
    this.lastSyncedAt,
    required this.createdAt,
    this.books = const [],
  });

  factory PrizeList.fromJson(Map<String, dynamic> json) {
    return PrizeList(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      prizeName: json['prize_name'] as String,
      prizeWikidataId: json['prize_wikidata_id'] as String,
      listType: json['list_type'] as String,
      year: json['year'] as int?,
      coverUrl: json['cover_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.parse(json['last_synced_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  PrizeList copyWith({List<PrizeListBook>? books}) {
    return PrizeList(
      id: id,
      title: title,
      description: description,
      prizeName: prizeName,
      prizeWikidataId: prizeWikidataId,
      listType: listType,
      year: year,
      coverUrl: coverUrl,
      isActive: isActive,
      lastSyncedAt: lastSyncedAt,
      createdAt: createdAt,
      books: books ?? this.books,
    );
  }

  int get bookCount => books.length;

  bool get isThematic => listType == 'thematic';
}

class PrizeListBook {
  final String id;
  final String listId;
  final String? isbn;
  final String? wikidataBookId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? description;
  final int? pageCount;
  final int? publicationYear;
  final String? openLibraryId;
  final int position;

  PrizeListBook({
    required this.id,
    required this.listId,
    this.isbn,
    this.wikidataBookId,
    required this.title,
    this.author,
    this.coverUrl,
    this.description,
    this.pageCount,
    this.publicationYear,
    this.openLibraryId,
    required this.position,
  });

  factory PrizeListBook.fromJson(Map<String, dynamic> json) {
    return PrizeListBook(
      id: json['id'] as String,
      listId: json['list_id'] as String,
      isbn: json['isbn'] as String?,
      wikidataBookId: json['wikidata_book_id'] as String?,
      title: json['title'] as String,
      author: json['author'] as String?,
      coverUrl: json['cover_url'] as String?,
      description: json['description'] as String?,
      pageCount: json['page_count'] as int?,
      publicationYear: json['publication_year'] as int?,
      openLibraryId: json['open_library_id'] as String?,
      position: json['position'] as int,
    );
  }
}
