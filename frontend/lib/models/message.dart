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
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      groupId: json['group_id'] as String?,
      chatId: json['chat_id'] as String?,
      senderId: json['sender_id'] as String,
      senderName:
          (json['sender_name'] ?? json['senderName'] ?? 'Unknown') as String,
      content: (json['content'] ?? '') as String,
      type: (json['type'] ?? 'text') as String,
      threadId: json['thread_id'] as String?,
      parentId: json['parent_id'] as String?,
      isThreadRoot: json['is_thread_root'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
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
}
