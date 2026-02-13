# 🤖 Copilot Instructions — Padrão de Projetos AWS com Terraform

> **Este documento é vivo.** Ele evolui conforme o projeto cresce. O agente deve consultá-lo sempre
> que receber uma solicitação e propor atualizações quando novos padrões forem estabelecidos.

---

## 📌 Visão Geral

Eu trabalho com projetos que usam **infraestrutura AWS gerenciada por Terraform**, com **ambientes separados (dev/prod)** e **repositórios independentes por recurso AWS**. Todos os repos são reunidos em um único **VS Code Workspace** para facilitar o desenvolvimento.

### Filosofia Central

1. **1 recurso AWS = 1 repositório Terraform** (isolamento total)
2. **dev e prod sempre separados** com `terraform.tfvars` próprios
3. **Deploy e Destroy devem funcionar perfeitamente** — sem lixo na AWS
4. **State remoto no S3** com lock no DynamoDB para segurança
5. **Frontend separado** com deploy na Vercel (ou similar)
6. **Tudo deve ser destruível** — `terraform destroy` precisa limpar 100% dos recursos

---

## 🏗️ Arquitetura do Workspace

```
📁 C:\GIT\{nome-projeto}\                    ← Frontend + workspace config
📁 C:\GIT\{nome-projeto}-terraform\           ← Todos os repos Terraform (multi-root workspace)
    ├── 📁 dynamodb\                          ← Tabelas DynamoDB
    ├── 📁 lambda\                            ← Lambda Functions + código fonte
    ├── 📁 apigateway\                        ← API Gateway HTTP
    ├── 📁 s3\                                ← Buckets S3 (se necessário)
    ├── 📁 sqs\                               ← Filas SQS (se necessário)
    ├── 📁 cognito\                           ← Cognito User Pools (se necessário)
    ├── 📁 sns\                               ← SNS Topics (se necessário)
    ├── 📁 eventbridge\                       ← EventBridge Rules (se necessário)
    ├── 📁 cloudfront\                        ← CloudFront Distributions (se necessário)
    ├── 📁 rds\                               ← RDS/Aurora (se necessário)
    ├── 📁 ecs\                               ← ECS/Fargate (se necessário)
    ├── 📁 stepfunctions\                     ← Step Functions (se necessário)
    └── 📁 iam\                               ← Roles/Policies compartilhadas (se necessário)
```

### Workspace File (.code-workspace)

O arquivo `.code-workspace` fica no repositório do **frontend** e referencia todos os repos:

```json
{
  "folders": [
    { "path": "." },
    { "path": "../{nome-projeto}-terraform/apigateway" },
    { "path": "../{nome-projeto}-terraform/dynamodb" },
    { "path": "../{nome-projeto}-terraform/lambda" }
  ]
}
```

---

## 📐 Estrutura Padrão de Cada Repositório Terraform

Todo repositório de recurso AWS **DEVE** seguir esta estrutura:

```
{recurso}/
├── main.tf                     ← Recursos Terraform
├── variables.tf                ← Variáveis com validação
├── outputs.tf                  ← Outputs para outros módulos consumirem
├── README.md                   ← Documentação com deploy, destroy e dependências
├── .gitignore                  ← Ignorar .terraform/, *.tfstate, *.tfplan, etc.
├── .terraform.lock.hcl         ← Lock do provider (versionado)
├── dev/
│   ├── terraform.tfvars        ← Valores reais de dev (⚠️ pode conter secrets, NÃO versionar)
│   └── terraform.tfvars.example ← Template de exemplo (versionado)
├── prod/
│   ├── terraform.tfvars        ← Valores reais de prod (⚠️ NÃO versionar)
│   └── terraform.tfvars.example ← Template de exemplo (versionado)
└── .github/                    ← (opcional) CI/CD workflows
```

### Se o recurso contém código-fonte (ex: Lambda):

```
lambda/
├── main.tf
├── variables.tf
├── outputs.tf
├── README.md
├── dev/ e prod/                ← tfvars
└── lambda/                     ← Código-fonte da aplicação
    ├── main.py                 ← Handler principal
    ├── Dockerfile              ← Build da imagem Docker
    ├── requirements.txt        ← Dependências Python
    ├── controller/             ← Controllers (routing/parsing)
    ├── services/               ← Lógica de negócio
    ├── repository/             ← Acesso a dados (DynamoDB)
    ├── models/                 ← Modelos de domínio
    ├── dtos/                   ← Validação com Pydantic
    └── utils/                  ← JWT, logging, exceptions
```

