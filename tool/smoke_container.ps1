param(
  [string]$Image = 'chimera-smoke:local',
  [string]$ContainerName = 'chimera-smoke',
  [int]$HostPort = 18080
)

$ErrorActionPreference = 'Stop'
$healthUri = "http://127.0.0.1:$HostPort/healthz"

docker build --file deploy/web/Dockerfile --tag $Image --build-arg YGG_ENVIRONMENT=local .
if ($LASTEXITCODE -ne 0) {
  throw 'Container build failed.'
}

try {
  docker run --detach --rm --name $ContainerName --publish "127.0.0.1:${HostPort}:8080" $Image
  if ($LASTEXITCODE -ne 0) {
    throw 'Container start failed.'
  }

  $deadline = (Get-Date).AddSeconds(60)
  do {
    try {
      $response = Invoke-WebRequest -UseBasicParsing -Uri $healthUri
      if ($response.StatusCode -eq 200 -and $response.Content -ceq '{"status":"ok"}') {
        Write-Output 'Container smoke: OK'
        exit 0
      }
    } catch {
      Start-Sleep -Seconds 1
    }
  } while ((Get-Date) -lt $deadline)

  throw "Container did not return the exact health contract at $healthUri."
} finally {
  docker rm --force $ContainerName 2>$null | Out-Null
}

