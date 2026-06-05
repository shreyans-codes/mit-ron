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
  final bool isIncoming;
  final List<Flair> flairs;
  final bool isCreator;

  Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio = '',
    this.isFriend = false,
    this.friendStatus,
    this.isIncoming = false,
    this.flairs = const [],
    this.isCreator = false,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final rawFlairs = json['flairs'] as List<dynamic>? ?? [];
    final flairsList = rawFlairs.map((f) {
      if (f is String) {
        return Flair(id: f, name: f);
      }
      return Flair.fromJson(f as Map<String, dynamic>);
    }).toList();
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: (json['display_name'] ?? '') as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: (json['bio'] ?? '') as String,
      isFriend: json['is_friend'] as bool? ?? false,
      friendStatus: json['friend_status'] as String?,
      isIncoming: json['is_incoming'] as bool? ?? false,
      flairs: flairsList,
      isCreator: json['is_creator'] as bool? ?? false,
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
      'is_creator': isCreator,
    };
  }
}
