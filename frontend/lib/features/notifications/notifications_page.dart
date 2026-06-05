import 'package:flutter/material.dart';
import '../../models/notification.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../groups/group_chat_page.dart';
import '../../widgets/mitron_app_bar.dart';

class NotificationsPage extends StatefulWidget {
  static const String routeName = '/notifications';

  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    await NotificationService.instance.loadNotifications();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationService.instance.notifications;

    return Scaffold(
      appBar: MitronAppBar(
        title: 'Notifications',
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () async {
                await NotificationService.instance.markAllAsRead();
                if (mounted) setState(() {});
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(child: Text('No notifications yet'))
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return NotificationItem(
                    notification: notif,
                    onTap: () => _handleNotificationTap(notif),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _handleNotificationTap(AppNotification notif) async {
    await NotificationService.instance.markAsRead(notif.id);
    if (!mounted) return;
    setState(() {});

    final referenceId = notif.referenceId;
    if (referenceId == null || referenceId.isEmpty) return;

    try {
      switch (notif.type) {
        case NotificationType.newMessage:
          if (notif.referenceType == ReferenceType.group) {
            await _openGroupChat(referenceId);
          } else if (notif.referenceType == ReferenceType.event) {
            await _openEventChat(referenceId);
          }
          break;
        case NotificationType.groupAdded:
          await _openGroupChat(referenceId);
          break;
        case NotificationType.friendRequest:
        case NotificationType.friendResponse:
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $e')),
      );
    }
  }

  Future<void> _openGroupChat(String groupId) async {
    final group = await AuthService.instance.getGroupDetail(groupId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupChatPage(group: group)),
    );
  }

  Future<void> _openEventChat(String eventId) async {
    final event = await AuthService.instance.getEventDetail(eventId);
    final group = await AuthService.instance.getGroupDetail(event.groupId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventChatPage(event: event, group: group),
      ),
    );
  }
}

class NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  String _contextLabel() {
    switch (notification.referenceType) {
      case ReferenceType.group:
        return 'Group';
      case ReferenceType.event:
        return 'Event';
      case ReferenceType.friend:
        return 'Friend';
      case ReferenceType.message:
        return 'Message';
      case null:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final contextLabel = _contextLabel();
    final subtitleParts = <String>[];
    if (contextLabel.isNotEmpty) {
      subtitleParts.add(contextLabel);
    }
    if (notification.body != null && notification.body!.isNotEmpty) {
      subtitleParts.add(notification.body!);
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? Colors.grey[300]
            : Theme.of(context).colorScheme.primary,
        child: Icon(_getIcon(), color: Colors.white),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' · ')),
      trailing: notification.isRead
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
      onTap: onTap,
    );
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.newMessage:
        return Icons.message;
      case NotificationType.friendRequest:
        return Icons.person_add;
      case NotificationType.groupAdded:
        return Icons.group_add;
      case NotificationType.friendResponse:
        return Icons.person;
    }
  }
}
