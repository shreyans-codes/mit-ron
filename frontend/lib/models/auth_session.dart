import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final AuthUser user;
}
