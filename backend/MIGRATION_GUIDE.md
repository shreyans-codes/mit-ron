# Backend Migration Guide

## Notification System

### FCM (Firebase Cloud Messaging)

**Why FCM in Backend?**

FCM is set up in the backend because:
1. **Security**: Push notifications require a service account key that must remain server-side
2. **Token Management**: The backend stores device tokens and sends notifications via FCM API
3. **Business Logic**: Notification creation happens when events occur (new message, friend request, etc.)

**How it works:**
1. Mobile app registers with FCM and gets a device token
2. App sends this token to your backend via `POST /device-token`
3. Backend stores the token in `device_tokens` table
4. When something triggers a notification (e.g., new message), backend:
   - Creates a notification record in `notifications` table
   - Sends push notification via FCM API to all stored tokens for that user
   - (Optional) Sends realtime update via Supabase

**Environment Variables:**
```env
# Required for FCM push notifications
FCM_PROJECT_ID=your-firebase-project-id
# Optional: path to service account JSON (or set GOOGLE_APPLICATION_CREDENTIALS env var)
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

---

## Swapping Push Providers

### Replace FCM with OneSignal

1. Create `backend/internal/notifications/onesignal.go`:

```go
package notifications

type OneSignalNotifier struct {
    appID   string
    apiKey  string
    client  *http.Client
}

func NewOneSignalNotifier(appID, apiKey string) *OneSignalNotifier {
    return &OneSignalNotifier{
        appID:  appID,
        apiKey: apiKey,
        client: &http.Client{Timeout: 30 * time.Second},
    }
}

func (o *OneSignalNotifier) SendPushNotification(token, title, body string, data map[string]string) error {
    // Implement OneSignal API call
    // POST https://onesignal.com/api/v1/notifications
}
```

2. Update `main.go` to use OneSignalNotifier instead of FCMNotifier:

```go
onesignalAppID := os.Getenv("ONESIGNAL_APP_ID")
onesignalAPIKey := os.Getenv("ONESIGNAL_API_KEY")
var pushNotifier notifications.PushNotifier
if onesignalAppID != "" && onesignalAPIKey != "" {
    pushNotifier = notifications.NewOneSignalNotifier(onesignalAppID, onesignalAPIKey)
}
```

3. Add environment variables:
```env
ONESIGNAL_APP_ID=your-onesignal-app-id
ONESIGNAL_API_KEY=your-onesignal-api-key
```

---

## Swapping Realtime Providers

### Replace Supabase with Custom WebSocket

1. Create `backend/internal/notifications/websocket.go`:

```go
package notifications

type WebSocketNotifier struct {
    clients map[string]*Client // userID -> WebSocket client
    hub     *Hub               // WebSocket hub for broadcasting
    mu      sync.RWMutex
}

func NewWebSocketNotifier() *WebSocketNotifier {
    return &WebSocketNotifier{
        clients: make(map[string]*Client),
    }
}
```

2. The interface remains the same - just implement `RealtimeNotifier` interface

---

## Environment Variables Summary

| Variable | Required | Description |
|-----------|----------|-------------|
| `FCM_PROJECT_ID` | No | Firebase project ID for push notifications |
| `GOOGLE_APPLICATION_CREDENTIALS` | No* | Path to service account JSON (*required if FCM_PROJECT_ID set) |
| `ONESIGNAL_APP_ID` | No* | OneSignal app ID (*use instead of FCM) |
| `ONESIGNAL_API_KEY` | No* | OneSignal API key (*use instead of FCM) |


## Realtime (Flutter + Cloudflare Pages)

The app uses the Supabase **anon key** for Realtime (`postgres_changes` on `messages` / `notifications`). This matches the previous setup: no backend JWT is sent to Supabase, and you do **not** need to align `JWT_SECRET` with Supabase’s JWT secret.

Requirements:

- Realtime enabled for `messages` and `notifications` in the Supabase dashboard.
- RLS policies (or table settings) must allow anon Realtime subscriptions if you use RLS.

**Web:** If live updates are unreliable in the browser, chat polls every 3s as a fallback. **Android/iOS** rely on Realtime only (8s poll is a light backup).