output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "lambda_arn" {
  value = module.lambda.function_arn
}

output "lambda_name" {
  value = module.lambda.function_name
}

output "api_endpoint" {
  value = module.apigateway.api_endpoint
}
