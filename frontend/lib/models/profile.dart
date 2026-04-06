// frontend/lib/models/profile.dart
class Profile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String bio;

  Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio = '',
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'] ?? '',
      avatarUrl: json['avatar_url'],
      bio: json['bio'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
    };
  }
}
