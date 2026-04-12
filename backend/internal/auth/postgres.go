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
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mitron/backend/internal/models"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrAlreadyFriends        = errors.New("already friends")
	ErrFriendRequestPending  = errors.New("friend request already pending")
	ErrFriendRequestNotFound = errors.New("no pending friend request from this user")
)

type PostgresAuthenticator struct {
	pool      *pgxpool.Pool
	jwtSecret []byte
}

func NewPostgresAuthenticator(pool *pgxpool.Pool, jwtSecret string) (*PostgresAuthenticator, error) {
	if pool == nil {
		return nil, errors.New("database pool is nil")
	}
	return &PostgresAuthenticator{
		pool:      pool,
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
	err = p.pool.QueryRow(context.Background(),
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
				ID:       userID,
				Email:    email,
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
	err = p.pool.QueryRow(context.Background(),
		"SELECT id, email, username, password_hash FROM users WHERE email = $1",
		loginIdentifier).Scan(&userID, &email, &username, &hashedPassword)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			log.Printf("User not found by email, trying username for %s", loginIdentifier)
			// If not found by email, try by username
			err = p.pool.QueryRow(context.Background(),
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
		err := p.pool.QueryRow(context.Background(), "SELECT COUNT(*) FROM users WHERE username = $1 AND id <> $2", username, user.ID).Scan(&count)
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
	err = p.pool.QueryRow(context.Background(), query, updateValues...).Scan(&updatedUserID)
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
	log.Printf("Fetching user by ID: %s", userID)
	var user models.User
	query := `
		SELECT id, email, username, display_name, avatar_url, bio, created_at 
		FROM public.users 
		WHERE id = $1
	`
	timeout := 10 * time.Second // Set a reasonable timeout for database operations
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel() // Ensure the context is cancelled to release resources

	row := p.pool.QueryRow(ctx, query, userID)
	err := row.Scan(&user.ID, &user.Email, &user.Username, &user.DisplayName, &user.AvatarURL, &user.Bio, &user.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			log.Printf("User with ID %s not found", userID)
			return nil, errors.New("user not found")
		}
		log.Printf("Database error fetching user by ID %s: %v", userID, err)
		return nil, fmt.Errorf("database error fetching user by ID: %v", err)
	}
	log.Printf("Successfully fetched user by ID: %s", userID)
	return &user, nil
}

// GetUserByUsername retrieves user details by username.
func (p *PostgresAuthenticator) GetUserByUsername(username string) (*models.User, error) {
	log.Printf("Fetching user by username: %s", username)
	query := `
		SELECT id, email, username, display_name, avatar_url, bio, created_at
		FROM public.users
		WHERE username = $1
	`
	timeout := 10 * time.Second // Set a reasonable timeout
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	row := p.pool.QueryRow(ctx, query, username)
	var user models.User
	err := row.Scan(&user.ID, &user.Username, &user.Email, &user.DisplayName, &user.AvatarURL, &user.Bio, &user.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			log.Printf("User with username %s not found", username)
			return nil, errors.New("user not found")
		}
		log.Printf("Database error fetching user by username %s: %v", username, err)
		return nil, fmt.Errorf("database error fetching user by username: %v", err)
	}
	log.Printf("Successfully fetched user by username: %s", username)
	return &user, nil
}

func (p *PostgresAuthenticator) SearchUsers(query string) ([]models.Profile, error) {
	if query == "" {
		return []models.Profile{}, nil
	}

	log.Printf("Searching users for query: %s", query)
	searchQuery := "%" + strings.ToLower(query) + "%"
	sql := `
		SELECT id, username, display_name, avatar_url, bio
		FROM public.users
		WHERE LOWER(username) LIKE $1 OR LOWER(display_name) LIKE $1
		ORDER BY username ASC
		LIMIT 10 
	`
	timeout := 10 * time.Second // Set a reasonable timeout
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	rows, err := p.pool.Query(ctx, sql, searchQuery)
	if err != nil {
		log.Printf("Failed to search users: %v", err)
		return nil, fmt.Errorf("failed to search users: %v", err)
	}
	defer rows.Close()

	var profiles = []models.Profile{}
	for rows.Next() {
		var profile models.Profile
		if err := rows.Scan(&profile.ID, &profile.Username, &profile.DisplayName, &profile.AvatarURL, &profile.Bio); err != nil {
			log.Printf("Error scanning user profile row: %v", err)
			continue // Skip this row but continue processing others
		}
		profiles = append(profiles, profile)
	}

	if err := rows.Err(); err != nil {
		log.Printf("Error iterating user search results: %v", err)
		return nil, fmt.Errorf("error iterating user search results: %v", err)
	}
	log.Printf("Found %d users for query: %s", len(profiles), query)
	return profiles, nil
}

func (p *PostgresAuthenticator) AddFriend(initiatorID, recipientID string) error {
	if initiatorID == recipientID {
		return errors.New("cannot add yourself as a friend")
	}

	ctx := context.Background()
	var status string
	err := p.pool.QueryRow(ctx, `
		SELECT status::text FROM public.friends
		WHERE (initiator_id = $1 AND recipient_id = $2) OR (initiator_id = $2 AND recipient_id = $1)
	`, initiatorID, recipientID).Scan(&status)

	if errors.Is(err, pgx.ErrNoRows) {
		_, insErr := p.pool.Exec(ctx,
			`INSERT INTO public.friends (initiator_id, recipient_id, status) VALUES ($1, $2, 'pending')`,
			initiatorID, recipientID)
		if insErr != nil {
			return fmt.Errorf("database error adding friend: %v", insErr)
		}
		return nil
	}
	if err != nil {
		return fmt.Errorf("database error checking friendship: %v", err)
	}

	switch status {
	case "accepted":
		return ErrAlreadyFriends
	case "pending":
		return ErrFriendRequestPending
	case "rejected":
		_, updErr := p.pool.Exec(ctx, `
			UPDATE public.friends
			SET initiator_id = $1, recipient_id = $2, status = 'pending', created_at = now()
			WHERE (initiator_id = $1 AND recipient_id = $2) OR (initiator_id = $2 AND recipient_id = $1)
		`, initiatorID, recipientID)
		if updErr != nil {
			return fmt.Errorf("database error re-opening friend request: %v", updErr)
		}
		return nil
	default:
		return fmt.Errorf("unknown friendship status: %s", status)
	}
}

func (p *PostgresAuthenticator) RespondToFriendRequest(recipientID, initiatorID string, accept bool) error {
	if recipientID == initiatorID {
		return errors.New("invalid friend request response")
	}
	ctx := context.Background()
	newStatus := "rejected"
	if accept {
		newStatus = "accepted"
	}
	tag, err := p.pool.Exec(ctx, `
		UPDATE public.friends
		SET status = $1::friendship_status
		WHERE initiator_id = $2 AND recipient_id = $3 AND status = 'pending'
	`, newStatus, initiatorID, recipientID)
	if err != nil {
		return fmt.Errorf("database error responding to friend request: %v", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrFriendRequestNotFound
	}
	return nil
}

func (p *PostgresAuthenticator) RemoveFriend(userID, friendID string) error {
	if userID == friendID {
		return errors.New("cannot remove yourself as a friend")
	}

	ctx := context.Background()
	var exists bool
	err := p.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM public.friends
			WHERE ((initiator_id = $1 AND recipient_id = $2) OR (initiator_id = $2 AND recipient_id = $1))
			AND status = 'accepted'
		)
	`, userID, friendID).Scan(&exists)
	if err != nil {
		return fmt.Errorf("database error checking friendship: %v", err)
	}
	if !exists {
		return errors.New("user is not your friend")
	}

	_, err = p.pool.Exec(ctx, `
		DELETE FROM public.friends
		WHERE ((initiator_id = $1 AND recipient_id = $2) OR (initiator_id = $2 AND recipient_id = $1))
		AND status = 'accepted'
	`, userID, friendID)
	if err != nil {
		return fmt.Errorf("database error removing friend: %v", err)
	}
	return nil
}

func (p *PostgresAuthenticator) GetFriendLists(userID string) (*models.FriendLists, error) {
	ctx := context.Background()
	out := &models.FriendLists{
		Friends:         []models.Profile{},
		PendingIncoming: []models.PendingFriendProfile{},
		PendingOutgoing: []models.PendingFriendProfile{},
	}

	friendsSQL := `
		SELECT u.id, u.username, u.display_name, u.avatar_url, u.bio
		FROM public.friends f
		JOIN public.users u ON u.id = CASE
			WHEN f.initiator_id = $1 THEN f.recipient_id
			ELSE f.initiator_id
		END
		WHERE (f.initiator_id = $1 OR f.recipient_id = $1) AND f.status = 'accepted'
		ORDER BY u.username ASC
	`
	rows, err := p.pool.Query(ctx, friendsSQL, userID)
	if err != nil {
		return nil, fmt.Errorf("database error listing friends: %v", err)
	}
	defer rows.Close()
	for rows.Next() {
		var profile models.Profile
		if err := rows.Scan(&profile.ID, &profile.Username, &profile.DisplayName, &profile.AvatarURL, &profile.Bio); err != nil {
			return nil, fmt.Errorf("scan friend profile: %v", err)
		}
		out.Friends = append(out.Friends, profile)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	incomingSQL := `
		SELECT u.id, u.username, u.display_name, u.avatar_url, u.bio, f.initiator_id::text
		FROM public.friends f
		JOIN public.users u ON u.id = f.initiator_id
		WHERE f.recipient_id = $1 AND f.status = 'pending'
		ORDER BY f.created_at DESC
	`
	rowsIn, err := p.pool.Query(ctx, incomingSQL, userID)
	if err != nil {
		return nil, fmt.Errorf("database error listing incoming requests: %v", err)
	}
	defer rowsIn.Close()
	for rowsIn.Next() {
		var profile models.Profile
		var initID string
		if err := rowsIn.Scan(&profile.ID, &profile.Username, &profile.DisplayName, &profile.AvatarURL, &profile.Bio, &initID); err != nil {
			return nil, fmt.Errorf("scan incoming request: %v", err)
		}
		out.PendingIncoming = append(out.PendingIncoming, models.PendingFriendProfile{
			Profile:     profile,
			InitiatorID: initID,
		})
	}
	if err := rowsIn.Err(); err != nil {
		return nil, err
	}

	outgoingSQL := `
		SELECT u.id, u.username, u.display_name, u.avatar_url, u.bio, f.initiator_id::text
		FROM public.friends f
		JOIN public.users u ON u.id = f.recipient_id
		WHERE f.initiator_id = $1 AND f.status = 'pending'
		ORDER BY f.created_at DESC
	`
	rowsOut, err := p.pool.Query(ctx, outgoingSQL, userID)
	if err != nil {
		return nil, fmt.Errorf("database error listing outgoing requests: %v", err)
	}
	defer rowsOut.Close()
	for rowsOut.Next() {
		var profile models.Profile
		var initID string
		if err := rowsOut.Scan(&profile.ID, &profile.Username, &profile.DisplayName, &profile.AvatarURL, &profile.Bio, &initID); err != nil {
			return nil, fmt.Errorf("scan outgoing request: %v", err)
		}
		out.PendingOutgoing = append(out.PendingOutgoing, models.PendingFriendProfile{
			Profile:     profile,
			InitiatorID: initID,
		})
	}
	if err := rowsOut.Err(); err != nil {
		return nil, err
	}

	return out, nil
}

func (p *PostgresAuthenticator) CreateGroup(name, description, creatorID, avatarURL string) (*models.Group, error) {
	var groupID string
	avatarURLPtr := &avatarURL
	if avatarURL == "" {
		avatarURLPtr = nil
	}
	err := p.pool.QueryRow(context.Background(),
		"INSERT INTO public.groups (name, description, created_by, group_image_url) VALUES ($1, $2, $3, $4) RETURNING id",
		name, description, creatorID, avatarURLPtr).Scan(&groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to create group: %v", err)
	}

	// Add the creator as the first member of the group
	_, err = p.pool.Exec(context.Background(),
		"INSERT INTO public.group_members (group_id, user_id) VALUES ($1, $2)",
		groupID, creatorID)
	if err != nil {
		// Attempt to clean up the created group if adding member fails
		_, _ = p.pool.Exec(context.Background(), "DELETE FROM public.groups WHERE id = $1", groupID)
		return nil, fmt.Errorf("failed to add creator to group: %v", err)
	}

	// Assign Admin flair to creator (default flair with group_id = NULL)
	var adminFlairID string
	err = p.pool.QueryRow(context.Background(),
		"SELECT id FROM public.flairs WHERE name = 'Admin' AND group_id IS NULL LIMIT 1",
	).Scan(&adminFlairID)
	if err == nil && adminFlairID != "" {
		_, _ = p.pool.Exec(context.Background(),
			"INSERT INTO public.group_member_flairs (group_id, user_id, flair_id) VALUES ($1, $2, $3)",
			groupID, creatorID, adminFlairID)
	}

	// Fetch the created group details
	group, err := p.getGroupByID(groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch created group: %v", err)
	}

	return group, nil
}

func (p *PostgresAuthenticator) UpdateGroup(groupID, name, description, avatarURL string) (*models.Group, error) {
	var updateFields []string
	var updateValues []interface{}
	var i int

	if name != "" {
		i++
		updateFields = append(updateFields, fmt.Sprintf("name = $%d", i))
		updateValues = append(updateValues, name)
	}
	if description != "" || description == "" {
		i++
		updateFields = append(updateFields, fmt.Sprintf("description = $%d", i))
		updateValues = append(updateValues, description)
	}
	if avatarURL != "" {
		i++
		updateFields = append(updateFields, fmt.Sprintf("group_image_url = $%d", i))
		updateValues = append(updateValues, avatarURL)
	}

	if len(updateFields) == 0 {
		return p.GetGroupByID(groupID)
	}

	i++
	updateFields = append(updateFields, fmt.Sprintf("id = $%d", i))
	updateValues = append(updateValues, groupID)

	query := fmt.Sprintf("UPDATE public.groups SET %s WHERE id = $%d RETURNING id, name, COALESCE(description, ''), created_by, created_at, COALESCE(group_image_url, '')",
		strings.Join(updateFields[:len(updateFields)-1], ", "), i)

	var group models.Group
	err := p.pool.QueryRow(context.Background(), query, updateValues...).Scan(
		&group.ID, &group.Name, &group.Description, &group.CreatedBy, &group.CreatedAt, &group.GroupImageURL)
	if err != nil {
		return nil, fmt.Errorf("failed to update group: %v", err)
	}

	return &group, nil
}

func (p *PostgresAuthenticator) JoinGroup(groupID, userID string) error {
	var groupExists bool
	err := p.pool.QueryRow(context.Background(), "SELECT EXISTS(SELECT 1 FROM public.groups WHERE id = $1)", groupID).Scan(&groupExists)
	if err != nil {
		return fmt.Errorf("database error checking group existence: %v", err)
	}
	if !groupExists {
		return errors.New("group not found")
	}

	// Check if user is already a member
	var memberExists bool
	err = p.pool.QueryRow(context.Background(), "SELECT EXISTS(SELECT 1 FROM public.group_members WHERE group_id = $1 AND user_id = $2)", groupID, userID).Scan(&memberExists)
	if err != nil {
		return fmt.Errorf("database error checking group membership: %v", err)
	}
	if memberExists {
		return errors.New("user is already a member of this group")
	}

	_, err = p.pool.Exec(context.Background(),
		"INSERT INTO public.group_members (group_id, user_id) VALUES ($1, $2)",
		groupID, userID)
	if err != nil {
		return fmt.Errorf("database error joining group: %v", err)
	}

	return nil
}

func (p *PostgresAuthenticator) GetGroupFlairs(groupID string) ([]models.Flair, error) {
	rows, err := p.pool.Query(context.Background(),
		"SELECT id, name, group_id FROM public.flairs WHERE group_id = $1 OR group_id IS NULL ORDER BY group_id, name",
		groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to get flairs: %v", err)
	}
	defer rows.Close()

	var flairs []models.Flair
	for rows.Next() {
		var f models.Flair
		if err := rows.Scan(&f.ID, &f.Name, &f.GroupID); err != nil {
			continue
		}
		flairs = append(flairs, f)
	}
	return flairs, rows.Err()
}

func (p *PostgresAuthenticator) AddGroupFlair(groupID, name string) (*models.Flair, error) {
	var flairID string
	err := p.pool.QueryRow(context.Background(),
		"INSERT INTO public.flairs (name, group_id) VALUES ($1, $2) RETURNING id",
		name, groupID).Scan(&flairID)
	if err != nil {
		return nil, fmt.Errorf("failed to add flair: %v", err)
	}
	return &models.Flair{ID: flairID, Name: name, GroupID: &groupID}, nil
}

func (p *PostgresAuthenticator) GetMemberFlairs(groupID, userID string) ([]models.Flair, error) {
	rows, err := p.pool.Query(context.Background(),
		`SELECT f.id, f.name, f.group_id FROM public.flairs f
		JOIN public.group_member_flairs gmf ON f.id = gmf.flair_id
		WHERE gmf.group_id = $1 AND gmf.user_id = $2`,
		groupID, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get member flairs: %v", err)
	}
	defer rows.Close()

	var flairs []models.Flair
	for rows.Next() {
		var f models.Flair
		if err := rows.Scan(&f.ID, &f.Name, &f.GroupID); err != nil {
			continue
		}
		flairs = append(flairs, f)
	}
	return flairs, rows.Err()
}

func (p *PostgresAuthenticator) AssignFlair(groupID, userID, flairID string) error {
	_, err := p.pool.Exec(context.Background(),
		"INSERT INTO public.group_member_flairs (group_id, user_id, flair_id) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
		groupID, userID, flairID)
	if err != nil {
		return fmt.Errorf("failed to assign flair: %v", err)
	}
	return nil
}

func (p *PostgresAuthenticator) RemoveFlair(groupID, userID, flairID string) error {
	_, err := p.pool.Exec(context.Background(),
		"DELETE FROM public.group_member_flairs WHERE group_id = $1 AND user_id = $2 AND flair_id = $3",
		groupID, userID, flairID)
	if err != nil {
		return fmt.Errorf("failed to remove flair: %v", err)
	}
	return nil
}

func (p *PostgresAuthenticator) CreateEvent(groupID, title, description, creatorID string) (*models.Event, error) {
	var eventID string
	err := p.pool.QueryRow(context.Background(),
		"INSERT INTO events (group_id, title, description, created_by) VALUES ($1, $2, $3, $4) RETURNING id",
		groupID, title, description, creatorID).Scan(&eventID)
	if err != nil {
		return nil, fmt.Errorf("failed to create event: %v", err)
	}

	chatID, err := p.createEventChat(eventID, groupID)
	if err != nil {
		log.Printf("Warning: failed to create event chat: %v", err)
	}

	event, err := p.getEventByID(eventID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch created event: %v", err)
	}
	if chatID != "" {
		event.ChatID = &chatID
	}
	return event, nil
}

func (p *PostgresAuthenticator) GetEvents(groupID string) ([]models.Event, error) {
	rows, err := p.pool.Query(context.Background(),
		"SELECT id, group_id, title, COALESCE(description, ''), created_by, created_at, resolution_message_id FROM events WHERE group_id = $1 ORDER BY created_at DESC",
		groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to get events: %v", err)
	}
	defer rows.Close()

	var events []models.Event
	for rows.Next() {
		var event models.Event
		if err := rows.Scan(&event.ID, &event.GroupID, &event.Title, &event.Description, &event.CreatedBy, &event.CreatedAt, &event.ResolutionMsgID); err != nil {
			log.Printf("Error scanning event row: %v", err)
			continue
		}
		events = append(events, event)
	}
	return events, rows.Err()
}

func (p *PostgresAuthenticator) GetEventByID(eventID string) (*models.Event, error) {
	event, err := p.getEventByID(eventID)
	if err != nil {
		return nil, err
	}
	chatID, err := p.GetEventChatID(eventID)
	if err == nil && chatID != "" {
		event.ChatID = &chatID
	}
	return event, nil
}

func (p *PostgresAuthenticator) getEventByID(eventID string) (*models.Event, error) {
	var event models.Event
	err := p.pool.QueryRow(context.Background(),
		"SELECT id, group_id, title, COALESCE(description, ''), created_by, created_at, resolution_message_id FROM events WHERE id = $1",
		eventID).Scan(&event.ID, &event.GroupID, &event.Title, &event.Description, &event.CreatedBy, &event.CreatedAt, &event.ResolutionMsgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("event not found")
		}
		return nil, fmt.Errorf("failed to get event: %v", err)
	}
	return &event, nil
}

func (p *PostgresAuthenticator) createEventChat(eventID, groupID string) (string, error) {
	var chatID string
	err := p.pool.QueryRow(context.Background(),
		"INSERT INTO chats (type, event_id, group_id) VALUES ('event', $1, $2) RETURNING id",
		eventID, groupID).Scan(&chatID)
	if err != nil {
		return "", fmt.Errorf("failed to create event chat: %v", err)
	}
	return chatID, nil
}

func (p *PostgresAuthenticator) GetEventChatID(eventID string) (string, error) {
	var chatID string
	err := p.pool.QueryRow(context.Background(),
		"SELECT id FROM chats WHERE event_id = $1 AND type = 'event'",
		eventID).Scan(&chatID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil
		}
		return "", err
	}
	return chatID, nil
}

func (p *PostgresAuthenticator) GetOrCreateGroupChat(groupID string) (string, error) {
	var chatID string
	err := p.pool.QueryRow(context.Background(),
		"SELECT id FROM chats WHERE group_id = $1 AND type = 'group'",
		groupID).Scan(&chatID)
	if err == nil {
		return chatID, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", fmt.Errorf("failed to get group chat: %v", err)
	}
	err = p.pool.QueryRow(context.Background(),
		"INSERT INTO chats (type, group_id) VALUES ('group', $1) RETURNING id",
		groupID).Scan(&chatID)
	if err != nil {
		return "", fmt.Errorf("failed to create group chat: %v", err)
	}
	return chatID, nil
}

func (p *PostgresAuthenticator) ResolveEvent(eventID, messageID string) error {
	_, err := p.pool.Exec(context.Background(),
		"UPDATE events SET resolution_message_id = $1 WHERE id = $2",
		messageID, eventID)
	if err != nil {
		return fmt.Errorf("failed to resolve event: %v", err)
	}
	return nil
}

func (p *PostgresAuthenticator) GetMyGroups(userID string) ([]models.Group, error) {
	query := `
		SELECT g.id, g.name, COALESCE(g.description, ''), g.created_by, g.created_at, 
			(SELECT COUNT(*) FROM public.group_members WHERE group_id = g.id) AS member_count
		FROM public.groups g
		JOIN public.group_members gm ON g.id = gm.group_id
		WHERE gm.user_id = $1
		ORDER BY g.created_at DESC
	`
	rows, err := p.pool.Query(context.Background(), query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user's groups: %v", err)
	}
	defer rows.Close()

	var groups = []models.Group{}
	for rows.Next() {
		var group models.Group
		var memberCount int
		if err := rows.Scan(&group.ID, &group.Name, &group.Description, &group.CreatedBy, &group.CreatedAt, &memberCount); err != nil {
			log.Printf("Error scanning group row: %v", err)
			continue
		}
		group.MemberCount = memberCount
		groups = append(groups, group)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating user's groups: %v", err)
	}

	return groups, nil
}

func (p *PostgresAuthenticator) GetGroupMembers(groupID string) ([]models.Profile, error) {
	query := `
		SELECT u.id, u.username, COALESCE(u.display_name, ''), u.avatar_url, COALESCE(u.bio, ''),
			(SELECT created_by FROM public.groups WHERE id = $1) = u.id as is_creator,
			COALESCE(array_agg(f.name ORDER BY f.name) FILTER (WHERE f.name IS NOT NULL), '{}')
		FROM public.group_members gm
		JOIN public.users u ON u.id = gm.user_id
		LEFT JOIN public.group_member_flairs gmf ON gmf.group_id = gm.group_id AND gmf.user_id = gm.user_id
		LEFT JOIN public.flairs f ON f.id = gmf.flair_id
		WHERE gm.group_id = $1
		GROUP BY u.id, u.username, u.display_name, u.avatar_url, u.bio
		ORDER BY is_creator DESC, u.username ASC
	`
	rows, err := p.pool.Query(context.Background(), query, groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to get group members: %v", err)
	}
	defer rows.Close()

	var profiles = []models.Profile{}
	for rows.Next() {
		var profile models.Profile
		var flairNames []string
		if err := rows.Scan(&profile.ID, &profile.Username, &profile.DisplayName, &profile.AvatarURL, &profile.Bio, &profile.IsCreator, &flairNames); err != nil {
			log.Printf("Error scanning group member row: %v", err)
			continue
		}
		profile.Flairs = flairNames
		profiles = append(profiles, profile)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating group members: %v", err)
	}

	return profiles, nil
}

func (p *PostgresAuthenticator) AddGroupMember(groupID, userID string) error {
	ctx := context.Background()

	var groupExists bool
	err := p.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM public.groups WHERE id = $1)", groupID).Scan(&groupExists)
	if err != nil {
		return fmt.Errorf("database error checking group: %v", err)
	}
	if !groupExists {
		return errors.New("group not found")
	}

	var memberExists bool
	err = p.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM public.group_members WHERE group_id = $1 AND user_id = $2)", groupID, userID).Scan(&memberExists)
	if err != nil {
		return fmt.Errorf("database error checking membership: %v", err)
	}
	if memberExists {
		return errors.New("user is already a member of this group")
	}

	_, err = p.pool.Exec(ctx, "INSERT INTO public.group_members (group_id, user_id) VALUES ($1, $2)", groupID, userID)
	if err != nil {
		return fmt.Errorf("failed to add member: %v", err)
	}

	return nil
}

func (p *PostgresAuthenticator) DeleteGroup(groupID, userID string) error {
	ctx := context.Background()

	var creatorID string
	err := p.pool.QueryRow(ctx, "SELECT created_by FROM public.groups WHERE id = $1", groupID).Scan(&creatorID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("group not found")
		}
		return fmt.Errorf("database error checking group: %v", err)
	}

	if creatorID != userID {
		return errors.New("only the group creator can delete this group")
	}

	_, err = p.pool.Exec(ctx, "DELETE FROM public.group_members WHERE group_id = $1", groupID)
	if err != nil {
		return fmt.Errorf("failed to delete group members: %v", err)
	}

	_, err = p.pool.Exec(ctx, "DELETE FROM public.groups WHERE id = $1", groupID)
	if err != nil {
		return fmt.Errorf("failed to delete group: %v", err)
	}

	return nil
}

func (p *PostgresAuthenticator) RemoveGroupMember(groupID, adminUserID, memberID string) error {
	ctx := context.Background()

	var creatorID string
	err := p.pool.QueryRow(ctx, "SELECT created_by FROM public.groups WHERE id = $1", groupID).Scan(&creatorID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("group not found")
		}
		return fmt.Errorf("database error checking group: %v", err)
	}

	if creatorID != adminUserID {
		return errors.New("only the group creator can remove members")
	}

	if memberID == adminUserID {
		return errors.New("cannot remove yourself from the group")
	}

	var memberExists bool
	err = p.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM public.group_members WHERE group_id = $1 AND user_id = $2)", groupID, memberID).Scan(&memberExists)
	if err != nil {
		return fmt.Errorf("database error checking member: %v", err)
	}
	if !memberExists {
		return errors.New("user is not a member of this group")
	}

	_, err = p.pool.Exec(ctx, "DELETE FROM public.group_members WHERE group_id = $1 AND user_id = $2", groupID, memberID)
	if err != nil {
		return fmt.Errorf("failed to remove member: %v", err)
	}

	return nil
}

func (p *PostgresAuthenticator) GetGroupByID(groupID string) (*models.Group, error) {
	query := `
		SELECT g.id, g.name, COALESCE(g.description, ''), g.created_by, g.created_at, COALESCE(g.group_image_url, ''), COUNT(gm.user_id) AS member_count
		FROM public.groups g
		LEFT JOIN public.group_members gm ON g.id = gm.group_id
		WHERE g.id = $1
		GROUP BY g.id, g.name, g.description, g.created_by, g.created_at, g.group_image_url
	`
	row := p.pool.QueryRow(context.Background(), query, groupID)
	var group models.Group
	var groupImageURL string
	err := row.Scan(&group.ID, &group.Name, &group.Description, &group.CreatedBy, &group.CreatedAt, &groupImageURL, &group.MemberCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("group not found")
		}
		return nil, fmt.Errorf("database error fetching group by ID: %v", err)
	}
	if groupImageURL != "" {
		group.GroupImageURL = &groupImageURL
	}
	return &group, nil
}

func (p *PostgresAuthenticator) getGroupByID(groupID string) (*models.Group, error) {
	query := `
		SELECT g.id, g.name, COALESCE(g.description, ''), g.created_by, g.created_at, COALESCE(g.group_image_url, ''), COUNT(gm.user_id) AS member_count
		FROM public.groups g
		LEFT JOIN public.group_members gm ON g.id = gm.group_id
		WHERE g.id = $1
		GROUP BY g.id, g.name, g.description, g.created_by, g.created_at, g.group_image_url
	`
	row := p.pool.QueryRow(context.Background(), query, groupID)
	var group models.Group
	var groupImageURL string
	err := row.Scan(&group.ID, &group.Name, &group.Description, &group.CreatedBy, &group.CreatedAt, &groupImageURL, &group.MemberCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("group not found")
		}
		return nil, fmt.Errorf("database error fetching group by ID: %v", err)
	}
	if groupImageURL != "" {
		group.GroupImageURL = &groupImageURL
	}
	return &group, nil
}

func (p *PostgresAuthenticator) GetProfile(username string) (*models.Profile, error) {
	query := `
		SELECT id, username, display_name, avatar_url, bio
		FROM public.users
		WHERE username = $1
	`
	row := p.pool.QueryRow(context.Background(), query, username)
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

func (p *PostgresAuthenticator) GetProfileWithFriendshipStatus(requestingUserID, profileUsername string) (*models.ProfileWithStatus, error) {
	profile, err := p.GetProfile(profileUsername)
	if err != nil {
		return nil, err
	}

	friendshipStatus, isFriend, isIncoming := p.checkFriendshipStatus(requestingUserID, profile.ID)

	return &models.ProfileWithStatus{
		Profile:      *profile,
		IsFriend:     isFriend,
		FriendStatus: friendshipStatus,
		IsIncoming:   isIncoming,
	}, nil
}

func (p *PostgresAuthenticator) GetProfileByUserID(userID string) (*models.Profile, error) {
	query := `
		SELECT id, username, display_name, avatar_url, bio
		FROM public.users
		WHERE id = $1
	`
	row := p.pool.QueryRow(context.Background(), query, userID)
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

func (p *PostgresAuthenticator) checkFriendshipStatus(userID, otherUserID string) (*string, bool, bool) {
	if userID == otherUserID {
		return nil, false, false
	}

	var initiatorID, recipientID, status string
	err := p.pool.QueryRow(context.Background(), `
		SELECT initiator_id, recipient_id, status::text FROM public.friends
		WHERE (initiator_id = $1 AND recipient_id = $2) OR (initiator_id = $2 AND recipient_id = $1)
	`, userID, otherUserID).Scan(&initiatorID, &recipientID, &status)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, false, false
		}
		return nil, false, false
	}

	isFriend := status == "accepted"
	isIncoming := status == "pending" && recipientID == userID
	return &status, isFriend, isIncoming
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

func (p *PostgresAuthenticator) CreateMessage(chatID, senderID, content string, parentID, threadID *string, isThreadRoot bool) (*models.Message, error) {
	var messageID string
	var threadIDPtr, parentIDPtr *string

	threadIDVal := stringValue(threadID)
	parentIDVal := stringValue(parentID)

	if threadIDVal != "" {
		threadIDPtr = &threadIDVal
	}
	if parentIDVal != "" {
		parentIDPtr = &parentIDVal
	}

	err := p.pool.QueryRow(context.Background(),
		`INSERT INTO public.messages (chat_id, sender_id, content, parent_message_id, thread_id, is_thread_root, type) 
		 VALUES ($1, $2, $3, $4, $5, $6, 'text') RETURNING id`,
		chatID, senderID, content, parentIDPtr, threadIDPtr, isThreadRoot).Scan(&messageID)
	if err != nil {
		return nil, fmt.Errorf("failed to create message: %v", err)
	}

	message, err := p.getMessageByChatID(chatID, messageID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch created message: %v", err)
	}
	return message, nil
}

func (p *PostgresAuthenticator) GetMessages(groupID string) ([]models.Message, error) {
	chatID, err := p.GetOrCreateGroupChat(groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to get group chat: %v", err)
	}
	if chatID == "" {
		return []models.Message{}, nil
	}
	return p.GetChatMessages(chatID)
}

func (p *PostgresAuthenticator) GetEventMessages(eventID string) ([]models.Message, error) {
	var chatID string
	err := p.pool.QueryRow(context.Background(),
		"SELECT id FROM chats WHERE event_id = $1 AND type = 'event'",
		eventID).Scan(&chatID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return []models.Message{}, nil
		}
		return nil, fmt.Errorf("failed to get event chat: %v", err)
	}

	query := `
		SELECT m.id, m.chat_id, m.sender_id, m.type, m.content, m.parent_message_id, m.thread_id, m.is_thread_root, m.created_at, m.updated_at,
			COALESCE(u.display_name, u.username) as sender_name
		FROM messages m
		JOIN users u ON m.sender_id = u.id
		WHERE m.chat_id = $1
		ORDER BY m.created_at ASC
	`
	rows, err := p.pool.Query(context.Background(), query, chatID)
	if err != nil {
		return nil, fmt.Errorf("failed to get event messages: %v", err)
	}
	defer rows.Close()

	var messages []models.Message
	for rows.Next() {
		var msg models.Message
		var senderName string
		if err := rows.Scan(&msg.ID, &msg.ChatID, &msg.SenderID, &msg.Type, &msg.Content, &msg.ParentMsgID, &msg.ThreadID, &msg.IsThreadRoot, &msg.CreatedAt, &msg.UpdatedAt, &senderName); err != nil {
			log.Printf("Error scanning message: %v", err)
			continue
		}
		msg.SenderName = senderName
		messages = append(messages, msg)
	}

	return messages, rows.Err()
}

func (p *PostgresAuthenticator) GetChatMessages(chatID string) ([]models.Message, error) {
	query := `
		SELECT m.id, m.chat_id, m.sender_id, m.type, m.content, m.parent_message_id, m.thread_id, m.is_thread_root, m.created_at, m.updated_at,
			COALESCE(u.display_name, u.username) as sender_name
		FROM messages m
		JOIN users u ON m.sender_id = u.id
		WHERE m.chat_id = $1
		ORDER BY m.created_at ASC
	`
	rows, err := p.pool.Query(context.Background(), query, chatID)
	if err != nil {
		return nil, fmt.Errorf("failed to get chat messages: %v", err)
	}
	defer rows.Close()

	var messages []models.Message
	for rows.Next() {
		var msg models.Message
		var senderName string
		if err := rows.Scan(&msg.ID, &msg.ChatID, &msg.SenderID, &msg.Type, &msg.Content, &msg.ParentMsgID, &msg.ThreadID, &msg.IsThreadRoot, &msg.CreatedAt, &msg.UpdatedAt, &senderName); err != nil {
			log.Printf("Error scanning message: %v", err)
			continue
		}
		msg.SenderName = senderName
		messages = append(messages, msg)
	}

	return messages, rows.Err()
}

func (p *PostgresAuthenticator) getMessageByChatID(chatID, messageID string) (*models.Message, error) {
	query := `
		SELECT m.id, m.chat_id, m.sender_id, m.type, m.content, m.parent_message_id, m.thread_id, m.is_thread_root, m.created_at, m.updated_at,
			COALESCE(u.display_name, u.username) as sender_name
		FROM messages m
		JOIN users u ON m.sender_id = u.id
		WHERE m.id = $1 AND m.chat_id = $2
	`
	row := p.pool.QueryRow(context.Background(), query, messageID, chatID)
	var msg models.Message
	var senderName string
	err := row.Scan(&msg.ID, &msg.ChatID, &msg.SenderID, &msg.Type, &msg.Content, &msg.ParentMsgID, &msg.ThreadID, &msg.IsThreadRoot, &msg.CreatedAt, &msg.UpdatedAt, &senderName)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("message not found")
		}
		return nil, fmt.Errorf("failed to get message: %v", err)
	}
	msg.SenderName = senderName
	return &msg, nil
}

func (p *PostgresAuthenticator) getMessageByID(messageID string) (*models.Message, error) {
	query := `
		SELECT id, group_id, sender_id, content, message_type, thread_id, parent_id, created_at
		FROM public.messages
		WHERE id = $1
	`
	row := p.pool.QueryRow(context.Background(), query, messageID)
	var msg models.Message
	var messageType string
	err := row.Scan(&msg.ID, &msg.GroupID, &msg.SenderID, &msg.Content, &messageType, &msg.ThreadID, &msg.ParentID, &msg.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("message not found")
		}
		return nil, fmt.Errorf("failed to get message: %v", err)
	}
	msg.MessageType = models.MessageType(messageType)
	return &msg, nil
}
