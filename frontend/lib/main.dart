import 'package:flutter/material.dart';

import 'core/theme/app_theme_scope.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/login_page.dart';
import 'features/auth/signup_page.dart';
import 'features/friends/friends_list_page.dart'; // Import FriendsListPage
import 'features/groups/create_group_page.dart'; // Import CreateGroupPage
import 'features/groups/group_info_page.dart'; // Import GroupInfoPage
import 'features/groups/group_list_page.dart'; // Import GroupListPage
import 'features/groups/join_group_page.dart'; // Import JoinGroupPage
import 'features/settings/settings_page.dart';
import 'models/group.dart';
import 'features/settings/update_profile_page.dart';
import 'features/users/profile/user_profile_page.dart'; // Import UserProfilePage
import 'features/users/search/user_search_page.dart'; // Import UserSearchPage
import 'features/shell/placeholder_home_page.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart'; // Import CacheService

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final themeController = await ThemeController.load();
  await AuthService.instance.init();
  await CacheService.instance.init(); // Initialize CacheService

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
            initialRoute: isAuthenticated
                ? PlaceholderHomePage.routeName
                : LoginPage.routeName,
            routes: {
              LoginPage.routeName: (_) => const LoginPage(),
              SignUpPage.routeName: (_) => const SignUpPage(),
              SettingsPage.routeName: (_) => const SettingsPage(),
              UpdateProfilePage.routeName: (_) => const UpdateProfilePage(),
              PlaceholderHomePage.routeName: (_) => const PlaceholderHomePage(),
              UserSearchPage.routeName: (_) => const UserSearchPage(),
              UserProfilePage.routeName: (context) {
                final args = ModalRoute.of(context)!.settings.arguments;
                if (args is String) {
                  return UserProfilePage(username: args);
                }
                return const UserProfilePage(
                  username: '',
                ); // Provide a default or handle error
              },
              FriendsListPage.routeName: (_) => const FriendsListPage(),
              GroupListPage.routeName: (_) =>
                  const GroupListPage(), // Add route for GroupListPage
              CreateGroupPage.routeName: (_) =>
                  const CreateGroupPage(), // Add route for CreateGroupPage
              JoinGroupPage.routeName: (_) =>
                  const JoinGroupPage(), // Add route for JoinGroupPage
              GroupInfoPage.routeName: (context) {
                final args = ModalRoute.of(context)!.settings.arguments;
                if (args is Group) {
                  return GroupInfoPage(group: args);
                }
                return GroupInfoPage(
                  group: Group(
                    id: '',
                    name: '',
                    creatorId: '',
                    createdAt: DateTime.now(),
                  ),
                );
              },
            },
          );
        },
      ),
    );
  }
}
