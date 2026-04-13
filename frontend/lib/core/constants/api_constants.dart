class ApiConstants {
  static const String baseUrl = 'https://mit-ron.onrender.com';

  // Auth Endpoints
  static const String login = '/login';
  static const String signup = '/signup';
  static const String signout = '/signout';
  static const String profileUpdate = '/profile/update';

  // User Endpoints
  static const String userSearch = '/users/search';
  static const String profile =
      '/profile'; // Will be used as /profile/:username

  // Friends Endpoints
  static const String friendsList = '/friends';
  static const String addFriend = '/friends/add';
  static const String removeFriend = '/friends/remove';
  static const String respondFriend = '/friends/respond';

  // Groups Endpoints
  static const String createGroup = '/groups/create';
  static const String updateGroup = '/groups/update';
  static const String joinGroup = '/groups/join';
  static const String myGroups = '/groups/my';
  static const String groupDetail = '/groups/detail';
  static const String groupMembers = '/groups/members';
  static const String deleteGroup = '/groups/delete';
  static const String addGroupMember = '/groups/add-member';
  static const String removeGroupMember = '/groups/remove-member';

  // Image Endpoints
  static const String generateImage = '/generate-image';

  // Message Endpoints
  static const String sendMessage = '/messages/send';
  static const String getMessages = '/messages';

  // Event Endpoints
  static const String createEvent = '/events/create';
  static const String getEvents = '/events';
  static const String resolveEvent = '/events/resolve';
  static const String deleteEvent = '/events/delete';
  static const String updateEvent = '/events/update';

  // Notification Endpoints
  static const String getNotifications = '/notifications';
  static const String markNotificationRead = '/notifications/:id/read';
  static const String markAllNotificationsRead = '/notifications/read-all';
  static const String unreadNotificationCount = '/notifications/unread-count';
  static const String registerDeviceToken = '/device-token';
}
