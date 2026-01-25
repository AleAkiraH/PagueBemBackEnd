
# Manual Deployment Guide

Este guia descreve como fazer deploy manual da infraestrutura usando Terraform.
**Agora execute todos os comandos a partir da pasta BackEnd/**

## Pré-requisitos

- Terraform >= 1.5.0 instalado
- AWS CLI configurado com credenciais (`aws configure`)
- Docker instalado (para build da imagem Lambda)
- PowerShell (Windows)

## Variáveis de Ambiente AWS

Configure suas credenciais AWS:
```powershell
$env:AWS_ACCESS_KEY_ID="sua-access-key"
$env:AWS_SECRET_ACCESS_KEY="sua-secret-key"
$env:AWS_DEFAULT_REGION="us-east-1"
```

## Passo 1: Deploy do Backend (S3 + DynamoDB para Terraform State)

```powershell
cd BackEnd\infrastructure\backend

# Inicializar Terraform
terraform init

# Planejar (revisar mudanças)
terraform plan -var="region=us-east-1" `
  -var="bucket_name=aleakirah-paguebembackend-dev-tfstate" `
  -var="dynamodb_table_name=aleakirah-paguebembackend-dev-tfstate-locks"

# Aplicar
terraform apply -var="region=us-east-1" `
  -var="bucket_name=aleakirah-paguebembackend-dev-tfstate" `
  -var="dynamodb_table_name=aleakirah-paguebembackend-dev-tfstate-locks"
```

**Nota:** Ajuste os nomes do bucket e tabela DynamoDB conforme necessário. O bucket S3 só aceita letras minúsculas, números e hífens.

## Passo 2: Deploy do ECR Repository

```powershell
cd ..\ecr

# Inicializar com backend remoto
terraform init `
  -backend-config="bucket=aleakirah-paguebembackend-dev-tfstate" `
  -backend-config="key=ecr/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=aleakirah-paguebembackend-dev-tfstate-locks"

# Planejar
terraform plan -var="region=us-east-1" -var="name=paguebem-qrreader"

# Aplicar
terraform apply -var="region=us-east-1" -var="name=paguebem-qrreader"

# Capturar o repository_url
$ECR_REPO_URL = terraform output -raw repository_url
Write-Output "ECR Repository URL: $ECR_REPO_URL"
```

## Passo 3: Build e Push da Imagem Docker

```powershell
cd ..\.. # volte para BackEnd

# Login no ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build da imagem (agora o Dockerfile está em BackEnd/)
docker build -t paguebem-qrreader:latest BackEnd/

docker tag paguebem-qrreader:latest "${ECR_REPO_URL}:latest"

# Push para ECR
docker push "${ECR_REPO_URL}:latest"
```

## Passo 4: Deploy da Lambda Function

```powershell
cd infrastructure\lambda

# Inicializar com backend remoto
terraform init `
  -backend-config="bucket=aleakirah-paguebembackend-dev-tfstate" `
  -backend-config="key=lambda/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=aleakirah-paguebembackend-dev-tfstate-locks"

# Planejar
terraform plan `
  -var="region=us-east-1" `
  -var="function_name=paguebem-qrreader" `
  -var="role_name=paguebem-qrreader-lambda-role" `
  -var="image_uri=${ECR_REPO_URL}:latest"

# Aplicar
terraform apply `
  -var="region=us-east-1" `
  -var="function_name=paguebem-qrreader" `
  -var="role_name=paguebem-qrreader-lambda-role" `
  -var="image_uri=${ECR_REPO_URL}:latest"

# Capturar outputs
$LAMBDA_ARN = terraform output -raw lambda_arn
$LAMBDA_NAME = terraform output -raw lambda_name
Write-Output "Lambda ARN: $LAMBDA_ARN"
Write-Output "Lambda Name: $LAMBDA_NAME"
```

## Passo 5: Deploy do API Gateway

```powershell
cd ..\apigateway

# Inicializar com backend remoto
terraform init `
  -backend-config="bucket=aleakirah-paguebembackend-dev-tfstate" `
  -backend-config="key=apigateway/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=aleakirah-paguebembackend-dev-tfstate-locks"

# Planejar
terraform plan `
  -var="region=us-east-1" `
  -var="api_name=paguebem-api" `
  -var="lambda_arn=$LAMBDA_ARN" `
  -var="lambda_name=$LAMBDA_NAME"

# Aplicar
terraform apply `
  -var="region=us-east-1" `
  -var="api_name=paguebem-api" `
  -var="lambda_arn=$LAMBDA_ARN" `
  -var="lambda_name=$LAMBDA_NAME"

# Capturar API endpoint
$API_ENDPOINT = terraform output -raw api_endpoint
Write-Output "API Endpoint: $API_ENDPOINT"
```

## Passo 6: Deploy do DynamoDB (Opcional - se necessário)

```powershell
cd ..\dynamodb

# Inicializar com backend remoto
terraform init `
  -backend-config="bucket=aleakirah-paguebembackend-dev-tfstate" `
  -backend-config="key=dynamodb/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=aleakirah-paguebembackend-dev-tfstate-locks"

# Planejar
terraform plan -var="region=us-east-1" -var="table_name=paguebem-app-data"

# Aplicar
terraform apply -var="region=us-east-1" -var="table_name=paguebem-app-data"
```

## Testar a API

```powershell
# Criar payload de teste (imagem em base64)
$ImagePath = "local\qrcode1.jpeg"
$ImageBytes = [System.IO.File]::ReadAllBytes($ImagePath)
$Base64Image = [System.Convert]::ToBase64String($ImageBytes)

$Body = @{
    image = $Base64Image
} | ConvertTo-Json

# Fazer requisição POST
Invoke-RestMethod -Uri "${API_ENDPOINT}/decode" -Method POST -Body $Body -ContentType "application/json"
```

## Importar Recursos Existentes (se necessário)

Se os recursos já existem na AWS e você precisa importá-los para o Terraform state:

### ECR Repository
```powershell
cd infrastructure\ecr
$env:TF_VAR_region="us-east-1"
$env:TF_VAR_name="paguebem-qrreader"
terraform import aws_ecr_repository.this paguebem-qrreader
```

### IAM Role
```powershell
cd ..\lambda
$env:TF_VAR_region="us-east-1"
$env:TF_VAR_role_name="paguebem-qrreader-lambda-role"
$env:TF_VAR_function_name="paguebem-qrreader"
$env:TF_VAR_image_uri="ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/paguebem-qrreader:latest"
terraform import aws_iam_role.lambda_exec paguebem-qrreader-lambda-role
```

### Lambda Function
```powershell
terraform import aws_lambda_function.this paguebem-qrreader
```

## Destruir Infraestrutura

Para destruir toda a infraestrutura (na ordem reversa):

```powershell
# API Gateway
cd infrastructure\apigateway
terraform destroy -var="region=us-east-1" -var="api_name=paguebem-api" -var="lambda_arn=$LAMBDA_ARN" -var="lambda_name=$LAMBDA_NAME"

# Lambda
cd ..\lambda
terraform destroy -var="region=us-east-1" -var="function_name=paguebem-qrreader" -var="role_name=paguebem-qrreader-lambda-role" -var="image_uri=${ECR_REPO_URL}:latest"

# ECR (remove imagens antes se force_delete=false)
cd ..\ecr
terraform destroy -var="region=us-east-1" -var="name=paguebem-qrreader"

# DynamoDB (se criado)
cd ..\dynamodb
terraform destroy -var="region=us-east-1" -var="table_name=paguebem-app-data"

# Backend (cuidado! isso remove o state)
cd ..\backend
terraform destroy -var="region=us-east-1" -var="bucket_name=aleakirah-paguebembackend-dev-tfstate" -var="dynamodb_table_name=aleakirah-paguebembackend-dev-tfstate-locks"
```

## Notas Importantes

1. **Ordem de Deploy:** Backend → ECR → Build/Push Image → Lambda → API Gateway → DynamoDB
2. **Ordem de Destroy:** API Gateway → Lambda → ECR → DynamoDB → Backend (reverso)
3. **State Management:** Cada módulo (exceto backend) usa remote state no S3
4. **Nomes de Recursos:** Ajuste conforme sua convenção de nomenclatura
5. **Região AWS:** Todos os exemplos usam `us-east-1`, ajuste se necessário
6. **Backend Config:** Use os mesmos valores de bucket/table em todos os módulos

# One-step Deploy (recommended)

Agora você pode fazer todo o deploy com um único comando a partir da pasta `infrastructure`.

```powershell
cd infrastructure
terraform init
terraform apply -auto-approve
```

- O `apply` irá:
  - criar o repositório ECR (se não existir);
  - construir a imagem Docker localmente (usa o `Dockerfile` na raiz do repo);
  - dar push da imagem para o ECR com a tag configurada (`latest` por padrão);
  - criar a função Lambda apontando para a imagem no ECR;
  - criar o API Gateway integrado com a Lambda;
  - criar a tabela DynamoDB de aplicação (se habilitada).

# One-step Destroy (remove tudo)

Para destruir toda a infraestrutura criada pelo passo acima (ordem reversa automaticamente):

```powershell
cd infrastructure
terraform destroy -auto-approve
```

> Observação importante: por padrão o state fica local (arquivo). Se você quiser usar o backend remoto (S3 + DynamoDB lock), rode o script `bootstrap-remote-backend.ps1` (vai criar o bucket/tabela e reconfigurar o backend). Veja a seção "Migrar state para backend remoto" abaixo.

# Migrar state para backend remoto (opcional)

O repositório fornece um script para criar o backend remoto e reconfigurar o Terraform para usar o S3/DynamoDB:

```powershell
cd infrastructure
.\bootstrap-remote-backend.ps1
```

Isso vai:
- aplicar o módulo `backend` (criar bucket S3 e tabela DynamoDB);
- reconfigurar o backend do Terraform no diretório `infrastructure` para usar o bucket criado;
- opcionalmente você pode checar o state com `terraform state list`.

# One-command deploy with imports (convenience)

Se você quiser um workflow totalmente baseado em Terraform (sem scripts), execute dois passos rápidos para garantir que quaisquer recursos já existentes sejam adotados antes de aplicar o restante:

```powershell
cd infrastructure
# 1) Detecta e importa recursos já existentes (ECR / IAM role / Lambda) para o state. Se não houver recursos existentes, é um no-op.
terraform apply -target=null_resource.import_ecr -target=null_resource.import_iam_role -target=null_resource.import_lambda -auto-approve

# 2) Aplica o resto da infra (cria ECR se não existir, faz build/push, cria Lambda, API Gateway, DynamoDB)
terraform apply -auto-approve
```

Explicação curta:
- O primeiro passo executa os "null_resource" de importação. Eles só farão `terraform import` quando detectarem recursos já criados na conta.
- O segundo passo aplica o plano final com tudo gerenciado pelo Terraform. Depois disso, `terraform destroy` removerá os recursos que o Terraform passou a gerenciar.

> Observação: executar `terraform apply -auto-approve` direto funciona em um ambiente limpo (sem recursos existentes). Se houver recursos criados anteriormente fora do Terraform, execute o passo de import acima antes do apply para evitar conflitos (ResourceAlreadyExists).
