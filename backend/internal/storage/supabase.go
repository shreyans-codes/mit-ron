package storage

import (
	"bytes"
	"github.com/supabase-community/supabase-go"
)

type SupabaseStorage struct {
	client *supabase.Client
}

func NewSupabaseStorage(url, anonKey string) *SupabaseStorage {
	client, _ := supabase.NewClient(url, anonKey, &supabase.ClientOptions{})
	return &SupabaseStorage{
		client: client,
	}
}

func (s *SupabaseStorage) UploadFile(bucket, fileName string, file []byte) (string, error) {
	// Create a reader from the byte slice
	reader := bytes.NewReader(file)
	
	// Upload the file to the bucket
	_, err := s.client.Storage.UploadFile(bucket, fileName, reader)
	if err != nil {
		return "", err
	}
	
	return s.GetPublicURL(bucket, fileName), nil
}

func (s *SupabaseStorage) GetPublicURL(bucket, fileName string) string {
	// Get the public URL for the file
	resp := s.client.Storage.GetPublicUrl(bucket, fileName)
	return resp.SignedURL
}
