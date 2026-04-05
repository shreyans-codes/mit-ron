class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.username,
    this.profilePictureUrl,
    this.bio,
  });

  final String id;
  final String email;
  final String displayName;
  final String? username;
  final String? profilePictureUrl;
  final String? bio;

  AuthUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? username,
    String? profilePictureUrl,
    String? bio,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bio: bio ?? this.bio,
    );
  }
}
