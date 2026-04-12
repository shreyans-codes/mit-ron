package storage

import "time"

type SignedURLResult struct {
	SignedURL string
	ExpiresAt time.Time
}

type StorageProvider interface {
	UploadFile(bucket, fileName string, file []byte) (string, error)
	GetSignedURL(bucket, fileName string, expires int) (SignedURLResult, error)
	GetSignedURLFromPath(path string, expires int) (SignedURLResult, error)
	DeleteFile(bucket, fileName string) error
}
