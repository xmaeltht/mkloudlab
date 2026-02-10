terraform {
  backend "s3" {
    bucket = "mkloudlab-bucket"
    key    = "keycloak-realm/terraform.tfstate"
    region = "us-east-1"

    endpoints = {
      s3 = "https://minio.maelkloud.com"
    }

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true

    # Credentials - use environment variables for security:
    # export AWS_ACCESS_KEY_ID="terraform"
    # export AWS_SECRET_ACCESS_KEY="terraformS3cret2024MinIO"
    # export AWS_ENDPOINT_URL_S3="https://minio.maelkloud.com"
  }
}
