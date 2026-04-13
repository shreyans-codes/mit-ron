import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../models/notification.dart';
import '../core/constants/api_constants.dart';
import '../services/auth_service.dart';
import 'realtime/realtime_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  RealtimeService _realtimeService = NoOpRealtimeService();
  final List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  Function(int)? _onUnreadCountChanged;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  RealtimeService get realtimeService => _realtimeService;

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
