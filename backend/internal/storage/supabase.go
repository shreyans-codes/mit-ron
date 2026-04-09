package storage

import (
	"bytes"

	"github.com/supabase-community/supabase-go"
)

type SupabaseStorage struct {
	client        *supabase.Client
	serviceClient *supabase.Client
}

func NewSupabaseStorage(url, anonKey, serviceKey string) *SupabaseStorage {
	client, _ := supabase.NewClient(url, anonKey, &supabase.ClientOptions{})

	var serviceClient *supabase.Client
	if serviceKey != "" && serviceKey != "your-supabase-service-role-key" {
		serviceClient, _ = supabase.NewClient(url, serviceKey, &supabase.ClientOptions{})
	}

	return &SupabaseStorage{
		client:        client,
		serviceClient: serviceClient,
	}
}

func (s *SupabaseStorage) UploadFile(bucket, fileName string, file []byte) (string, error) {
	reader := bytes.NewReader(file)

	uploadClient := s.client
	if s.serviceClient != nil {
		uploadClient = s.serviceClient
	}

	_, err := uploadClient.Storage.UploadFile(bucket, fileName, reader)
	if err != nil {
		return "", err
	}

	return s.GetSignedURL(bucket, fileName, 3600)
}

func (s *SupabaseStorage) GetSignedURL(bucket, fileName string, expires int) (string, error) {
	signedClient := s.serviceClient
	if signedClient == nil {
		signedClient = s.client
	}

	resp := signedClient.Storage.GetPublicUrl(bucket, fileName)
	return resp.SignedURL, nil
}

func (s *SupabaseStorage) GetPublicURL(bucket, fileName string) string {
	url, _ := s.GetSignedURL(bucket, fileName, 3600)
	return url
}
