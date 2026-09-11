# Hyperledger Fabric DevOps Assessment

This repository implements the supplied assessment with one organization, two peers, one Raft orderer, CouchDB, TLS, CLI operations, and Go asset-transfer chaincode.

## Prerequisites

- Docker Desktop with Linux containers enabled
- Docker Compose v2 (`docker compose version`)
- PowerShell 5+ or PowerShell 7+
- At least 8 GB RAM available to Docker

The scripts use pinned Fabric 2.5.9 images and generate cryptographic material locally. Do not commit `organizations/`, `channel-artifacts/`, or private keys.

## Run

```powershell
.\scripts\setup.ps1
.\scripts\test.ps1 -PackageId "asset-transfer_1.0:<hash>"
.\scripts\cleanup.ps1
```

`setup.ps1` generates crypto material, the orderer genesis block, the channel transaction, starts the services, creates `mychannel`, joins both peers, packages the chaincode, and installs it on peer0. Capture the package ID printed by `peer lifecycle chaincode queryinstalled`, then pass it to `test.ps1`.

```powershell
docker compose exec cli bash -lc 'peer lifecycle chaincode queryinstalled'
# Replace <hash> with the package hash returned above.
.\scripts\test.ps1 -PackageId "asset-transfer_1.0:<hash>"
```

## Architecture

`peer0` and `peer1` use separate CouchDB services and communicate over the internal `fabric_devops` network. The orderer and both peers mount generated TLS certificates. The CLI runs Fabric lifecycle commands with the Org1 admin identity. The Go chaincode runs as a Fabric chaincode-as-a-service container, avoiding a peer Docker-socket dependency while preserving the standard package/install/approve/commit lifecycle.

## Evidence and report

Execution logs belong in `evidence/`. `REPORT.md` maps each assignment requirement to the implementation and required proof. Because the current development machine did not have Docker installed during scaffolding, runtime evidence must be generated on a Docker-enabled host.

## Security notes

This is an assessment network, not a production deployment. Private keys are generated locally, the CouchDB credentials are demonstration values, and the Docker socket mount grants elevated access to peer containers. Production hardening would require secret management, restricted socket access, external TLS CA governance, non-default credentials, resource limits, backups, and multi-node ordering.
