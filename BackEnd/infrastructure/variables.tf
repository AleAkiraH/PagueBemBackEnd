variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ecr_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "paguebem-qrreader"
}

variable "ecr_force_delete" {
  description = "Whether to force delete the ECR repository on destroy"
  type        = bool
  default     = true
}

variable "local_image_name" {
  description = "Local Docker image name to build"
  type        = string
  default     = "paguebem-qrreader"
}

variable "image_tag" {
  description = "Docker image tag to use"
  type        = string
  default     = "latest"
}

variable "lambda_name" {
  description = "Lambda function name"
  type        = string
  default     = "paguebem-qrreader"
}

variable "lambda_role_name" {
  description = "IAM role name for Lambda"
  type        = string
  default     = "paguebem-qrreader-lambda-role"
}

variable "lambda_timeout" {
  description = "Lambda timeout"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory size MB"
  type        = number
  default     = 512
}

variable "lambda_environment" {
  description = "Map of environment variables for Lambda"
  type        = map(string)
  default     = {}
}

variable "api_name" {
  description = "API Gateway name"
  type        = string
  default     = "paguebem-api"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for application data"
  type        = string
  default     = "paguebem-app-data"
}