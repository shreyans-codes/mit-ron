package auth

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
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

func (p *PostgresAuthenticator) Signup(username, email, password string) (*models.AuthResponse, error) {
	log.Printf("Signup attempt for username=%s, email=%s", username, email)
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("Bcrypt error during signup: %v", err)
		return nil, err
	}

	var userID string
	err = p.conn.QueryRow(context.Background(),
		"INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING id",
		username, email, string(hashedPassword)).Scan(&userID)

	if err != nil {
		log.Printf("Database error during signup: %v", err)
		return nil, fmt.Errorf("could not create user: %v", err)
	}

	log.Printf("User created successfully: %s", userID)
	token, err := p.generateToken(userID)
	if err != nil {
		log.Printf("Token generation error during signup: %v", err)
		return nil, err
	}

	// Fetch user details after creation to return in AuthResponse
	user, err := p.getUserByID(userID)
	if err != nil {
		log.Printf("Failed to fetch user after signup: %v", err)
		// Return the token even if user fetching fails, but log the error
		return &models.AuthResponse{
			AccessToken: token,
			User: models.User{ // Minimal user info if fetch fails
				ID:    userID,
				Email: email,
				Username: username,
			},
		}, nil
	}

	return &models.AuthResponse{
		AccessToken: token,
		User:        *user,
	}, nil
}

func (p *PostgresAuthenticator) Login(loginIdentifier, password string) (*models.AuthResponse, error) {
	log.Printf("Login attempt for identifier=%s", loginIdentifier)
	var userID, hashedPassword, email string
	var username *string
	var err error

	// Try to find user by email first, then by username
	err = p.conn.QueryRow(context.Background(),
		"SELECT id, email, username, password_hash FROM users WHERE email = $1",
		loginIdentifier).Scan(&userID, &email, &username, &hashedPassword)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			log.Printf("User not found by email, trying username for %s", loginIdentifier)
			// If not found by email, try by username
			err = p.conn.QueryRow(context.Background(),
				"SELECT id, email, username, password_hash FROM users WHERE username = $1",
				loginIdentifier).Scan(&userID, &email, &username, &hashedPassword)
			if err != nil {
				if errors.Is(err, pgx.ErrNoRows) {
					log.Printf("User not found by email or username: %s", loginIdentifier)
					return nil, errors.New("user not found")
				}
				log.Printf("Database error during login (username query): %v", err)
				return nil, fmt.Errorf("database error: %v", err)
			}
		} else {
			log.Printf("Database error during login (email query): %v", err)
			return nil, fmt.Errorf("database error: %v", err)
		}
	}

	if err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password)); err != nil {
		log.Printf("Invalid credentials for user: %s", loginIdentifier)
		return nil, errors.New("invalid credentials")
	}

	log.Printf("Login successful for user: %s", userID)
	token, err := p.generateToken(userID)
	if err != nil {
		log.Printf("Token generation error during login: %v", err)
		return nil, err
	}

	// Fetch full user details for the response
	user, err := p.getUserByID(userID)
	if err != nil {
		log.Printf("Failed to fetch user after login: %v", err)
		return &models.AuthResponse{ // Minimal user info if fetch fails
			AccessToken: token,
			User: models.User{
				ID:       userID,
				Email:    email,
				Username: stringValue(username),
			},
		}, nil
	}

	return &models.AuthResponse{
		AccessToken: token,
		User:        *user,
	}, nil
}

func (p *PostgresAuthenticator) Signout(token string) error {
	// For JWT, signout is usually handled on FE by deleting token.
	// A token blacklist could be implemented here if necessary.
	return nil
}

