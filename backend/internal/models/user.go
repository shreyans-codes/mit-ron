package models

import "time"

type User struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	Username     string    `json:"username"`
	PasswordHash string    `json:"-"`
	DisplayName  *string   `json:"display_name,omitempty"`
	AvatarURL    *string   `json:"avatar_url,omitempty"`
	Bio          *string   `json:"bio,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}

type AuthResponse struct {
	AccessToken string `json:"access_token"`
	User        User   `json:"user"`
}

type Profile struct {
	ID          string   `json:"id"`
	Username    string   `json:"username"`
	DisplayName *string  `json:"display_name"`
	AvatarURL   *string  `json:"avatar_url"`
	Bio         *string  `json:"bio"`
	IsCreator   bool    `json:"is_creator,omitempty"`
	Flairs      []Flair `json:"flairs,omitempty"`
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
	ID             string    `json:"id"`
	Name           string    `json:"name"`
	Description    *string   `json:"description,omitempty"`
	CreatedBy      *string   `json:"created_by"`
	CreatedAt      time.Time `json:"created_at"`
	MemberCount    int       `json:"member_count"`
	GroupImageURL  *string   `json:"group_image_url,omitempty"`
	ChatID         *string   `json:"chat_id,omitempty"`
	LastActivityAt *string   `json:"last_activity_at,omitempty"`
	UnreadCount    int       `json:"unread_count,omitempty"`
}

type GroupMember struct {
	GroupID  string    `json:"group_id"`
	UserID   string    `json:"user_id"`
	Role     *string   `json:"role"`
	JoinedAt time.Time `json:"joined_at"`
}

type Flair struct {
	ID      string  `json:"id"`
	Name    string  `json:"name"`
	GroupID *string `json:"group_id,omitempty"`
}

type GroupMemberWithFlairs struct {
	GroupMember
	Flairs []Flair `json:"flairs,omitempty"`
}

type Event struct {
	ID              string    `json:"id"`
	GroupID         string    `json:"group_id"`
	Title           string    `json:"title"`
	Description     *string   `json:"description"`
	CreatedBy       *string   `json:"created_by"`
	CreatedAt       time.Time `json:"created_at"`
	ResolutionMsgID *string   `json:"resolution_message_id"`
	ChatID          *string   `json:"chat_id,omitempty"`
	LastActivityAt  *string   `json:"last_activity_at,omitempty"`
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
	MessageType  MessageType        `json:"message_type"`
	Poll         *MessagePollDetails `json:"poll,omitempty"`
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

type PollOptionWithVotes struct {
	ID         string `json:"id"`
	OptionText string `json:"option_text"`
	VoteCount  int    `json:"vote_count"`
}

type MessagePollDetails struct {
	MessageID        string                `json:"message_id"`
	Question         string                `json:"question"`
	IsMultipleChoice bool                  `json:"is_multiple_choice"`
	Options          []PollOptionWithVotes `json:"options"`
	MyVoteOptionIDs  []string              `json:"my_vote_option_ids,omitempty"`
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

type NotificationType string

const (
	NotificationTypeNewMessage     NotificationType = "new_message"
	NotificationTypeFriendRequest  NotificationType = "friend_request"
	NotificationTypeGroupAdded     NotificationType = "group_added"
	NotificationTypeFriendResponse NotificationType = "friend_response"
)

type ReferenceType string

const (
	ReferenceTypeMessage ReferenceType = "message"
	ReferenceTypeGroup   ReferenceType = "group"
	ReferenceTypeFriend  ReferenceType = "friend"
	ReferenceTypeEvent   ReferenceType = "event"
)

type Notification struct {
	ID            string           `json:"id"`
	UserID        string           `json:"user_id"`
	Type          NotificationType `json:"type"`
	ReferenceID   *string          `json:"reference_id,omitempty"`
	ReferenceType *ReferenceType   `json:"reference_type,omitempty"`
	Title         string           `json:"title"`
	Body          *string          `json:"body,omitempty"`
	IsRead        bool             `json:"is_read"`
	CreatedAt     time.Time        `json:"created_at"`
}

type DeviceToken struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Token     string    `json:"token"`
	Platform  string    `json:"platform"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
