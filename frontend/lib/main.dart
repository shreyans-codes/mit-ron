import 'package:flutter/material.dart';

import 'core/theme/app_theme_scope.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/login_page.dart';
import 'features/auth/signup_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/update_profile_page.dart';
import 'features/shell/placeholder_home_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final themeController = await ThemeController.load();
  await AuthService.instance.init();
  
  runApp(MitronApp(themeController: themeController));
}

class MitronApp extends StatelessWidget {
  const MitronApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService.instance.isAuthenticated;

    return AppThemeScope(
      controller: themeController,
      child: ListenableBuilder(
        listenable: themeController,
        builder: (_, _) {
          return MaterialApp(
            title: 'Mitron',
            debugShowCheckedModeBanner: false,
            theme: themeController.themeData,
            initialRoute: isAuthenticated ? PlaceholderHomePage.routeName : LoginPage.routeName,
            routes: {
              LoginPage.routeName: (_) => const LoginPage(),
              SignUpPage.routeName: (_) => const SignUpPage(),
              SettingsPage.routeName: (_) => const SettingsPage(),
              UpdateProfilePage.routeName: (_) => const UpdateProfilePage(),
              PlaceholderHomePage.routeName: (_) => const PlaceholderHomePage(),
            },
          );
        },
      ),
    );
  }
}
