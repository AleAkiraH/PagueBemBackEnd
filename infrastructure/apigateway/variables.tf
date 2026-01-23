variable "name" {
  description = "Name of the API Gateway"
  type        = string
  default     = "paguebem-api"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_arn" {
  description = "Lambda function ARN to integrate with API Gateway"
  type        = string
}

variable "lambda_name" {
  description = "Lambda function name (for permission statement)"
  type        = string
}
