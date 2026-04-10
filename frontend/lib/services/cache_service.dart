// frontend/lib/services/cache_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class ImageCacheData {
  final String filePath;
  final String localPath;
  final DateTime cachedAt;

  ImageCacheData({
    required this.filePath,
    required this.localPath,
    required this.cachedAt,
  });

  Map<String, dynamic> toJson() => {
    'file_path': filePath,
    'local_path': localPath,
    'cached_at': cachedAt.toIso8601String(),
  };

  factory ImageCacheData.fromJson(Map<String, dynamic> json) {
    return ImageCacheData(
      filePath: json['file_path'] as String,
      localPath: json['local_path'] as String,
      cachedAt: DateTime.parse(json['cached_at'] as String),
    );
  }
}

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static SharedPreferences? _prefs;

  static const String _userAvatarPrefix = 'cached_user_avatar_';
  static const String _groupImagePrefix = 'cached_group_image_';
  static const String _currentUserAvatarKey = 'cached_current_user_avatar';

  static const Duration cacheExpiry = Duration(days: 30);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    developer.log('CacheService initialized.');
  }

  Future<void> saveData(String key, String value) async {
    if (_prefs == null) {
      throw Exception('CacheService not initialized. Call init() first.');
    }
    await _prefs!.setString(key, value);
  }

  Future<String?> getData(String key) async {
    if (_prefs == null) {
      throw Exception('CacheService not initialized. Call init() first.');
    }
    return _prefs!.getString(key);
  }

  Future<void> deleteData(String key) async {
    if (_prefs == null) {
      throw Exception('CacheService not initialized. Call init() first.');
    }
    await _prefs!.remove(key);
  }

  Future<String> _getLocalImageDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${directory.path}/cached_images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir.path;
  }

  Future<String> _saveImageToLocal(String userId, Uint8List imageBytes) async {
    final dir = await _getLocalImageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${userId}_$timestamp.jpg';
    final filePath = '$dir/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);
    return filePath;
  }

  bool _isCacheValid(ImageCacheData? cacheData) {
    if (cacheData == null) return false;
    final now = DateTime.now();
    final expiryDate = cacheData.cachedAt.add(cacheExpiry);
    return now.isBefore(expiryDate);
  }

  Future<void> cacheUserAvatar(
    String userId,
    String filePath,
    Uint8List imageBytes,
  ) async {
    developer.log('Caching avatar for user $userId with file path: $filePath');

    final localPath = await _saveImageToLocal(userId, imageBytes);

    final cacheData = ImageCacheData(
      filePath: filePath,
      localPath: localPath,
      cachedAt: DateTime.now(),
    );

    final data = jsonEncode(cacheData.toJson());
    await saveData('$_userAvatarPrefix$userId', data);
    developer.log('Cached avatar for user: $userId at local path: $localPath');
  }

  Future<ImageCacheData?> getCachedUserAvatar(String userId) async {
    final data = await getData('$_userAvatarPrefix$userId');
    if (data == null) return null;

    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final cacheData = ImageCacheData.fromJson(decoded);
      if (!_isCacheValid(cacheData)) {
        await deleteData('$_userAvatarPrefix$userId');
        return null;
      }
      return cacheData;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getUserAvatarLocalPath(String userId) async {
    final cacheData = await getCachedUserAvatar(userId);
    return cacheData?.localPath;
  }

  Future<String?> getUserAvatarFilePath(String userId) async {
    final cacheData = await getCachedUserAvatar(userId);
    return cacheData?.filePath;
  }

  Future<bool> shouldRefreshUserAvatar(
    String userId,
    String newFilePath,
  ) async {
    final cacheData = await getCachedUserAvatar(userId);
    if (cacheData == null) return true;
    return cacheData.filePath != newFilePath;
  }

  Future<void> cacheGroupImage(
    String groupId,
    String filePath,
    Uint8List imageBytes,
  ) async {
    developer.log('Caching image for group $groupId with file path: $filePath');

    final dir = await _getLocalImageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'group_${groupId}_$timestamp.jpg';
    final localPath = '$dir/$fileName';

    final file = File(localPath);
    await file.writeAsBytes(imageBytes);

    final cacheData = ImageCacheData(
      filePath: filePath,
      localPath: localPath,
      cachedAt: DateTime.now(),
    );

    final data = jsonEncode(cacheData.toJson());
    await saveData('$_groupImagePrefix$groupId', data);
    developer.log('Cached image for group: $groupId at local path: $localPath');
  }

  Future<ImageCacheData?> getCachedGroupImage(String groupId) async {
    final data = await getData('$_groupImagePrefix$groupId');
    if (data == null) return null;

    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final cacheData = ImageCacheData.fromJson(decoded);
      if (!_isCacheValid(cacheData)) {
        await deleteData('$_groupImagePrefix$groupId');
        return null;
      }
      return cacheData;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getGroupImageLocalPath(String groupId) async {
    final cacheData = await getCachedGroupImage(groupId);
    return cacheData?.localPath;
  }

  Future<String?> getGroupImageFilePath(String groupId) async {
    final cacheData = await getCachedGroupImage(groupId);
    return cacheData?.filePath;
  }

  Future<bool> shouldRefreshGroupImage(
    String groupId,
    String newFilePath,
  ) async {
    final cacheData = await getCachedGroupImage(groupId);
    if (cacheData == null) return true;
    return cacheData.filePath != newFilePath;
  }

  Future<void> cacheCurrentUserAvatar(
    String filePath,
    Uint8List imageBytes,
  ) async {
    developer.log('Caching current user avatar with file path: $filePath');

    final dir = await _getLocalImageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'current_user_$timestamp.jpg';
    final localPath = '$dir/$fileName';

    final file = File(localPath);
    await file.writeAsBytes(imageBytes);

    final cacheData = ImageCacheData(
      filePath: filePath,
      localPath: localPath,
      cachedAt: DateTime.now(),
    );

    final data = jsonEncode(cacheData.toJson());
    await saveData(_currentUserAvatarKey, data);
    developer.log('Cached current user avatar at local path: $localPath');
  }

  Future<ImageCacheData?> getCachedCurrentUserAvatar() async {
    final data = await getData(_currentUserAvatarKey);
    if (data == null) return null;

    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final cacheData = ImageCacheData.fromJson(decoded);
      if (!_isCacheValid(cacheData)) {
        await deleteData(_currentUserAvatarKey);
        return null;
      }
      return cacheData;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getCurrentUserAvatarLocalPath() async {
    final cacheData = await getCachedCurrentUserAvatar();
    return cacheData?.localPath;
  }

  Future<String?> getCurrentUserAvatarFilePath() async {
    final cacheData = await getCachedCurrentUserAvatar();
    return cacheData?.filePath;
  }

  Future<bool> shouldRefreshCurrentUserAvatar(String newFilePath) async {
    final cacheData = await getCachedCurrentUserAvatar();
    if (cacheData == null) return true;
    return cacheData.filePath != newFilePath;
  }

  bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    return url.startsWith('http://') || url.startsWith('https://');
  }
}
