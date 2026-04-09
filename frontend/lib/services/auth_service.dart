// frontend/lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer; // Import dart:developer for log
import '../core/constants/api_constants.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';
import '../models/profile.dart';
import '../models/friend_lists.dart';
import '../models/group.dart';
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

  /// Exact value sent as the `Authorization` HTTP header (e.g. `Bearer eyJ...`).
  String? get authorizationHeaderValue =>
      _token == null ? null : 'Bearer ${_token!.trim()}';

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
      body: jsonEncode({
        'login_identifier': loginIdentifier,
        'password': password,
      }),
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

  Future<AuthSession> signUp(
    String username,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.signup}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
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
          headers: {'Authorization': 'Bearer ${_token!.trim()}'},
        );
      } catch (e) {
        developer.log('Logout API call failed: $e');
      }
    }
    await _clearSession();
  }

  // Handles profile updates, including text fields and optional avatar file
  Future<AuthUser> updateProfile({
    String? displayName,
    String? bio,
    String? username,
    File? avatar,
  }) async {
    if (_token == null) throw AuthException('Not authenticated');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profileUpdate}'),
    );
    request.headers['Authorization'] = 'Bearer ${_token!.trim()}';

    if (displayName != null) {
      request.fields['display_name'] = displayName;
    }
    if (bio != null) {
      request.fields['bio'] = bio;
    }
    if (username != null) {
      request.fields['username'] = username;
    }

    if (avatar != null) {
      request.files.add(
        await http.MultipartFile.fromPath('avatar', avatar.path),
      );
    }

    if (request.fields.isEmpty && request.files.isEmpty) {
      throw AuthException("No updates provided.");
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final updatedUser = _userFromJson(jsonDecode(response.body));
      await _saveCurrentUser(updatedUser);
      return updatedUser;
    } else {
      final error =
          jsonDecode(response.body)['error'] ?? 'Profile update failed';
      throw AuthException(error);
    }
  }

  // DEPRECATED: use updateProfile instead
  Future<AuthUser> uploadAvatar({required File avatar}) async {
    return updateProfile(avatar: avatar);
  }

  Future<List<Profile>> searchUsers(String query) async {
    if (_token == null) throw AuthException('Not authenticated');

    final cachedProfiles = await getCachedProfiles();
    if (cachedProfiles.isNotEmpty) {
      return cachedProfiles;
    }

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userSearch}?q=$query'),
      headers: {'Authorization': 'Bearer ${_token!.trim()}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final profiles = data.map((item) => _profileFromJson(item)).toList();
      await cacheProfiles(profiles);
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
      headers: {'Authorization': 'Bearer ${_token!.trim()}'},
    );

    if (response.statusCode == 200) {
      return _profileFromJson(jsonDecode(response.body));
    } else {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to fetch profile';
      throw AuthException(error);
    }
  }

  Future<void> addFriend(String friendUsername) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.addFriend}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_token!.trim()}',
      },
      body: jsonEncode({'friend_username': friendUsername}),
    );

    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to add friend';
      throw AuthException(error);
    }
  }

  Future<Group> createGroup(
    String name, {
    String? description,
    String? avatarPath,
  }) async {
    if (_token == null) throw AuthException('Not authenticated');

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createGroup}');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${_token!.trim()}';
    request.fields['name'] = name;
    if (description != null) {
      request.fields['description'] = description;
    }
    if (avatarPath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('avatar', avatarPath),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return _groupFromJson(jsonDecode(response.body));
    } else {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to create group';
      throw AuthException(error);
    }
  }

  Future<void> joinGroup(String groupId) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.joinGroup}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_token!.trim()}',
      },
      body: jsonEncode({'group_id': groupId}),
    );

    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to join group';
      throw AuthException(error);
    }
  }

  Future<List<Group>> getMyGroups() async {
    if (_token == null) throw AuthException('Not authenticated');

    final cachedGroups = await getCachedGroups();
    if (cachedGroups.isNotEmpty) {
      return cachedGroups;
    }

    return refreshGroups();
  }

  Future<List<Group>> refreshGroups() async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myGroups}'),
      headers: {'Authorization': 'Bearer ${_token!.trim()}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final groups = data.map((item) => _groupFromJson(item)).toList();
      await cacheGroups(groups);
      return groups;
    } else {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to fetch groups';
      throw AuthException(error);
    }
  }

  Future<List<Profile>> getGroupMembers(String groupId) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.groupMembers}?group_id=$groupId',
      ),
      headers: {'Authorization': 'Bearer ${_token!.trim()}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => _profileFromJson(item)).toList();
    } else {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to fetch group members';
      throw AuthException(error);
    }
  }

  Future<void> deleteGroup(String groupId) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deleteGroup}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_token!.trim()}',
      },
      body: jsonEncode({'group_id': groupId}),
    );

    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to delete group';
      throw AuthException(error);
    }
  }

  Future<void> addGroupMember(String groupId, String userId) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.addGroupMember}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_token!.trim()}',
      },
      body: jsonEncode({'group_id': groupId, 'user_id': userId}),
    );

    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to add member';
      throw AuthException(error);
    }
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.removeGroupMember}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_token!.trim()}',
      },
      body: jsonEncode({'group_id': groupId, 'user_id': userId}),
    );

    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to remove member';
      throw AuthException(error);
    }
  }

  Future<FriendLists> getFriendLists() async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.friendsList}'),
      headers: {'Authorization': 'Bearer ${_token!.trim()}'},
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return FriendLists.fromJson(data);
    }
    final error =
        jsonDecode(response.body)['error'] ?? 'Failed to fetch friends';
    throw AuthException(error is String ? error : error.toString());
  }

  Future<void> respondToFriendRequest({
    required String initiatorId,
    required bool accept,
  }) async {
    if (_token == null) throw AuthException('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.respondFriend}'),
      headers: {
        'Authorization': 'Bearer ${_token!.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'initiator_id': initiatorId, 'accept': accept}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final error = body is Map<String, dynamic> ? body['error'] : null;
      throw AuthException(
        error?.toString() ?? 'Failed to respond to friend request',
      );
    }
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
    await CacheService.instance.saveData(
      _cachedProfilesKey,
      jsonEncode(cacheEntry),
    );
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
        await CacheService.instance.deleteData(_cachedProfilesKey);
        return [];
      }
    } catch (e) {
      developer.log('Failed to decode or parse cached profiles: $e');
      await CacheService.instance.deleteData(_cachedProfilesKey);
      return [];
    }
  }

  Future<void> cacheGroups(List<Group> groups) async {
    final cacheEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'groups': groups.map((g) => _groupToJson(g)).toList(),
    };
    await CacheService.instance.saveData(
      _cachedGroupsKey,
      jsonEncode(cacheEntry),
    );
  }

  Future<void> updateCachedGroupMemberCount(
    String groupId,
    int memberCount,
  ) async {
    final cachedGroups = await getCachedGroups();
    final updatedGroups = cachedGroups.map((g) {
      if (g.id == groupId) {
        return Group(
          id: g.id,
          name: g.name,
          description: g.description,
          creatorId: g.creatorId,
          createdAt: g.createdAt,
          memberCount: memberCount,
          groupImageUrl: g.groupImageUrl,
        );
      }
      return g;
    }).toList();
    await cacheGroups(updatedGroups);
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
        await CacheService.instance.deleteData(_cachedGroupsKey);
        return [];
      }
    } catch (e) {
      developer.log('Failed to decode or parse cached groups: $e');
      await CacheService.instance.deleteData(_cachedGroupsKey);
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
    final avatarUrl = json['avatar_url'] as String?;
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      profilePictureUrl: avatarUrl,
      bio: json['bio'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
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
    final avatarUrl = json['avatar_url'] as String?;
    final userId = json['id'] as String?;
    if (userId != null && avatarUrl != null && avatarUrl.isNotEmpty) {
      // Only cache if it's a valid URL (has http/https), not raw path
      if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
        CacheService.instance.cacheUserAvatar(userId, avatarUrl);
      }
    }
    return Profile(
      id: userId ?? '',
      username: json['username'] as String,
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: avatarUrl,
      bio: json['bio'] as String? ?? '',
      isFriend: json['is_friend'] as bool? ?? false,
      friendStatus: json['friend_status'] as String?,
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
    final groupImageUrl = json['group_image_url'] as String?;
    final groupId = json['id'] as String?;
    if (groupId != null && groupImageUrl != null && groupImageUrl.isNotEmpty) {
      CacheService.instance.cacheGroupImage(groupId, groupImageUrl);
    }
    return Group(
      id: groupId ?? '',
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      creatorId: json['creator_id'] as String,
      createdAt: DateTime.parse(json['created_at']),
      memberCount: json['member_count'] as int? ?? 0,
      groupImageUrl: groupImageUrl,
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

    // Clear cache entries as well
    await CacheService.instance.deleteData(_cachedProfilesKey);
    await CacheService.instance.deleteData(_cachedGroupsKey);
  }
}