---

## 🔧 Padrão do main.tf

Todo `main.tf` **DEVE** conter:

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "{nome-projeto}-terraform-state"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
    # key é passado via -backend-config="key=..." no terraform init
    # Dev:  {recurso}/dev/terraform.tfstate
    # Prod: {recurso}/prod/terraform.tfstate
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Repository  = "{nome-projeto}-terraform-{recurso}"
    }
  }
}
```

### Regras obrigatórias:

- **Backend S3**: Bucket `{nome-projeto}-terraform-state` com DynamoDB `terraform-locks`
- **State separado por ambiente**: key segue padrão `{recurso}/{env}/terraform.tfstate`
- **Default Tags**: SEMPRE incluir `Environment`, `Project`, `ManagedBy`, `Repository`
- **Nomes de recursos**: padrão `{nome-projeto}-{descritivo}-{environment}` (ex: `controlese-api-dev`)

---

## 🔧 Padrão do variables.tf

Toda `variables.tf` **DEVE** conter ao menos:

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment (dev, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be 'dev' or 'prod'."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "{nome-projeto}"
}
```

---

## 🔧 Padrão do outputs.tf

Outputs devem expor **tudo que outros módulos possam precisar**:

- **DynamoDB**: `table_name`, `table_arn` para cada tabela
- **Lambda**: `function_name`, `function_arn`, `role_arn`, `ecr_repository_url`
- **API Gateway**: `api_endpoint`, `api_id`, `api_execution_arn`, `stage_name`
- **S3**: `bucket_name`, `bucket_arn`
- **SQS**: `queue_url`, `queue_arn`
- **SNS**: `topic_arn`

---

## 🔧 Padrão do .gitignore (Terraform repos)

```gitignore
# Terraform
.terraform/
terraform.tfstate
terraform.tfstate.*
*.tfplan
*.tfstate.backup
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Secrets
.env
.env.local
.env.*.local

# NÃO versionar tfvars com secrets reais
# dev/terraform.tfvars   ← contém ARNs e secrets
# prod/terraform.tfvars  ← contém ARNs e secrets

# Python (se aplicável)
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
build/
dist/

# IDE
.vscode/
.idea/
```

---

## 🚀 Comandos de Deploy e Destroy

### Ordem de Deploy (IMPORTANTE — respeitar dependências)

```
1️⃣  dynamodb     → Sem dependências (criar primeiro)
2️⃣  s3           → Sem dependências (se usado)
3️⃣  sqs          → Sem dependências (se usado)
4️⃣  lambda       → Depende de: dynamodb (ARNs), sqs (ARNs, se usado)
5️⃣  apigateway   → Depende de: lambda (ARN e nome da função)
6️⃣  cloudfront   → Depende de: s3 e/ou apigateway (se usado)
7️⃣  frontend     → Depende de: apigateway (endpoint URL)
```

### Ordem de Destroy (INVERSA do deploy)

```
7️⃣  frontend     → Remover deploy da Vercel
6️⃣  cloudfront   → Destroy primeiro (se usado)
5️⃣  apigateway   → terraform destroy -var-file="{env}/terraform.tfvars"
4️⃣  lambda       → terraform destroy -var-file="{env}/terraform.tfvars"
3️⃣  sqs          → terraform destroy -var-file="{env}/terraform.tfvars" (se usado)
2️⃣  s3           → terraform destroy -var-file="{env}/terraform.tfvars" (se usado)
1️⃣  dynamodb     → terraform destroy -var-file="{env}/terraform.tfvars"
```

### Comandos para cada recurso:

```powershell
# ===== INIT (primeira vez ou troca de ambiente) =====
terraform init -backend-config="key={recurso}/{env}/terraform.tfstate"

# Exemplo para dynamodb em dev:
terraform init -backend-config="key=dynamodb/dev/terraform.tfstate"

# ===== PLAN (visualizar mudanças) =====
terraform plan -var-file="{env}/terraform.tfvars"

# ===== APPLY (deploy) =====
terraform apply -var-file="{env}/terraform.tfvars"

# ===== DESTROY (remover tudo) =====
terraform destroy -var-file="{env}/terraform.tfvars"
```

