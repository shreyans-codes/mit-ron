import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mitron_theme.dart';
import 'theme_variant.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._(this._prefs, this._variant);

  static const _storageKey = 'mitron_theme_variant';

  final SharedPreferences _prefs;
  AppThemeVariant _variant;

  AppThemeVariant get variant => _variant;

  ThemeData get themeData => MitronTheme.build(_variant);

  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    final initial = AppThemeVariant.fromStorage(stored);
    return ThemeController._(prefs, initial);
  }

  Future<void> setVariant(AppThemeVariant value) async {
    if (_variant == value) return;
    _variant = value;
    await _prefs.setString(_storageKey, value.name);
    notifyListeners();
  }
}
