import 'profile.dart';

class PendingFriendProfile {
  final Profile profile;
  final String initiatorId;

  PendingFriendProfile({required this.profile, required this.initiatorId});

  factory PendingFriendProfile.fromJson(Map<String, dynamic> json) {
    return PendingFriendProfile(
      profile: Profile.fromJson(json['profile'] as Map<String, dynamic>),
      initiatorId: json['initiator_id'] as String,
    );
  }
}

class FriendLists {
  final List<Profile> friends;
  final List<PendingFriendProfile> pendingIncoming;
  final List<PendingFriendProfile> pendingOutgoing;

  FriendLists({
    required this.friends,
    required this.pendingIncoming,
    required this.pendingOutgoing,
  });

  factory FriendLists.fromJson(Map<String, dynamic> json) {
    final friendsJson = json['friends'] as List<dynamic>? ?? [];
    final incomingJson = json['pending_incoming'] as List<dynamic>? ?? [];
    final outgoingJson = json['pending_outgoing'] as List<dynamic>? ?? [];
    return FriendLists(
      friends: friendsJson.map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList(),
      pendingIncoming: incomingJson.map((e) => PendingFriendProfile.fromJson(e as Map<String, dynamic>)).toList(),
      pendingOutgoing: outgoingJson.map((e) => PendingFriendProfile.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
