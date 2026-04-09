// frontend/lib/services/cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static SharedPreferences? _prefs;

  static const String _userAvatarKey = 'cached_user_avatar';
  static const String _groupImagePrefix = 'cached_group_image_';
  static const String _userAvatarPrefix = 'cached_user_avatar_';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Clear old invalid avatar URLs that don't have proper URLs
    final oldData = _prefs?.getString(_userAvatarKey);
    if (oldData != null) {
      try {
        final decoded = jsonDecode(oldData);
        final url = decoded['url'] as String?;
        if (url != null && !url.startsWith('http')) {
          await _prefs?.remove(_userAvatarKey);
          developer.log('Cleared invalid cached avatar URL: $url');
        }
      } catch (e) {
        // If not JSON, check if it's a raw path
        if (!oldData.startsWith('http')) {
          await _prefs?.remove(_userAvatarKey);
        }
      }
    }

    developer.log('CacheService initialized.');
  }

  Future<void> saveData(String key, String value) async {
    if (_prefs == null) {
      throw Exception('CacheService not initialized. Call init() first.');
    }
    await _prefs!.setString(key, value);
    developer.log('Data saved to cache for key: $key');
  }

  Future<String?> getData(String key) async {
    if (_prefs == null) {
      throw Exception('CacheService not initialized. Call init() first.');
    }
    final data = _prefs!.getString(key);
    if (data != null) {
      developer.log('Data retrieved from cache for key: $key');
    } else {
      developer.log('No data found in cache for key: $key');
    }
    return data;
  }

  Future<void> deleteData(String key) async {
    if (_prefs == null) {
      throw Exception('CacheService not initialized. Call init() first.');
    }
    await _prefs!.remove(key);
    developer.log('Data deleted from cache for key: $key');
  }

  Future<void> cacheUserAvatar(String userId, String avatarUrl) async {
    developer.log('Caching avatar for user $userId: $avatarUrl');
    final data = jsonEncode({
      'url': avatarUrl,
      'cachedAt': DateTime.now().toIso8601String(),
    });
    await saveData('$_userAvatarPrefix$userId', data);
    developer.log('Cached avatar for user: $userId');
  }

  Future<String?> getCachedUserAvatar(String userId) async {
    developer.log(
      'Getting cached avatar for user: $userId, key: $_userAvatarPrefix$userId',
    );
    final data = await getData('$_userAvatarPrefix$userId');
    developer.log('Got cached avatar data for $userId: $data');
    if (data == null) return null;

    try {
      final decoded = jsonDecode(data);
      developer.log('Decoded avatar URL for $userId: ${decoded['url']}');
      return decoded['url'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> cacheGroupImage(String groupId, String imageUrl) async {
    final data = jsonEncode({
      'url': imageUrl,
      'cachedAt': DateTime.now().toIso8601String(),
    });
    await saveData('$_groupImagePrefix$groupId', data);
    developer.log('Cached image for group: $groupId');
  }

  Future<String?> getCachedGroupImage(String groupId) async {
    final data = await getData('$_groupImagePrefix$groupId');
    if (data == null) return null;

    try {
      final decoded = jsonDecode(data);
      return decoded['url'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> cacheCurrentUserAvatar(String avatarUrl) async {
    developer.log('Caching current user avatar: $avatarUrl');
    await saveData(_userAvatarKey, avatarUrl);
    developer.log('Cached current user avatar');
  }

  Future<String?> getCachedCurrentUserAvatar() async {
    developer.log('Getting cached current user avatar, key: $_userAvatarKey');
    final data = await getData(_userAvatarKey);
    developer.log('Got cached current user avatar: $data');
    return data;
  }

  bool isValidUrl(String? url) {
    developer.log('Validating URL: $url');
    if (url == null || url.isEmpty) {
      developer.log('URL is null or empty');
      return false;
    }
    final isValid = url.startsWith('http://') || url.startsWith('https://');
    developer.log('URL validation result: $isValid');
    return isValid;
  }
}
