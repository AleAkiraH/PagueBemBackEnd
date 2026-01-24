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

Default naming and convenience

If you prefer not to fill backend names when running the manual workflows, the workflows will generate sensible defaults automatically using this pattern:

- S3 bucket for Terraform state: <owner>-<repo>-<env>-tfstate
- DynamoDB table for locks: <owner>-<repo>-<env>-tfstate-locks

where:
- owner = GitHub repository owner (your username or organization)
- repo = GitHub repository name (sanitized: lowercase, non-alphanumeric replaced with '-')
- env = environment input to the workflow (default: `dev`)

Example generated names:
- `aleakirah-paguebembackend-dev-tfstate`
- `aleakirah-paguebembackend-dev-tfstate-locks`

The workflows validate the generated S3 bucket name and will fail early if it doesn't meet S3 naming rules; in that case provide a custom `bucket_name` input when triggering the workflow.
