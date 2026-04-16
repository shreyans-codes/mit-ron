import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification.dart';
import '../../models/message.dart';
import '../realtime/realtime_service.dart';

class SupabaseRealtimeService implements RealtimeService {
  final SupabaseClient _supabase;
  String? _currentUserId;
  RealtimeChannel? _channel;
  RealtimeChannel? _chatChannel;

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
  Future<void> subscribeToChatMessages(
    String chatId,
    Function(Message) onMessage,
  ) async {
    _chatChannel?.unsubscribe();

    _chatChannel = _supabase
        .channel('chat-messages-$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (PostgresChangePayload payload) {
            final msg = Message.fromJson(payload.newRecord);
            onMessage(msg);
          },
        )
        .subscribe();
  }

  @override
  Future<void> unsubscribeFromChatMessages(String chatId) async {
    if (_chatChannel != null) {
      await _supabase.removeChannel(_chatChannel!);
      _chatChannel = null;
    }
  }

  // Legacy methods for backward compatibility
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
    unsubscribe();
    unsubscribeFromChatMessages('');
  }
}
