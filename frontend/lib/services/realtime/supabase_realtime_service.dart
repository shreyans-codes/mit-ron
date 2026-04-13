import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification.dart';
import '../realtime/realtime_service.dart';

class SupabaseRealtimeService implements RealtimeService {
  final SupabaseClient _supabase;
  String? _currentUserId;
  RealtimeChannel? _channel;

  SupabaseRealtimeService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> subscribe(
    String userId,
    Function(AppNotification) onNotification,
  ) async {
    _currentUserId = userId;

    _channel = _supabase
        .channel('notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (PostgresChangePayload payload) {
            final notif = AppNotification.fromJson(payload.newRecord);
            onNotification(notif);
          },
        )
        .subscribe();
  }

  @override
  Future<void> unsubscribe() async {
    if (_channel != null) {
      await _supabase.removeChannel(_channel!);
      _channel = null;
    }
    _currentUserId = null;
  }

  @override
  bool get isSubscribed => _currentUserId != null;

  @override
  void dispose() {
    unsubscribe();
  }
}
