# check_ecr.ps1
# Recebe: { "repository_name": "nome" }
# Retorna: { "found": true/false }

param()

# Lê JSON da entrada padrão
$inputJson = Get-Content -Raw | ConvertFrom-Json
$repositoryName = $inputJson.repository_name

try {
    $repo = aws ecr describe-repositories --repository-names $repositoryName | ConvertFrom-Json
    if ($repo.repositories.Count -gt 0) {
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
