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

Defaults to reduce manual inputs

Workflows will auto-generate Terraform backend resource names if you don't provide them when triggering the workflow. Defaults follow the pattern `<owner>-<repo>-<env>-tfstate` (for the S3 bucket) and `<owner>-<repo>-<env>-tfstate-locks` (for the DynamoDB lock table). The `env` input defaults to `dev`.

If you want to provide stable names for all environments (recommended for production), pass `bucket_name` and `dynamodb_table_name` when running the `Terraform Backend Setup` workflow. For CI/test runs you can skip these inputs and let the workflow choose reasonable defaults for you.

Quick reminder on environment names

- The workflows generate backend names automatically when you leave the backend fields blank.
- Defaults follow the pattern `<owner>-<repo>-<env>-tfstate` for the S3 bucket and `<owner>-<repo>-<env>-tfstate-locks` for the DynamoDB lock table. The `env` defaults to `dev`.
- Ensure you use the same `env` when running `Terraform Backend Setup` and `Deploy` so they target the same bucket/table.

For this repository (owner: `AleAkiraH`, repo: `PagueBemBackEnd`) the computed defaults would be:
- `aleakirah-paguebembackend-dev-tfstate`
- `aleakirah-paguebembackend-dev-tfstate-locks`

If you prefer a different naming scheme, edit the workflow or provide a stable backend in your own Terraform automation.