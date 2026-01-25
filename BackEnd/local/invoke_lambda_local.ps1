# Invoke the Lambda-compatible container running RIC locally
# Usage: .\invoke_lambda_local.ps1 <image-path-or-file>
# Examples:
# .\invoke_lambda_local.ps1 qrcode1.jpeg


param(
    [string]$sample = "qrcode1.jpeg"
)

# Ajuste para rodar sempre a partir de BackEnd/local
if (-not (Test-Path $sample)) {
    $sample = Join-Path $PSScriptRoot $sample
}

if (-not (Test-Path $sample)) {
    Write-Error "Sample file not found: $sample"
    exit 1
}

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($sample))
# Direct event with image key
$eventDirect = @{ image = $b64 } | ConvertTo-Json -Compress
# API Gateway style (body is string)
$eventAPIGateway = @{ body = ($(@{ image = $b64 } | ConvertTo-Json -Compress)) } | ConvertTo-Json -Compress

Write-Host "Calling RIC with direct event..."
Invoke-RestMethod -Method POST -ContentType 'application/json' -Body $eventDirect http://localhost:9000/2015-03-31/functions/function/invocations | ConvertTo-Json -Depth 5

Write-Host "\nCalling RIC with API Gateway style event..."
Invoke-RestMethod -Method POST -ContentType 'application/json' -Body $eventAPIGateway http://localhost:9000/2015-03-31/functions/function/invocations | ConvertTo-Json -Depth 5