---

## 🧹 Regras de Limpeza Total (Zero Lixo na AWS)

Para garantir que `terraform destroy` remove TUDO:

1. **ECR**: usar `force_delete = true` no `aws_ecr_repository`
2. **S3 Buckets**: usar `force_destroy = true` no `aws_s3_bucket`
3. **CloudWatch Log Groups**: são criados explicitamente no Terraform (não auto-criados)
4. **Lambda Permissions**: definidas no módulo que cria a integração
5. **DynamoDB**: tabelas são deletadas com destroy normalmente
6. **SQS**: filas são deletadas com destroy normalmente
7. **API Gateway**: stages e routes são deletados em cascata

### ⚠️ NUNCA criar recursos manualmente no console AWS!
Se criar manualmente, o Terraform não consegue destruir. Tudo DEVE estar no código.

---

## 📋 Checklist para Criar um Novo Projeto

Quando eu pedir para criar um novo projeto, siga este fluxo:

### Pergunta Inicial Obrigatória:

> **"Quais recursos AWS você pretende utilizar neste projeto?"**
> 
> Opções comuns:
> - 🗄️ **DynamoDB** — Banco NoSQL
> - ⚡ **Lambda** — Funções serverless (Python/Node)
> - 🌐 **API Gateway** — HTTP API para expor endpoints
> - 📦 **S3** — Armazenamento de arquivos
> - 📨 **SQS** — Filas de mensagens
> - 🔔 **SNS** — Notificações
> - 👤 **Cognito** — Autenticação de usuários
> - 🌍 **CloudFront** — CDN
> - 📅 **EventBridge** — Agendamentos e eventos
> - 🗃️ **RDS/Aurora** — Banco relacional
> - 🐳 **ECS/Fargate** — Containers
> - 🔄 **Step Functions** — Orquestração de workflows
> - 🖥️ **Frontend** — React/Vite (Vercel)
>
> **Qual é o nome do projeto?** (usado para: repo, tags, nomes de recursos)

### Após a resposta, criar:

1. **Bucket S3 para state** (se ainda não existir): `{nome-projeto}-terraform-state`
2. **Tabela DynamoDB para locks** (se ainda não existir): `terraform-locks`
3. **Repositório para cada recurso** com a estrutura padrão
4. **Arquivo `.code-workspace`** referenciando todos os repos
5. **README.md** em cada repo com instruções de deploy e destroy
6. **terraform.tfvars.example** para dev e prod em cada repo
7. **Atualizar este arquivo** `copilot-instructions.md` com o novo projeto

---

## 📦 Templates por Recurso AWS

### DynamoDB

```hcl
# Exemplo de tabela padrão
resource "aws_dynamodb_table" "exemplo" {
  name           = "NomeTabela-${var.environment}"
  billing_mode   = var.billing_mode  # PAY_PER_REQUEST para dev, PROVISIONED para prod se necessário
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # GSI para busca por usuário (padrão comum)
  attribute {
    name = "usuario_id"
    type = "S"
  }

  global_secondary_index {
    name            = "usuario_id-index"
    hash_key        = "usuario_id"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr  # false em dev, true em prod
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "NomeTabela-${var.environment}"
  }
}
```

### Lambda (com Docker/ECR)

Padrão atual:
- **Runtime**: Python 3.11 via Docker image (`public.ecr.aws/lambda/python:3.11`)
- **Build**: Terraform `null_resource` com triggers automáticos em `.py`, `requirements.txt`, `Dockerfile`
- **ECR**: `force_delete = true` para destroy limpo
- **Estrutura**: controller → service → repository (camadas separadas)
- **Validação**: Pydantic DTOs
- **Auth**: JWT customizado (ou Cognito se preferido)

### API Gateway

Padrão atual:
- **Tipo**: HTTP API v2 (`aws_apigatewayv2_api`)
- **Integração**: `AWS_PROXY` com Lambda
- **Route**: `$default` (catch-all, routing feito no Lambda)
- **CORS**: Configurado na API Gateway
- **Stage**: auto_deploy = true
- **Logs**: CloudWatch com formato JSON estruturado

