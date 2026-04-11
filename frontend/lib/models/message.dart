class Message {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final String? threadId;
  final String? parentId;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    this.threadId,
    this.parentId,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      groupId: json['group_id'],
      senderId: json['sender_id'],
      content: json['content'] ?? '',
      threadId: json['thread_id'],
      parentId: json['parent_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'sender_id': senderId,
      'content': content,
      'thread_id': threadId,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isThread => threadId != null;

  bool get isReply => parentId != null;
}
