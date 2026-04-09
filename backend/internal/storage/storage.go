package storage

type StorageProvider interface {
	UploadFile(bucket, fileName string, file []byte) (string, error)
	GetSignedURL(bucket, fileName string, expires int) (string, error)
}
