# PowerShell script to build and run the Docker image locally
# Usage: .\build_and_run_docker.ps1

$imageName = "paguebem/qrreader:latest"

Write-Host "Building image $imageName..."
docker build -t $imageName .

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed"
    exit $LASTEXITCODE
}

Write-Host "Running container (port 8080 mapped)"
Write-Host "Press Ctrl+C to stop"

docker run --rm -p 8080:8080 --name paguebem-qrreader $imageName
