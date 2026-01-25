variable "function_name" { type = string }
variable "role_name" { type = string }
variable "image_uri" { type = string }
variable "region" { type = string }
variable "environment" { type = map(string) }
variable "timeout" { type = number }
variable "memory_size" { type = number }
