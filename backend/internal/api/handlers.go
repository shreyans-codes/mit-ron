package api

import (
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mitron/backend/internal/auth"
	"github.com/mitron/backend/internal/models"
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
	LoginIdentifier string `json:"login_identifier" binding:"required"` // Combined email/username
	Password        string `json:"password" binding:"required"`
}

type SignupRequest struct {
	Username string `json:"username" binding:"required"`
	Email    string `json:"email" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func (h *Handler) HandleSignup(c *gin.Context) {
	var req SignupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	resp, err := h.auth.Signup(req.Username, req.Email, req.Password)
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

	resp, err := h.auth.Login(req.LoginIdentifier, req.Password) // Use loginIdentifier
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
		if h.storage == nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Storage provider not initialized"})
			return
		}
		avatarURL, err = h.storage.UploadFile("avatars", fileName, fileBytes)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Upload failed: " + err.Error()})
			return
		}
	} else if !errors.Is(err, http.ErrMissingFile) {
		log.Printf("Error retrieving avatar file: %v", err)
	}

	displayName := c.PostForm("display_name")
	bio := c.PostForm("bio")
	username := c.PostForm("username")

	updateData := map[string]interface{}{}
	if displayName != "" {
		updateData["display_name"] = displayName
	}
	if avatarURL != "" {
		updateData["avatar_url"] = avatarURL
	}
	if bio != "" {
		updateData["bio"] = bio
	}
	if username != "" {
		updateData["username"] = username
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

// --- New Handlers for Users, Friends, Groups ---

func (h *Handler) HandleSearchUsers(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Query parameter 'q' is required"})
		return
	}

	profiles, err := h.auth.SearchUsers(query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to search users: %v", err)})
		return
	}

	c.JSON(http.StatusOK, profiles)
}

func (h *Handler) HandleGetProfile(c *gin.Context) {
	username := c.Param("username")
	if username == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username parameter is required"})
		return
	}

	token := c.GetString("token")
	requestingUserID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	targetUser, err := h.auth.GetUserByUsername(username)
	isOwner := err == nil && targetUser.ID == requestingUserID

	var profileWithStatus *models.ProfileWithStatus
	if isOwner {
		profile, err := h.auth.GetProfile(username)
		if err != nil {
			if errors.Is(err, errors.New("user profile not found")) {
				c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			} else {
				c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to get user profile: %v", err)})
			}
			return
		}
		profileWithStatus = &models.ProfileWithStatus{
			Profile:      *profile,
			IsFriend:     false,
			FriendStatus: nil,
		}
		enriched := h.enrichProfileWithSignedURLs(*profileWithStatus)
		profileWithStatus = &enriched
	} else {
		var err error
		profileWithStatus, err = h.auth.GetProfileWithFriendshipStatus(requestingUserID, username)
		if err != nil {
			if errors.Is(err, errors.New("user profile not found")) {
				c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			} else {
				c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to get user profile: %v", err)})
			}
			return
		}
		enriched := h.enrichProfileWithSignedURLs(*profileWithStatus)
		profileWithStatus = &enriched
	}

	c.JSON(http.StatusOK, profileWithStatus)
}

func (h *Handler) enrichProfileWithSignedURLs(profile models.ProfileWithStatus) models.ProfileWithStatus {
	return profile
}

func (h *Handler) HandleGetFriendLists(c *gin.Context) {
	token := c.GetString("token")
	userID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	friendLists, err := h.auth.GetFriendLists(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to fetch friends: %v", err)})
		return
	}

	c.JSON(http.StatusOK, friendLists)
}

func (h *Handler) HandleAddFriend(c *gin.Context) {
	token := c.GetString("token")
	currentUserID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		FriendUsername string `json:"friend_username" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	friendUser, err := h.auth.GetUserByUsername(req.FriendUsername)
	if err != nil {
		if errors.Is(err, errors.New("user not found")) {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to find user: %v", err)})
		}
		return
	}

	err = h.auth.AddFriend(currentUserID, friendUser.ID)
	if err != nil {
		switch {
		case errors.Is(err, auth.ErrAlreadyFriends), errors.Is(err, auth.ErrFriendRequestPending):
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend request sent successfully"})
}

func (h *Handler) HandleRemoveFriend(c *gin.Context) {
	token := c.GetString("token")
	currentUserID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		FriendUsername string `json:"friend_username" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	friendUser, err := h.auth.GetUserByUsername(req.FriendUsername)
	if err != nil {
		if errors.Is(err, errors.New("user not found")) {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to find user: %v", err)})
		}
		return
	}

	err = h.auth.RemoveFriend(currentUserID, friendUser.ID)
	if err != nil {
		if err.Error() == "cannot remove yourself as a friend" {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "user is not your friend" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend removed successfully"})
}

func (h *Handler) HandleRespondToFriendRequest(c *gin.Context) {
	token := c.GetString("token")
	currentUserID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		InitiatorID string `json:"initiator_id" binding:"required"`
		Accept      bool   `json:"accept"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.auth.RespondToFriendRequest(currentUserID, req.InitiatorID, req.Accept)
	if err != nil {
		if errors.Is(err, auth.ErrFriendRequestNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if req.Accept {
		c.JSON(http.StatusOK, gin.H{"message": "Friend request accepted"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Friend request declined"})
}

func (h *Handler) HandleCreateGroup(c *gin.Context) {
	token := c.GetString("token")
	creatorID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	name := c.PostForm("name")
	if name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name is required"})
		return
	}
	description := c.PostForm("description")
	avatarURL := ""

	file, err := c.FormFile("avatar")
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

		fileName := fmt.Sprintf("group_%d_%s", time.Now().UnixNano(), filepath.Base(file.Filename))
		if h.storage == nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Storage provider not initialized"})
			return
		}
		avatarURL, err = h.storage.UploadFile("group-icons", fileName, fileBytes)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Upload failed: " + err.Error()})
			return
		}
	} else if !errors.Is(err, http.ErrMissingFile) {
		log.Printf("Error retrieving group avatar: %v", err)
	}

	group, err := h.auth.CreateGroup(name, description, creatorID, avatarURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	enrichedGroup := h.enrichGroupWithSignedURLs(*group)
	c.JSON(http.StatusCreated, enrichedGroup)
}

func (h *Handler) HandleJoinGroup(c *gin.Context) {
	token := c.GetString("token")
	userID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		GroupID string `json:"group_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.auth.JoinGroup(req.GroupID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Successfully joined group"})
}

func (h *Handler) HandleGetMyGroups(c *gin.Context) {
	token := c.GetString("token")
	userID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	groups, err := h.auth.GetMyGroups(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to retrieve groups: %v", err)})
		return
	}

	enrichedGroups := make([]models.Group, len(groups))
	for i, group := range groups {
		enrichedGroups[i] = h.enrichGroupWithSignedURLs(group)
	}

	c.JSON(http.StatusOK, enrichedGroups)
}

func (h *Handler) HandleGetGroupDetail(c *gin.Context) {
	token := c.GetString("token")
	_, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	groupID := c.Query("group_id")
	if groupID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "group_id is required"})
		return
	}

	group, err := h.auth.GetGroupByID(groupID)
	if err != nil {
		if err.Error() == "group not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to get group: %v", err)})
		return
	}

	enrichedGroup := h.enrichGroupWithSignedURLs(*group)
	c.JSON(http.StatusOK, enrichedGroup)
}

func (h *Handler) enrichGroupWithSignedURLs(group models.Group) models.Group {
	return group
}

func (h *Handler) HandleGetGroupMembers(c *gin.Context) {
	groupID := c.Query("group_id")
	if groupID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "group_id is required"})
		return
	}

	profiles, err := h.auth.GetGroupMembers(groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to retrieve group members: %v", err)})
		return
	}

	c.JSON(http.StatusOK, profiles)
}

func (h *Handler) HandleDeleteGroup(c *gin.Context) {
	token := c.GetString("token")
	userID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		GroupID string `json:"group_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.auth.DeleteGroup(req.GroupID, userID)
	if err != nil {
		if err.Error() == "only the group creator can delete this group" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "group not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Group deleted successfully"})
}

func (h *Handler) HandleAddGroupMember(c *gin.Context) {
	token := c.GetString("token")
	_, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		GroupID string `json:"group_id" binding:"required"`
		UserID  string `json:"user_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.auth.AddGroupMember(req.GroupID, req.UserID)
	if err != nil {
		if err.Error() == "group not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "user is already a member of this group" {
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Member added successfully"})
}

func (h *Handler) HandleRemoveGroupMember(c *gin.Context) {
	token := c.GetString("token")
	userID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		GroupID string `json:"group_id" binding:"required"`
		UserID  string `json:"user_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.auth.RemoveGroupMember(req.GroupID, userID, req.UserID)
	if err != nil {
		if err.Error() == "group not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "only the group creator can remove members" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "cannot remove yourself from the group" {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "user is not a member of this group" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Member removed successfully"})
}

func (h *Handler) HandleGenerateImage(c *gin.Context) {
	token := c.GetString("token")
	_, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		FilePath string `json:"file_path" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file_path is required"})
		return
	}

	if req.FilePath == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file_path cannot be empty"})
		return
	}

	urlResult, err := h.storage.GetSignedURLFromPath(req.FilePath, 3600)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate signed URL: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"signed_url": urlResult.SignedURL})
}

// Helper functions
func (h *Handler) getUserIDFromToken(token string) (string, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return "", errors.New("authorization token missing")
	}
	// AuthMiddleware stores the raw JWT after stripping "Bearer ".
	// Accept optional "Bearer " prefix for callers that pass the full header value.
	if len(token) >= 7 && strings.EqualFold(token[:7], "bearer ") {
		token = strings.TrimSpace(token[7:])
	}
	if token == "" {
		return "", errors.New("invalid authorization format")
	}

	user, err := h.auth.GetUserFromToken(token)
	if err != nil {
		return "", err
	}
	return user.ID, nil
}

// getUserByUsername retrieves user by username using the authenticator.
func (h *Handler) getUserByUsername(username string) (*models.User, error) {
	// Delegate the call to the authenticator
	return h.auth.GetUserByUsername(username)
}

// Helper for unique filename
func SystemTimeNow() int64 {
	return time.Now().UnixNano()
}

func (h *Handler) HandleSendMessage(c *gin.Context) {
	token := c.GetString("token")
	userID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		GroupID      string  `json:"group_id"`
		EventID      string  `json:"event_id"`
		Content      string  `json:"content" binding:"required"`
		ParentID     *string `json:"parent_id"`
		ThreadID     *string `json:"thread_id"`
		IsThreadRoot bool    `json:"is_thread_root"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Content == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "content is required"})
		return
	}

	var chatID string
	if req.EventID != "" {
		chatID, err = h.auth.GetEventChatID(req.EventID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get event chat"})
			return
		}
	} else if req.GroupID != "" {
		chatID, err = h.auth.GetOrCreateGroupChat(req.GroupID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get group chat"})
			return
		}
	} else {
		c.JSON(http.StatusBadRequest, gin.H{"error": "group_id or event_id is required"})
		return
	}

	message, err := h.auth.CreateMessage(chatID, userID, req.Content, req.ParentID, req.ThreadID, req.IsThreadRoot)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to send message: %v", err)})
		return
	}

	c.JSON(http.StatusCreated, message)
}

