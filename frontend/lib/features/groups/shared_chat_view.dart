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
  });

  final String chatId;
  final String groupId;
  final String? eventId;
  final String emptyMessage;

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

  Message? get lastMessage => _messages.isEmpty ? null : _messages.last;

  @override
  void initState() {
    super.initState();
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
      final message = await AuthService.instance.sendMessage(
        groupId: widget.groupId,
        content: content,
        eventId: widget.eventId,
      );
      if (!mounted) return;
      setState(() {
        _messages = appendChatMessage(_messages, message);
        _messageController.clear();
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
    final listEntries = buildChatListEntries(_messages);

    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
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
                        return ChatMessageBubble(
                          sender: isMe ? 'You' : message.senderName,
                          text: message.content,
                          isMe: isMe,
                          timestamp: message.createdAt,
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
}
