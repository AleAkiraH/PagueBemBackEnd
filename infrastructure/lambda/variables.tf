variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "paguebem-qrreader"
}

variable "image_uri" {
  description = "Container image URI for the Lambda function (ECR image URI with tag)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "role_name" {
  description = "IAM Role name for the Lambda"
  type        = string
  default     = "paguebem-qrreader-lambda-role"
}

variable "timeout" {
  description = "Lambda timeout"
  type        = number
  default     = 10
}

variable "memory_size" {
  description = "Lambda memory size MB"
  type        = number
  default     = 512
}

variable "environment" {
  description = "Map of environment variables for Lambda"
  type        = map(string)
  default     = {}
}
