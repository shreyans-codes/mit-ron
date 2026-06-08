import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/mitron_colors.dart';
import '../../models/auth_session.dart';
import '../../models/event.dart';
import '../../models/group.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/group_avatar.dart';
import '../../widgets/home_drawer.dart';
import '../../widgets/mitron_app_bar.dart';
import '../auth/login_page.dart';
import '../groups/group_chat_page.dart';
import '../groups/group_list_page.dart';
import '../notifications/notifications_page.dart';
import '../onboarding/onboarding_page.dart';

class PlaceholderHomePage extends StatefulWidget {
  const PlaceholderHomePage({super.key, this.session, this.shellMode = false});

  static const String routeName = '/home';

  final AuthSession? session;
  final bool shellMode;

  @override
  State<PlaceholderHomePage> createState() => _PlaceholderHomePageState();
}

class _EventWithGroup {
  const _EventWithGroup({required this.event, required this.group});

  final Event event;
  final Group group;
}

class _PlaceholderHomePageState extends State<PlaceholderHomePage> {
  int _unreadCount = 0;
  List<Group> _groups = [];
  List<_EventWithGroup> _events = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (!widget.shellMode) {
      NotificationService.instance.setUnreadCountListener((count) {
        if (mounted) setState(() => _unreadCount = count);
      });
    }
    _initialize();
  }

  Future<void> _initialize() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (kIsWeb) {
        await NotificationService.instance.setOnboardingComplete();
      } else {
        final hasOnboarded =
            await NotificationService.instance.hasCompletedOnboarding();
        if (!hasOnboarded) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              OnboardingPage.routeName,
            );
          }
          return;
        }
      }

      await _loadRealtimeData();
      await _loadHomeData();
    });
  }

  Future<void> _loadRealtimeData() async {
    await NotificationService.instance.getUnreadCount();
    if (!kIsWeb) {
      await NotificationService.instance.ensurePushRegistration();
    }
    final user = AuthService.instance.currentUser;
    if (user != null) {
      await NotificationService.instance.startRealtimeSubscription(user.id);
    }
  }

  Future<void> _loadHomeData() async {
    if (!AuthService.instance.isAuthenticated) {
      _redirectToLogin();
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final cachedGroups = await AuthService.instance.getCachedGroups();
      if (cachedGroups.isNotEmpty && mounted) {
        setState(() {
          _groups = cachedGroups;
          _loading = false;
        });
        _loadEventsForGroups(cachedGroups);
      }

      final groups = await AuthService.instance.refreshGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
      await _loadEventsForGroups(groups);
    } catch (e) {
      if (!mounted) return;
      if (!AuthService.instance.isAuthenticated) {
        _redirectToLogin();
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadEventsForGroups(List<Group> groups) async {
    if (groups.isEmpty) {
      if (mounted) setState(() => _events = []);
      return;
    }

    try {
      final results = await Future.wait(
        groups.map((group) => AuthService.instance.getEvents(group.id)),
      );

      final events = <_EventWithGroup>[];
      for (var i = 0; i < groups.length; i++) {
        for (final event in results[i]) {
          events.add(_EventWithGroup(event: event, group: groups[i]));
        }
      }

      events.sort((a, b) {
        final aTime = _parseActivityTime(
          a.event.lastActivityAt,
          a.event.createdAt,
        );
        final bTime = _parseActivityTime(
          b.event.lastActivityAt,
          b.event.createdAt,
        );
        return bTime.compareTo(aTime);
      });

      if (mounted) setState(() => _events = events);
    } catch (e) {
      debugPrint('Failed to load events: $e');
    }
  }

  DateTime _parseActivityTime(String? activityAt, DateTime fallback) {
    if (activityAt == null || activityAt.isEmpty) return fallback;
    return DateTime.tryParse(activityAt) ?? fallback;
  }

  void _redirectToLogin() {
    if (widget.shellMode) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      LoginPage.routeName,
      (route) => false,
    );
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

  String _formatLastActivity(String? timestamp, DateTime fallback) {
    final dt = timestamp != null && timestamp.isNotEmpty
        ? DateTime.tryParse(timestamp)
        : null;
    final resolved = dt ?? fallback;
    final diff = DateTime.now().difference(resolved);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }

  Future<void> _openGroupChat(Group group) async {
    await AuthService.instance.updateCachedGroupUnreadCount(group.id, 0);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupChatPage(group: group),
      ),
    );
    if (!mounted) return;
    await _loadHomeData();
  }

  Future<void> _openEventChat(_EventWithGroup item) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventChatPage(
          event: item.event,
          group: item.group,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    final user = AuthService.instance.currentUser;

    if (user == null) {
      if (!widget.shellMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _redirectToLogin());
      }
      return const Center(child: CircularProgressIndicator());
    }

    final homeBody = _loading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
        ? Center(child: Text('Error: $_errorMessage'))
        : RefreshIndicator(
            onRefresh: _loadHomeData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Hi, ${user.displayName.isEmpty ? user.username : user.displayName}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your groups and events',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: mc.brandSubtitle,
                  ),
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Groups',
                  actionLabel: 'See all',
                  onAction: () =>
                      Navigator.of(context).pushNamed(GroupListPage.routeName),
                ),
                const SizedBox(height: 12),
                if (_groups.isEmpty)
                  _EmptySection(message: 'No groups yet. Create or join one!')
                else
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _groups.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return _GroupTile(
                          group: group,
                          onTap: () => _openGroupChat(group),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 32),
                _SectionHeader(title: 'Events'),
                const SizedBox(height: 12),
                if (_events.isEmpty)
                  _EmptySection(
                    message: 'No events yet. Start one in a group chat.',
                  )
                else
                  ..._events.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EventRow(
                        item: item,
                        activityLabel: _formatLastActivity(
                          item.event.lastActivityAt,
                          item.event.createdAt,
                        ),
                        onTap: () => _openEventChat(item),
                      ),
                    ),
                  ),
              ],
            ),
          );

    if (widget.shellMode) return homeBody;

    return Scaffold(
      appBar: MitronAppBar(
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
      ),
      drawer: HomeDrawer(
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
      ),
      body: homeBody,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: mc.brandSubtitle,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: mc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: mc.textMuted,
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.onTap});

  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: mc.cardSurface,
      elevation: 2,
      shadowColor: mc.cardShadow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: mc.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GroupAvatar(group: group, radius: 26),
                  if (group.unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: mc.cardSurface, width: 2),
                        ),
                        child: Text(
                          group.unreadCount > 9 ? '9+' : '${group.unreadCount}',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                group.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.item,
    required this.activityLabel,
    required this.onTap,
  });

  final _EventWithGroup item;
  final String activityLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final event = item.event;

    return Material(
      color: mc.cardSurface,
      elevation: 2,
      shadowColor: mc.cardShadow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: mc.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              GroupAvatar(group: item.group, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Group: ${item.group.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mc.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                activityLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
