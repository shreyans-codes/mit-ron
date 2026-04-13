enum NotificationType {
  newMessage('new_message'),
  friendRequest('friend_request'),
  groupAdded('group_added'),
  friendResponse('friend_response');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.newMessage,
    );
  }
}

enum ReferenceType {
  message('message'),
  group('group'),
  friend('friend'),
  event('event');

  final String value;
  const ReferenceType(this.value);

  static ReferenceType? fromString(String? value) {
    if (value == null) return null;
    return ReferenceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReferenceType.message,
    );
  }
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String? referenceId;
  final ReferenceType? referenceType;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    this.referenceId,
    this.referenceType,
    required this.title,
    this.body,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      referenceId: json['reference_id'] as String?,
      referenceType: ReferenceType.fromString(
        json['reference_type'] as String?,
      ),
      title: json['title'] as String,
      body: json['body'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.value,
      'reference_id': referenceId,
      'reference_type': referenceType?.value,
      'title': title,
      'body': body,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? referenceId,
    ReferenceType? referenceType,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
