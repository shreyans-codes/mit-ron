import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    if (dotenv.env['LOCAL'] == '1') {
      return 'https://mit-ron.shreyanssethia.in';
    }
    return dotenv.env['API_BASE_URL'] ?? 'https://mit-ron.shreyanssethia.in';
  }

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static String get fcmProjectId => dotenv.env['FCM_PROJECT_ID'] ?? '';

  // Auth Endpoints
  static const String login = '/login';
  static const String signup = '/signup';
  static const String signout = '/signout';
  static const String profileUpdate = '/profile/update';

  // User Endpoints
  static const String userSearch = '/users/search';
  static const String profile = '/profile';

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
  static const String markMessagesRead = '/messages/read';

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
