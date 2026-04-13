package notifications

import "github.com/mitron/backend/internal/models"

type Notifier interface {
	Subscribe(userID string) error
	Unsubscribe(userID string) error
	SendNotification(userID string, notif models.Notification) error
	SendPushNotification(token, title, body string, data map[string]string) error
}

type PushNotifier interface {
	SendPushNotification(token, title, body string, data map[string]string) error
}

type RealtimeNotifier interface {
	Subscribe(userID string) error
	Unsubscribe(userID string) error
	SendNotification(userID string, notif models.Notification) error
}
