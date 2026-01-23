# Infrastructure and GitHub Actions

- Infrastructure Terraform files are in `infrastructure/` separated by component: `backend`, `ecr`, `lambda`, `apigateway`, `dynamodb`.
- Workflows are provided under `.github/workflows/` and are manual (`workflow_dispatch`) only:
  - `Terraform Backend Setup` - creates the S3 bucket and DynamoDB table to be used as the Terraform remote backend and locking table. Run this first (provide `bucket_name` and `dynamodb_table_name`).
  - `Deploy Infrastructure` - deploys components (ECR -> Lambda -> API Gateway -> DynamoDB). Inputs let you choose which components to deploy and the backend bucket/table to use for Terraform state.
  - `Destroy Infrastructure` - tears down resources (manual trigger, choose which components to destroy).

## Required GitHub repository secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Notes:

- None of the workflows run automatically; you must trigger them manually from the Actions tab.
- For `Deploy`, the workflow can build and push the Docker image to ECR and then deploy the Lambda using that image (or you can provide an existing `image_uri`).
- For local testing of the Lambda image you can still use the docker-based local server or the RIC-based invocation as shown earlier.

IAM permissions required for automation

The AWS credentials used by the GitHub workflows must have enough permissions to create the resources in the modules. Minimum required actions include (but are not limited to):
- s3:CreateBucket, s3:PutBucketVersioning, s3:PutEncryptionConfiguration, s3:PutBucketPublicAccessBlock
- dynamodb:CreateTable, dynamodb:DeleteTable
- iam:CreateRole, iam:AttachRolePolicy, iam:DeleteRole
- ecr:CreateRepository, ecr:DeleteRepository, ecr:PutImage, ecr:BatchDeleteImage
- lambda:CreateFunction, lambda:DeleteFunction, lambda:AddPermission
- apigateway:* (for creating the API)

For production use, prefer provisioning a least-privilege IAM principal specifically for CI/CD and store its keys in GitHub Secrets.