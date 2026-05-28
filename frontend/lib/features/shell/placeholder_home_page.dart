import 'package:flutter/material.dart';

import '../../core/theme/mitron_colors.dart';
import '../../core/utils/platform_image_provider.dart';
import '../../models/auth_session.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_version_footer.dart';
import '../../widgets/auth_token_footer.dart';
import '../auth/login_page.dart';
import '../friends/friends_list_page.dart';
import '../groups/group_list_page.dart';
import '../settings/settings_page.dart';
import '../users/profile/user_profile_page.dart';
import '../users/search/user_search_page.dart';
import '../notifications/notifications_page.dart';
import '../onboarding/onboarding_page.dart';

class PlaceholderHomePage extends StatefulWidget {
  const PlaceholderHomePage({super.key, this.session});

  static const String routeName = '/home';

  final AuthSession? session;

  @override
  State<PlaceholderHomePage> createState() => _PlaceholderHomePageState();
}

class _PlaceholderHomePageState extends State<PlaceholderHomePage> {
  int _unreadCount = 0;
  bool _checkedOnboarding = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.setUnreadCountListener((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Check onboarding status after a brief delay to let the page build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final hasOnboarded = await NotificationService.instance
          .hasCompletedOnboarding();
      if (hasOnboarded) {
        setState(() => _checkedOnboarding = true);
        await _loadRealtimeData();
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(OnboardingPage.routeName);
        }
      }
    });
  }

  Future<void> _loadRealtimeData() async {
    await NotificationService.instance.getUnreadCount();
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await NotificationService.instance.startRealtimeSubscription(user.id);
    }
  }

  Future<String?> _getCurrentUserAvatarUrl() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;

    final localPath = await CacheService.instance.getUserAvatarLocalPath(
      user.id,
    );
    if (localPath != null) {
      return localPath;
    }

    final profile = await AuthService.instance.getUserProfile(user.username);
    return profile.avatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    final user = AuthService.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitron'),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(NotificationsPage.routeName);
                },
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(UserSearchPage.routeName);
            },
            icon: const Icon(Icons.search),
            tooltip: 'Search Users',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(SettingsPage.routeName);
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String?>(
                    future: _getCurrentUserAvatarUrl(),
                    builder: (context, snapshot) {
                      final avatarPath = snapshot.data;
                      if (avatarPath != null && avatarPath.isNotEmpty) {
                        return CircleAvatar(
                          backgroundImage: platformImageProvider(avatarPath),
                          radius: 30,
                        );
                      }
                      return const CircleAvatar(
                        radius: 30,
                        child: Icon(Icons.person, size: 40),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.displayName.isEmpty ? user.username : user.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search Users'),
              onTap: () =>
                  Navigator.of(context).pushNamed(UserSearchPage.routeName),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Friends'),
              onTap: () =>
                  Navigator.of(context).pushNamed(FriendsListPage.routeName),
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Groups'),
              onTap: () =>
                  Navigator.of(context).pushNamed(GroupListPage.routeName),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Profile'),
              onTap: () => Navigator.of(
                context,
              ).pushNamed(UserProfilePage.routeName, arguments: user.username),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () =>
                  Navigator.of(context).pushNamed(SettingsPage.routeName),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.instance.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      LoginPage.routeName,
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${user.displayName.isEmpty ? user.username : user.displayName}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: mc.textMuted),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Use the menu to search users, friends, groups, and settings.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: mc.brandSubtitle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const AuthTokenFooter(), const AppVersionFooter()],
            ),
          ),
        ],
      ),
    );
  }
}
