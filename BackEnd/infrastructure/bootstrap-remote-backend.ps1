Param(
  [string]$bucketName = "aleakirah-paguebembackend-dev-tfstate",
  [string]$dynamodbTable = "aleakirah-paguebembackend-dev-tfstate-locks",
  [string]$region = "us-east-1"
)

Write-Output "Creating backend resources (S3 + DynamoDB) in region $region..."

Push-Location .\backend
$env:TF_INPUT = "0"
terraform init -input=false
terraform apply -input=false -auto-approve -var="region=$region" -var="bucket_name=$bucketName" -var="dynamodb_table_name=$dynamodbTable"
Pop-Location

Write-Output "Backend resources created. To reconfigure the root Terraform backend to use the S3 bucket, run:" 
Write-Output "  cd BackEnd\infrastructure"
Write-Output "  terraform init -reconfigure -backend-config=\"bucket=$bucketName\" -backend-config=\"key=infrastructure/terraform.tfstate\" -backend-config=\"region=$region\" -backend-config=\"dynamodb_table=$dynamodbTable\""

Write-Output "After reconfigure, you may be prompted to migrate state from local to the remote backend. Confirm to proceed."