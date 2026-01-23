variable "bucket_name" {
  description = "S3 bucket name to use for Terraform remote state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name to use for Terraform state locking"
  type        = string
}

variable "region" {
  description = "AWS region to create backend resources in"
  type        = string
  default     = "us-east-1"
}
