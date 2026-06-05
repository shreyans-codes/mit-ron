import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/platform_image_provider.dart';
import '../../models/group.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../widgets/mitron_button.dart';
import '../../widgets/mitron_app_bar.dart';
import 'group_flairs_sheet.dart';

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
  List<Flair> _availableFlairs = [];
  bool _isLoading = true;
  String? _error;
  bool _isEditing = false;
  XFile? _selectedAvatarFile;
  String? _groupImageLocalPath;
  late Group _currentGroup;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    _loadGroupData();
  }

  Future<void> _loadGroupImageFromCache() async {
    final localPath = await CacheService.instance.getGroupImageLocalPath(widget.group.id);
    if (localPath != null && localPath.isNotEmpty && mounted) {
      setState(() {
        _groupImageLocalPath = localPath;
      });
    }
  }

  Future<void> _loadGroupData() async {
    try {
      final group = await AuthService.instance.getGroupDetailWithCache(widget.group.id);
      _currentGroup = group;
      _loadGroupImageFromCache();
      final members = await AuthService.instance.getGroupMembers(
        widget.group.id,
      );
      final flairs = await AuthService.instance.getGroupFlairs(widget.group.id);
      final currentUserId = AuthService.instance.currentUser?.id;
      members.sort((a, b) {
        if (a.id == currentUserId) return -1;
        if (b.id == currentUserId) return 1;
        return 0;
      });
      setState(() {
        _members = members;
        _availableFlairs = flairs;
        _isLoading = false;
      });
      widget.onMembersUpdated?.call();
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
          'Are you sure you want to delete "${widget.group.name}"?\n\nDeleting this group will also delete all events and messages associated with this group. This action cannot be undone.',
        ),
        actions: [
          MitronButton(
            type: MitronButtonType.text,
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          MitronButton(
            type: MitronButtonType.destructive,
            label: 'Delete',
            onPressed: () {
              Navigator.of(context).pop();
              _deleteGroup();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showManageMyFlairs(Profile member) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => GroupFlairsSheet(
        groupId: widget.group.id,
        member: member,
        availableFlairs: _availableFlairs,
        onUpdated: _loadGroupData,
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
          _loadGroupData();
          widget.onMembersUpdated?.call();
        },
      ),
    );
  }

  void _showKickMemberDialog(Profile member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${member.displayName} from "${widget.group.name}"?',
        ),
        actions: [
          MitronButton(
            type: MitronButtonType.text,
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          MitronButton(
            type: MitronButtonType.destructive,
            label: 'Remove',
            onPressed: () {
              Navigator.of(context).pop();
              _kickMember(member);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _kickMember(Profile member) async {
    try {
      await AuthService.instance.removeGroupMember(widget.group.id, member.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.displayName} removed from group')),
        );
        _loadGroupData();
        widget.onMembersUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove member: $e')));
      }
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _selectedAvatarFile = file);
    }
  }

  void _showEditGroupDialog() {
    final nameController = TextEditingController(text: _currentGroup.name);
    final descController = TextEditingController(
      text: _currentGroup.description,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Group'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    await _pickAvatar();
                    if (_selectedAvatarFile != null) {
                      setDialogState(() {});
                    }
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        backgroundImage:
                            platformImageProvider(_selectedAvatarFile?.path) ??
                            platformImageProvider(_groupImageLocalPath) ??
                            platformImageProvider(_currentGroup.groupImageUrl),
                        child:
                            _selectedAvatarFile == null &&
                                    _groupImageLocalPath == null &&
                                    _currentGroup.groupImageUrl == null
                            ? Text(
                                _currentGroup.name.isNotEmpty
                                    ? _currentGroup.name[0].toUpperCase()
                                    : 'G',
                                style: const TextStyle(fontSize: 32),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'Enter group name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter description (optional)',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            MitronButton(
              type: MitronButtonType.text,
              label: 'Cancel',
              onPressed: () => Navigator.pop(ctx),
            ),
            MitronButton(
              type: MitronButtonType.primary,
              label: 'Save',
              isLoading: _isEditing,
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _updateGroup(name, descController.text.trim());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateGroup(String name, String description) async {
    setState(() => _isEditing = true);
    try {
      final group = await AuthService.instance.updateGroup(
        _currentGroup.id,
        name: name,
        description: description,
        avatarFile: _selectedAvatarFile,
      );
      if (mounted) {
        setState(() {
          _currentGroup = group;
          _selectedAvatarFile = null;
        });
        widget.onMembersUpdated?.call();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Group updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update group: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isEditing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = AuthService.instance.currentUser?.id;

    return Scaffold(
      appBar: MitronAppBar(
        title: 'Group Details',
        actions: [
          if (_isCreator)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditGroupDialog(),
              tooltip: 'Edit Group',
            ),
        ],
      ),
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
                    backgroundImage:
                        platformImageProvider(_groupImageLocalPath) ??
                        platformImageProvider(_currentGroup.groupImageUrl),
                    child: _groupImageLocalPath == null && _currentGroup.groupImageUrl == null
                        ? Text(
                            _currentGroup.name.isNotEmpty
                                ? _currentGroup.name[0].toUpperCase()
                                : 'G',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentGroup.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_currentGroup.description != null &&
                      _currentGroup.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _currentGroup.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: MitronButton(
                      type: MitronButtonType.primary,
                      label: 'Add Members',
                      icon: Icons.person_add,
                      onPressed: _showAddMembersDialog,
                      fullWidth: true,
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
                      final isMemberCreator =
                          member.id == _currentGroup.creatorId;
                      return _MemberTile(
                        member: member,
                        isCurrentUser: isCurrentUser,
                        isCreator: isMemberCreator,
                        isAdmin: _isCreator,
                        onKickMember: () => _showKickMemberDialog(member),
                        onManageFlairs: isCurrentUser
                            ? () => _showManageMyFlairs(member)
                            : null,
                        showMemberMenu:
                            isCurrentUser || (_isCreator && !isCurrentUser),
                      );
                    },
                  ),
                  if (_isCreator) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: MitronButton(
                        type: MitronButtonType.destructive,
                        label: 'Delete Group',
                        icon: Icons.delete_outline,
                        onPressed: _showDeleteConfirmation,
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
  final bool isCreator;
  final bool isAdmin;
  final VoidCallback onKickMember;
  final VoidCallback? onManageFlairs;
  final bool showMemberMenu;

  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.isCreator,
    required this.isAdmin,
    required this.onKickMember,
    this.onManageFlairs,
    this.showMemberMenu = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final displayFlairs = List<Flair>.from(member.flairs);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          FutureBuilder<String?>(
            future: CacheService.instance.getUserAvatarLocalPath(member.id),
            builder: (context, snapshot) {
              final localPath = snapshot.data;
              if (localPath != null && localPath.isNotEmpty) {
                return CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary,
                  backgroundImage: platformImageProvider(localPath),
                  child: null,
                );
              }
              return CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  member.displayName.isNotEmpty
                      ? member.displayName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              );
            },
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
                if (displayFlairs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: displayFlairs.map((flair) {
                      final isAdmin = flair.name == 'Admin';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          flair.name,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isAdmin
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          if (showMemberMenu)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurface,
              ),
              offset: const Offset(0, 40),
              onSelected: (value) {
                if (value == 'kick') {
                  onKickMember();
                } else if (value == 'flairs') {
                  onManageFlairs?.call();
                }
              },
              itemBuilder: (context) => [
                if (onManageFlairs != null)
                  const PopupMenuItem(
                    value: 'flairs',
                    child: Text('Add flairs'),
                  ),
                if (isAdmin && !isCurrentUser)
                  PopupMenuItem(
                    value: 'kick',
                    child: Text(
                      'Kick member',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
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
