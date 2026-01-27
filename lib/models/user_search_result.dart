// lib/models/user_search_result.dart
// Modèle pour les résultats de recherche d'utilisateurs

class UserBadgeSimple {
  final String id;
  final String name;
  final String icon;
  final String color;
  final DateTime? unlockedAt;

  UserBadgeSimple({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.unlockedAt,
  });

  factory UserBadgeSimple.fromJson(Map<String, dynamic> json) {
    return UserBadgeSimple(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
    );
  }
}

class CurrentBook {
  final int id;
  final String title;
  final String? author;
  final String? coverUrl;

  CurrentBook({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
  });

  factory CurrentBook.fromJson(Map<String, dynamic> json) {
    return CurrentBook(
      id: json['id'] as int,
      title: json['title'] as String,
      author: json['author'] as String?,
      coverUrl: json['cover_url'] as String?,
    );
  }
}

class UserSearchResult {
  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final bool isProfilePrivate;

  // Données publiques (disponibles uniquement si isProfilePrivate = false)
  final List<UserBadgeSimple>? recentBadges;
  final int? booksFinished;
  final DateTime? memberSince;
  final int? currentStreak;
  final CurrentBook? currentBook;
  final int? friendsCount;

  UserSearchResult({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.isProfilePrivate = false,
    this.recentBadges,
    this.booksFinished,
    this.memberSince,
    this.currentStreak,
    this.currentBook,
    this.friendsCount,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    final isPrivate = json['is_profile_private'] as bool? ?? false;

    return UserSearchResult(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? json['email'] as String? ?? 'Utilisateur',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isProfilePrivate: isPrivate,

      // Ces champs ne sont présents que si le profil est public
      recentBadges: !isPrivate && json['recent_badges'] != null
          ? (json['recent_badges'] as List)
              .map((b) => UserBadgeSimple.fromJson(b as Map<String, dynamic>))
              .toList()
          : null,
      booksFinished: !isPrivate ? (json['books_finished'] as num?)?.toInt() : null,
      memberSince: !isPrivate && json['member_since'] != null
          ? DateTime.parse(json['member_since'] as String)
          : null,
      currentStreak: !isPrivate ? (json['current_streak'] as num?)?.toInt() : null,
      currentBook: !isPrivate && json['current_book'] != null
          ? CurrentBook.fromJson(json['current_book'] as Map<String, dynamic>)
          : null,
      friendsCount: !isPrivate ? (json['friends_count'] as num?)?.toInt() : null,
    );
  }
}
