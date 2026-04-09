package storage

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strings"
	"time"
)

type SupabaseStorage struct {
	url        string
	anonKey    string
	serviceKey string
	httpClient *http.Client
}

func NewSupabaseStorage(url, anonKey, serviceKey string) *SupabaseStorage {
	return &SupabaseStorage{
		url:        url,
		anonKey:    anonKey,
		serviceKey: serviceKey,
		httpClient: &http.Client{Timeout: 30 * time.Second},
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

func (s *SupabaseStorage) GetSignedURL(bucket, fileName string, expires int) (string, error) {
	body := fmt.Sprintf(`{"expiresIn": %d}`, expires)
	req, err := http.NewRequest("POST",
		fmt.Sprintf("%s/storage/v1/object/sign/%s/%s", s.url, bucket, fileName),
		strings.NewReader(body))
	if err != nil {
		return "", err
	}

	req.Header.Set("Authorization", "Bearer "+s.getKey())
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("signed URL failed: %s", string(respBody))
	}

	var result map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	signedPath, ok := result["signedURL"]
	if !ok || signedPath == "" {
		return "", fmt.Errorf("no signed URL in response")
	}

	return s.url + "/storage/v1" + signedPath, nil
}

func (s *SupabaseStorage) GetSignedURLFromPath(path string, expires int) (string, error) {
	body := fmt.Sprintf(`{"expiresIn": %d}`, expires)
	req, err := http.NewRequest("POST",
		fmt.Sprintf("%s/storage/v1/object/sign/%s", s.url, path),
		strings.NewReader(body))
	if err != nil {
		return "", err
	}

	req.Header.Set("Authorization", "Bearer "+s.getKey())
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("signed URL failed: %s", string(respBody))
	}

	var result map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	signedPath, ok := result["signedURL"]
	if !ok || signedPath == "" {
		return "", fmt.Errorf("no signed URL in response")
	}

	return s.url + "/storage/v1" + signedPath, nil
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
