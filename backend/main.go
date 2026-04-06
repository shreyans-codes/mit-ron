package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5" // Import pgx
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

	// Initialize database connection
	conn, err := pgx.Connect(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer conn.Close(context.Background()) // Ensure connection is closed

	// Initialize modular components
	authenticator, err := auth.NewPostgresAuthenticator(conn, jwtSecret) // Pass existing conn
	if err != nil {
		log.Fatalf("Failed to initialize authenticator: %v", err)
	}
	defer authenticator.Close() // Ensure authenticator's connection is closed

	// Use Supabase for storage only
	storageProvider := storage.NewSupabaseStorage(supabaseURL, supabaseAnonKey)
	// Pass the connection to the handler
	handler := api.NewHandler(authenticator, storageProvider, conn)

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
		protected.POST("/friends/add", handler.HandleAddFriend)

		// Groups
		protected.POST("/groups/create", handler.HandleCreateGroup)
		protected.POST("/groups/join", handler.HandleJoinGroup)
		protected.GET("/groups/my", handler.HandleGetMyGroups)
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
