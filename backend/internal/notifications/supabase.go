package notifications

import (
	"fmt"
	"log"
	"sync"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mitron/backend/internal/models"
	"github.com/supabase-community/supabase-go"
)

type SupabaseRealtimeNotifier struct {
	supabaseClient *supabase.Client
	pool           *pgxpool.Pool
	subscriptions  map[string]*RealtimeSubscription
	mu             sync.RWMutex
}

type RealtimeSubscription struct {
	UserID  string
	Channel string
}

func NewSupabaseRealtimeNotifier(supabaseURL, supabaseAnonKey string, pool *pgxpool.Pool) (*SupabaseRealtimeNotifier, error) {
	client, err := supabase.NewClient(supabaseURL, supabaseAnonKey, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create supabase client: %w", err)
	}

	return &SupabaseRealtimeNotifier{
		supabaseClient: client,
		pool:           pool,
		subscriptions:  make(map[string]*RealtimeSubscription),
	}, nil
}

func (s *SupabaseRealtimeNotifier) Subscribe(userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.subscriptions[userID]; exists {
		return nil
	}

	channelName := fmt.Sprintf("notifications-%s", userID)
	s.subscriptions[userID] = &RealtimeSubscription{
		UserID:  userID,
		Channel: channelName,
	}

	log.Printf("Subscribed user %s to realtime channel %s", userID, channelName)
	return nil
}

func (s *SupabaseRealtimeNotifier) Unsubscribe(userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	delete(s.subscriptions, userID)
	log.Printf("Unsubscribed user %s from realtime", userID)
	return nil
}

func (s *SupabaseRealtimeNotifier) SendNotification(userID string, notif models.Notification) error {
	s.mu.RLock()
	_, exists := s.subscriptions[userID]
	s.mu.RUnlock()

	if !exists {
		log.Printf("User %s not subscribed, skipping realtime notification", userID)
		return nil
	}

	log.Printf("Would send realtime notification to user %s: type=%s, title=%s", userID, notif.Type, notif.Title)
	return nil
}

func (s *SupabaseRealtimeNotifier) SendPushNotification(token, title, body string, data map[string]string) error {
	log.Println("Supabase realtime does not support push notifications. Use FCM notifier instead.")
	return nil
}
