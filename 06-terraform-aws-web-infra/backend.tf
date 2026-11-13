terraform {
  backend "s3" {
    bucket = "<Unique S3 Bucket Name>"
    key    = "terraform/backend"
    region = "us-east-1"
  }
}