func (p *PostgresAuthenticator) UpdateUser(token string, updateData map[string]interface{}) (*models.User, error) {
	user, err := p.GetUserFromToken(token)
	if err != nil {
		return nil, err
	}

	updateFields := []string{}
	updateValues := []interface{}{}
	i := 1

	if displayName, ok := updateData["display_name"].(string); ok {
		updateFields = append(updateFields, fmt.Sprintf("display_name = $%d", i))
		updateValues = append(updateValues, displayName)
		i++
	}
	if avatarURL, ok := updateData["avatar_url"].(string); ok {
		updateFields = append(updateFields, fmt.Sprintf("avatar_url = $%d", i))
		updateValues = append(updateValues, avatarURL)
		i++
	}
	if bio, ok := updateData["bio"].(string); ok {
		updateFields = append(updateFields, fmt.Sprintf("bio = $%d", i))
		updateValues = append(updateValues, bio)
		i++
	}
	// Add username update logic if needed, ensuring validation
	if username, ok := updateData["username"].(string); ok {
		// Basic validation for username format
		if !isValidUsername(username) {
			return nil, errors.New("invalid username format. Only alphanumeric characters and underscores are allowed.")
		}
		// Check if username is already taken by another user
		var count int
		err := p.conn.QueryRow(context.Background(), "SELECT COUNT(*) FROM users WHERE username = $1 AND id <> $2", username, user.ID).Scan(&count)
		if err != nil {
			return nil, fmt.Errorf("failed to check username availability: %v", err)
		}
		if count > 0 {
			return nil, errors.New("username is already taken")
		}
		updateFields = append(updateFields, fmt.Sprintf("username = $%d", i))
		updateValues = append(updateValues, username)
		i++
	}


	if len(updateFields) == 0 {
		return nil, errors.New("no valid update data provided")
	}

	updateValues = append(updateValues, user.ID) // Add user.ID for the WHERE clause
	query := fmt.Sprintf("UPDATE public.users SET %s WHERE id = $%d RETURNING id", strings.Join(updateFields, ", "), i)

	var updatedUserID string
	err = p.conn.QueryRow(context.Background(), query, updateValues...).Scan(&updatedUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to update user: %v", err)
	}

	// Fetch the updated user details
	updatedUser, err := p.getUserByID(updatedUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch updated user details: %v", err)
	}

	return updatedUser, nil
}

func (p *PostgresAuthenticator) GetUserFromToken(tokenString string) (*models.User, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return p.jwtSecret, nil
	})

	if err != nil {
		return nil, fmt.Errorf("token parsing error: %v", err)
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}

	userID, ok := claims["user_id"].(string)
	if !ok {
		return nil, errors.New("invalid user ID in token claims")
	}

	return p.getUserByID(userID)
}

func (p *PostgresAuthenticator) getUserByID(userID string) (*models.User, error) {
	var user models.User
	query := `
		SELECT id, email, username, display_name, avatar_url, bio, created_at 
		FROM public.users 
		WHERE id = $1
	`
	row := p.conn.QueryRow(context.Background(), query, userID)
	err := row.Scan(&user.ID, &user.Email, &user.Username, &user.DisplayName, &user.AvatarURL, &user.Bio, &user.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("user not found")
		}
		return nil, fmt.Errorf("database error fetching user by ID: %v", err)
	}
	return &user, nil
}

// GetUserByUsername retrieves user details by username.
func (p *PostgresAuthenticator) GetUserByUsername(username string) (*models.User, error) {
	query := `
		SELECT id, username, email, display_name, avatar_url, bio, created_at
		FROM public.users
		WHERE username = $1
	`
	row := p.conn.QueryRow(context.Background(), query, username)
	var user models.User
	err := row.Scan(&user.ID, &user.Username, &user.Email, &user.DisplayName, &user.AvatarURL, &user.Bio, &user.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("user not found")
		}
		return nil, fmt.Errorf("database error fetching user by username: %v", err)
	}
	return &user, nil
}


