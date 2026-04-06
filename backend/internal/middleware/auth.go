package middleware

import (
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/mitron/backend/internal/auth"
)

func AuthMiddleware(authenticator auth.Authenticator) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Missing token"})
			c.Abort()
			return
		}

		if after, ok := strings.CutPrefix(token, "Bearer "); ok {
			token = after
		}

		user, err := authenticator.GetUserFromToken(token)
		if err != nil {
			log.Printf("AuthMiddleware: Failed to get user from token. Error: %v", err) // More specific logging
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		c.Set("user", user)
		c.Set("token", token)
		c.Next()
	}
}
