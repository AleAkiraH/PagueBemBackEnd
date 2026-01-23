variable "name" {
  description = "Name of the ECR repository to create"
  type        = string
  default     = "paguebem-qrreader"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "force_delete" {
  description = "Whether to force delete ECR repository even if it has images"
  type        = bool
  default     = true
}
