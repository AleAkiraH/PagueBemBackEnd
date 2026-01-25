provider "aws" {
  region = var.region
}

data "external" "ecr" {
  program = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", "& '../scripts/check_ecr.ps1' '${var.ecr_name}' '${var.region}'"]
}

resource "null_resource" "import_ecr" {
  triggers = {
    found = data.external.ecr.result["found"]
  }

  provisioner "local-exec" {
  command = "PowerShell -NoProfile -ExecutionPolicy Bypass -Command \"& '../scripts/import_ecr_if_needed.ps1' '${var.ecr_name}'\""
  }
}

data "external" "iam_role" {
  program = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", "& '../scripts/check_iam_role.ps1' '${var.lambda_role_name}'"]
}

resource "null_resource" "import_iam_role" {
  triggers = {
    found = data.external.iam_role.result["found"]
  }

  provisioner "local-exec" {
  command = "PowerShell -NoProfile -ExecutionPolicy Bypass -Command \"& '../scripts/import_iam_if_needed.ps1' '${var.lambda_role_name}'\""
  }
}

data "external" "lambda_fn" {
  program = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", "& '../scripts/check_lambda.ps1' '${var.lambda_name}' '${var.region}'"]
}

resource "null_resource" "import_lambda" {
  triggers = {
    found = data.external.lambda_fn.result["found"]
  }

  provisioner "local-exec" {
  command = "PowerShell -NoProfile -ExecutionPolicy Bypass -Command \"& '../scripts/import_lambda_if_needed.ps1' '${var.lambda_name}' '${var.region}'\""
  }
}

module "ecr" {
  source       = "./ecr"
  name         = var.ecr_name
  force_delete = var.ecr_force_delete

  depends_on = [null_resource.import_ecr]
}

resource "null_resource" "docker_build_and_push" {
  # Trigger a rebuild when Dockerfile, lambda code, requirements or tag changes
  triggers = {
  dockerfile_md5   = filemd5("${path.root}/../Dockerfile")
  lambda_md5       = filemd5("${path.root}/../lambda_function.py")
  requirements_md5 = filemd5("${path.root}/../requirements.txt")
    tag              = var.image_tag
    local_name       = var.local_image_name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<EOT
$ErrorActionPreference = 'Stop'
$registry = "${module.ecr.repository_url}" -split '/' | Select-Object -First 1
aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin $registry
# build from repo root
docker build -t ${var.local_image_name}:${var.image_tag} "${path.root}"
docker tag ${var.local_image_name}:${var.image_tag} "${module.ecr.repository_url}:${var.image_tag}"
docker push "${module.ecr.repository_url}:${var.image_tag}"
EOT
  }

  depends_on = [module.ecr, null_resource.import_ecr]
}

module "lambda" {
  source        = "./lambda"
  function_name = var.lambda_name
  role_name     = var.lambda_role_name
  image_uri     = "${module.ecr.repository_url}:${var.image_tag}"
  region        = var.region
  environment   = var.lambda_environment
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  depends_on = [null_resource.import_iam_role, null_resource.import_lambda, null_resource.docker_build_and_push]
}

module "apigateway" {
  source      = "./apigateway"
  name        = var.api_name
  region      = var.region
  lambda_arn  = module.lambda.function_arn
  lambda_name = module.lambda.function_name

  depends_on = [module.lambda, null_resource.import_lambda]
}


