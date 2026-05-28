// frontend/lib/features/friends/friends_list_page.dart
import 'package:flutter/material.dart';
import 'package:mitron/core/utils/platform_image_provider.dart';
import 'package:mitron/models/friend_lists.dart';
import 'package:mitron/models/profile.dart';
import 'package:mitron/services/auth_service.dart';
import 'package:mitron/services/cache_service.dart';
import '../users/search/user_search_page.dart';
import '../users/profile/user_profile_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  static const routeName = '/friends';

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  FriendLists? _lists;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lists = await AuthService.instance.getFriendLists();
      setState(() {
        _lists = lists;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _respond(PendingFriendProfile pending, bool accept) async {
    try {
      await AuthService.instance.respondToFriendRequest(
        initiatorId: pending.initiatorId,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Request accepted' : 'Request declined'),
        ),
      );
      await _fetchFriends();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _profileTile(Profile profile, {List<Widget>? trailing}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: FutureBuilder<String?>(
          future: CacheService.instance.getUserAvatarLocalPath(profile.id),
          builder: (context, snapshot) {
            final localPath = snapshot.data;
            if (localPath != null && localPath.isNotEmpty) {
              return CircleAvatar(
                backgroundImage: platformImageProvider(localPath),
                child: null,
              );
            }
            return CircleAvatar(child: const Icon(Icons.person));
          },
        ),
        title: Text(
          profile.displayName.isEmpty ? profile.username : profile.displayName,
        ),
        subtitle: Text('@${profile.username}'),
        trailing: trailing != null && trailing.isNotEmpty
            ? Row(mainAxisSize: MainAxisSize.min, children: trailing)
            : null,
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(UserProfilePage.routeName, arguments: profile.username);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).pushNamed(UserSearchPage.routeName);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text('Error: $_errorMessage'))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final lists = _lists!;
    final hasAny =
        lists.friends.isNotEmpty ||
        lists.pendingIncoming.isNotEmpty ||
        lists.pendingOutgoing.isNotEmpty;

    if (!hasAny) {
      return const Center(child: Text('You have no friends yet. Add some!'));
    }

    return RefreshIndicator(
      onRefresh: _fetchFriends,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (lists.pendingIncoming.isNotEmpty) ...[
            _sectionHeader('Requests for you'),
            ...lists.pendingIncoming.map(
              (p) => _profileTile(
                p.profile,
                trailing: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _respond(p, false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _respond(p, true),
                  ),
                ],
              ),
            ),
          ],
          if (lists.pendingOutgoing.isNotEmpty) ...[
            _sectionHeader('Waiting for response'),
            ...lists.pendingOutgoing.map(
              (p) => _profileTile(
                p.profile,
                trailing: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'Pending',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (lists.friends.isNotEmpty) ...[
            _sectionHeader('Friends'),
            ...lists.friends.map((p) => _profileTile(p)),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
