import 'poll.dart';

class Message {
  final String id;
  final String? groupId;
  final String? chatId;
  final String senderId;
  final String senderName;
  final String content;
  final String type;
  final String? threadId;
  final String? parentId;
  final bool isThreadRoot;
  final DateTime createdAt;
  final MessagePoll? poll;

  Message({
    required this.id,
    this.groupId,
    this.chatId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.type = 'text',
    this.threadId,
    this.parentId,
    this.isThreadRoot = false,
    required this.createdAt,
    this.poll,
  });

  bool get isPoll => type == 'poll';

  static DateTime _parseCreatedAt(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawSenderName = json['sender_name'] ?? json['senderName'];
    final senderName = rawSenderName?.toString() ?? 'Unknown';
    final type = (json['type'] ?? json['message_type'] ?? 'text').toString();
    MessagePoll? poll;
    if (json['poll'] is Map<String, dynamic>) {
      poll = MessagePoll.fromJson(json['poll'] as Map<String, dynamic>);
    }
    return Message(
      id: json['id'].toString(),
      groupId: json['group_id']?.toString(),
      chatId: json['chat_id']?.toString(),
      senderId: json['sender_id'].toString(),
      senderName: senderName,
      content: (json['content'] ?? '') as String,
      type: type,
      threadId: json['thread_id']?.toString(),
      parentId: json['parent_id']?.toString(),
      isThreadRoot:
          json['is_thread_root'] == true ||
          json['is_thread_root']?.toString() == 'true',
      createdAt: _parseCreatedAt(json['created_at']),
      poll: poll,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'type': type,
      'thread_id': threadId,
      'parent_id': parentId,
      'is_thread_root': isThreadRoot,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isThread => threadId != null;

  bool get isReply => parentId != null;

  bool get hasResolvedSenderName =>
      senderName.isNotEmpty && senderName != 'Unknown';

  Message copyWith({
    String? id,
    String? groupId,
    String? chatId,
    String? senderId,
    String? senderName,
    String? content,
    String? type,
    String? threadId,
    String? parentId,
    bool? isThreadRoot,
    DateTime? createdAt,
    MessagePoll? poll,
  }) {
    return Message(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      type: type ?? this.type,
      threadId: threadId ?? this.threadId,
      parentId: parentId ?? this.parentId,
      isThreadRoot: isThreadRoot ?? this.isThreadRoot,
      createdAt: createdAt ?? this.createdAt,
      poll: poll ?? this.poll,
    );
  }
}
