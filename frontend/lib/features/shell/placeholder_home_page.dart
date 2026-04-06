import 'package:flutter/material.dart';

import '../../core/theme/mitron_colors.dart';
import '../../models/auth_session.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_version_footer.dart';
import '../auth/login_page.dart';
import '../friends/friends_list_page.dart'; // Import FriendsListPage
import '../groups/group_list_page.dart';   // Import GroupListPage
import '../settings/settings_page.dart';
import '../settings/update_profile_page.dart';
import '../users/profile/user_profile_page.dart'; // Import UserProfilePage
import '../users/search/user_search_page.dart'; // Import UserSearchPage

/// Temporary landing screen after auth succeeds. Replace with main app shell.
class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key, this.session});

  static const String routeName = '/home';

  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    final user = AuthService.instance.currentUser;
    final token = AuthService.instance.token;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitron'),
        actions: [
          // User Search Action
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(UserSearchPage.routeName);
            },
            icon: const Icon(Icons.search),
            tooltip: 'Search Users',
          ),
          // Settings Action
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
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user.profilePictureUrl != null)
                    CircleAvatar(
                      backgroundImage: NetworkImage(user.profilePictureUrl!),
                      radius: 30,
                    )
                  else
                    const CircleAvatar(
                      child: Icon(Icons.person, size: 40),
                      radius: 30,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    user.displayName.isEmpty ? user.username : user.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                // Currently on home, so just close drawer or do nothing
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
                // Navigate to user's own profile page
                Navigator.of(context).pushNamed(
                  UserProfilePage.routeName,
                  arguments: user.username, // Pass username to profile page
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
            const Spacer(), // Pushes logout to the bottom
            Padding(
              padding: const EdgeInsets.all(16.0),
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
             const SizedBox(height: 20),
            const SizedBox(
              width: double.infinity,
              child: AppVersionFooter(),
            ),
          ],
        ),
      ),
    );
  }
}
