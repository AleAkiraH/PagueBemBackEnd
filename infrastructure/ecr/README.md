ECR repository module

Creates an ECR repository where docker images for the Lambda will be pushed.

Usage:
- Deploy this module first (via the `Deploy` workflow with component 'ecr' or locally with terraform).
- After creation, build and push the docker image to the returned repository URL, e.g.:
  - `docker build -t <repository_url>:<tag> .`
  - `docker push <repository_url>:<tag>`
