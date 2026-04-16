// frontend/lib/models/group.dart
class Group {
  final String id;
  final String name;
  final String? description;
  final String creatorId;
  final DateTime createdAt;
  final int memberCount;
  final String? groupImageUrl;
  final String? chatId;
  final String? lastActivityAt;
  final int unreadCount;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.creatorId,
    required this.createdAt,
    this.memberCount = 0,
    this.groupImageUrl,
    this.chatId,
    this.lastActivityAt,
    this.unreadCount = 0,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      creatorId: json['created_by'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at']),
      memberCount: json['member_count'] ?? 0,
      groupImageUrl: json['group_image_url'],
      chatId: json['chat_id'],
      lastActivityAt: json['last_activity_at'],
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_by': creatorId,
      'created_at': createdAt.toIso8601String(),
      'member_count': memberCount,
      'group_image_url': groupImageUrl,
      'chat_id': chatId,
      'last_activity_at': lastActivityAt,
      'unread_count': unreadCount,
    };
  }
}

class GroupMember {
  final String groupId;
  final String userId;
  final DateTime joinedAt;
  final List<Flair> flairs;

  GroupMember({
    required this.groupId,
    required this.userId,
    required this.joinedAt,
    this.flairs = const [],
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      groupId: json['group_id'],
      userId: json['user_id'],
      joinedAt: DateTime.parse(json['joined_at']),
      flairs: (json['flairs'] as List? ?? [])
          .map((f) => Flair.fromJson(f))
          .toList(),
    );
  }
}

class Flair {
  final String id;
  final String name;
  final String? groupId;

  Flair({required this.id, required this.name, this.groupId});

  factory Flair.fromJson(Map<String, dynamic> json) {
    return Flair(id: json['id'], name: json['name'], groupId: json['group_id']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'group_id': groupId};
  }
}