### S3 (Template)

```hcl
resource "aws_s3_bucket" "exemplo" {
  bucket        = "${var.project_name}-{descritivo}-${var.environment}"
  force_destroy = true  # IMPORTANTE: permite destroy limpo

  tags = {
    Name = "${var.project_name}-{descritivo}-${var.environment}"
  }
}

resource "aws_s3_bucket_versioning" "exemplo" {
  bucket = aws_s3_bucket.exemplo.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "exemplo" {
  bucket = aws_s3_bucket.exemplo.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "exemplo" {
  bucket                  = aws_s3_bucket.exemplo.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### SQS (Template)

```hcl
resource "aws_sqs_queue" "exemplo" {
  name                       = "${var.project_name}-{descritivo}-${var.environment}"
  message_retention_seconds  = 345600  # 4 dias
  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 10      # Long polling

  tags = {
    Name = "${var.project_name}-{descritivo}-${var.environment}"
  }
}

# Dead Letter Queue (recomendado)
resource "aws_sqs_queue" "exemplo_dlq" {
  name                      = "${var.project_name}-{descritivo}-dlq-${var.environment}"
  message_retention_seconds = 1209600  # 14 dias

  tags = {
    Name = "${var.project_name}-{descritivo}-dlq-${var.environment}"
  }
}

resource "aws_sqs_queue_redrive_policy" "exemplo" {
  queue_url = aws_sqs_queue.exemplo.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.exemplo_dlq.arn
    maxReceiveCount     = 3
  })
}
```

---

## 🔗 Como Conectar Recursos Entre Repositórios

Os repositórios são independentes. A conexão é feita via **outputs → tfvars**:

```
┌─────────────┐    outputs.tf     ┌─────────────┐
│  DynamoDB    │ ──── ARNs ─────► │   Lambda     │
│  repo        │    table names   │   repo       │
└─────────────┘                   └─────────────┘
                                       │
                                  function_arn
                                  function_name
                                       │
                                       ▼
                                  ┌─────────────┐
                                  │ API Gateway  │
                                  │ repo         │
                                  └─────────────┘
                                       │
                                  api_endpoint
                                       │
                                       ▼
                                  ┌─────────────┐
                                  │  Frontend    │
                                  │  (.env)      │
                                  └─────────────┘
