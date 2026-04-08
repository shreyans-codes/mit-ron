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
  final bool isCreator;

  Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio = '',
    this.isFriend = false,
    this.friendStatus,
    this.flairs = const [],
    this.isCreator = false,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final flairsList =
        (json['flairs'] as List<dynamic>?)
            ?.map((f) => Flair.fromJson(f as Map<String, dynamic>))
            .toList() ??
        [];
    final isCreator = json['is_creator'] as bool? ?? false;
    if (isCreator) {
      flairsList.insert(0, Flair(id: 'admin', name: 'Admin', groupId: null));
    }
    return Profile(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'] ?? '',
      avatarUrl: json['avatar_url'],
      bio: json['bio'] ?? '',
      isFriend: json['is_friend'] ?? false,
      friendStatus: json['friend_status'],
      flairs: flairsList,
      isCreator: isCreator,
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
