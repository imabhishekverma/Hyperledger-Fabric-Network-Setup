# Hyperledger Fabric DevOps Assessment Report

## Executive summary

The repository defines a Docker Compose Hyperledger Fabric 2.5.9 network containing one organization (`Org1`), two peers, one Raft orderer, two CouchDB state databases, TLS configuration, CLI automation, and Go asset-transfer chaincode.

## Requirement mapping

| Assignment requirement | Implementation | Evidence to capture |
|---|---|---|
| Fabric v2.x+ | Fabric 2.5.9 images and lifecycle commands | `docker compose images`, lifecycle output |
| One organization | `Org1MSP` in `crypto-config.yaml` and `configtx.yaml` | generated MSP tree, config files |
| Two peers | `peer0.org1.example.com`, `peer1.org1.example.com` | `docker compose ps`, peer logs |
| One orderer | Single etcdraft consentor | orderer logs, genesis block |
| CouchDB | One CouchDB per peer | `docker compose ps`, CouchDB health responses |
| TLS | Peer, orderer, and CLI TLS environment/configuration | successful TLS CLI commands |
| Genesis/channel artifacts | `cryptogen` and `configtxgen` in `setup.ps1` | `channel-artifacts/` |
| Network deployment | `docker-compose.yaml` | `docker compose ps` |
| Channel creation/join | `setup.ps1` creates and joins `mychannel` | join output and `peer channel getinfo` |
| Chaincode lifecycle | CCAAS Go package, install on both peers, approve, and commit | lifecycle command output |
| Transaction testing | `InitLedger` invoke and `ReadAsset` query | invoke/query output |
| Logging | `test.ps1` captures service logs | `evidence/fabric.log` |
| Cleanup | `cleanup.ps1` removes containers, volumes, artifacts | cleanup output |

## Operational procedure

1. Install Docker Desktop and verify `docker compose version`.
2. Run `scripts/setup.ps1`.
3. Record the package ID returned by `peer lifecycle chaincode queryinstalled`.
4. Approve and commit the chaincode using the commands in `README.md`.
5. Invoke `InitLedger`, query `asset1`, and save output under `evidence/`.
6. Capture `docker compose ps` and relevant logs.
7. Run `scripts/cleanup.ps1` after evidence is collected.

## Design decisions

- `cryptogen` keeps this assessment deterministic and avoids adding CA enrollment services.
- A single-node Raft orderer meets the assignment scope but is not fault tolerant.
- CCAAS keeps the Go chaincode lifecycle reproducible with modern Docker Desktop without mounting the Docker socket into peer containers.

## Verified execution

Runtime verification completed on Docker Desktop with the pinned images. Evidence shows all seven runtime containers running, both peers at channel height 4, chaincode installed on both peers, and the definition committed at version 1.0/sequence 1. The final invoke returned status 200 and the query returned:

```json
{"ID":"asset1","color":"green","size":7,"owner":"Alice","appraisedValue":450}
```

Evidence files are stored under `evidence/`, including `containers-all.txt`, `peer0-channel.txt`, `peer1-channel.txt`, `chaincode-installed.txt`, `chaincode-committed.txt`, `transaction-invoke.txt`, `transaction-query.txt`, and `fabric.log`.
- CouchDB is configured independently for both peers so state database failures are isolated.
- Channel and application capabilities are set to `V2_0` for the Fabric v2 lifecycle.
- TLS is enabled for orderer, peer, and CLI commands.

## Limitations and production improvements

The current implementation is intentionally assessment-sized. Production use would require multiple orderers, multiple organizations, managed identities, non-default credentials, secret rotation, network policies, resource limits, persistent backups, monitoring, CI/CD, and removal or isolation of the Docker socket mount.

## Submission checklist

- [ ] Source repository pushed to GitHub/GitLab.
- [ ] `README.md` reviewed on a clean Docker host.
- [ ] `docker compose ps` evidence captured.
- [ ] Channel join evidence captured for both peers.
- [ ] Chaincode package/install/approval/commit evidence captured.
- [ ] Successful invoke and query evidence captured.
- [ ] Fabric logs reviewed for errors.
- [ ] Generated credentials excluded from version control.
- [ ] Cleanup completed after evidence capture.
