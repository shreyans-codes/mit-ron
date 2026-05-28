import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import 'chat_message_list.dart';

/// Shared group/event chat body: loads messages, realtime, send, and date dividers.
class ChatMessagesPanel extends StatefulWidget {
  const ChatMessagesPanel({
    super.key,
    required this.chatId,
    required this.groupId,
    this.eventId,
    this.emptyMessage = 'No messages yet',
    this.initialThreadRootId,
    this.initialThreadRootMessage,
  });

  final String chatId;
  final String groupId;
  final String? eventId;
  final String emptyMessage;
  final String? initialThreadRootId;
  final Message? initialThreadRootMessage;

  @override
  State<ChatMessagesPanel> createState() => ChatMessagesPanelState();
}

class ChatMessagesPanelState extends State<ChatMessagesPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isMarkingRead = false;
  String? _lastMarkedMessageId;
  Message? _selectedMessage;
  Message? _replyToMessage;
  String? _activeThreadRootId;
  Message? _threadRootMessage;

  Message? get lastMessage => _messages.isEmpty ? null : _messages.last;

  @override
  void initState() {
    super.initState();
    _activeThreadRootId = widget.initialThreadRootId;
    _threadRootMessage = widget.initialThreadRootMessage;
    _cacheGroupMemberNames();
    _loadMessages();
    _subscribeToRealtimeMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    NotificationService.instance.realtimeService.unsubscribeFromChatMessages(
      widget.chatId,
    );
    super.dispose();
  }

  Future<void> _cacheGroupMemberNames() async {
    try {
      await AuthService.instance.getGroupMembers(widget.groupId);
      if (mounted) {
        setState(() => _messages = refreshMessageSenders(_messages));
      }
    } catch (_) {}
  }

  void _subscribeToRealtimeMessages() {
    NotificationService.instance.realtimeService.subscribeToChatMessages(
      widget.chatId,
      (newMessage) {
        if (!mounted) return;
        final currentUserId = AuthService.instance.currentUser?.id;
        setState(() {
          _messages = appendChatMessage(_messages, newMessage);
        });
        if (newMessage.senderId != currentUserId) {
          _markVisibleMessagesAsRead(newMessage.id);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollChatToBottom(_scrollController);
        });
      },
    );
  }

  Future<void> _markVisibleMessagesAsRead(String? messageId) async {
    if (messageId == null || messageId.isEmpty) return;
    if (_isMarkingRead || _lastMarkedMessageId == messageId) return;
    _isMarkingRead = true;
    try {
      await AuthService.instance.markMessagesAsRead(widget.chatId, messageId);
      _lastMarkedMessageId = messageId;
      await AuthService.instance.updateCachedGroupUnreadCount(widget.groupId, 0);
    } catch (_) {
      // Best-effort call; avoid interrupting chat UI for read receipts failure.
    } finally {
      _isMarkingRead = false;
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await AuthService.instance.getMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages = refreshMessageSenders(messages);
        if (_activeThreadRootId != null) {
          _threadRootMessage = _findMessageById(_activeThreadRootId!);
        }
        _isLoading = false;
      });
      if (messages.isNotEmpty) {
        await _markVisibleMessagesAsRead(messages.last.id);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollChatToBottom(_scrollController);
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final threadId = _activeThreadRootId ?? _replyToMessage?.threadId;
      final parentId = _replyToMessage?.id;
      final message = await AuthService.instance.sendMessage(
        groupId: widget.groupId,
        content: content,
        parentId: parentId,
        threadId: threadId,
        eventId: widget.eventId,
      );
      if (!mounted) return;
      setState(() {
        _messages = appendChatMessage(_messages, message);
        _messageController.clear();
        _replyToMessage = null;
        _isSending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollChatToBottom(_scrollController);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.currentUser?.id;
    final visibleMessages = _visibleMessages();
    final listEntries = buildChatListEntries(visibleMessages);
    final threadReplyCountByRootId = _threadReplyCountByRootId();

    return Column(
      children: [
        if (_selectedMessage != null) _buildSelectionBar(),
        if (_activeThreadRootId != null) _buildThreadModeBar(),
        if (_replyToMessage != null) _buildReplyContextBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : visibleMessages.isEmpty
              ? Center(child: Text(widget.emptyMessage))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: listEntries.length,
                  itemBuilder: (context, index) {
                    final entry = listEntries[index];
                    switch (entry) {
                      case ChatDateSeparatorEntry(:final date):
                        return ChatDateDivider(
                          label: formatChatDateLabel(date),
                        );
                      case ChatMessageEntry(:final message):
                        final isMe = message.senderId == currentUserId;
                        final parent = message.parentId == null
                            ? null
                            : _findMessageById(message.parentId!);
                        final threadReplyCount =
                            threadReplyCountByRootId[message.id] ?? 0;
                        return ChatMessageBubble(
                          sender: isMe ? 'You' : message.senderName,
                          text: message.content,
                          isMe: isMe,
                          timestamp: message.createdAt,
                          isSelected: _selectedMessage?.id == message.id,
                          onLongPress: () => _onLongPressMessage(message),
                          replyPreview: parent == null
                              ? null
                              : '${parent.senderName}: ${parent.content}',
                          threadReplyCount: threadReplyCount,
                          onOpenThread: threadReplyCount > 0
                              ? () => _openThread(message.id, message)
                              : null,
                          isThreadContext: _activeThreadRootId != null,
                        );
                    }
                  },
                ),
        ),
        ChatMessageInput(
          controller: _messageController,
          onSend: _sendMessage,
          isLoading: _isSending,
        ),
      ],
    );
  }

  Message? _findMessageById(String id) {
    for (final message in _messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  List<Message> _visibleMessages() {
    final rootId = _activeThreadRootId;
    if (rootId == null) {
      final visible = _messages
          .where((message) => message.threadId == null || message.id == rootId)
          .toList();
      visible.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return visible;
    }
    final visible = _messages
        .where((message) => message.id == rootId || message.threadId == rootId)
        .toList();
    visible.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return visible;
  }

  Map<String, int> _threadReplyCountByRootId() {
    final counts = <String, int>{};
    for (final message in _messages) {
      final rootId = message.threadId;
      if (rootId == null || rootId.isEmpty) continue;
      counts[rootId] = (counts[rootId] ?? 0) + 1;
    }
    return counts;
  }

  void _onLongPressMessage(Message message) {
    setState(() {
      _selectedMessage = message;
    });
  }

  void _openThread(String rootId, Message rootMessage) {
    setState(() {
      _activeThreadRootId = rootId;
      _threadRootMessage = rootMessage;
      _selectedMessage = null;
      _replyToMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollChatToBottom(_scrollController);
    });
  }

  Widget _buildSelectionBar() {
    final selected = _selectedMessage!;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selected.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              IconButton(
                tooltip: 'Reply',
                icon: const Icon(Icons.reply),
                onPressed: () {
                  setState(() {
                    _replyToMessage = selected;
                    _selectedMessage = null;
                  });
                },
              ),
              IconButton(
                tooltip: 'Start thread',
                icon: const Icon(Icons.forum_outlined),
                onPressed: () => _openThread(selected.id, selected),
              ),
              IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedMessage = null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreadModeBar() {
    final root = _threadRootMessage;
    final title = root == null
        ? 'Thread'
        : 'Thread: ${root.senderName} - ${root.content}';
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _activeThreadRootId = null;
                  _threadRootMessage = null;
                  _replyToMessage = null;
                  _selectedMessage = null;
                });
              },
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyContextBar() {
    final replyTo = _replyToMessage!;
    final text = '${replyTo.senderName}: ${replyTo.content}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyToMessage = null),
          ),
        ],
      ),
    );
  }
}
