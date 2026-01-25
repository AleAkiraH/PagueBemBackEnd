# check_lambda.ps1
# Recebe: { "function_name": "nome" }
# Retorna: { "found": true/false }

param()

$inputJson = Get-Content -Raw | ConvertFrom-Json
$functionName = $inputJson.function_name

try {
    $lambda = aws lambda get-function --function-name $functionName | ConvertFrom-Json
    if ($lambda.Configuration) {
        Write-Output ('{"found": "true"}')
        exit 0
    } else {
        Write-Output ('{"found": "false"}')
        exit 0
    }
} catch {
    Write-Output ('{"found": false, "error": "' + $_.Exception.Message.Replace('"','\"') + '"}')
    exit 0
}
