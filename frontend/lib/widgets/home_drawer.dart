import 'package:flutter/material.dart';

import '../core/theme/mitron_colors.dart';
import '../core/utils/platform_image_provider.dart';
import '../models/auth_user.dart';
import '../features/friends/friends_list_page.dart';
import '../features/groups/group_list_page.dart';
import '../features/settings/settings_page.dart';
import '../features/users/profile/user_profile_page.dart';
import '../features/users/search/user_search_page.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
    required this.user,
    required this.avatarFuture,
    required this.onSignOut,
  });

  final AuthUser user;
  final Future<String?> avatarFuture;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            decoration: BoxDecoration(
              gradient: mc.authBackgroundGradient(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String?>(
                  future: avatarFuture,
                  builder: (context, snapshot) {
                    final avatarPath = snapshot.data;
                    if (avatarPath != null && avatarPath.isNotEmpty) {
                      return CircleAvatar(
                        radius: 30,
                        backgroundImage: platformImageProvider(avatarPath),
                      );
                    }
                    return CircleAvatar(
                      radius: 30,
                      backgroundColor: scheme.primary.withValues(alpha: 0.2),
                      child: Icon(Icons.person, size: 36, color: scheme.primary),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  user.displayName.isEmpty ? user.username : user.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mc.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.home_outlined,
            label: 'Home',
            onTap: () => Navigator.of(context).pop(),
          ),
          _DrawerItem(
            icon: Icons.search,
            label: 'Search Users',
            onTap: () =>
                Navigator.of(context).pushNamed(UserSearchPage.routeName),
          ),
          _DrawerItem(
            icon: Icons.people_outline,
            label: 'Friends',
            onTap: () =>
                Navigator.of(context).pushNamed(FriendsListPage.routeName),
          ),
          _DrawerItem(
            icon: Icons.groups_outlined,
            label: 'Groups',
            onTap: () =>
                Navigator.of(context).pushNamed(GroupListPage.routeName),
          ),
          _DrawerItem(
            icon: Icons.person_outline,
            label: 'My Profile',
            onTap: () => Navigator.of(
              context,
            ).pushNamed(UserProfilePage.routeName, arguments: user.username),
          ),
          _DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () =>
                Navigator.of(context).pushNamed(SettingsPage.routeName),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: onTap,
    );
  }
}
