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
    final data = jsonEncode({
      'url': avatarUrl,
      'cachedAt': DateTime.now().toIso8601String(),
    });
    await saveData('$_userAvatarPrefix$userId', data);
    developer.log('Cached avatar for user: $userId');
  }

  Future<String?> getCachedUserAvatar(String userId) async {
    final data = await getData('$_userAvatarPrefix$userId');
    if (data == null) return null;

    try {
      final decoded = jsonDecode(data);
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
    await saveData(_userAvatarKey, avatarUrl);
    developer.log('Cached current user avatar');
  }

  Future<String?> getCachedCurrentUserAvatar() async {
    return getData(_userAvatarKey);
  }

  bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }
}
