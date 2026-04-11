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

type AuthResponse struct {
	AccessToken string `json:"access_token"`
	User        User   `json:"user"`
}

type Profile struct {
	ID          string  `json:"id"`
	Username    string  `json:"username"`
	DisplayName *string `json:"display_name"`
	AvatarURL   *string `json:"avatar_url"`
	Bio         *string `json:"bio"`
}

type ProfileWithStatus struct {
	Profile
	IsFriend     bool    `json:"is_friend"`
	FriendStatus *string `json:"friend_status,omitempty"`
	IsIncoming   bool    `json:"is_incoming,omitempty"`
}

type FriendLists struct {
	Friends         []Profile              `json:"friends"`
	PendingIncoming []PendingFriendProfile `json:"pending_incoming"`
	PendingOutgoing []PendingFriendProfile `json:"pending_outgoing"`
}

type PendingFriendProfile struct {
	Profile     Profile `json:"profile"`
	InitiatorID string  `json:"initiator_id"`
}

type Group struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	Description   *string   `json:"description,omitempty"`
	CreatorID     *string   `json:"created_by"`
	CreatedAt     time.Time `json:"created_at"`
	MemberCount   int       `json:"member_count"`
	GroupImageURL *string   `json:"group_image_url,omitempty"`
}

type GroupMember struct {
	GroupID  string    `json:"group_id"`
	UserID   string    `json:"user_id"`
	JoinedAt time.Time `json:"joined_at"`
}

type Event struct {
	ID              string    `json:"id"`
	GroupID         string    `json:"group_id"`
	Title           string    `json:"title"`
	Description     *string   `json:"description"`
	CreatorID       *string   `json:"created_by"`
	CreatedAt       time.Time `json:"created_at"`
	ResolutionMsgID *string   `json:"resolution_message_id"`
	ChatID          *string   `json:"chat_id,omitempty"`
}

type Chat struct {
	ID        string    `json:"id"`
	Type      string    `json:"type"`
	GroupID   *string   `json:"group_id"`
	EventID   *string   `json:"event_id"`
	CreatedAt time.Time `json:"created_at"`
}

type MessageType string

const (
	MessageTypeText MessageType = "text"
	MessageTypePoll MessageType = "poll"
	MessageTypeMap  MessageType = "map"
	MessageTypeLink MessageType = "link"
)

type Message struct {
	ID           string      `json:"id"`
	GroupID      string      `json:"group_id,omitempty"`
	ChatID       string      `json:"chat_id,omitempty"`
	SenderID     string      `json:"sender_id"`
	SenderName   string      `json:"sender_name,omitempty"`
	Type         MessageType `json:"type"`
	Content      string      `json:"content"`
	ParentMsgID  *string     `json:"parent_id,omitempty"`
	ParentID     *string     `json:"parent_message_id,omitempty"`
	ThreadID     *string     `json:"thread_id,omitempty"`
	IsThreadRoot bool        `json:"is_thread_root"`
	CreatedAt    time.Time   `json:"created_at"`
	UpdatedAt    *time.Time  `json:"updated_at,omitempty"`
	MessageType  MessageType `json:"message_type"`
}

type Poll struct {
	MessageID        string `json:"message_id"`
	Question         string `json:"question"`
	IsMultipleChoice bool   `json:"is_multiple_choice"`
}

type PollOption struct {
	ID         string `json:"id"`
	PollID     string `json:"poll_id"`
	OptionText string `json:"option_text"`
}

type PollVote struct {
	PollID   string `json:"poll_id"`
	OptionID string `json:"option_id"`
	UserID   string `json:"user_id"`
}

type MessageMedia struct {
	MessageID    string  `json:"message_id"`
	MediaURL     string  `json:"media_url"`
	MediaType    *string `json:"media_type"`
	ThumbnailURL *string `json:"thumbnail_url"`
}

type MessageMap struct {
	MessageID string  `json:"message_id"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	PlaceName *string `json:"place_name"`
	MapLink   *string `json:"map_link"`
}

type MessageLink struct {
	MessageID    string  `json:"message_id"`
	URL          string  `json:"url"`
	Title        *string `json:"title"`
	Description  *string `json:"description"`
	PreviewImage *string `json:"preview_image"`
}
