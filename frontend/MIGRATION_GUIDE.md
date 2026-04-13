# Frontend Migration Guide

## Notification System

### Supabase Realtime

**Why Realtime in Frontend?**

1. **Real-time Updates**: The frontend needs to receive instant notifications when the app is open
2. **Token Management**: Supabase SDK handles authentication for realtime subscriptions
3. **Battery Efficient**: Uses persistent connection only when needed

**How it works:**
1. App initializes Supabase client
2. When user logs in, `SupabaseRealtimeService.subscribe(userId)` is called
3. Subscribes to `INSERT` events on `notifications` table filtered by `user_id`
4. When new notification inserted in DB, Supabase pushes it to the app
5. App displays notification and shows local push notification

---

## Swapping Realtime Providers

### Replace Supabase with Custom WebSocket

1. Implement the `RealtimeService` interface in a new file:

```dart
// lib/services/realtime/websocket_realtime_service.dart

import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/notification.dart';
import 'realtime_service.dart';

class WebSocketRealtimeService implements RealtimeService {
  WebSocketChannel? _channel;
  String? _currentUserId;
  final _notificationController = StreamController<AppNotification>.broadcast();
  Timer? _reconnectTimer;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> subscribe(String userId, Function(AppNotification) onNotification) async {
    _currentUserId = userId;
    _connect(userId);
  }

  void _connect(String userId) {
    final uri = Uri.parse('wss://your-server.com/ws?userId=$userId');
    _channel = WebSocketChannel.connect(uri);
    
    _channel!.stream.listen((data) {
      final notif = AppNotification.fromJson(jsonDecode(data));
      onNotification(notif);
    });
  }

  @override
  Future<void> unsubscribe() async {
    await _channel?.sink.close();
    _channel = null;
    _currentUserId = null;
  }

  @override
  bool get isSubscribed => _currentUserId != null;

  @override
  void dispose() {
    unsubscribe();
    _notificationController.close();
  }
}
```

2. Update `main.dart` to use the new service:

```dart
// In main.dart, after auth initialization
import 'services/realtime/websocket_realtime_service.dart';

// Replace SupabaseRealtimeService with WebSocketRealtimeService
NotificationService.instance.setRealtimeService(WebSocketRealtimeService());
```

---

## Swapping Push Notification Provider

### Replace FCM with OneSignal

1. Add OneSignal to `pubspec.yaml`:

```yaml
dependencies:
  onesignal_flutter: ^4.0.0
```

2. Update `notification_service.dart`:

```dart
import 'package:onesignal_flutter/onesignal.dart';

class NotificationService {
  // ... existing code ...

  Future<void> initialize() async {
    // Keep local notifications for in-app
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // ... rest of local notifications init ...

    // Initialize OneSignal
    OneSignal.initWithAppId("YOUR-ONESIGNAL-APP-ID");
    OneSignal.setNotificationWillShowInForegroundHandler((event) {
      // Handle notification received while app is in foreground
    });
    OneSignal.setNotificationOpenedHandler((openedEvent) {
      // Handle notification tap
    });
  }

  Future<void> registerDeviceToken(String token, String platform) async {
    // OneSignal handles token automatically, but you can also
    // send to your backend if needed
    await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.registerDeviceToken}'),
      headers: {...},
      body: jsonEncode({
        'token': OneSignal.DeviceState.userId, // OneSignal player ID
        'platform': platform,
      }),
    );
  }

  // Remove _showLocalNotification since OneSignal handles this
}
```

3. Update backend to use OneSignal (see Backend Migration Guide)

---

## Environment Configuration

### Required for Notifications

| Platform | Setup |
|----------|-------|
| **Supabase Realtime** | Enable in Supabase dashboard: Database → Replication → Enable for `notifications` table |
| **FCM** | See Backend Migration Guide |
| **OneSignal** | Create app in OneSignal dashboard, get App ID |

---

## Code Structure for Future Migration

```
lib/services/
├── notification_service.dart     # Main service (don't change)
├── realtime/
│   ├── realtime_service.dart     # Interface (keep same)
│   ├── supabase_realtime_service.dart  # Current impl
│   └── websocket_realtime_service.dart # Future impl
```

The `NotificationService` is designed to work with any `RealtimeService` implementation through the abstract interface. To swap providers, simply call:
```dart
NotificationService.instance.setRealtimeService(NewRealtimeServiceImpl());
```