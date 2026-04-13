import 'package:flutter/material.dart';
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import 'dart:developer' as developer;

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
      appBar: AppBar(
        title: const Text('Notifications'),
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

  void _handleNotificationTap(AppNotification notif) async {
    await NotificationService.instance.markAsRead(notif.id);
    if (mounted) setState(() {});

    switch (notif.type) {
      case NotificationType.newMessage:
        if (notif.referenceType == ReferenceType.group) {
          developer.log('Navigate to group chat: ${notif.referenceId}');
        } else if (notif.referenceType == ReferenceType.event) {
          developer.log('Navigate to event chat: ${notif.referenceId}');
        }
        break;
      case NotificationType.friendRequest:
        developer.log('Navigate to friend request: ${notif.referenceId}');
        break;
      case NotificationType.groupAdded:
        developer.log('Navigate to group: ${notif.referenceId}');
        break;
      case NotificationType.friendResponse:
        developer.log('Navigate to friend: ${notif.referenceId}');
        break;
    }
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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? Colors.grey[300]
            : Theme.of(context).primaryColor,
        child: Icon(_getIcon(), color: Colors.white),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: notification.body != null ? Text(notification.body!) : null,
      trailing: notification.isRead
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
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
