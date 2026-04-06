// frontend/lib/models/friend.dart
class Friend {
  final String userId;
  final String friendId;
  final DateTime createdAt;

  Friend({
    required this.userId,
    required this.friendId,
    required this.createdAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      userId: json['user_id'],
      friendId: json['friend_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'friend_id': friendId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
