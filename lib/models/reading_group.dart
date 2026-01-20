class ReadingGroup {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final bool isPrivate;
  final String creatorId;
  final DateTime createdAt;
  final int? memberCount;
  final String? userRole;
  final String? creatorName;

  ReadingGroup({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.isPrivate,
    required this.creatorId,
    required this.createdAt,
    this.memberCount,
    this.userRole,
    this.creatorName,
  });

  factory ReadingGroup.fromJson(Map<String, dynamic> json) {
    return ReadingGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      creatorId: json['creator_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      memberCount: json['member_count'] as int?,
      userRole: json['user_role'] as String?,
      creatorName: json['creator_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_url': coverUrl,
      'is_private': isPrivate,
      'creator_id': creatorId,
      'created_at': createdAt.toIso8601String(),
      'member_count': memberCount,
      'user_role': userRole,
      'creator_name': creatorName,
    };
  }

  bool get isAdmin => userRole == 'admin';
  bool get isMember => userRole == 'member';
}

class GroupMember {
  final String id;
  final String groupId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String? userName;
  final String? userEmail;
  final String? userAvatar;

  GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.userName,
    this.userEmail,
    this.userAvatar,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
      userAvatar: json['user_avatar'] as String?,
    );
  }

  String get displayName => userName ?? userEmail ?? 'Unknown';
  bool get isAdmin => role == 'admin';
}

class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String inviterId;
  final String inviterName;
  final String status;
  final DateTime createdAt;

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.inviterId,
    required this.inviterName,
    required this.status,
    required this.createdAt,
  });

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      groupName: json['group_name'] as String,
      inviterId: json['inviter_id'] as String,
      inviterName: json['inviter_name'] as String? ?? 'Unknown',
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isPending => status == 'pending';
}

class GroupActivity {
  final String id;
  final String groupId;
  final String userId;
  final String activityType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;

  GroupActivity({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.activityType,
    required this.payload,
    required this.createdAt,
    this.userName,
    this.userAvatar,
  });

  factory GroupActivity.fromJson(Map<String, dynamic> json) {
    return GroupActivity(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      activityType: json['activity_type'] as String,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
    );
  }

  String get displayName => userName ?? 'Unknown';
}
