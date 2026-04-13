package notifications

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mitron/backend/internal/models"
)

type NotificationService struct {
	pool             *pgxpool.Pool
	realtimeNotifier RealtimeNotifier
	pushNotifier     PushNotifier
	tokenStore       DeviceTokenStore
}

func NewNotificationService(pool *pgxpool.Pool, realtimeNotifier RealtimeNotifier, pushNotifier PushNotifier, tokenStore DeviceTokenStore) *NotificationService {
	return &NotificationService{
		pool:             pool,
		realtimeNotifier: realtimeNotifier,
		pushNotifier:     pushNotifier,
		tokenStore:       tokenStore,
	}
}

func (s *NotificationService) CreateNotification(userID string, notifType models.NotificationType, referenceID *string, referenceType *models.ReferenceType, title, body string) (*models.Notification, error) {
	var notifID string
	err := s.pool.QueryRow(context.Background(), `
		INSERT INTO notifications (user_id, type, reference_id, reference_type, title, body)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`, userID, notifType, referenceID, referenceType, title, body).Scan(&notifID)

	if err != nil {
		return nil, fmt.Errorf("failed to create notification: %w", err)
	}

	notif := models.Notification{
		ID:            notifID,
		UserID:        userID,
		Type:          notifType,
		ReferenceID:   referenceID,
		ReferenceType: referenceType,
		Title:         title,
		Body:          &body,
		IsRead:        false,
	}

	if s.realtimeNotifier != nil {
		_ = s.realtimeNotifier.SendNotification(userID, notif)
	}

	if s.pushNotifier != nil && s.tokenStore != nil {
		tokens, err := s.tokenStore.GetTokens(userID)
		if err == nil && len(tokens) > 0 {
			for _, token := range tokens {
				_ = s.pushNotifier.SendPushNotification(token, title, body, map[string]string{
					"notification_id": notifID,
					"type":            string(notifType),
				})
			}
		}
	}

	return &notif, nil
}

func (s *NotificationService) GetNotifications(userID string, limit, offset int) ([]models.Notification, error) {
	rows, err := s.pool.Query(context.Background(), `
		SELECT id, user_id, type, reference_id, reference_type, title, body, is_read, created_at
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get notifications: %w", err)
	}
	defer rows.Close()

	var notifs []models.Notification
	for rows.Next() {
		var n models.Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.ReferenceID, &n.ReferenceType, &n.Title, &n.Body, &n.IsRead, &n.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan notification: %w", err)
		}
		notifs = append(notifs, n)
	}
	return notifs, nil
}

func (s *NotificationService) GetUnreadCount(userID string) (int, error) {
	var count int
	err := s.pool.QueryRow(context.Background(), `
		SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false
	`, userID).Scan(&count)
	return count, err
}

func (s *NotificationService) MarkAsRead(notificationID, userID string) error {
	_, err := s.pool.Exec(context.Background(), `
		UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2
	`, notificationID, userID)
	return err
}

func (s *NotificationService) MarkAllAsRead(userID string) error {
	_, err := s.pool.Exec(context.Background(), `
		UPDATE notifications SET is_read = true WHERE user_id = $1
	`, userID)
	return err
}

func (s *NotificationService) StoreDeviceToken(userID, token, platform string) error {
	if s.tokenStore != nil {
		return s.tokenStore.StoreToken(userID, token, platform)
	}
	return nil
}

func (s *NotificationService) DeleteDeviceToken(token string) error {
	if s.tokenStore != nil {
		return s.tokenStore.DeleteToken(token)
	}
	return nil
}
