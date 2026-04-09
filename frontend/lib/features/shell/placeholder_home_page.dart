import 'package:flutter/material.dart';

import '../../core/theme/mitron_colors.dart';
import '../../models/auth_session.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../widgets/app_version_footer.dart';
import '../../widgets/auth_token_footer.dart';
import '../auth/login_page.dart';
import '../friends/friends_list_page.dart';
import '../groups/group_list_page.dart';
import '../settings/settings_page.dart';
import '../users/profile/user_profile_page.dart';
import '../users/search/user_search_page.dart';

/// Landing screen after auth succeeds. Replace with main app shell.
class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key, this.session});

  static const String routeName = '/home';

  final AuthSession? session;

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
                    future: CacheService.instance.getCachedCurrentUserAvatar(),
                    builder: (context, snapshot) {
                      final avatarUrl = snapshot.data ?? user.profilePictureUrl;
                      final cacheService = CacheService.instance;
                      if (avatarUrl != null &&
                          cacheService.isValidUrl(avatarUrl)) {
                        return CircleAvatar(
                          backgroundImage: NetworkImage(avatarUrl),
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
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search Users'),
              onTap: () {
                Navigator.of(context).pushNamed(UserSearchPage.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Friends'),
              onTap: () {
                Navigator.of(context).pushNamed(FriendsListPage.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Groups'),
              onTap: () {
                Navigator.of(context).pushNamed(GroupListPage.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.of(context).pushNamed(
                  UserProfilePage.routeName,
                  arguments: user.username,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pushNamed(SettingsPage.routeName);
              },
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
                    'Use the menu to search users, friends, groups, and settings. '
                    'Your session token for debugging is pinned at the bottom.',
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
            padding: const EdgeInsets.fromLTRB(24, 12, 8, 4),
            child: const AuthTokenFooter(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: SizedBox(width: double.infinity, child: AppVersionFooter()),
          ),
        ],
      ),
    );
  }
}
