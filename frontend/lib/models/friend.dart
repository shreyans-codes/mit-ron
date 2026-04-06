// frontend/lib/models/friend.dart
class Friend {
  final String initiatorId;
  final String recipientId;
  final String status;
  final DateTime createdAt;

  Friend({
    required this.initiatorId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      initiatorId: json['initiator_id'] as String,
      recipientId: json['recipient_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'initiator_id': initiatorId,
      'recipient_id': recipientId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
