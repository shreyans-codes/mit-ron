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
	"github.com/mitron/backend/internal/storage"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found")
	}

	dbURL := os.Getenv("DATABASE_URL")
	supabaseURL := os.Getenv("SUPABASE_URL")
	supabaseAnonKey := os.Getenv("SUPABASE_ANON_KEY")
	jwtSecret := os.Getenv("JWT_SECRET")

	if dbURL == "" || jwtSecret == "" {
		log.Fatal("DATABASE_URL and JWT_SECRET must be set")
	}

	poolConfig, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		log.Fatalf("Failed to parse DATABASE_URL: %v", err)
	}

	// pgx v5 uses StatementCacheCapacity / DefaultQueryExecMode, not MaxPreparedStatements.
	// Transaction poolers (e.g. Supabase :6543, PgBouncer) break named prepared statements
	// (stmtcache_*), which surfaces as SQLSTATE 42P05 "already exists".
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

	storageProvider := storage.NewSupabaseStorage(supabaseURL, supabaseAnonKey)
	handler := api.NewHandler(authenticator, storageProvider)

	r := gin.Default()

	// CORS configuration
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"}, // Adjust this in production
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// Health check for Render
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// Public routes
	r.POST("/signup", handler.HandleSignup)
	r.POST("/login", handler.HandleLogin)

	// Protected routes
	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(authenticator))
	{
		protected.POST("/signout", handler.HandleSignout)
		protected.POST("/profile/update", handler.HandleUpdateProfile)

		// User profile and search
		protected.GET("/users/search", handler.HandleSearchUsers)
		protected.GET("/profile/:username", handler.HandleGetProfile)

		// Friends
		protected.GET("/friends", handler.HandleGetFriends)
		protected.POST("/friends/add", handler.HandleAddFriend)
		protected.POST("/friends/respond", handler.HandleRespondFriendRequest)

		// Groups
		protected.POST("/groups/create", handler.HandleCreateGroup)
		protected.POST("/groups/join", handler.HandleJoinGroup)
		protected.GET("/groups/my", handler.HandleGetMyGroups)
		protected.GET("/groups/members", handler.HandleGetGroupMembers)
		protected.POST("/groups/delete", handler.HandleDeleteGroup)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Explicitly bind to 0.0.0.0 for Render compatibility
	addr := "0.0.0.0:" + port
	log.Printf("Server starting on %s", addr)
	r.Run(addr)
}

// useSimplePostgresProtocol returns true when DATABASE_URL likely points at a
// transaction pooler or when PGX_SIMPLE_PROTOCOL=1 forces it.
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
