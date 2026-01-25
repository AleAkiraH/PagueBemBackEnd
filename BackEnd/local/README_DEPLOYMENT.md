Deployment notes for lambda_function.py

- This handler expects a base64-encoded image (data URI or raw base64) in the POST body.
- Requirements (see `requirements.txt`): Pillow, pyzbar, opencv-python-headless, numpy.

Packaging notes for AWS Lambda:
- pyzbar requires the native ZBar library (libzbar). You must provide it to the runtime via a Lambda Layer or build a custom container image that includes libzbar.
- Alternatively use an AWS Lambda container image that already includes required native libraries.
- `opencv-python-headless` is large; prefer a prebuilt layer or container as well.

Local testing:
- Run `python lambda_function.py qrcode1.jpeg` to run a local test using the included sample images.

Local Docker image (Amazon Linux 2 based)

This repository inclui um Dockerfile em BackEnd/ que constrói uma imagem Amazon Linux 2 com libzbar e dependências Python para testar a Lambda localmente.

Build the image:

- PowerShell:
  - `docker build -t paguebem/qrreader:latest .`
- Linux/macOS:
  - `docker build -t paguebem/qrreader:latest .`

Run the container (it will listen on port 8080):

- `docker run -d --rm -p 8080:8080 --name paguebem-qrreader paguebem/qrreader:latest`

Endpoints:
- POST /decode
  - JSON: `{ "image": "<base64>" }` (Content-Type: application/json)
  - Raw base64 body: POST text/plain with raw base64 and server will treat it as `isBase64Encoded=true`

Examples

- PowerShell example (reads qrcode1.jpeg and posts it):

  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("qrcode1.jpeg"));
  $json = @{image=$b64} | ConvertTo-Json -Compress;
  Invoke-RestMethod -Method POST -ContentType 'application/json' -Body $json http://localhost:8080/decode

- curl example (Linux/macOS):

  b64=$(base64 -w0 qrcode1.jpeg)
  curl -X POST -H "Content-Type: application/json" -d "{\"image\":\"$b64\"}" http://localhost:8080/decode

Using the image as an AWS Lambda container image

The Docker image in this repo can be run as a Lambda-compatible image (it includes native libzbar, OpenCV libs and the Python dependencies) because it installs the AWS Lambda Runtime Interface Client (`awslambdaric`).

Build the Lambda-compatible image:

- `docker build -t paguebem/qrreader:lambda .`

Run the container as a Lambda runtime (maps host port 9000 to container 8080 used by the RIC):

- `docker run -d --name paguebem-lambda -p 9000:8080 paguebem/qrreader:lambda`

Invoke the function locally (RIC endpoint):

- PowerShell (convenience script included): `.\invoke_lambda_local.ps1 qrcode1.jpeg`
- curl example (Linux/macOS):
  - `b64=$(base64 -w0 qrcode1.jpeg)`
  - `curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"image":"'$b64'"}'`

Notes:
- The container defaults to running the RIC and handling invocations via the handler `lambda_function.lambda_handler` (you can change it via CMD/ENTRYPOINT if needed).
- Para rodar o servidor Flask de teste manual, use: `docker run --rm -p 8080:8080 --entrypoint python3 paguebem/qrreader:lambda BackEnd/server.py`.

Notes
- The image installs and registers libzbar so `pyzbar` works inside the container.
- `opencv-python-headless` pode requerer libs de sistema adicionais (incluídas no Dockerfile em BackEnd/). Se houver erro de importação do cv2, verifique os logs do container e adicione os pacotes necessários.
- The Docker image is Amazon Linux 2 based to be similar to the AWS Lambda environment. For an actual Lambda deployment prefer using a Lambda Layer (for libzbar/OpenCV) or an AWS Lambda container image with preinstalled native libs.
