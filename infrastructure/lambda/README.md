Lambda module

Creates a Lambda function using a container image (`package_type = "Image"`).

Inputs:
- `image_uri` (required) - the ECR image URI (including tag) to use for the Lambda.

Usage:
- Ensure the image is pushed to ECR before running this module (Deploy workflow handles building/pushing).
- Call `terraform apply` in this folder or run the Deploy workflow. The module creates an IAM role with the AWSLambdaBasicExecutionRole policy attached.
