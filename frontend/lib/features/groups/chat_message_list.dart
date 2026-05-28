import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../services/auth_service.dart';

String normalizeMessageId(String id) => id.toLowerCase();

bool messagesContain(List<Message> messages, Message candidate) {
  final candidateId = normalizeMessageId(candidate.id);
  return messages.any((existing) {
    if (normalizeMessageId(existing.id) == candidateId) {
      return true;
    }
    return existing.senderId == candidate.senderId &&
        existing.content == candidate.content &&
        existing.createdAt.difference(candidate.createdAt).inSeconds.abs() < 10;
  });
}

/// Appends a message from send or realtime, deduplicating by id and near-duplicates.
List<Message> appendChatMessage(List<Message> messages, Message incoming) {
  final message = AuthService.instance.enrichMessage(incoming);
  if (messagesContain(messages, message)) {
    return messages;
  }
  return [...messages, message];
}

List<Message> refreshMessageSenders(List<Message> messages) {
  return AuthService.instance.enrichMessages(messages);
}

void scrollChatToBottom(ScrollController controller) {
  if (!controller.hasClients) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollChatToBottom(controller);
    });
    return;
  }
  controller.animateTo(
    controller.position.maxScrollExtent,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String formatChatDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = dateOnly(now);
  final yesterday = today.subtract(const Duration(days: 1));
  final day = dateOnly(date);
  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

sealed class ChatListEntry {}

class ChatDateSeparatorEntry extends ChatListEntry {
  ChatDateSeparatorEntry(this.date);

  final DateTime date;
}

class ChatMessageEntry extends ChatListEntry {
  ChatMessageEntry(this.message);

  final Message message;
}

List<ChatListEntry> buildChatListEntries(List<Message> messages) {
  final entries = <ChatListEntry>[];
  DateTime? lastDate;
  for (final message in messages) {
    final messageDate = dateOnly(message.createdAt);
    if (lastDate == null || messageDate != lastDate) {
      entries.add(ChatDateSeparatorEntry(messageDate));
      lastDate = messageDate;
    }
    entries.add(ChatMessageEntry(message));
  }
  return entries;
}

class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.outlineVariant;
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: lineColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: textStyle),
          ),
          Expanded(child: Divider(color: lineColor)),
        ],
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.sender,
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  final String sender;
  final String text;
  final bool isMe;
  final DateTime timestamp;

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
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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

class ChatMessageInput extends StatelessWidget {
  const ChatMessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
