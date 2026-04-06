// frontend/lib/models/group.dart
class Group {
  final String id;
  final String name;
  final String? description;
  final String creatorId;
  final DateTime createdAt;
  final int memberCount;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.creatorId,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      creatorId: json['creator_id'],
      createdAt: DateTime.parse(json['created_at']),
      memberCount: json['member_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'creator_id': creatorId,
      'created_at': createdAt.toIso8601String(),
      'member_count': memberCount,
    };
  }
}
