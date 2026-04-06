import 'dart:math';

import '../models/auth_session.dart';
import '../models/auth_user.dart';
import 'auth_exception.dart';

/// In-memory mock auth. Replace with real HTTP client when backend exists.
class MockAuthApi {
  MockAuthApi._();

  static final MockAuthApi instance = MockAuthApi._();

  final Map<String, String> _passwordsByEmail = {
    'demo@mitron.app': 'password123',
  };
  
  final Map<String, AuthUser> _usersByEmail = {
    'demo@mitron.app': AuthUser(
      id: 'usr_demo',
      email: 'demo@mitron.app',
      displayName: 'Demo User',
      username: 'demouser',
      bio: 'Just testing things out!',
      createdAt: DateTime.now(),
    ),
  };

  final Random _random = Random();

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 750));
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw AuthException('Enter your email.');
    }
    final storedPassword = _passwordsByEmail[normalized];
    if (storedPassword == null) {
      throw AuthException('No account found for that email.');
    }
    if (storedPassword != password) {
      throw AuthException('Incorrect password.');
    }
    return _createSession(normalized);
  }

  Future<AuthSession> signUp({
    required String displayName,
    required String email,
    required String password,
    String? username,
    String? profilePictureUrl,
    String? bio,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw AuthException('Enter your email.');
    }
    if (_passwordsByEmail.containsKey(normalized)) {
      throw AuthException('That email is already registered.');
    }
    
    _passwordsByEmail[normalized] = password;
    _usersByEmail[normalized] = AuthUser(
      id: 'usr_${email.hashCode.abs()}',
      email: normalized,
      displayName: displayName.trim(),
      username: username?.trim() ?? '',
      profilePictureUrl: profilePictureUrl?.trim(),
      bio: bio?.trim(),
      createdAt: DateTime.now(),
    );
    
    return _createSession(normalized);
  }

  Future<AuthUser> updateUser(AuthUser user) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _usersByEmail[user.email] = user;
    return user;
  }

  AuthSession _createSession(String email) {
    final user = _usersByEmail[email]!;
    final token =
        'mock_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
    return AuthSession(
      accessToken: token,
      user: user,
    );
  }
}
