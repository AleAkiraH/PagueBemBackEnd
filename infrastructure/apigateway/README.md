API Gateway module (HTTP API)

Creates an HTTP API (API Gateway v2) with a single POST /decode route integrated with the supplied Lambda function ARN.

Inputs:
- `lambda_arn` - ARN of the Lambda function used by the integration
- `lambda_name` - Lambda function name used for permission binding

Usage:
- Deploy the Lambda first, then apply this module specifying the Lambda ARN or by running the Deploy workflow with components `lambda` and `apigateway`.
