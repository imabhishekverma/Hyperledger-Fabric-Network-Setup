[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$PackageId
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force -Path evidence | Out-Null

function Run([string]$Command) {
  Write-Host "> $Command" -ForegroundColor Cyan
  Invoke-Expression "$Command 2>&1 | Tee-Object -FilePath evidence/command-output.log -Append"
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $Command" }
}

function RunArgs([string[]]$Arguments) {
  Write-Host "> docker $($Arguments -join ' ')" -ForegroundColor Cyan
  & docker @Arguments 2>&1 | Tee-Object -FilePath evidence/command-output.log -Append
  if ($LASTEXITCODE -ne 0) { throw "Command failed: docker $($Arguments -join ' ')" }
}

Run "docker compose ps"
Run "docker compose exec cli bash -lc 'peer lifecycle chaincode queryinstalled'"
Run "docker compose exec cli bash -lc 'peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset-transfer --version 1.0 --package-id $PackageId --sequence 1 --tls --cafile `$ORDERER_CA'"
Run "docker compose exec cli bash -lc 'peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name asset-transfer --version 1.0 --sequence 1 --tls --cafile `$ORDERER_CA --output json'"
Run "docker compose exec cli bash -lc 'peer lifecycle chaincode commit -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset-transfer --version 1.0 --sequence 1 --tls --cafile `$ORDERER_CA --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /etc/hyperledger/fabric/peer/tls/ca.crt --peerAddresses peer1.org1.example.com:8051 --tlsRootCertFiles /etc/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt'"
Run "docker compose exec cli bash -lc 'peer lifecycle chaincode querycommitted --channelID mychannel --name asset-transfer --tls --cafile `$ORDERER_CA'"
$invokePayload = '{"function":"UpdateAsset","Args":["asset1","green","7","Alice","450"]}'
RunArgs @("compose", "exec", "-T", "cli", "peer", "chaincode", "invoke", "-o", "orderer.example.com:7050", "--ordererTLSHostnameOverride", "orderer.example.com", "--tls", "--cafile", "/etc/hyperledger/fabric/orderer/tls/ca.crt", "-C", "mychannel", "-n", "asset-transfer", "--peerAddresses", "peer0.org1.example.com:7051", "--tlsRootCertFiles", "/etc/hyperledger/fabric/peer/tls/ca.crt", "--peerAddresses", "peer1.org1.example.com:8051", "--tlsRootCertFiles", "/etc/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt", "-c", $invokePayload)
$queryPayload = '{"function":"ReadAsset","Args":["asset1"]}'
RunArgs @("compose", "exec", "-T", "cli", "peer", "chaincode", "query", "-C", "mychannel", "-n", "asset-transfer", "-c", $queryPayload)

Run "docker compose logs --no-color orderer.example.com peer0.org1.example.com peer1.org1.example.com | Tee-Object evidence/fabric.log"
