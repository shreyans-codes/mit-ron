// frontend/lib/features/groups/group_list_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mitron/models/group.dart';
import 'package:mitron/services/auth_service.dart';
import 'package:mitron/services/cache_service.dart';
import 'create_group_page.dart';
import 'join_group_page.dart';
import 'group_chat_page.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  static const routeName = '/groups';

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<Group> _groups = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cachedGroups = await AuthService.instance.getCachedGroups();
      if (cachedGroups.isNotEmpty) {
        setState(() {
          _groups = cachedGroups;
          _isLoading = false;
        });
        return;
      }

      final groups = await AuthService.instance.getMyGroups();
      setState(() {
        _groups = groups;
      });
      if (groups.isNotEmpty) {
        await AuthService.instance.cacheGroups(groups);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshGroups() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final groups = await AuthService.instance.refreshGroups();
      setState(() {
        _groups = groups;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Refresh successful')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to refresh: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _updateGroupMemberCount(String groupId, int memberCount) async {
    await AuthService.instance.updateCachedGroupMemberCount(
      groupId,
      memberCount,
    );
    final updatedGroups = await AuthService.instance.getCachedGroups();
    if (mounted) {
      setState(() {
        _groups = updatedGroups;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final createdGroup = await Navigator.of(
                context,
              ).pushNamed(CreateGroupPage.routeName);
              if (!context.mounted) return;
              if (createdGroup != null && createdGroup is Group) {
                _fetchGroups();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Group "${createdGroup.name}" created!'),
                  ),
                );
              }
            },
            tooltip: 'Create Group',
          ),
          IconButton(
            icon: const Icon(Icons.group_add), // Changed to a valid icon
            onPressed: () async {
              final joined = await Navigator.of(
                context,
              ).pushNamed(JoinGroupPage.routeName);
              if (!context.mounted) return;
              if (joined != null && joined is bool && joined) {
                _fetchGroups();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Successfully joined group!')),
                );
              }
            },
            tooltip: 'Join Group',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text('Error: $_errorMessage'))
          : _groups.isEmpty
          ? const Center(
              child: Text('You are not in any groups yet. Create or join one!'),
            )
          : RefreshIndicator(
              onRefresh: _refreshGroups,
              notificationPredicate: (notification) => true,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: FutureBuilder<String?>(
                        future: CacheService.instance.getGroupImageLocalPath(
                          group.id,
                        ),
                        builder: (context, snapshot) {
                          final localPath = snapshot.data;
                          if (localPath != null && localPath.isNotEmpty) {
                            return CircleAvatar(
                              backgroundImage: FileImage(File(localPath)),
                            );
                          }
                          return CircleAvatar(
                            child: Text(
                              group.name.isNotEmpty
                                  ? group.name[0].toUpperCase()
                                  : 'G',
                            ),
                          );
                        },
                      ),
                      title: Text(group.name),
                      subtitle: Text(
                        group.description ?? 'No description provided.',
                      ),
                      trailing: Text('Members: ${group.memberCount}'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GroupChatPage(
                              group: group,
                              onMemberCountUpdated: _updateGroupMemberCount,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
