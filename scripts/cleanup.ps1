$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
docker rm -f asset-transfer-server 2>$null | Out-Null
docker compose down --volumes --remove-orphans
if ($LASTEXITCODE -ne 0) { throw "docker compose cleanup failed" }
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "organizations", "channel-artifacts"
Write-Host "Fabric containers, volumes, and generated artifacts removed. Source files were preserved." -ForegroundColor Green
