package models

type User struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

type Profile struct {
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url"`
}

type AuthResponse struct {
	AccessToken string `json:"access_token"`
	User        User   `json:"user"`
}
