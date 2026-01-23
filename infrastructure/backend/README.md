Terraform backend resources: S3 bucket for remote state and DynamoDB table for state locking.

Usage:
- Run the GitHub Actions workflow `Terraform Backend Setup` (manual) to create a bucket and lock table.
- Optionally run locally with `terraform init` and `terraform apply -var 'bucket_name=<name>' -var 'dynamodb_table_name=<name>'` (ensure AWS credentials are configured).

Notes:
- The bucket will have versioning and server-side encryption enabled.
- The DynamoDB table uses PAY_PER_REQUEST billing.
