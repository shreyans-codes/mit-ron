import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  Future<void> saveData(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    log.fine('Data saved to cache for key: $key');
  }

  Future<String?> getData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data != null) {
      log.fine('Data retrieved from cache for key: $key');
    } else {
      log.fine('No data found in cache for key: $key');
    }
    return data;
  }

  Future<void> deleteData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    log.fine('Data deleted from cache for key: $key');
  }
}
