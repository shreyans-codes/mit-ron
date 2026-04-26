import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification.dart';
import '../../models/message.dart';
import '../realtime/realtime_service.dart';

class SupabaseRealtimeService implements RealtimeService {
  RealtimeChannel? _channel;
  RealtimeChannel? _chatChannel;
  String? _currentUserId;
  Timer? _heartbeatTimer;

  SupabaseRealtimeService();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> subscribe(
    String userId,
    Function(AppNotification) onNotification,
  ) async {
    _currentUserId = userId;

    _channel = _client
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
    _heartbeatTimer?.cancel();
    if (_channel != null) {
      await _client.removeChannel(_channel!);
      _channel = null;
    }
    _currentUserId = null;
  }

  @override
  bool get isSubscribed => _currentUserId != null;

  @override
  Future<void> subscribeToChatMessages(
    String chatId,
    Function(Message) onMessage,
  ) async {
    print('[SupabaseRealtime] subscribeToChatMessages called for: $chatId');

    // Cancel existing
    _heartbeatTimer?.cancel();
    if (_chatChannel != null) {
      print('[SupabaseRealtime] Removing existing channel');
      await _client.removeChannel(_chatChannel!);
      _chatChannel = null;
    }

    print('[SupabaseRealtime] Creating channel for chat: $chatId');

    // Create channel first
    _chatChannel = _client.channel('chat:$chatId');

    final completer = Completer<RealtimeSubscribeStatus>();

    // Then add the listener - WITH filter AND client-side fallback
    _chatChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'chat_id',
        value: chatId,
      ),
      callback: (PostgresChangePayload payload) {
        print(
          '[SupabaseRealtime] 🎯 Callback triggered! eventType=${payload.eventType}',
        );
        print('[SupabaseRealtime] payload newRecord: ${payload.newRecord}');

        // Client-side filter as backup
        if (payload.newRecord != null &&
            payload.newRecord['chat_id']?.toString() == chatId) {
          print(
            '[SupabaseRealtime] chat_id matches: ${payload.newRecord['chat_id']}',
          );
          try {
            final msg = Message.fromJson(payload.newRecord);
            print('[SupabaseRealtime] 🎉 Parsed message: ${msg.content}');
            onMessage(msg);
          } catch (e) {
            print('[SupabaseRealtime] Parse error: $e');
          }
        }
      },
    );

    // Subscribe with status callback and wait for it
    _chatChannel!.subscribe((status, err) {
      print('[SupabaseRealtime] Subscribe callback: status=$status err=$err');
      if (!completer.isCompleted) {
        completer.complete(status);
      }
    });

    // Wait for subscription
    final status = await completer.future;
    print('[SupabaseRealtime] Final subscription status: $status');

    // Check for timeout using string comparison
    if (status.toString().contains('timedOut')) {
      print('[SupabaseRealtime] ⚠️ Subscription timed out, retrying...');
      await Future.delayed(const Duration(seconds: 2));
      _chatChannel!.subscribe((status, err) {
        print('[SupabaseRealtime] Retry callback: status=$status err=$err');
      });
    }

    // Heartbeat to keep connection alive
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      print('[SupabaseRealtime] Heartbeat tick');
    });
  }

  @override
  Future<void> unsubscribeFromChatMessages(String chatId) async {
    _heartbeatTimer?.cancel();
    if (_chatChannel != null) {
      await _client.removeChannel(_chatChannel!);
      _chatChannel = null;
    }
  }

  @override
  Future<void> subscribeToGroupMessages(
    String groupId,
    Function(Message) onMessage,
  ) async {
    await subscribeToChatMessages(groupId, onMessage);
  }

  @override
  Future<void> unsubscribeFromGroupMessages(String groupId) async {
    await unsubscribeFromChatMessages(groupId);
  }

  @override
  Future<void> subscribeToEventMessages(
    String eventId,
    Function(Message) onMessage,
  ) async {
    await subscribeToChatMessages(eventId, onMessage);
  }

  @override
  Future<void> unsubscribeFromEventMessages(String eventId) async {
    await unsubscribeFromChatMessages(eventId);
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    unsubscribe();
    unsubscribeFromChatMessages('');
  }
}
