import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/home_drawer.dart';
import '../../widgets/mitron_app_bar.dart';
import '../../widgets/mitron_icons.dart';
import '../auth/login_page.dart';
import '../friends/friends_list_page.dart';
import '../notifications/notifications_page.dart';
import '../settings/settings_page.dart';
import '../users/search/user_search_page.dart';
import 'placeholder_home_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  static const String routeName = '/home';

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _tabIndex = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.setUnreadCountListener((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !AuthService.instance.isAuthenticated) return;
      NotificationService.instance.getUnreadCount();
    });
  }

  Future<String?> _getCurrentUserAvatarUrl() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;

    final localPath = await CacheService.instance.getUserAvatarLocalPath(
      user.id,
    );
    if (localPath != null) return localPath;

    final profile = await AuthService.instance.getUserProfile(user.username);
    return profile.avatarUrl;
  }

  PreferredSizeWidget _buildAppBar() {
    switch (_tabIndex) {
      case 0:
        return MitronAppBar(
          title: 'Mitron',
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
          ],
        );
      case 1:
        return const MitronAppBar(title: 'Search');
      case 2:
        return const MitronAppBar(title: 'Friends');
      case 3:
        return const MitronAppBar(title: 'Settings');
      default:
        return const MitronAppBar(title: 'Mitron');
    }
  }

  void _onTabSelected(int index) => setState(() => _tabIndex = index);

  Widget _buildBottomNav(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BottomNavigationBar(
      currentIndex: _tabIndex,
      onTap: _onTabSelected,
      type: BottomNavigationBarType.fixed,
      backgroundColor: scheme.surface,
      selectedItemColor: scheme.primary,
      unselectedItemColor: scheme.onSurfaceVariant,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      iconSize: 24,
      items: [
        BottomNavigationBarItem(
          icon: Icon(MitronIcons.home),
          activeIcon: Icon(MitronIcons.homeFilled),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(MitronIcons.search),
          activeIcon: Icon(MitronIcons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(MitronIcons.friends),
          activeIcon: Icon(MitronIcons.friendsFilled),
          label: 'Friends',
        ),
        BottomNavigationBarItem(
          icon: Icon(MitronIcons.settings),
          activeIcon: Icon(MitronIcons.settingsFilled),
          label: 'Settings',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          LoginPage.routeName,
          (route) => false,
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = AuthService.instance.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      drawer: _tabIndex == 0 && user != null
          ? HomeDrawer(
              user: user,
              avatarFuture: _getCurrentUserAvatarUrl(),
              onSignOut: () async {
                await AuthService.instance.logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    LoginPage.routeName,
                    (route) => false,
                  );
                }
              },
            )
          : null,
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: _tabIndex,
          children: const [
            PlaceholderHomePage(shellMode: true),
            UserSearchPage(shellMode: true),
            FriendsListPage(shellMode: true),
            SettingsPage(shellMode: true),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildBottomNav(context),
      ),
    );
  }
}
