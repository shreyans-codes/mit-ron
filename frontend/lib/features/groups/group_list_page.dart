// frontend/lib/features/groups/group_list_page.dart
import 'package:flutter/material.dart';
import 'package:mitron/models/group.dart';
import 'package:mitron/services/auth_service.dart';
import 'package:mitron/services/cache_service.dart'; // Import CacheService
import 'create_group_page.dart'; // Import CreateGroupPage
import 'join_group_page.dart';   // Import JoinGroupPage

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  static const routeName = '/groups';

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<Group> _groups = [];
  bool _isLoading = true;
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
      // Check cache first
      final cachedGroups = await AuthService.instance.getCachedGroups();
      if (cachedGroups.isNotEmpty) {
        setState(() {
          _groups = cachedGroups;
          _isLoading = false;
        });
        // Optionally, still fetch from network to refresh data if cache is stale
        // For now, just use cache if available.
        return;
      }

      final groups = await AuthService.instance.getMyGroups();
      setState(() {
        _groups = groups;
      });
      // Cache the fetched groups if successful
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final createdGroup = await Navigator.of(context).pushNamed(CreateGroupPage.routeName);
              if (createdGroup != null && createdGroup is Group && mounted) {
                // Refresh the list if a group was created
                _fetchGroups();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Group "${createdGroup.name}" created!')),
                );
              }
            },
            tooltip: 'Create Group',
          ),
          IconButton(
            icon: const Icon(Icons.join_ளுக்கான), // Icon for joining a group
            onPressed: () async {
              final joined = await Navigator.of(context).pushNamed(JoinGroupPage.routeName);
              if (joined != null && joined is bool && joined && mounted) {
                // Refresh the list if joining was successful (assuming join returns bool true)
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
                  ? const Center(child: Text('You are not in any groups yet. Create or join one!'))
                  : ListView.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(group.name),
                            subtitle: Text(group.description ?? 'No description provided.'),
                            trailing: Text('Members: ${group.memberCount}'),
                            onTap: () {
                              // TODO: Navigate to Group Details screen
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('View details of ${group.name}')),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
