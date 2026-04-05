import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';
import 'auth_exception.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _baseUrl = 'http://localhost:8080'; // Update for production/mobile
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  String? _token;
  AuthUser? _currentUser;

  String? get token => _token;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _currentUser = _userFromJson(jsonDecode(userJson));
    }
  }

  Future<AuthSession> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final session = _sessionFromJson(data);
      await _saveSession(session);
      return session;
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Login failed';
      throw AuthException(error);
    }
  }

  Future<AuthSession> signUp(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final session = _sessionFromJson(data);
      await _saveSession(session);
      return session;
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Signup failed';
      throw AuthException(error);
    }
  }

  Future<void> logout() async {
    if (_token != null) {
      await http.post(
        Uri.parse('$_baseUrl/signout'),
        headers: {'Authorization': 'Bearer $_token'},
      );
    }
    await _clearSession();
  }

  Future<AuthUser> updateProfile({String? displayName, File? avatar}) async {
    if (_token == null) throw AuthException('Not authenticated');

    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/profile/update'));
    request.headers['Authorization'] = 'Bearer $_token';
    
    if (displayName != null) {
      request.fields['display_name'] = displayName;
    }
    
    if (avatar != null) {
      request.files.add(await http.MultipartFile.fromPath('avatar', avatar.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final user = _userFromJson(jsonDecode(response.body));
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(_userToJson(user)));
      return user;
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Update failed';
      throw AuthException(error);
    }
  }

  AuthSession _sessionFromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'],
      user: _userFromJson(json['user']),
    );
  }

  AuthUser _userFromJson(Map<String, dynamic> json) {
    // Handle both backend User model and Frontend AuthUser model
    final metadata = json['user_metadata'] ?? {};
    return AuthUser(
      id: json['id'],
      email: json['email'],
      displayName: metadata['display_name'] ?? json['display_name'] ?? '',
      profilePictureUrl: metadata['avatar_url'] ?? json['avatar_url'],
    );
  }

  Map<String, dynamic> _userToJson(AuthUser user) {
    return {
      'id': user.id,
      'email': user.email,
      'display_name': user.displayName,
      'avatar_url': user.profilePictureUrl,
    };
  }

  Future<void> _saveSession(AuthSession session) async {
    _token = session.accessToken;
    _currentUser = session.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_userKey, jsonEncode(_userToJson(_currentUser!)));
  }

  Future<void> _clearSession() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
