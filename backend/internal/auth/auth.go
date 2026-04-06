package auth

import (
	"github.com/mitron/backend/internal/models"
)

type Authenticator interface {
	Signup(username, email, password string) (*models.AuthResponse, error)
	Login(email, password string) (*models.AuthResponse, error)
	Signout(token string) error
	UpdateUser(token string, updateData map[string]interface{}) (*models.User, error)
	GetUserFromToken(token string) (*models.User, error)
	GetUserByUsername(username string) (*models.User, error)
	SearchUsers(query string) ([]models.Profile, error)
	AddFriend(initiatorID, recipientID string) error
	RespondToFriendRequest(recipientID, initiatorID string, accept bool) error
	GetFriendLists(userID string) (*models.FriendLists, error)
	CreateGroup(name, description, creatorID string) (*models.Group, error)
	JoinGroup(groupID, userID string) error
	GetMyGroups(userID string) ([]models.Group, error)
	GetProfile(username string) (*models.Profile, error)
}
