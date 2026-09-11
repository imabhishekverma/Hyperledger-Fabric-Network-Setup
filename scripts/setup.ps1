[CmdletBinding()]
param([switch]$SkipBuild)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
  Write-Host "> $Command $($Arguments -join ' ')" -ForegroundColor Cyan
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $Command $($Arguments -join ' ')" }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Docker is required. Install Docker Desktop and ensure 'docker' is on PATH." }
Invoke-Checked docker @("compose", "version")

# Make reruns safe on Windows by releasing mounted crypto files before cleanup.
docker rm -f asset-transfer-server 2>$null | Out-Null
Invoke-Checked docker @("compose", "down", "--volumes", "--remove-orphans")

New-Item -ItemType Directory -Force -Path "organizations", "channel-artifacts", "evidence" | Out-Null
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "organizations", "channel-artifacts"
New-Item -ItemType Directory -Force -Path "organizations", "channel-artifacts" | Out-Null

$tools = "hyperledger/fabric-tools:2.5.9"
$mount = "${PWD}:/workspace"
Invoke-Checked docker @("run", "--rm", "-v", $mount, "-w", "/workspace", $tools, "cryptogen", "generate", "--config=/workspace/config/crypto-config.yaml", "--output=/workspace/organizations")
Invoke-Checked docker @("run", "--rm", "-v", $mount, "-e", "FABRIC_CFG_PATH=/workspace/config", "-w", "/workspace/config", $tools, "configtxgen", "-profile", "OrdererGenesis", "-channelID", "system-channel", "-outputBlock", "/workspace/channel-artifacts/genesis.block")
Invoke-Checked docker @("run", "--rm", "-v", $mount, "-e", "FABRIC_CFG_PATH=/workspace/config", "-w", "/workspace/config", $tools, "configtxgen", "-profile", "ApplicationChannel", "-outputCreateChannelTx", "/workspace/channel-artifacts/mychannel.tx", "-channelID", "mychannel")

Invoke-Checked docker @("compose", "up", "-d", "orderer.example.com", "couchdb0", "couchdb1", "peer0.org1.example.com", "peer1.org1.example.com", "cli")
Start-Sleep -Seconds 8

if (-not $SkipBuild) {
  Invoke-Checked docker @("compose", "exec", "cli", "bash", "-lc", "peer channel create -o orderer.example.com:7050 -c mychannel -f /workspace/channel-artifacts/mychannel.tx --outputBlock /workspace/channel-artifacts/mychannel.block --tls --cafile `$ORDERER_CA")
  Invoke-Checked docker @("compose", "exec", "cli", "bash", "-lc", "peer channel join -b /workspace/channel-artifacts/mychannel.block")
  Invoke-Checked docker @("compose", "exec", "cli", "bash", "-lc", "CORE_PEER_ADDRESS=peer1.org1.example.com:8051 CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt peer channel join -b /workspace/channel-artifacts/mychannel.block")
  Invoke-Checked docker @("compose", "exec", "cli", "bash", "-lc", "rm -rf /tmp/ccpkg; mkdir -p /tmp/ccpkg/code; cp /workspace/chaincode/asset-transfer/connection.json /tmp/ccpkg/code/; cp /workspace/chaincode/asset-transfer/metadata.json /tmp/ccpkg/metadata.json; tar czf /tmp/ccpkg/code.tar.gz -C /tmp/ccpkg/code connection.json; tar czf /workspace/chaincode/asset-transfer.tar.gz -C /tmp/ccpkg metadata.json code.tar.gz")
  Invoke-Checked docker @("compose", "build", "asset-transfer")
  $packageId = (& docker compose exec -T cli peer lifecycle chaincode calculatepackageid /workspace/chaincode/asset-transfer.tar.gz | Select-Object -Last 1).Trim()
  if ([string]::IsNullOrWhiteSpace($packageId)) { throw "Could not calculate chaincode package ID" }
  Write-Host "Package ID: $packageId" -ForegroundColor Green
  Invoke-Checked docker @("compose", "run", "-d", "--no-deps", "--name", "asset-transfer-server", "-e", "CHAINCODE_ID=$packageId", "asset-transfer")
  Invoke-Checked docker @("network", "disconnect", "fabric_devops", "asset-transfer-server")
  Invoke-Checked docker @("network", "connect", "--alias", "asset-transfer", "fabric_devops", "asset-transfer-server")
  Invoke-Checked docker @("compose", "exec", "cli", "bash", "-lc", "peer lifecycle chaincode install /workspace/chaincode/asset-transfer.tar.gz")
  Invoke-Checked docker @("compose", "exec", "cli", "bash", "-lc", "CORE_PEER_ADDRESS=peer1.org1.example.com:8051 CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt peer lifecycle chaincode install /workspace/chaincode/asset-transfer.tar.gz")
}

Write-Host "Network started. Run .\scripts\test.ps1 to complete lifecycle and capture evidence." -ForegroundColor Green
