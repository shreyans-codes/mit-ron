package notifications

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mitron/backend/internal/models"
)

type FCMConfig struct {
	ProjectID       string
	CredentialsFile string
}

type FCMNotificationPayload struct {
	Message struct {
		Token        string `json:"token"`
		Notification struct {
			Title string `json:"title"`
			Body  string `json:"body"`
		} `json:"notification"`
		Data map[string]string `json:"data,omitempty"`
	} `json:"message"`
}

type FCMResponse struct {
	Name string `json:"name"`
}

type FCMNotifier struct {
	config      *FCMConfig
	httpClient  *http.Client
	accessToken string
	tokenExpiry time.Time
	mu          sync.Mutex
}

func NewFCMNotifier(config *FCMConfig) *FCMNotifier {
	return &FCMNotifier{
		config: config,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func (f *FCMNotifier) SendPushNotification(token, title, body string, data map[string]string) error {
	if token == "" {
		log.Println("FCM: Empty token, skipping notification")
		return nil
	}

	if err := f.ensureAccessToken(); err != nil {
		return fmt.Errorf("failed to get access token: %w", err)
	}

	payload := FCMNotificationPayload{}
	payload.Message.Token = token
	payload.Message.Notification.Title = title
	payload.Message.Notification.Body = body
	if len(data) > 0 {
		payload.Message.Data = data
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal FCM payload: %w", err)
	}

	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", f.config.ProjectID)
	req, err := http.NewRequest("POST", url, strings.NewReader(string(payloadBytes)))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+f.accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := f.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send FCM request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		log.Printf("FCM error response: %s", string(respBody))
		return fmt.Errorf("FCM returned status %d", resp.StatusCode)
	}

	log.Printf("FCM notification sent successfully to token: %s...", token[:min(20, len(token))])
	return nil
}

func (f *FCMNotifier) ensureAccessToken() error {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.accessToken != "" && time.Now().Before(f.tokenExpiry) {
		return nil
	}

	accessToken, err := f.getAccessTokenFromCredentials()
	if err != nil {
		return err
	}

	f.accessToken = accessToken
	f.tokenExpiry = time.Now().Add(55 * time.Minute) // Refresh before 1 hour expiry
	return nil
}

func (f *FCMNotifier) getAccessTokenFromCredentials() (string, error) {
	credentialsFile := f.config.CredentialsFile
	if credentialsFile == "" {
		credentialsFile = os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	}

	if credentialsFile != "" {
		return f.getAccessTokenFromFile(credentialsFile)
	}

	return f.getAccessTokenFromMetadata()
}

func (f *FCMNotifier) getAccessTokenFromFile(path string) (string, error) {
	type ServiceAccount struct {
		Type         string `json:"type"`
		ProjectID    string `json:"project_id"`
		PrivateKeyID string `json:"private_key_id"`
		PrivateKey   string `json:"private_key"`
		ClientEmail  string `json:"client_email"`
		ClientID     string `json:"client_id"`
		AuthURI      string `json:"auth_uri"`
		TokenURI     string `json:"token_uri"`
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("failed to read credentials file: %w", err)
	}

	var creds ServiceAccount
	if err := json.Unmarshal(data, &creds); err != nil {
		return "", fmt.Errorf("failed to parse credentials: %w", err)
	}

	// Parse private key
	privateKeyBytes := []byte(creds.PrivateKey)

	// Try to decode from base64 if it's base64 encoded
	keyDecoded, err := base64.RawURLEncoding.DecodeString(creds.PrivateKey)
	if err == nil {
		privateKeyBytes = keyDecoded
	}

	// Parse as PKCS1 or PKCS8
	var privateKey *rsa.PrivateKey
	if key, err := x509.ParsePKCS1PrivateKey(privateKeyBytes); err == nil {
		privateKey = key
	} else if key, err := x509.ParsePKCS8PrivateKey(privateKeyBytes); err == nil {
		privateKey = key.(*rsa.PrivateKey)
	} else {
		log.Printf("Failed to parse private key: %v", err)
		return "", fmt.Errorf("failed to parse private key: %w", err)
	}

	// Create JWT header and payload
	header := `{"alg":"RS256","typ":"JWT"}`
	now := time.Now()
	payload := fmt.Sprintf(`{
		"iss":"%s",
		"sub":"%s",
		"aud":"https://oauth2.googleapis.com",
		"iat":%d,
		"exp":%d
	}`, creds.ClientEmail, creds.ClientEmail, now.Unix(), now.Add(3600).Unix())

	headerEncoded := base64.RawURLEncoding.EncodeToString([]byte(header))
	payloadEncoded := base64.RawURLEncoding.EncodeToString([]byte(payload))
	signingInput := headerEncoded + "." + payloadEncoded

	// Sign the JWT
	hash := sha256.Sum256([]byte(signingInput))
	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, hash[:])
	if err != nil {
		return "", fmt.Errorf("failed to sign JWT: %w", err)
	}

	jwtAssertion := signingInput + "." + base64.RawURLEncoding.EncodeToString(signature)

	// Exchange JWT for access token
	tokenURL := creds.TokenURI
	if tokenURL == "" {
		tokenURL = "https://oauth2.googleapis.com/token"
	}

	req, err := http.NewRequest("POST", tokenURL, strings.NewReader(
		"grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion="+jwtAssertion))
	if err != nil {
		return "", fmt.Errorf("failed to create token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := f.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to exchange JWT for token: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("Token exchange response: %s", string(body))
		return "", fmt.Errorf("token exchange failed with status %d", resp.StatusCode)
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("failed to decode token response: %w", err)
	}

	log.Printf("Successfully obtained FCM access token")
	return tokenResp.AccessToken, nil
}

func (f *FCMNotifier) getAccessTokenFromMetadata() (string, error) {
	req, err := http.NewRequest("GET", "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token", nil)
	if err != nil {
		return "", fmt.Errorf("failed to create metadata request: %w", err)
	}
	req.Header.Set("Metadata-Flavor", "Google")

	resp, err := f.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to get metadata token: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("metadata service returned status %d", resp.StatusCode)
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("failed to decode token response: %w", err)
	}

	return tokenResp.AccessToken, nil
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

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
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
