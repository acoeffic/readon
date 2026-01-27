// lib/models/reading_goal.dart

enum GoalCategory {
  quantity,
  regularity,
  quality;

  String get label {
    switch (this) {
      case GoalCategory.quantity:
        return 'Quantite';
      case GoalCategory.regularity:
        return 'Regularite';
      case GoalCategory.quality:
        return 'Qualite / Intention';
    }
  }

  String get dbValue {
    switch (this) {
      case GoalCategory.quantity:
        return 'quantity';
      case GoalCategory.regularity:
        return 'regularity';
      case GoalCategory.quality:
        return 'quality';
    }
  }

  static GoalCategory fromDb(String value) {
    switch (value) {
      case 'quantity':
        return GoalCategory.quantity;
      case 'regularity':
        return GoalCategory.regularity;
      case 'quality':
        return GoalCategory.quality;
      default:
        return GoalCategory.quantity;
    }
  }
}

enum GoalType {
  // Quantity
  booksPerYear('books_per_year', GoalCategory.quantity),
  // Regularity
  daysPerWeek('days_per_week', GoalCategory.regularity),
  streakTarget('streak_target', GoalCategory.regularity),
  minutesPerDay('minutes_per_day', GoalCategory.regularity),
  // Quality
  nonfictionBooks('nonfiction_books', GoalCategory.quality),
  fictionBooks('fiction_books', GoalCategory.quality),
  finishStarted('finish_started', GoalCategory.quality),
  differentGenres('different_genres', GoalCategory.quality);

  final String dbValue;
  final GoalCategory category;
  const GoalType(this.dbValue, this.category);

  static GoalType fromDb(String value) {
    return GoalType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => GoalType.booksPerYear,
    );
  }

  String get emoji {
    switch (this) {
      case GoalType.booksPerYear:
        return '📚';
      case GoalType.daysPerWeek:
        return '🔁';
      case GoalType.streakTarget:
        return '🔥';
      case GoalType.minutesPerDay:
        return '⏱';
      case GoalType.nonfictionBooks:
        return '🧠';
      case GoalType.fictionBooks:
        return '📖';
      case GoalType.finishStarted:
        return '🎯';
      case GoalType.differentGenres:
        return '🌍';
    }
  }

  String get label {
    switch (this) {
      case GoalType.booksPerYear:
        return 'Livres par an';
      case GoalType.daysPerWeek:
        return 'Jours de lecture / semaine';
      case GoalType.streakTarget:
        return 'Streak cible';
      case GoalType.minutesPerDay:
        return 'Minutes de lecture / jour';
      case GoalType.nonfictionBooks:
        return 'Livres non-fiction';
      case GoalType.fictionBooks:
        return 'Romans';
      case GoalType.finishStarted:
        return 'Finir les livres commences';
      case GoalType.differentGenres:
        return 'Genres differents';
    }
  }

  String unitLabel(int value) {
    switch (this) {
      case GoalType.booksPerYear:
        return '$value livres';
      case GoalType.daysPerWeek:
        return '$value jours/sem';
      case GoalType.streakTarget:
        return '$value jours';
      case GoalType.minutesPerDay:
        return '$value min/jour';
      case GoalType.nonfictionBooks:
        return '$value livres';
      case GoalType.fictionBooks:
        return '$value romans';
      case GoalType.finishStarted:
        return 'Tous';
      case GoalType.differentGenres:
        return '$value genres';
    }
  }
}

class ReadingGoal {
  final int id;
  final String userId;
  final GoalCategory category;
  final GoalType goalType;
  final int targetValue;
  final int year;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int currentValue;
  final int? extraValue;

  ReadingGoal({
    required this.id,
    required this.userId,
    required this.category,
    required this.goalType,
    required this.targetValue,
    required this.year,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.currentValue = 0,
    this.extraValue,
  });

  factory ReadingGoal.fromJson(Map<String, dynamic> json) {
    return ReadingGoal(
      id: json['id'] as int,
      userId: json['user_id'] as String? ?? '',
      category: GoalCategory.fromDb(json['category'] as String),
      goalType: GoalType.fromDb(json['goal_type'] as String),
      targetValue: json['target_value'] as int,
      year: json['year'] as int? ?? DateTime.now().year,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      currentValue: json['current_value'] as int? ?? 0,
      extraValue: json['extra_value'] as int?,
    );
  }

  Map<String, dynamic> toInsert() {
    return {
      'user_id': userId,
      'category': category.dbValue,
      'goal_type': goalType.dbValue,
      'target_value': targetValue,
      'year': year,
      'is_active': isActive,
    };
  }

  double get progressPercent {
    if (targetValue <= 0) return 0;
    if (goalType == GoalType.finishStarted) {
      if (extraValue == null || extraValue == 0) return 0;
      return (currentValue / extraValue!).clamp(0.0, 1.0);
    }
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  String get progressText {
    if (goalType == GoalType.finishStarted) {
      return '$currentValue / ${extraValue ?? '?'} termines';
    }
    return '$currentValue / ${goalType.unitLabel(targetValue)}';
  }

  bool get isCompleted => progressPercent >= 1.0;

  ReadingGoal copyWith({
    int? currentValue,
    int? extraValue,
    int? targetValue,
    bool? isActive,
  }) {
    return ReadingGoal(
      id: id,
      userId: userId,
      category: category,
      goalType: goalType,
      targetValue: targetValue ?? this.targetValue,
      year: year,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      currentValue: currentValue ?? this.currentValue,
      extraValue: extraValue ?? this.extraValue,
    );
  }
}
