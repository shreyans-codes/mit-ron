package main

import (
	"context"
	"log"
	"os"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/mitron/backend/internal/api"
	"github.com/mitron/backend/internal/auth"
	"github.com/mitron/backend/internal/middleware"
	"github.com/mitron/backend/internal/notifications"
	"github.com/mitron/backend/internal/storage"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found")
	}

	dbURL := os.Getenv("DATABASE_URL")
	supabaseURL := os.Getenv("SUPABASE_URL")
	supabaseAnonKey := os.Getenv("SUPABASE_ANON_KEY")
	supabaseServiceKey := os.Getenv("SUPABASE_SERVICE_ROLE_KEY")
	jwtSecret := os.Getenv("JWT_SECRET")

	if dbURL == "" || jwtSecret == "" {
		log.Fatal("DATABASE_URL and JWT_SECRET must be set")
	}

	poolConfig, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		log.Fatalf("Failed to parse DATABASE_URL: %v", err)
	}

	if useSimplePostgresProtocol(dbURL) {
		poolConfig.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
		poolConfig.ConnConfig.StatementCacheCapacity = 0
		poolConfig.ConnConfig.DescriptionCacheCapacity = 0
		log.Println("Using PostgreSQL simple query protocol (recommended for transaction poolers / Supabase pooler)")
	}

	dbPool, err := pgxpool.NewWithConfig(context.Background(), poolConfig)
	if err != nil {
		log.Fatalf("Failed to create database pool: %v", err)
	}
	defer dbPool.Close()

	authenticator, err := auth.NewPostgresAuthenticator(dbPool, jwtSecret)
	if err != nil {
		log.Fatalf("Failed to initialize authenticator: %v", err)
	}

	storageProvider := storage.NewSupabaseStorage(supabaseURL, supabaseAnonKey, supabaseServiceKey)

	var notifService *notifications.NotificationService
	realtimeNotifier, err := notifications.NewSupabaseRealtimeNotifier(supabaseURL, supabaseAnonKey, dbPool)
	if err != nil {
		log.Printf("Warning: Failed to create realtime notifier: %v", err)
	}

	fcmProjectID := os.Getenv("FCM_PROJECT_ID")
	var pushNotifier notifications.PushNotifier
	if fcmProjectID != "" {
		pushNotifier = notifications.NewFCMNotifier(&notifications.FCMConfig{
			ProjectID: fcmProjectID,
		})
		log.Printf("FCM push notifications enabled for project: %s", fcmProjectID)
	} else {
		log.Println("FCM push notifications not configured (set FCM_PROJECT_ID)")
	}

	tokenStore := notifications.NewPostgresDeviceTokenStore(dbPool)

	notifService = notifications.NewNotificationService(dbPool, realtimeNotifier, pushNotifier, tokenStore)
	log.Println("Notification service initialized")

	handler := api.NewHandler(authenticator, storageProvider, notifService)

	r := gin.Default()

	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	r.POST("/signup", handler.HandleSignup)
	r.POST("/login", handler.HandleLogin)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(authenticator))
	{
		protected.POST("/signout", handler.HandleSignout)
		protected.POST("/profile/update", handler.HandleUpdateProfile)

		protected.GET("/users/search", handler.HandleSearchUsers)
		protected.GET("/profile/:username", handler.HandleGetProfile)

		protected.GET("/friends", handler.HandleGetFriendLists)
		protected.POST("/friends/add", handler.HandleAddFriend)
		protected.POST("/friends/remove", handler.HandleRemoveFriend)
		protected.POST("/friends/respond", handler.HandleRespondToFriendRequest)

		protected.POST("/groups/create", handler.HandleCreateGroup)
		protected.POST("/groups/join", handler.HandleJoinGroup)
		protected.GET("/groups/my", handler.HandleGetMyGroups)
		protected.GET("/groups/detail", handler.HandleGetGroupDetail)
		protected.GET("/groups/members", handler.HandleGetGroupMembers)
		protected.POST("/groups/add-member", handler.HandleAddGroupMember)
		protected.POST("/groups/remove-member", handler.HandleRemoveGroupMember)
		protected.POST("/groups/delete", handler.HandleDeleteGroup)
		protected.POST("/groups/update", handler.HandleUpdateGroup)
		protected.GET("/groups/flairs", handler.HandleGetGroupFlairs)
		protected.POST("/groups/flairs", handler.HandleAddGroupFlair)
		protected.POST("/groups/flairs/assign", handler.HandleAssignFlair)
		protected.POST("/groups/flairs/remove", handler.HandleRemoveFlair)

		protected.POST("/messages/send", handler.HandleSendMessage)
		protected.GET("/messages", handler.HandleGetMessages)
		protected.POST("/messages/read", handler.HandleMarkMessagesRead)
		protected.POST("/polls/vote", handler.HandleVotePoll)

		protected.POST("/events/create", handler.HandleCreateEvent)
		protected.GET("/events", handler.HandleGetEvents)
		protected.GET("/events/detail", handler.HandleGetEventDetail)
		protected.POST("/events/resolve", handler.HandleResolveEvent)
		protected.POST("/events/delete", handler.HandleDeleteEvent)
		protected.POST("/events/update", handler.HandleUpdateEvent)

		protected.POST("/generate-image", handler.HandleGenerateImage)

		protected.GET("/notifications", handler.HandleGetNotifications)
		protected.PATCH("/notifications/:id/read", handler.HandleMarkNotificationRead)
		protected.PATCH("/notifications/read-all", handler.HandleMarkAllNotificationsRead)
		protected.GET("/notifications/unread-count", handler.HandleGetUnreadNotificationCount)
		protected.POST("/device-token", handler.HandleRegisterDeviceToken)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	local := os.Getenv("LOCAL")
	var addr string
	if local == "1" {
		addr = "localhost:" + port
	} else {
		addr = "0.0.0.0:" + port
	}

	log.Printf("Server starting on %s", addr)
	r.Run(addr)
}

func useSimplePostgresProtocol(dbURL string) bool {
	if os.Getenv("PGX_SIMPLE_PROTOCOL") == "1" {
		return true
	}
	if os.Getenv("PGX_SIMPLE_PROTOCOL") == "0" {
		return false
	}
	u := strings.ToLower(dbURL)
	return strings.Contains(u, "pooler.supabase.com") ||
		strings.Contains(u, "pgbouncer=true") ||
		strings.Contains(u, ":6543/")
}
