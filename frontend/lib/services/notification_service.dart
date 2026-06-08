import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart';
import '../core/constants/api_constants.dart';
import '../services/auth_service.dart';
import 'realtime/realtime_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _firstLaunchKey = 'has_completed_onboarding';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  RealtimeService _realtimeService = NoOpRealtimeService();
  final List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  Function(int)? _onUnreadCountChanged;
  bool _notificationsEnabled = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  RealtimeService get realtimeService => _realtimeService;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? false;
  }

  Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, true);
  }

  void setUnreadCountListener(Function(int) listener) {
    _onUnreadCountChanged = listener;
  }

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Load saved preference
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? false;

    if (!kIsWeb && ApiConstants.fcmProjectId.isNotEmpty) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_onForegroundPushMessage);
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerFcmToken);
    }
  }

  Future<void> ensurePushRegistration() async {
    if (!_notificationsEnabled) return;
    await registerFcmTokenIfLoggedIn();
  }

  Future<bool> requestNotificationPermission() async {
    if (ApiConstants.fcmProjectId.isEmpty) {
      // If no FCM configured, just track user preference
      _notificationsEnabled = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsEnabledKey, true);
      return true;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      _notificationsEnabled = granted;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsEnabledKey, granted);

      if (granted) {
        await registerFcmTokenIfLoggedIn();
      }

      return granted;
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
      return false;
    }
  }

  Future<void> loadNotificationPermissionStatus() async {
    if (ApiConstants.fcmProjectId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? false;
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      _notificationsEnabled =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('Failed to get notification settings: $e');
    }
  }

  Future<void> registerFcmTokenIfLoggedIn() async {
    if (ApiConstants.fcmProjectId.isEmpty) return;

    final authHeader = AuthService.instance.authorizationHeaderValue;
    if (authHeader == null) return;

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        debugPrint('FCM Token: $fcmToken');
        await _registerFcmToken(fcmToken);
      }
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
  }

  Future<void> _registerFcmToken(String token) async {
    // Determine platform
    String platform = 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      platform = 'ios';
    }
    await registerDeviceToken(token, platform);
  }

  void setRealtimeService(RealtimeService service) {
    _realtimeService.dispose();
    _realtimeService = service;
  }

  Future<void> startRealtimeSubscription(String userId) async {
    await _realtimeService.subscribe(userId, _onRealtimeNotification);
  }

  void _onRealtimeNotification(AppNotification notif) {
    _notifications.insert(0, notif);
    _unreadCount++;
    _onUnreadCountChanged?.call(_unreadCount);
    _showLocalNotification(notif);
  }

  void _onForegroundPushMessage(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;
    final fallbackId = message.messageId ?? DateTime.now().toIso8601String();
    _showLocalNotification(
      AppNotification(
        id: fallbackId,
        userId: AuthService.instance.currentUser?.id ?? '',
        title: notif.title ?? 'Mitron',
        body: notif.body ?? '',
        type: NotificationType.newMessage,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      debugPrint('Notification tapped with payload: $payload');
    }
  }

  Future<void> _showLocalNotification(AppNotification notif) async {
    const androidDetails = AndroidNotificationDetails(
      'mitron_notifications',
      'Mitron Notifications',
      channelDescription:
          'Notifications for new messages, friend requests, etc.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notif.id.hashCode,
      notif.title,
      notif.body,
      details,
      payload: jsonEncode({
        'notification_id': notif.id,
        'type': notif.type.value,
        'reference_id': notif.referenceId,
        'reference_type': notif.referenceType?.value,
      }),
    );
  }

  Future<void> loadNotifications() async {
    final authHeader = AuthService.instance.authorizationHeaderValue;
    if (authHeader == null) return;

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.getNotifications}'),
      headers: {'Authorization': authHeader},
    );

    if (response.statusCode == 401) {
      await AuthService.instance.handleUnauthorized();
      return;
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      _notifications.clear();
      _notifications.addAll(data.map((e) => AppNotification.fromJson(e)));
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      _onUnreadCountChanged?.call(_unreadCount);
    }
  }

  Future<int> getUnreadCount() async {
    final authHeader = AuthService.instance.authorizationHeaderValue;
    if (authHeader == null) return 0;

    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.unreadNotificationCount}',
      ),
      headers: {'Authorization': authHeader},
    );

    if (response.statusCode == 401) {
      await AuthService.instance.handleUnauthorized();
      return 0;
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _unreadCount = data['unread_count'] ?? 0;
      _onUnreadCountChanged?.call(_unreadCount);
      return _unreadCount;
    }
    return 0;
  }

  Future<void> markAsRead(String notificationId) async {
    final authHeader = AuthService.instance.authorizationHeaderValue;
    if (authHeader == null) return;

    final url = '${ApiConstants.baseUrl}/notifications/$notificationId/read';
    final response = await http.patch(
      Uri.parse(url),
      headers: {'Authorization': authHeader},
    );

    if (response.statusCode == 401) {
      await AuthService.instance.handleUnauthorized();
      return;
    }

    if (response.statusCode == 200) {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        _onUnreadCountChanged?.call(_unreadCount);
      }
    }
  }

  Future<void> markAllAsRead() async {
    final authHeader = AuthService.instance.authorizationHeaderValue;
    if (authHeader == null) return;

    final response = await http.patch(
      Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.markAllNotificationsRead}',
      ),
      headers: {'Authorization': authHeader},
    );

    if (response.statusCode == 401) {
      await AuthService.instance.handleUnauthorized();
      return;
    }

    if (response.statusCode == 200) {
      for (var i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      _unreadCount = 0;
      _onUnreadCountChanged?.call(_unreadCount);
    }
  }

  Future<void> registerDeviceToken(String token, String platform) async {
    final authHeader = AuthService.instance.authorizationHeaderValue;
    if (authHeader == null) return;

    await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.registerDeviceToken}'),
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'token': token, 'platform': platform}),
    );
  }

  void dispose() {
    _realtimeService.dispose();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (ApiConstants.fcmProjectId.isEmpty) return;
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}
