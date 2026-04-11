class Event {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final String? creatorId;
  final DateTime createdAt;
  final String? resolutionMessageId;
  final String? chatId;

  Event({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    this.creatorId,
    required this.createdAt,
    this.resolutionMessageId,
    this.chatId,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      creatorId: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolutionMessageId: json['resolution_message_id'] as String?,
      chatId: json['chat_id'] as String?,
    );
  }

  bool get isResolved => resolutionMessageId != null;
}
