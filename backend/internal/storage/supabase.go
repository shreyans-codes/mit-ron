package storage

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type urlCache struct {
	url       string
	expiresAt time.Time
}

type SupabaseStorage struct {
	url        string
	anonKey    string
	serviceKey string
	httpClient *http.Client
	urlCache   map[string]urlCache
	cacheMutex sync.RWMutex
}

func NewSupabaseStorage(url, anonKey, serviceKey string) *SupabaseStorage {
	return &SupabaseStorage{
		url:        url,
		anonKey:    anonKey,
		serviceKey: serviceKey,
		httpClient: &http.Client{Timeout: 30 * time.Second},
		urlCache:   make(map[string]urlCache),
	}
}

func (s *SupabaseStorage) getKey() string {
	if s.serviceKey != "" && s.serviceKey != "your-supabase-service-role-key" {
		return s.serviceKey
	}
	return s.anonKey
}

func (s *SupabaseStorage) UploadFile(bucket, fileName string, file []byte) (string, error) {
	contentType := s.detectContentType(fileName)

	req, err := http.NewRequest("POST",
		fmt.Sprintf("%s/storage/v1/object/%s/%s", s.url, bucket, fileName),
		bytes.NewReader(file))
	if err != nil {
		return "", err
	}

	req.Header.Set("Authorization", "Bearer "+s.getKey())
	req.Header.Set("Content-Type", contentType)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("upload failed: %s", string(body))
	}

	return bucket + "/" + fileName, nil
}

func (s *SupabaseStorage) GetSignedURL(bucket, fileName string, expires int) (SignedURLResult, error) {
	body := fmt.Sprintf(`{"expiresIn": %d}`, expires)
	req, err := http.NewRequest("POST",
		fmt.Sprintf("%s/storage/v1/object/sign/%s/%s", s.url, bucket, fileName),
		strings.NewReader(body))
	if err != nil {
		return SignedURLResult{}, err
	}

	req.Header.Set("Authorization", "Bearer "+s.getKey())
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return SignedURLResult{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return SignedURLResult{}, fmt.Errorf("signed URL failed: %s", string(respBody))
	}

	var result map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return SignedURLResult{}, err
	}

	signedPath, ok := result["signedURL"]
	if !ok || signedPath == "" {
		return SignedURLResult{}, fmt.Errorf("no signed URL in response")
	}

	return SignedURLResult{
		SignedURL: s.url + "/storage/v1" + signedPath,
		ExpiresAt: time.Now().Add(time.Duration(expires) * time.Second),
	}, nil
}

func (s *SupabaseStorage) GetSignedURLFromPath(path string, expires int) (SignedURLResult, error) {
	s.cacheMutex.RLock()
	cached, found := s.urlCache[path]
	s.cacheMutex.RUnlock()

	if found && time.Now().Before(cached.expiresAt) {
		return SignedURLResult{
			SignedURL: cached.url,
			ExpiresAt: cached.expiresAt,
		}, nil
	}

	log.Printf("Generating signed URL for path: %s", path)

	body := fmt.Sprintf(`{"expiresIn": %d}`, expires)
	req, err := http.NewRequest("POST",
		fmt.Sprintf("%s/storage/v1/object/sign/%s", s.url, path),
		strings.NewReader(body))
	if err != nil {
		log.Printf("Error creating signed URL request: %v", err)
		return SignedURLResult{}, err
	}

	req.Header.Set("Authorization", "Bearer "+s.getKey())
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		log.Printf("Error making signed URL request: %v", err)
		return SignedURLResult{}, err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	log.Printf("Signed URL response status: %d, body: %s", resp.StatusCode, string(respBody))

	if resp.StatusCode >= 400 {
		return SignedURLResult{}, fmt.Errorf("signed URL failed: %s", string(respBody))
	}

	var result map[string]string
	if err := json.NewDecoder(bytes.NewReader(respBody)).Decode(&result); err != nil {
		log.Printf("Error decoding signed URL response: %v", err)
		return SignedURLResult{}, err
	}

	signedPath, ok := result["signedURL"]
	if !ok || signedPath == "" {
		log.Printf("No signedURL in response, result: %+v", result)
		return SignedURLResult{}, fmt.Errorf("no signed URL in response")
	}

	fullURL := s.url + "/storage/v1" + signedPath
	expiresAt := time.Now().Add(time.Duration(expires) * time.Second)

	s.cacheMutex.Lock()
	s.urlCache[path] = urlCache{url: fullURL, expiresAt: expiresAt}
	s.cacheMutex.Unlock()

	log.Printf("Generated signed URL: %s", fullURL)

	return SignedURLResult{
		SignedURL: fullURL,
		ExpiresAt: expiresAt,
	}, nil
}

func (s *SupabaseStorage) detectContentType(fileName string) string {
	ext := strings.ToLower(filepath.Ext(fileName))
	switch ext {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".gif":
		return "image/gif"
	case ".webp":
		return "image/webp"
	default:
		return "application/octet-stream"
	}
}

func (s *SupabaseStorage) DeleteFile(bucket, fileName string) error {
	req, err := http.NewRequest("DELETE",
		fmt.Sprintf("%s/storage/v1/object/%s/%s", s.url, bucket, fileName),
		nil)
	if err != nil {
		return err
	}

	req.Header.Set("Authorization", "Bearer "+s.getKey())

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("delete failed: %s", string(body))
	}

	return nil
}
