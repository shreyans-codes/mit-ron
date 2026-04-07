package models

import "time"

type User struct {
	ID          string    `json:"id"`
	Email       string    `json:"email"`
	Username    string    `json:"username"`
	DisplayName *string   `json:"display_name"`
	AvatarURL   *string   `json:"avatar_url"`
	Bio         *string   `json:"bio"`
	CreatedAt   time.Time `json:"created_at"`
}

type Profile struct {
	ID          string  `json:"id"`
	Username    string  `json:"username"`
	DisplayName *string `json:"display_name"`
	AvatarURL   *string `json:"avatar_url"`
	Bio         *string `json:"bio"`
}

type AuthResponse struct {
	AccessToken string `json:"access_token"`
	User        User   `json:"user"`
}

// FriendshipStatus matches Postgres enum public.friendship_status.
type FriendshipStatus string

const (
	FriendshipPending  FriendshipStatus = "pending"
	FriendshipAccepted FriendshipStatus = "accepted"
	FriendshipRejected FriendshipStatus = "rejected"
)

// Friend is one row in public.friends (directional request / relationship).
type Friend struct {
	InitiatorID string           `json:"initiator_id"`
	RecipientID string           `json:"recipient_id"`
	Status      FriendshipStatus `json:"status"`
	CreatedAt   time.Time        `json:"created_at"`
}

// PendingFriendProfile is a pending request with the other user's profile and initiator id (for accept/reject).
type PendingFriendProfile struct {
	Profile     Profile `json:"profile"`
	InitiatorID string  `json:"initiator_id"`
}

// FriendLists is returned by GET /friends.
type FriendLists struct {
	Friends         []Profile              `json:"friends"`
	PendingIncoming []PendingFriendProfile `json:"pending_incoming"`
	PendingOutgoing []PendingFriendProfile `json:"pending_outgoing"`
}

type Group struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description *string   `json:"description"`
	CreatorID   string    `json:"creator_id"`
	CreatedAt   time.Time `json:"created_at"`
	MemberCount int       `json:"member_count"`
}

type GroupMember struct {
	GroupID  string    `json:"group_id"`
	UserID   string    `json:"user_id"`
	JoinedAt time.Time `json:"joined_at"`
	Flairs   []Flair   `json:"flairs,omitempty"`
}

type Flair struct {
	ID      string  `json:"id"`
	Name    string  `json:"name"`
	GroupID *string `json:"group_id,omitempty"` // null for global flairs
}
