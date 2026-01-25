# check_iam_role.ps1
# Recebe: { "role_name": "nome" }
# Retorna: { "found": true/false }

param()

$inputJson = Get-Content -Raw | ConvertFrom-Json
$roleName = $inputJson.role_name

try {
    $role = aws iam get-role --role-name $roleName | ConvertFrom-Json
    if ($role.Role) {
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
