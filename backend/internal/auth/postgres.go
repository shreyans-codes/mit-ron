package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/mitron/backend/internal/models"
	"golang.org/x/crypto/bcrypt"
)

type PostgresAuthenticator struct {
	conn      *pgx.Conn
	jwtSecret []byte
}

func NewPostgresAuthenticator(dbURL, jwtSecret string) (*PostgresAuthenticator, error) {
	conn, err := pgx.Connect(context.Background(), dbURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %v", err)
	}

	return &PostgresAuthenticator{
		conn:      conn,
		jwtSecret: []byte(jwtSecret),
	}, nil
}

func (p *PostgresAuthenticator) Signup(email, password string) (*models.AuthResponse, error) {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	var userID string
	err = p.conn.QueryRow(context.Background(),
		"INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id",
		email, string(hashedPassword)).Scan(&userID)
	
	if err != nil {
		return nil, fmt.Errorf("could not create user: %v", err)
	}

	token, err := p.generateToken(userID)
	if err != nil {
		return nil, err
	}

	return &models.AuthResponse{
		AccessToken: token,
		User: models.User{
			ID:    userID,
			Email: email,
		},
	}, nil
}

func (p *PostgresAuthenticator) Login(email, password string) (*models.AuthResponse, error) {
	var userID, hashedPassword string
	err := p.conn.QueryRow(context.Background(),
		"SELECT id, password_hash FROM users WHERE email = $1",
		email).Scan(&userID, &hashedPassword)
	
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("user not found")
		}
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password)); err != nil {
		return nil, errors.New("invalid credentials")
	}

	token, err := p.generateToken(userID)
	if err != nil {
		return nil, err
	}

	return &models.AuthResponse{
		AccessToken: token,
		User: models.User{
			ID:    userID,
			Email: email,
		},
	}, nil
}

func (p *PostgresAuthenticator) Signout(token string) error {
	// For JWT, signout is usually handled on FE by deleting token.
	// You could implement a blacklist table here if needed.
	return nil
}

func (p *PostgresAuthenticator) UpdateUser(token string, updateData map[string]interface{}) (*models.User, error) {
	user, err := p.GetUserFromToken(token)
	if err != nil {
		return nil, err
	}

	if displayName, ok := updateData["display_name"].(string); ok {
		_, err = p.conn.Exec(context.Background(),
			"UPDATE users SET display_name = $1 WHERE id = $2",
			displayName, user.ID)
	}
	
	if avatarURL, ok := updateData["avatar_url"].(string); ok {
		_, err = p.conn.Exec(context.Background(),
			"UPDATE users SET avatar_url = $1 WHERE id = $2",
			avatarURL, user.ID)
	}

	if err != nil {
		return nil, err
	}

	return user, nil
}

func (p *PostgresAuthenticator) GetUserFromToken(tokenString string) (*models.User, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		return p.jwtSecret, nil
	})

	if err != nil || !token.Valid {
		return nil, errors.New("invalid token")
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, errors.New("invalid token claims")
	}

	userID := claims["user_id"].(string)
	
	var email string
	err = p.conn.QueryRow(context.Background(),
		"SELECT email FROM users WHERE id = $1", userID).Scan(&email)
	
	if err != nil {
		return nil, err
	}

	return &models.User{
		ID:    userID,
		Email: email,
	}, nil
}

func (p *PostgresAuthenticator) generateToken(userID string) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": userID,
		"exp":     time.Now().Add(time.Hour * 72).Unix(),
	})

	return token.SignedString(p.jwtSecret)
}

func (p *PostgresAuthenticator) Close() {
	if p.conn != nil {
		p.conn.Close(context.Background())
	}
}