func (h *Handler) HandleGetMessages(c *gin.Context) {
	token := c.GetString("token")
	_, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	groupID := c.Query("group_id")
	eventID := c.Query("event_id")

	if groupID == "" && eventID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "group_id or event_id is required"})
		return
	}

	var messages []models.Message
	if eventID != "" {
		messages, err = h.auth.GetEventMessages(eventID)
	} else {
		messages, err = h.auth.GetMessages(groupID)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to get messages: %v", err)})
		return
	}

	c.JSON(http.StatusOK, messages)
}

func (h *Handler) HandleGetEvents(c *gin.Context) {
	token := c.GetString("token")
	_, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	groupID := c.Query("group_id")
	if groupID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "group_id is required"})
		return
	}

	events, err := h.auth.GetEvents(groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to get events: %v", err)})
		return
	}

	c.JSON(http.StatusOK, events)
}

func (h *Handler) HandleCreateEvent(c *gin.Context) {
	token := c.GetString("token")
	userID, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		GroupID     string `json:"group_id" binding:"required"`
		Title       string `json:"title" binding:"required"`
		Description string `json:"description"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	event, err := h.auth.CreateEvent(req.GroupID, req.Title, req.Description, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to create event: %v", err)})
		return
	}

	c.JSON(http.StatusCreated, event)
}

func (h *Handler) HandleResolveEvent(c *gin.Context) {
	token := c.GetString("token")
	_, err := h.getUserIDFromToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var req struct {
		EventID   string `json:"event_id" binding:"required"`
		MessageID string `json:"message_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.auth.ResolveEvent(req.EventID, req.MessageID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to resolve event: %v", err)})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Event resolved"})
}
