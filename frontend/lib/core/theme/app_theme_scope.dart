import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// Provides [ThemeController] below the app root so any screen can change theme.
class AppThemeScope extends InheritedNotifier<ThemeController> {
  const AppThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope not found in widget tree');
    return scope!.notifier!;
  }
}
