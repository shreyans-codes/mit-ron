import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification.dart';
import '../../models/message.dart';
import '../auth_service.dart';
import '../realtime/realtime_service.dart';

class SupabaseRealtimeService implements RealtimeService {
  RealtimeChannel? _channel;
  final Map<String, RealtimeChannel> _chatChannels = {};
  String? _currentUserId;

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
    final existingChannel = _chatChannels[chatId];
    if (existingChannel != null) {
      await _client.removeChannel(existingChannel);
    }

    final channel = _client.channel('chat:$chatId');
    _chatChannels[chatId] = channel;

    final completer = Completer<RealtimeSubscribeStatus>();

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'chat_id',
        value: chatId,
      ),
      callback: (PostgresChangePayload payload) {
        final record = payload.newRecord;
        if (record['chat_id']?.toString() != chatId) {
          return;
        }
        try {
          final message = AuthService.instance.enrichMessage(
            Message.fromJson(record),
          );
          onMessage(message);
        } catch (_) {}
      },
    );

    channel.subscribe((status, err) {
      if (!completer.isCompleted) {
        completer.complete(status);
      }
    });

    final status = await completer.future;
    if (status.toString().contains('timedOut')) {
      await Future.delayed(const Duration(seconds: 2));
      channel.subscribe((_, _) {});
    }
  }

  @override
  Future<void> unsubscribeFromChatMessages(String chatId) async {
    final channel = _chatChannels.remove(chatId);
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  @override
  void dispose() {
    unsubscribe();
    final channels = _chatChannels.values.toList();
    for (final channel in channels) {
      _client.removeChannel(channel);
    }
    _chatChannels.clear();
  }
}
