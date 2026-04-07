import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../models/profile.dart';
import '../../models/friend_lists.dart';
import '../../services/auth_service.dart';

class GroupDetailsPage extends StatefulWidget {
  final Group group;
  final VoidCallback? onMembersUpdated;
  final VoidCallback? onGroupDeleted;
  const GroupDetailsPage({
    super.key,
    required this.group,
    this.onMembersUpdated,
    this.onGroupDeleted,
  });

  static const String routeName = '/group-details';

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  List<Profile> _members = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await AuthService.instance.getGroupMembers(
        widget.group.id,
      );
      final currentUserId = AuthService.instance.currentUser?.id;
      members.sort((a, b) {
        if (a.id == currentUserId) return -1;
        if (b.id == currentUserId) return 1;
        return 0;
      });
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool get _isCreator {
    final currentUserId = AuthService.instance.currentUser?.id;
    return currentUserId == widget.group.creatorId;
  }

  Future<void> _deleteGroup() async {
    try {
      await AuthService.instance.deleteGroup(widget.group.id);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        widget.onGroupDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete group: $e')));
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Are you sure you want to delete "${widget.group.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteGroup();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddMembersDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddMembersSheet(
        groupId: widget.group.id,
        currentMembers: _members,
        onMemberAdded: () {
          _loadMembers();
          widget.onMembersUpdated?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = AuthService.instance.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      widget.group.name.isNotEmpty
                          ? widget.group.name[0].toUpperCase()
                          : 'G',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.group.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.group.description != null &&
                      widget.group.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.group.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showAddMembersDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Members'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Members',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isCurrentUser = member.id == currentUserId;
                      return _MemberTile(
                        member: member,
                        isCurrentUser: isCurrentUser,
                      );
                    },
                  ),
                  if (_isCreator) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showDeleteConfirmation,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Group'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Profile member;
  final bool isCurrentUser;

  const _MemberTile({required this.member, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(color: theme.colorScheme.onPrimary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isCurrentUser
                          ? '${member.displayName} (You)'
                          : member.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (member.flairs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: member.flairs.map((flair) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          flair.name,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMembersSheet extends StatefulWidget {
  final String groupId;
  final List<Profile> currentMembers;
  final VoidCallback onMemberAdded;

  const _AddMembersSheet({
    required this.groupId,
    required this.currentMembers,
    required this.onMemberAdded,
  });

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Profile> _friends = [];
  List<Profile> _filteredFriends = [];
  bool _isLoading = true;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friendLists = await AuthService.instance.getFriendLists();
      final memberIds = widget.currentMembers.map((m) => m.id).toSet();
      final availableFriends = friendLists.friends
          .where((f) => !memberIds.contains(f.id))
          .toList();
      setState(() {
        _friends = availableFriends;
        _filteredFriends = availableFriends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load friends: $e')));
      }
    }
  }

  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((f) {
          final name = f.displayName.toLowerCase();
          final username = f.username.toLowerCase();
          final search = query.toLowerCase();
          return name.contains(search) || username.contains(search);
        }).toList();
      }
    });
  }

  Future<void> _addMember(Profile friend) async {
    setState(() => _isAdding = true);
    try {
      await AuthService.instance.addGroupMember(widget.groupId, friend.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friend.displayName} added to group')),
        );
        widget.onMemberAdded();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add member: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Members',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search friends...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: _filterFriends,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _friends.isEmpty
                              ? 'No friends to add'
                              : 'No matching friends',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredFriends.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final friend = _filteredFriends[index];
                      return _FriendTile(
                        friend: friend,
                        isAdding: _isAdding,
                        onAdd: () => _addMember(friend),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Profile friend;
  final bool isAdding;
  final VoidCallback onAdd;

  const _FriendTile({
    required this.friend,
    required this.isAdding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: friend.avatarUrl != null
                ? NetworkImage(friend.avatarUrl!)
                : null,
            child: friend.avatarUrl == null
                ? Text(
                    friend.displayName.isNotEmpty
                        ? friend.displayName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(color: theme.colorScheme.onPrimary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '@${friend.username}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: isAdding ? null : onAdd,
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
    );
  }
}
