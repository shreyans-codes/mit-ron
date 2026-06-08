import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;

import 'core/theme/app_theme_scope.dart';
import 'core/theme/theme_controller.dart';
import 'services/auth_service.dart';
import 'core/constants/api_constants.dart';
import 'features/auth/login_page.dart';
import 'features/auth/signup_page.dart';
import 'features/friends/friends_list_page.dart'; // Import FriendsListPage
import 'features/groups/create_group_page.dart'; // Import CreateGroupPage
import 'features/groups/group_details_page.dart'; // Import GroupDetailsPage
import 'features/groups/group_list_page.dart'; // Import GroupListPage
import 'features/groups/join_group_page.dart'; // Import JoinGroupPage
import 'features/settings/settings_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'models/group.dart';
import 'features/settings/update_profile_page.dart';
import 'features/users/profile/user_profile_page.dart'; // Import UserProfilePage
import 'features/users/search/user_search_page.dart'; // Import UserSearchPage
import 'features/shell/main_shell_page.dart';

import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'services/realtime/supabase_realtime_service.dart';
import 'features/notifications/notifications_page.dart'; // Import CacheService

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  debugPrint('FCM Project ID: ${ApiConstants.fcmProjectId}');
  debugPrint('Base URL: ${ApiConstants.baseUrl}');

  // Initialize Firebase (required for FCM)
  if (ApiConstants.fcmProjectId.isNotEmpty) {
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  // Realtime uses the anon key (RLS disabled on subscribed tables). Do not pass
  // the backend JWT here — Supabase validates it with its own JWT rules and
  // rejects it (InvalidJWT / exp), which breaks Realtime and can log users out.
  await Supabase.initialize(
    url: ApiConstants.supabaseUrl,
    anonKey: ApiConstants.supabaseAnonKey,
  );

  // Initialize services
  final themeController = await ThemeController.load();
  await AuthService.instance.init();

  AuthService.instance.on401Redirect = () {
    debugPrint('401 received, redirecting to login');
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      LoginPage.routeName,
      (route) => false,
    );
  };

  await CacheService.instance.init();

  // Initialize Notification Service
  await NotificationService.instance.initialize();
  NotificationService.instance.setRealtimeService(SupabaseRealtimeService());
  if (!kIsWeb) {
    await NotificationService.instance.ensurePushRegistration();
  }

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
            navigatorKey: navigatorKey,
            title: 'Mitron',
            debugShowCheckedModeBanner: false,
            theme: themeController.themeData,
            builder: (context, child) {
              if (kIsWeb) {
                final shortestSide = MediaQuery.sizeOf(context).shortestSide;
                final isMobileWeb = shortestSide < 600;
                if (!isMobileWeb) {
                  return const _MobileWebOnlyScreen();
                }
              }
              return child ?? const SizedBox.shrink();
            },
            initialRoute: isAuthenticated
                ? MainShellPage.routeName
                : LoginPage.routeName,
            onGenerateRoute: (settings) {
              // Handle onboarding route
              if (settings.name == OnboardingPage.routeName) {
                return MaterialPageRoute(
                  builder: (_) => const OnboardingPage(),
                );
              }
              return null;
            },
            routes: {
              LoginPage.routeName: (_) => const LoginPage(),
              SignUpPage.routeName: (_) => const SignUpPage(),
              SettingsPage.routeName: (_) => const SettingsPage(),
              UpdateProfilePage.routeName: (_) => const UpdateProfilePage(),
              MainShellPage.routeName: (_) => const MainShellPage(),
              OnboardingPage.routeName: (_) => const OnboardingPage(),
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
              GroupDetailsPage.routeName: (context) {
                final args = ModalRoute.of(context)!.settings.arguments;
                if (args is Group) {
                  return GroupDetailsPage(group: args);
                }
                return GroupDetailsPage(
                  group: Group(
                    id: '',
                    name: '',
                    creatorId: '',
                    createdAt: DateTime.now(),
                  ),
                );
              },
              NotificationsPage.routeName: (_) => const NotificationsPage(),
            },
          );
        },
      ),
    );
  }
}

class _MobileWebOnlyScreen extends StatelessWidget {
  const _MobileWebOnlyScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_iphone_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Open Mitron on mobile web',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This web build shares the same mobile app UI and is available on phone-sized browsers only.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
