// frontend/lib/services/cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer; // Import dart:developer for log

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  // Initialize SharedPreferences
  static SharedPreferences? _prefs;

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
}
