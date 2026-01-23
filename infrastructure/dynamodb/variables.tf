variable "table_name" {
  description = "Name of the DynamoDB table to create for app data"
  type        = string
  default     = "paguebem-app-table"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
