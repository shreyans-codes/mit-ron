package api

import (
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mitron/backend/internal/auth"
	"github.com/mitron/backend/internal/storage"
)

type Handler struct {
	auth    auth.Authenticator
	storage storage.StorageProvider
}

func NewHandler(a auth.Authenticator, s storage.StorageProvider) *Handler {
	return &Handler{auth: a, storage: s}
}

type AuthRequest struct {
	Email    string `json:"email" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func (h *Handler) HandleSignup(c *gin.Context) {
	var req AuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	resp, err := h.auth.Signup(req.Email, req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *Handler) HandleLogin(c *gin.Context) {
	var req AuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	resp, err := h.auth.Login(req.Email, req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid login credentials"})
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *Handler) HandleSignout(c *gin.Context) {
	token := c.GetString("token")
	err := h.auth.Signout(token)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Signed out successfully"})
}

func (h *Handler) HandleUpdateProfile(c *gin.Context) {
	token := c.GetString("token")

	// Handle file upload
	file, err := c.FormFile("avatar")
	var avatarURL string
	if err == nil {
		openedFile, err := file.Open()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to open file"})
			return
		}
		defer openedFile.Close()

		fileBytes, err := io.ReadAll(openedFile)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
			return
		}

		fileName := fmt.Sprintf("%d_%s", SystemTimeNow(), filepath.Base(file.Filename))
		avatarURL, err = h.storage.UploadFile("avatars", fileName, fileBytes)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Upload failed: " + err.Error()})
			return
		}
	}

	displayName := c.PostForm("display_name")
	updateData := map[string]interface{}{}
	if displayName != "" {
		updateData["display_name"] = displayName
	}
	if avatarURL != "" {
		updateData["avatar_url"] = avatarURL
	}

	if len(updateData) > 0 {
		user, err := h.auth.UpdateUser(token, updateData)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, user)
		return
	}

	c.JSON(http.StatusBadRequest, gin.H{"error": "No updates provided"})
}

// Helper for unique filename
func SystemTimeNow() int64 {
	return time.Now().UnixNano()
}