```

### Fluxo:

1. `terraform apply` no DynamoDB → copiar ARNs/nomes do output
2. Colar nos `terraform.tfvars` do Lambda
3. `terraform apply` no Lambda → copiar ARN/nome da função do output
4. Colar nos `terraform.tfvars` do API Gateway
5. `terraform apply` no API Gateway → copiar endpoint do output
6. Colar no `.env` do Frontend (`VITE_API_URL=...`)

---

## 🌐 Frontend

### Padrão Atual:

- **Framework**: React + Vite + TypeScript
- **Styling**: Tailwind CSS
- **Deploy**: Vercel
- **Config Vercel**: Root Directory = `controle_financeiro` (subpasta)
- **Variável de ambiente**: `VITE_API_URL` com endpoint do API Gateway

### Estrutura:

```
{nome-projeto}/
├── .github/
│   └── copilot-instructions.md  ← ESTE ARQUIVO
├── .gitignore
├── {subpasta-frontend}/
│   ├── package.json
│   ├── vite.config.ts
│   ├── tsconfig.json
│   ├── vercel.json
│   ├── .env                     ← VITE_API_URL (NÃO versionar)
│   ├── .env.example             ← Template (versionar)
│   └── src/
│       ├── App.tsx
│       ├── main.tsx
│       ├── components/
│       ├── hooks/
│       ├── pages/
│       ├── lib/
│       │   └── api.ts           ← Chamadas HTTP ao API Gateway
│       └── styles/
└── test-build.ps1               ← Script de validação local
```

---

## 📊 Projeto de Referência: Controlese

Este é o projeto atual e serve como **exemplo vivo** da arquitetura:

| Recurso     | Repo / Pasta                             | Status |
|-------------|------------------------------------------|--------|
| DynamoDB    | `controlese-terraform/dynamodb`          | ✅ Ativo |
| Lambda      | `controlese-terraform/lambda`            | ✅ Ativo |
| API Gateway | `controlese-terraform/apigateway`        | ✅ Ativo |
| Frontend    | `controlese/controle_financeiro`         | ✅ Ativo (Vercel) |

### Tabelas DynamoDB:
- `Usuarios-{env}` (hash: `usuario_id`, GSI: `nome_usuario`)
- `Transacoes-{env}` (hash: `transacao_id`, GSI: `usuario_id`)
- `Categorias-{env}` (hash: `categoria_id`, GSI: `usuario_id`)
- `Subcategorias-{env}` (hash: `subcategoria_id`, GSI: `usuario_id`)
- `Cartoes-{env}` (hash: `cartao_id`, GSI: `usuario_id`)

### Lambda:
- Função: `controlese-api-{env}`
- ECR: `controlese-api-{env}`
- Runtime: Python 3.11 (Docker)
- Camadas: controller → service → repository → DynamoDB

### API Gateway:
- HTTP API v2: `controlese-api-{env}`
- Stage: `{env}` (auto-deploy)
- Route: `$default` (catch-all)
- CORS: configurado para Vercel domain

### AWS Account: `695284873308`
### Region: `us-east-1`
### State Bucket: `controlese-terraform-state`

---

## 🧠 Regras para o Agente (Aprendizado Contínuo)

### SEMPRE:

1. **Perguntar quais recursos AWS** antes de criar um novo projeto
2. **Seguir a estrutura de pastas** descrita neste documento
3. **Usar backend S3** com DynamoDB locks
4. **Separar dev e prod** com tfvars independentes
5. **Incluir `force_delete`/`force_destroy`** em recursos que suportam
6. **Criar README.md** com instruções de deploy E destroy
7. **Criar `.tfvars.example`** para dev e prod (sem secrets reais)
8. **Nomear recursos** com padrão: `{projeto}-{descritivo}-{env}`
9. **Tagear tudo** com: Environment, Project, ManagedBy, Repository
10. **Validar variáveis** com `validation {}` blocks no Terraform
11. **Documentar outputs** com descriptions claras
12. **Respeitar ordem de deploy** (dependências entre repos)
13. **Atualizar este arquivo** quando novos padrões forem definidos

### NUNCA:

1. ❌ Criar recursos sem tags
2. ❌ Hardcodar account IDs, ARNs ou secrets no código
3. ❌ Misturar recursos de diferentes serviços AWS no mesmo repo
4. ❌ Versionar `terraform.tfvars` com secrets reais
5. ❌ Esquecer o `force_delete`/`force_destroy` em ECR, S3, etc.
6. ❌ Criar recursos manualmente no console AWS
7. ❌ Fazer deploy de prod sem antes testar em dev
8. ❌ Ignorar a ordem de destroy (pode causar dependências órfãs)

### QUANDO EU PEDIR PARA:

- **"Criar novo projeto"** → Perguntar recursos AWS + nome → seguir checklist acima
- **"Adicionar novo recurso"** → Criar novo repo com estrutura padrão → atualizar workspace
- **"Fazer deploy"** → Confirmar ambiente (dev/prod) → seguir ordem de dependências
- **"Destruir tudo"** → Confirmar ambiente → seguir ordem INVERSA de destroy → verificar que nada ficou
- **"Mudar algo no Lambda/API/DB"** → Editar o repo correto → plan → apply
- **"Conectar recurso novo ao Lambda"** → Criar IAM policy + env vars + tfvars

---

## 📝 Histórico de Decisões

| Data       | Decisão                                                      |
|------------|--------------------------------------------------------------|
| 2025-xx-xx | Estrutura multi-repo por recurso AWS criada (Controlese)     |
| 2025-xx-xx | Backend S3 + DynamoDB locks padronizado                      |
| 2025-xx-xx | Lambda com Docker/ECR como padrão (não ZIP)                  |
| 2025-xx-xx | API Gateway HTTP v2 com catch-all route como padrão          |
| 2025-xx-xx | Frontend React+Vite+TS com deploy Vercel como padrão         |
| 2026-02-12 | Documentação de padrões criada neste copilot-instructions.md |

---

> **Nota para o agente:** Este documento é a sua fonte de verdade. Sempre que criar ou modificar
> infraestrutura, consulte estas instruções. Se algo novo for decidido durante uma conversa,
> proponha adicionar aqui para que o conhecimento persista entre sessões.