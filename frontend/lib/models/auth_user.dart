class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.createdAt,
    this.profilePictureUrl,
    this.bio,
  });

  final String id;
  final String email;
  final String username;
  final String displayName;
  final DateTime createdAt;
  final String? profilePictureUrl;
  final String? bio;

  AuthUser copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    DateTime? createdAt,
    String? profilePictureUrl,
    String? bio,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bio: bio ?? this.bio,
    );
  }
}
