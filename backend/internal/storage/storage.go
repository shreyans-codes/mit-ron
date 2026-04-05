package storage

type StorageProvider interface {
	UploadFile(bucket, fileName string, file []byte) (string, error)
	GetPublicURL(bucket, fileName string) string
}
