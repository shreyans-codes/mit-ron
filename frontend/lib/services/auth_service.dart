// frontend/lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart'; // For ListEquality
import 'dart:developer'; // For log.warning
import '../core/constants/api_constants.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';
import '../models/profile.dart'; // Assuming Profile model exists
import '../models/friend.dart';   // Assuming Friend model exists
import '../models/group.dart';   // Assuming Group model exists
import 'auth_exception.dart';
import 'cache_service.dart'; // Import the new cache service

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

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

  Future<AuthSession> login(String loginIdentifier, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login_identifier': loginIdentifier, 'password': password}), // Changed key to login_identifier
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

  Future<AuthSession> signUp(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.signup}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
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
      try {
        await http.post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.signout}'),
          headers: {'Authorization': 'Bearer $_token'},
        );
      } catch (e) {
        log.warning('Logout API call failed: $e');
        // Continue clearing local session even if API call fails
      }
    }
    await _clearSession();
  }

  Future<AuthUser> updateProfile({String? displayName, String? avatarUrl, String? bio, String? username}) async {
    if (_token == null) throw AuthException('Not authenticated');

    Map<String, dynamic> updateData = {};
    if (displayName != null) {
      updateData['display_name'] = displayName;
    }
    if (bio != null) {
      updateData['bio'] = bio;
    }
    if (username != null) {
      updateData['username'] = username; // Ensure backend validates username format and uniqueness
    }

    // If only non-file fields are updated
    if (updateData.isNotEmpty) {
      final response, err := http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profileUpdate}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        final updatedUser = _userFromJson(jsonDecode(response.body));
        await _saveCurrentUser(updatedUser);
        return updatedUser;
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Profile update failed';
        throw AuthException(error);
      }
    }

    // Avatar upload is handled separately or requires multipart request implementation.
    throw AuthException("No updates provided or avatar upload not fully implemented in this example.");
  }

  // Method for avatar upload via multipart request (example structure)
  Future<AuthUser> uploadAvatar({required File avatar}) async {
    if (_token == null) throw AuthException('Not authenticated');

    var request = http.MultipartRequest('POST', Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profileUpdate}'));
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(await http.MultipartFile.fromPath('avatar', avatar.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final updatedUser = _userFromJson(jsonDecode(response.body));
      await _saveCurrentUser(updatedUser);
      return updatedUser;
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Avatar upload failed';
      throw AuthException(error);
    }
  }


  Future<List<Profile>> searchUsers(String query) async {
    if (_token == null) throw AuthException('Not authenticated');
    
    // Check cache first
    final cachedProfiles = await getCachedProfiles();
    // Basic cache check: If cache exists and is valid, return it.
    // A more sophisticated cache would match the query or invalidate intelligently.
    // For now, we assume if cache is valid, it's good enough.
    if (cachedProfiles.isNotEmpty) {
      return cachedProfiles;
    }

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userSearch}?q=$query'),
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final profiles = data.map((item) => _profileFromJson(item)).toList();
      await cacheProfiles(profiles); // Cache the new results
      return profiles;
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'User search failed';
      throw AuthException(error);
    }
  }

  Future<Profile> getUserProfile(String username) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}/$username'),
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      return _profileFromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to fetch profile';
      throw AuthException(error);
    }
  }

  Future<void> addFriend(String friendUsername) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.addFriend}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'friend_username': friendUsername}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to add friend';
      throw AuthException(error);
    }
  }

  Future<Group> createGroup(String name, {String? description}) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createGroup}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'name': name, 'description': description}),
    );

    if (response.statusCode == 201) {
      return _groupFromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to create group';
      throw AuthException(error);
    }
  }

  Future<void> joinGroup(String groupId) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.joinGroup}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'group_id': groupId}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to join group';
      throw AuthException(error);
    }
  }

  Future<List<Group>> getMyGroups() async {
    if (_token == null) throw AuthException('Not authenticated');
    
    // Check cache first
    final cachedGroups = await getCachedGroups();
    if (cachedGroups.isNotEmpty) {
      // Simple cache check; ideally, cache invalidation or smarter checks are needed.
      // For now, return if cache exists and is recent enough.
      return cachedGroups;
    }

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myGroups}'),
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final groups = data.map((item) => _groupFromJson(item)).toList();
      await cacheGroups(groups); // Cache the new results
      return groups;
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to fetch groups';
      throw AuthException(error);
    }
  }

  // Placeholder method for fetching friends
  // This will require a new backend endpoint (e.g., /friends/list)
  Future<List<Profile>> getFriends() async {
    if (_token == null) throw AuthException('Not authenticated');

    // TODO: Implement backend endpoint for fetching friends
    // Example call:
    // final response = await http.get(
    //   Uri.parse('${ApiConstants.baseUrl}${ApiConstants.friendsList}'), // Assuming this endpoint exists
    //   headers: {'Authorization': 'Bearer $_token'},
    // );
    // if (response.statusCode == 200) {
    //   final List<dynamic> data = jsonDecode(response.body);
    //   return data.map((item) => _profileFromJson(item)).toList();
    // } else {
    //   final error = jsonDecode(response.body)['error'] ?? 'Failed to fetch friends';
    //   throw AuthException(error);
    // }
    
    // Returning empty list as placeholder
    return [];
  }

  // --- Caching Logic ---
  static const String _cachedProfilesKey = 'cached_profiles';
  static const String _cachedGroupsKey = 'cached_groups';
  static const Duration _cacheDuration = Duration(days: 2);

  Future<void> cacheProfiles(List<Profile> profiles) async {
    final cacheEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'profiles': profiles.map((p) => _profileToJson(p)).toList(),
    };
    await CacheService.instance.saveData(_cachedProfilesKey, jsonEncode(cacheEntry));
  }

  Future<List<Profile>> getCachedProfiles() async {
    final cachedData = await CacheService.instance.getData(_cachedProfilesKey);
    if (cachedData == null) return [];

    try {
      final Map<String, dynamic> cacheEntry = jsonDecode(cachedData);
      final timestamp = DateTime.parse(cacheEntry['timestamp']);
      if (DateTime.now().difference(timestamp) <= _cacheDuration) {
        final List<dynamic> profilesData = cacheEntry['profiles'];
        return profilesData.map((item) => _profileFromJson(item)).toList();
      } else {
        // Cache expired
        await CacheService.instance.deleteData(_cachedProfilesKey);
        return [];
      }
    } catch (e) {
      log.warning('Failed to decode or parse cached profiles: $e');
      await CacheService.instance.deleteData(_cachedProfilesKey); // Clean up corrupted cache
      return [];
    }
  }

  Future<void> cacheGroups(List<Group> groups) async {
    final cacheEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'groups': groups.map((g) => _groupToJson(g)).toList(),
    };
    await CacheService.instance.saveData(_cachedGroupsKey, jsonEncode(cacheEntry));
  }

  Future<List<Group>> getCachedGroups() async {
    final cachedData = await CacheService.instance.getData(_cachedGroupsKey);
    if (cachedData == null) return [];

    try {
      final Map<String, dynamic> cacheEntry = jsonDecode(cachedData);
      final timestamp = DateTime.parse(cacheEntry['timestamp']);
      if (DateTime.now().difference(timestamp) <= _cacheDuration) {
        final List<dynamic> groupsData = cacheEntry['groups'];
        return groupsData.map((item) => _groupFromJson(item)).toList();
      } else {
        // Cache expired
        await CacheService.instance.deleteData(_cachedGroupsKey);
        return [];
      }
    } catch (e) {
      log.warning('Failed to decode or parse cached groups: $e');
      await CacheService.instance.deleteData(_cachedGroupsKey); // Clean up corrupted cache
      return [];
    }
  }

  // --- JSON Conversion ---

  AuthSession _sessionFromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      user: _userFromJson(json['user'] as Map<String, dynamic>),
    );
  }

  AuthUser _userFromJson(Map<String, dynamic> json) {
    // Handle potential differences in backend User model and frontend AuthUser model structure
    // Backend might return 'username', 'display_name', 'avatar_url', 'bio' directly or under 'user_metadata'
    final metadata = json['user_metadata'] ?? {}; // For potential Supabase compatibility
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String? ?? '', // From DB directly
      displayName: metadata['display_name'] ?? json['display_name'] ?? '', // Fallback for display name
      profilePictureUrl: metadata['avatar_url'] ?? json['avatar_url'], // Fallback for avatar URL
      bio: json['bio'] as String? ?? '', // From DB directly
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> _userToJson(AuthUser user) {
    return {
      'id': user.id,
      'email': user.email,
      'username': user.username,
      'display_name': user.displayName,
      'avatar_url': user.profilePictureUrl,
      'bio': user.bio,
      'created_at': user.createdAt.toIso8601String(),
    };
  }

  Profile _profileFromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String? ?? '',
    );
  }

  Map<String, dynamic> _profileToJson(Profile profile) {
    return {
      'id': profile.id,
      'username': profile.username,
      'display_name': profile.displayName,
      'avatar_url': profile.avatarUrl,
      'bio': profile.bio,
    };
  }

  Group _groupFromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      creatorId: json['creator_id'] as String,
      createdAt: DateTime.parse(json['created_at']),
      memberCount: json['member_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> _groupToJson(Group group) {
    return {
      'id': group.id,
      'name': group.name,
      'description': group.description,
      'creator_id': group.creatorId,
      'created_at': group.createdAt.toIso8601String(),
      'member_count': group.memberCount,
    };
  }

  // --- Session Management ---
  Future<void> _saveSession(AuthSession session) async {
    _token = session.accessToken;
    _currentUser = session.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_userKey, jsonEncode(_userToJson(_currentUser!)));
  }

  Future<void> _saveCurrentUser(AuthUser user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
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
