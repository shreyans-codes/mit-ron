import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../widgets/mitron_button.dart';
import 'group_details_page.dart';
import 'shared_chat_view.dart';

class GroupChatPage extends StatefulWidget {
  final Group group;
  const GroupChatPage({super.key, required this.group});

  static const String routeName = '/group-chat';

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage>
    with SingleTickerProviderStateMixin {
  int _memberCount = 0;
  bool _isLoadingMembers = true;
  late Group _currentGroup;
  List<Event> _events = [];
  bool _isLoadingEvents = true;
  late TabController _tabController;
  String? _currentUserId;
  bool get _isCreator => _currentUserId == _currentGroup.creatorId;

  String get _chatId => widget.group.chatId ?? widget.group.id;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    _memberCount = widget.group.memberCount;
    _currentUserId = AuthService.instance.currentUser?.id;
    _tabController = TabController(length: 2, vsync: this);
    _loadGroupDetail();
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupDetail() async {
    try {
      final group = await AuthService.instance.getGroupDetailWithCache(
        widget.group.id,
      );
      if (mounted) {
        setState(() {
          _currentGroup = group;
          _memberCount = group.memberCount;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  Future<void> _loadEvents() async {
    try {
      final events = await AuthService.instance.getEvents(widget.group.id);
      if (mounted) {
        setState(() {
          _events = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEvents = false);
      }
    }
  }

  void _showDeleteEventDialog(Event event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          MitronButton(
            type: MitronButtonType.text,
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
          MitronButton(
            type: MitronButtonType.destructive,
            label: 'Delete',
            onPressed: () {
              Navigator.pop(ctx);
              _deleteEvent(event);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(Event event) async {
    try {
      await AuthService.instance.deleteEvent(event.id);
      if (mounted) {
        setState(
          () => _events = _events.where((e) => e.id != event.id).toList(),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete event: $e')));
      }
    }
  }

  void _showEditEventDialog(Event event) {
    final titleController = TextEditingController(text: event.title);
    final descController = TextEditingController(text: event.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Event'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        content: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Event title',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          MitronButton(
            type: MitronButtonType.text,
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
          MitronButton(
            type: MitronButtonType.primary,
            label: 'Save',
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              await _updateEvent(event, title, descController.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateEvent(
    Event event,
    String title,
    String description,
  ) async {
    try {
      final updatedEvent = await AuthService.instance.updateEvent(
        event.id,
        title: title,
        description: description,
      );
      if (mounted) {
        setState(() {
          final idx = _events.indexWhere((e) => e.id == event.id);
          if (idx != -1) {
            _events[idx] = updatedEvent;
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update event: $e')));
      }
    }
  }

  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Event'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        actionsPadding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        content: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Event title',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          MitronButton(
            type: MitronButtonType.text,
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
          MitronButton(
            type: MitronButtonType.primary,
            label: 'Create',
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final event = await AuthService.instance.createEvent(
                  groupId: widget.group.id,
                  title: title,
                  description: descController.text.trim(),
                );
                if (mounted) {
                  setState(() => _events = [event, ..._events]);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GroupDetailsPage(
                group: _currentGroup,
                onMembersUpdated: _loadGroupDetail,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_currentGroup.name),
              Text(
                _isLoadingMembers ? '...' : '$_memberCount members',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        actions: [
          MitronIconButton(
            icon: Icons.add_circle_outline,
            onPressed: _showCreateEventDialog,
            tooltip: 'Create Event',
          ),
          MitronIconButton(
            icon: Icons.info_outline,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GroupDetailsPage(
                  group: _currentGroup,
                  onMembersUpdated: _loadGroupDetail,
                ),
              ),
            ),
            tooltip: 'Group Details',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chat'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatTab(), _buildEventsTab()],
      ),
    );
  }

  Widget _buildChatTab() {
    return ChatMessagesPanel(
      chatId: _chatId,
      groupId: widget.group.id,
    );
  }

  Widget _buildEventsTab() {
    if (_isLoadingEvents)
      return const Center(child: CircularProgressIndicator());
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No events yet'),
            const SizedBox(height: 16),
            MitronButton(
              type: MitronButtonType.primary,
              label: 'Create Event',
              icon: Icons.add,
              onPressed: _showCreateEventDialog,
              fullWidth: true,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          final isEventCreator = event.creatorId == _currentUserId;
          final canEdit = isEventCreator || _isCreator;
          return _EventCard(
            event: event,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    _EventChatPage(event: event, group: _currentGroup),
              ),
            ),
            canEdit: canEdit,
            onEdit: () => _showEditEventDialog(event),
            onDelete: () => _showDeleteEventDialog(event),
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.onTap,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (event.isResolved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Resolved',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  if (canEdit)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      offset: const Offset(0, 40),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 8),
                              Text('Edit Event'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete Event',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (event.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _formatDate(event.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventChatPage extends StatefulWidget {
  final Event event;
  final Group group;

  const _EventChatPage({required this.event, required this.group});

  @override
  State<_EventChatPage> createState() => _EventChatPageState();
}

class _EventChatPageState extends State<_EventChatPage> {
  final GlobalKey<ChatMessagesPanelState> _chatKey =
      GlobalKey<ChatMessagesPanelState>();

  Future<void> _resolveEvent() async {
    final lastMsg = _chatKey.currentState?.lastMessage;
    if (lastMsg == null) return;
    try {
      await AuthService.instance.resolveEvent(widget.event.id, lastMsg.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event resolved!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.title),
        actions: [
          if (!widget.event.isResolved)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: _resolveEvent,
            ),
        ],
      ),
      body: ChatMessagesPanel(
        key: _chatKey,
        chatId: widget.event.chatId ?? widget.event.id,
        groupId: widget.group.id,
        eventId: widget.event.id,
      ),
    );
  }
}
