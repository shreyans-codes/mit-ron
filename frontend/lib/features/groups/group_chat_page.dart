import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../models/message.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../widgets/mitron_button.dart';
import 'group_details_page.dart';

class GroupChatPage extends StatefulWidget {
  final Group group;
  const GroupChatPage({super.key, required this.group});

  static const String routeName = '/group-chat';

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  int _memberCount = 0;
  bool _isLoadingMembers = true;
  late Group _currentGroup;
  List<Message> _messages = [];
  bool _isLoadingMessages = true;
  List<Event> _events = [];
  bool _isLoadingEvents = true;
  late TabController _tabController;
  bool _isSending = false;
  String? _currentUserId;
  bool get _isCreator => _currentUserId == _currentGroup.creatorId;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    _memberCount = widget.group.memberCount;
    _currentUserId = AuthService.instance.currentUser?.id;
    _tabController = TabController(length: 2, vsync: this);
    _loadGroupDetail();
    _loadMessages();
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
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

  Future<void> _loadMessages() async {
    try {
      final messages = await AuthService.instance.getMessages(widget.group.id);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final message = await AuthService.instance.sendMessage(
        groupId: widget.group.id,
        content: content,
      );
      if (mounted) {
        setState(() {
          _messages = [..._messages, message];
          _messageController.clear();
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
    return Column(
      children: [
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? const Center(child: Text('No messages yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe =
                        msg.senderId == AuthService.instance.currentUser?.id;
                    return _MessageBubble(
                      sender: isMe ? 'You' : msg.senderName ?? 'Unknown',
                      text: msg.content,
                      isMe: isMe,
                      timestamp: msg.createdAt,
                    );
                  },
                ),
        ),
        _MessageInput(
          controller: _messageController,
          onSend: _sendMessage,
          isLoading: _isSending,
        ),
      ],
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
          final canDelete = isEventCreator || _isCreator;
          return _EventCard(
            event: event,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    _EventChatPage(event: event, group: _currentGroup),
              ),
            ),
            canDelete: canDelete,
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
  final bool canDelete;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.onTap,
    required this.canDelete,
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
                  if (canDelete)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
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
  final TextEditingController _messageController = TextEditingController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await AuthService.instance.getEventMessages(
        widget.event.id,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final message = await AuthService.instance.sendMessage(
        groupId: widget.group.id,
        content: content,
        eventId: widget.event.id,
      );
      if (mounted) {
        setState(() {
          _messages = [..._messages, message];
          _messageController.clear();
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _resolveEvent() async {
    if (_messages.isEmpty) return;
    final lastMsg = _messages.last;
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
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe =
                          msg.senderId == AuthService.instance.currentUser?.id;
                      return _MessageBubble(
                        sender: isMe ? 'You' : msg.senderName ?? 'Unknown',
                        text: msg.content,
                        isMe: isMe,
                        timestamp: msg.createdAt,
                      );
                    },
                  ),
          ),
          _MessageInput(
            controller: _messageController,
            onSend: _sendMessage,
            isLoading: _isSending,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String sender;
  final String text;
  final bool isMe;
  final DateTime timestamp;

  const _MessageBubble({
    required this.sender,
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                sender,
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 20),
              ),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _formatTime(timestamp),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                enabled: !isLoading,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isLoading ? null : onSend,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