func (p *PostgresAuthenticator) SearchUsers(query string) ([]models.Profile, error) {
	if query == "" {
		return []models.Profile{}, nil
	}

	// Use ILIKE for case-insensitive search and consider FTS for performance if needed
	// For now, using B-tree index on username and ILIKE for simplicity and cost-effectiveness
	searchQuery := "%" + strings.ToLower(query) + "%"
	sql := `
		SELECT id, username, display_name, avatar_url, bio
		FROM public.users
		WHERE LOWER(username) LIKE $1 OR LOWER(display_name) LIKE $1
		ORDER BY username ASC
		LIMIT 10 
	`
	rows, err := p.conn.Query(context.Background(), sql, searchQuery)
	if err != nil {
		return nil, fmt.Errorf("failed to search users: %v", err)
	}
	defer rows.Close()

	var profiles []models.Profile
	for rows.Next() {
		var profile models.Profile
		if err := rows.Scan(&profile.ID, &profile.Username, &profile.DisplayName, &profile.AvatarURL, &profile.Bio); err != nil {
			log.Printf("Error scanning user profile row: %v", err)
			continue // Skip this row but continue processing others
		}
		profiles = append(profiles, profile)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating user search results: %v", err)
	}

	return profiles, nil
}

func (p *PostgresAuthenticator) AddFriend(userID, friendID string) error {
	if userID == friendID {
		return errors.New("cannot add yourself as a friend")
	}

	// Check if friendship already exists
	var exists bool
	err := p.conn.QueryRow(context.Background(),
		"SELECT EXISTS(SELECT 1 FROM public.friends WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1))",
		userID, friendID).Scan(&exists)
	if err != nil {
		return fmt.Errorf("database error checking existing friendship: %v", err)
	}
	if exists {
		return errors.New("friendship already exists")
	}

	// Add the friendship (bidirectional or one-way depending on desired logic)
	// This example assumes a one-way add, but a real system might require confirmation.
	// For simplicity, we'll insert both ways to make querying easier if needed.
	_, err = p.conn.Exec(context.Background(),
		"INSERT INTO public.friends (user_id, friend_id) VALUES ($1, $2), ($2, $1)",
		userID, friendID)
	if err != nil {
		return fmt.Errorf("database error adding friend: %v", err)
	}
	return nil
}

func (p *PostgresAuthenticator) CreateGroup(name, description, creatorID string) (*models.Group, error) {
	var groupID string
	err := p.conn.QueryRow(context.Background(),
		"INSERT INTO public.groups (name, description, creator_id) VALUES ($1, $2, $3) RETURNING id",
		name, description, creatorID).Scan(&groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to create group: %v", err)
	}

	// Add the creator as the first member of the group
	_, err = p.conn.Exec(context.Background(),
		"INSERT INTO public.group_members (group_id, user_id) VALUES ($1, $2)",
		groupID, creatorID)
	if err != nil {
		// Attempt to clean up the created group if adding member fails
		_, _ = p.conn.Exec(context.Background(), "DELETE FROM public.groups WHERE id = $1", groupID)
		return nil, fmt.Errorf("failed to add creator to group: %v", err)
	}

	// Fetch the created group details
	group, err := p.getGroupByID(groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch created group: %v", err)
	}

	return group, nil
}

func (p *PostgresAuthenticator) JoinGroup(groupID, userID string) error {
	// Check if group exists
	var groupExists bool
	err := p.conn.QueryRow(context.Background(), "SELECT EXISTS(SELECT 1 FROM public.groups WHERE id = $1)", groupID).Scan(&groupExists)
	if err != nil {
		return fmt.Errorf("database error checking group existence: %v", err)
	}
	if !groupExists {
		return errors.New("group not found")
	}

	// Check if user is already a member
	var memberExists bool
	err = p.conn.QueryRow(context.Background(), "SELECT EXISTS(SELECT 1 FROM public.group_members WHERE group_id = $1 AND user_id = $2)", groupID, userID).Scan(&memberExists)
	if err != nil {
		return fmt.Errorf("database error checking group membership: %v", err)
	}
	if memberExists {
		return errors.New("user is already a member of this group")
	}

	_, err = p.conn.Exec(context.Background(),
		"INSERT INTO public.group_members (group_id, user_id) VALUES ($1, $2)",
		groupID, userID)
	if err != nil {
		return fmt.Errorf("database error joining group: %v", err)
	}
	return nil
}

