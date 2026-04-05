package auth

import (
	"github.com/mitron/backend/internal/models"
	"github.com/supabase-community/gotrue-go"
	"github.com/supabase-community/gotrue-go/types"
)

type SupabaseAuthenticator struct {
	client gotrue.Client
}

func NewSupabaseAuthenticator(url, anonKey string) *SupabaseAuthenticator {
	return &SupabaseAuthenticator{
		client: gotrue.New(url, anonKey),
	}
}

func (s *SupabaseAuthenticator) Signup(email, password string) (*models.AuthResponse, error) {
	resp, err := s.client.Signup(types.SignupRequest{
		Email:    email,
		Password: password,
	})
	if err != nil {
		return nil, err
	}

	return &models.AuthResponse{
		AccessToken: resp.AccessToken,
		User: models.User{
			ID:    resp.User.ID.String(),
			Email: resp.User.Email,
		},
	}, nil
}

func (s *SupabaseAuthenticator) Login(email, password string) (*models.AuthResponse, error) {
	resp, err := s.client.SignInWithEmailPassword(email, password)
	if err != nil {
		return nil, err
	}

	return &models.AuthResponse{
		AccessToken: resp.AccessToken,
		User: models.User{
			ID:    resp.User.ID.String(),
			Email: resp.User.Email,
		},
	}, nil
}

func (s *SupabaseAuthenticator) Signout(token string) error {
	return s.client.WithToken(token).Logout()
}

func (s *SupabaseAuthenticator) UpdateUser(token string, updateData map[string]interface{}) (*models.User, error) {
	resp, err := s.client.WithToken(token).UpdateUser(types.UpdateUserRequest{
		Data: updateData,
	})
	if err != nil {
		return nil, err
	}

	return &models.User{
		ID:    resp.User.ID.String(),
		Email: resp.User.Email,
	}, nil
}

func (s *SupabaseAuthenticator) GetUserFromToken(token string) (*models.User, error) {
	user, err := s.client.WithToken(token).GetUser()
	if err != nil {
		return nil, err
	}
	return &models.User{
		ID:    user.ID.String(),
		Email: user.Email,
	}, nil
}
