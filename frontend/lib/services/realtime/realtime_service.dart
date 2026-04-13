import '../../models/notification.dart';

abstract class RealtimeService {
  Future<void> initialize();
  Future<void> subscribe(
    String userId,
    Function(AppNotification) onNotification,
  );
  Future<void> unsubscribe();
  bool get isSubscribed;
  void dispose();
}

class NoOpRealtimeService implements RealtimeService {
  bool _subscribed = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> subscribe(
    String userId,
    Function(AppNotification) onNotification,
  ) async {
    _subscribed = true;
  }

  @override
  Future<void> unsubscribe() async {
    _subscribed = false;
  }

  @override
  bool get isSubscribed => _subscribed;

  @override
  void dispose() {
    _subscribed = false;
  }
}
