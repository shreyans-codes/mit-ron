// frontend/lib/models/profile.dart
import 'group.dart';

class Profile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String bio;
  final bool isFriend;
  final String? friendStatus;
  final List<Flair> flairs;

  Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio = '',
    this.isFriend = false,
    this.friendStatus,
    this.flairs = const [],
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'] ?? '',
      avatarUrl: json['avatar_url'],
      bio: json['bio'] ?? '',
      isFriend: json['is_friend'] ?? false,
      friendStatus: json['friend_status'],
      flairs:
          (json['flairs'] as List<dynamic>?)
              ?.map((f) => Flair.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_friend': isFriend,
      'friend_status': friendStatus,
      'flairs': flairs.map((f) => f.toJson()).toList(),
    };
  }
}