func (p *PostgresAuthenticator) GetMyGroups(userID string) ([]models.Group, error) {
	query := `
		SELECT g.id, g.name, g.description, g.creator_id, g.created_at, COUNT(gm.user_id) AS member_count
		FROM public.groups g
		JOIN public.group_members gm ON g.id = gm.group_id
		WHERE gm.user_id = $1
		GROUP BY g.id, g.name, g.description, g.creator_id, g.created_at
		ORDER BY g.created_at DESC
	`
	rows, err := p.conn.Query(context.Background(), query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user's groups: %v", err)
	}
	defer rows.Close()

	var groups []models.Group
	for rows.Next() {
		var group models.Group
		if err := rows.Scan(&group.ID, &group.Name, &group.Description, &group.CreatorID, &group.CreatedAt, &group.MemberCount); err != nil {
			log.Printf("Error scanning group row: %v", err)
			continue
		}
		groups = append(groups, group)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating user's groups: %v", err)
	}

	return groups, nil
}

func (p *PostgresAuthenticator) getGroupByID(groupID string) (*models.Group, error) {
	query := `
		SELECT g.id, g.name, g.description, g.creator_id, g.created_at, COUNT(gm.user_id) AS member_count
		FROM public.groups g
		LEFT JOIN public.group_members gm ON g.id = gm.group_id
		WHERE g.id = $1
		GROUP BY g.id, g.name, g.description, g.creator_id, g.created_at
	`
	row := p.conn.QueryRow(context.Background(), query, groupID)
	var group models.Group
	err := row.Scan(&group.ID, &group.Name, &group.Description, &group.CreatorID, &group.CreatedAt, &group.MemberCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("group not found")
		}
		return nil, fmt.Errorf("database error fetching group by ID: %v", err)
	}
	return &group, nil
}

func (p *PostgresAuthenticator) GetProfile(username string) (*models.Profile, error) {
	query := `
		SELECT id, username, display_name, avatar_url, bio
		FROM public.users
		WHERE username = $1
	`
	row := p.conn.QueryRow(context.Background(), query, username)
	var profile models.Profile
	err := row.Scan(&profile.ID, &profile.Username, &profile.DisplayName, &profile.AvatarURL, &profile.Bio)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("user profile not found")
		}
		return nil, fmt.Errorf("database error fetching user profile: %v", err)
	}
	return &profile, nil
}

func (p *PostgresAuthenticator) generateToken(userID string) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": userID,
		"exp":     time.Now().Add(time.Hour * 72).Unix(),
	})

	return token.SignedString(p.jwtSecret)
}

// isValidUsername checks if the username adheres to the specified format.
// Only alphanumeric characters and underscores are allowed.
// It also ensures the username is not empty.
func isValidUsername(username string) bool {
	if username == "" {
		return false
	}
	// Regex explanation:
	// ^               - start of string
	// [a-zA-Z0-9_]+  - one or more alphanumeric characters or underscores
	// $               - end of string
	// The ~* operator in PostgreSQL uses case-insensitive matching, so we don't need to worry about case here for the DB constraint itself.
	// However, the regex here ensures only allowed characters are present.
	// The check in the database ('username_format') will also use regex, so this client-side validation is for immediate feedback.
	for _, r := range username {
		if !((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_') {
			return false
		}
	}
	return true
}

// Helper to handle optional string pointer
func stringValue(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func (p *PostgresAuthenticator) Close() {
	if p.conn != nil {
		p.conn.Close(context.Background())
	}
}
