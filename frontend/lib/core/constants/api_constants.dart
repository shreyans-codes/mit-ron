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
  static const String respondFriend = '/friends/respond';

  // Groups Endpoints
  static const String createGroup = '/groups/create';
  static const String joinGroup = '/groups/join';
  static const String myGroups = '/groups/my';
  static const String groupMembers = '/groups/members';
}
