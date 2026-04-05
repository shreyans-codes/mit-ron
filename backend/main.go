package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
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

	// Initialize modular components
	authenticator, err := auth.NewPostgresAuthenticator(dbURL, jwtSecret)
	if err != nil {
		log.Fatalf("Failed to initialize authenticator: %v", err)
	}
	defer authenticator.Close()

	// Use Supabase for storage only
	storageProvider := storage.NewSupabaseStorage(supabaseURL, supabaseAnonKey)
	handler := api.NewHandler(authenticator, storageProvider)

	r := gin.Default()

	// Public routes
	r.POST("/signup", handler.HandleSignup)
	r.POST("/login", handler.HandleLogin)

	// Protected routes
	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(authenticator))
	{
		protected.POST("/signout", handler.HandleSignout)
		protected.POST("/profile/update", handler.HandleUpdateProfile)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	r.Run(":" + port)
}
