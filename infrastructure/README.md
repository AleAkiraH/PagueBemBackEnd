Infrastructure folder

This folder contains independent Terraform modules for the project's infrastructure pieces.

Modules:
- backend: S3 bucket + DynamoDB table used for Terraform remote backend and locking
- ecr: ECR repository for container image storage
- lambda: Lambda function that uses a container image
- apigateway: API Gateway HTTP API integrating with the Lambda
- dynamodb: example application DynamoDB table

General workflow:
1. Run the `Terraform Backend Setup` GitHub Actions workflow to create the remote backend S3 bucket and DynamoDB locks table (manual trigger).
2. Use the `Deploy` workflow to deploy modules (ECR, Lambda, API Gateway, DynamoDB) in the proper order. The Deploy workflow will build/push the container to ECR when needed.
3. Use the `Destroy` workflow to tear down modules when necessary.

All workflows are manual (`workflow_dispatch`) and will not run automatically.
