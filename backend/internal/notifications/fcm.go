package notifications

import (
	"context"
	"fmt"
	"log"
	"os"
	"sync"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mitron/backend/internal/models"
	"google.golang.org/api/option"
)

type FCMConfig struct {
	ProjectID       string
	CredentialsFile string
}

type FCMNotifier struct {
	config *FCMConfig
	client *messaging.Client
	app    *firebase.App
	mu     sync.Mutex
}

func NewFCMNotifier(config *FCMConfig) *FCMNotifier {
	notifier := &FCMNotifier{
		config: config,
	}

	credFile := config.CredentialsFile
	if credFile == "" {
		credFile = os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	}

	var opts []option.ClientOption
	if credFile != "" {
		opts = append(opts, option.WithCredentialsFile(credFile))
	}

	ctx := context.Background()
	app, err := firebase.NewApp(ctx, nil, opts...)
	if err != nil {
		log.Printf("Failed to initialize Firebase app: %v", err)
		return notifier
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		log.Printf("Failed to create FCM client: %v", err)
		return notifier
	}

	notifier.app = app
	notifier.client = client
	log.Println("FCM notifier initialized successfully")
	return notifier
}

func (f *FCMNotifier) SendPushNotification(token, title, body string, data map[string]string) error {
	if token == "" {
		log.Println("FCM: Empty token, skipping notification")
		return nil
	}

	if f.client == nil {
		return fmt.Errorf("FCM client not initialized")
	}

	ctx := context.Background()

	message := &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
	}

	_, err := f.client.Send(ctx, message)
	if err != nil {
		log.Printf("FCM send error: %v", err)
		return fmt.Errorf("failed to send FCM message: %w", err)
	}

	log.Printf("FCM notification sent successfully to token: %s...", truncate(token, 20))
	return nil
}

func (f *FCMNotifier) SendNotification(userID string, notif models.Notification) error {
	log.Printf("FCM notifier does not support realtime - use RealtimeNotifier for that")
	return nil
}

func (f *FCMNotifier) Subscribe(userID string) error {
	log.Printf("FCM notifier does not support realtime subscriptions")
	return nil
}

func (f *FCMNotifier) Unsubscribe(userID string) error {
	log.Printf("FCM notifier does not support realtime subscriptions")
	return nil
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen]
}

type DeviceTokenStore interface {
	StoreToken(userID, token, platform string) error
	DeleteToken(token string) error
	GetTokens(userID string) ([]string, error)
}

type PostgresDeviceTokenStore struct {
	pool *pgxpool.Pool
}

func NewPostgresDeviceTokenStore(pool *pgxpool.Pool) *PostgresDeviceTokenStore {
	return &PostgresDeviceTokenStore{pool: pool}
}

func (s *PostgresDeviceTokenStore) StoreToken(userID, token, platform string) error {
	_, err := s.pool.Exec(context.Background(), `
		INSERT INTO device_tokens (user_id, token, platform, updated_at)
		VALUES ($1, $2, $3, now())
		ON CONFLICT (token) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			platform = EXCLUDED.platform,
			updated_at = now()
	`, userID, token, platform)
	return err
}

func (s *PostgresDeviceTokenStore) DeleteToken(token string) error {
	_, err := s.pool.Exec(context.Background(), `DELETE FROM device_tokens WHERE token = $1`, token)
	return err
}

func (s *PostgresDeviceTokenStore) GetTokens(userID string) ([]string, error) {
	rows, err := s.pool.Query(context.Background(), `SELECT token FROM device_tokens WHERE user_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, err
		}
		tokens = append(tokens, token)
	}
	return tokens, nil
}
