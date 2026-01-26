class GroupChallenge {
  final String id;
  final String groupId;
  final String creatorId;
  final String type; // 'read_book', 'read_pages', 'read_daily'
  final String title;
  final String? description;
  final int? targetBookId;
  final String? targetBookTitle;
  final String? targetBookCover;
  final int targetValue;
  final int? targetDays;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;
  final int participantCount;
  final int? userProgress;
  final bool userCompleted;
  final bool userJoined;

  GroupChallenge({
    required this.id,
    required this.groupId,
    required this.creatorId,
    required this.type,
    required this.title,
    this.description,
    this.targetBookId,
    this.targetBookTitle,
    this.targetBookCover,
    required this.targetValue,
    this.targetDays,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    this.participantCount = 0,
    this.userProgress,
    this.userCompleted = false,
    this.userJoined = false,
  });

  factory GroupChallenge.fromJson(Map<String, dynamic> json) {
    return GroupChallenge(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      creatorId: json['creator_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      targetBookId: json['target_book_id'] as int?,
      targetBookTitle: json['target_book_title'] as String?,
      targetBookCover: json['target_book_cover'] as String?,
      targetValue: json['target_value'] as int,
      targetDays: json['target_days'] as int?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      participantCount: json['participant_count'] as int? ?? 0,
      userProgress: json['user_progress'] as int?,
      userCompleted: json['user_completed'] as bool? ?? false,
      userJoined: json['user_joined'] as bool? ?? false,
    );
  }

  bool get isActive => DateTime.now().isBefore(endsAt) && DateTime.now().isAfter(startsAt);
  bool get isExpired => DateTime.now().isAfter(endsAt);
  bool get isUpcoming => DateTime.now().isBefore(startsAt);

  Duration get timeRemaining => endsAt.difference(DateTime.now());

  String get typeLabel {
    switch (type) {
      case 'read_book':
        return 'Livre';
      case 'read_pages':
        return 'Pages';
      case 'read_daily':
        return 'Quotidien';
      default:
        return type;
    }
  }

  double get progressPercent {
    if (userProgress == null) return 0;
    if (type == 'read_daily') {
      return targetDays != null && targetDays! > 0
          ? (userProgress! / targetDays!).clamp(0.0, 1.0)
          : 0;
    }
    return targetValue > 0 ? (userProgress! / targetValue).clamp(0.0, 1.0) : 0;
  }
}

class ChallengeParticipant {
  final String id;
  final String challengeId;
  final String userId;
  final int progress;
  final bool completed;
  final DateTime joinedAt;
  final DateTime? completedAt;
  final String? userName;
  final String? userAvatar;

  ChallengeParticipant({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.progress,
    required this.completed,
    required this.joinedAt,
    this.completedAt,
    this.userName,
    this.userAvatar,
  });

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipant(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      userId: json['user_id'] as String,
      progress: json['progress'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
    );
  }

  String get displayName => userName ?? 'Utilisateur';
}
