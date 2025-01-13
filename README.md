# Noble Node with Remote Horcrux Signer Setup

This guide documents the setup of a Noble testnet node with Horcrux remote signing capability using Ansible and Docker.

## Prerequisites

- Two Ubuntu servers:
  - Full Node: 8 vCPUs, 16 GB RAM, 240 GB disk
  - Signer: 2 vCPUs, 2GB RAM, 40 GB disk
- Ansible installed on your local machine
- Docker installed on your local machine

## Repository Structure
```
ansible/
├── playbooks/
│   ├── ansible.cfg
│   ├── hosts.ini
│   ├── requirements.yml
│   ├── run-horcrux.yaml
│   ├── run-noble.yml
│   └── setup-docker.yml
└── roles/
    ├── horcrux/
    └── noble/

Note: validator_key directory and priv_validator_key.json are not included in the repository
for security reasons and should be generated locally.
```

## Setup Steps

### 1. Generate Validator Key
First, create a directory for the validator key (this directory is git-ignored):

```bash
mkdir -p validator_key
```

Then generate the validator key that will be used by Horcrux:
```bash
# Generate and save key
docker run -it --rm \
  -e MONIKER="my-validator" \
  -e CHAIN_ID="grand-1" \
  -e RUN_NODE="FALSE" \
  kaytheog/noble:latest > validator_key/priv_validator_key.json
```

⚠️ **Important Security Note**: 
- The validator_key directory is git-ignored to prevent accidental commit of sensitive keys
- Keep your validator key secure and never commit it to version control
- Make sure to backup your key safely

### 2. Install Docker
Run the Docker installation playbook:
```bash
ansible-playbook hosts.ini playbooks/setup-docker.yml
```

### 3. Setup Horcrux Signer
Deploy Horcrux on the signer node:
```bash
ansible-playbook  playbooks/run-horcrux.yaml
```

Key configurations:
- Uses single-signer mode for testnet
- Connects to Noble node at port 1234
- Stores validator key as `grand-1_priv_validator_key.json`

### 4. Setup Noble Node
Deploy the Noble node:
```bash
ansible-playbook hosts.ini playbooks/run-noble.yml
```

Key configurations:
- Uses remote signing configuration
- Listens on port 1234 for Horcrux connections
- Syncs with Noble testnet

## Verification

Check node status:
```bash
curl http://[noble-ip]:26657/status | jq
```

Expected output shows:
- Node syncing with network "grand-1"
- Validator key matching Horcrux configuration
- Node catching up with the chain

## Critical Configurations

1. Noble Node (`config.toml`):
```toml
# Remote signing configuration
priv_validator_laddr = "tcp://0.0.0.0:1234"
```

2. Horcrux Configuration (`config.yaml`):
```yaml
signMode: single
chainNodes:
- privValAddr: tcp://[noble-ip]:1234
debugAddr: ""
```

## Security Considerations

1. Firewall Rules
- Port 1234 only accessible between Noble and Horcrux
- RPC ports (26656/26657) as needed for node operation

2. Key Management
- Validator key stored only on Horcrux signer
- No private keys on Noble node
- Regular backup of key materials

## Network Requirements

- Noble Node:
  - Inbound: 26656, 26657 (peers/RPC)
  - Inbound: 1234 (Horcrux connection)
  
- Horcrux:
  - Outbound: 1234 (to Noble node)

## Monitoring the Node

While a monitoring stack is not deployed, the following steps outline how monitoring can be approached to ensure the node’s health and alert engineers of any issues:

### Key Metrics to Monitor

- Node Health

    - Block Height: Ensure the node's block height is in sync with the latest chain height.
    - Peer Count: Monitor the number of connected peers to verify proper network connectivity.
    - CPU/Memory Usage: Track resource utilization to identify bottlenecks or under-provisioned hardware.
    - Disk Space: Ensure sufficient disk space is available for node operation.

- Horcrux Signer

    - Signing Operations: Monitor successful/failed signing attempts and signing latency.
    - Network Connectivity: Verify that the Horcrux node maintains a stable connection to the full node.

- System Health

    - Track system logs for anomalies.
    - Monitor uptime and ensure no unplanned reboots.

- Alerting Recommendations
    - Configure alerts for:
        - Block height discrepancies.
        - Peer count dropping below a threshold (e.g., fewer than 5 peers).
        - Signing failures or latency exceeding a predefined threshold.
        - Disk usage exceeding 80%.
        - Use tools like Prometheus (for metrics collection) with 
        - Alertmanager to send alerts via email, Slack, or PagerDuty.

## Steps to Create a Validator from this point


### 1. Verify Node Synchronization

Ensure the node is fully synchronized with the network. You can check the synchronization status by querying a specific block height:

```bash
curl http://<ip>:26657/block?height=<block-height>
```

Replace `<block-height>` with a recent block number. A valid response indicates successful synchronization.

### 2. Create a Wallet

Generate a new key for your wallet:

```bash
nobled keys add <key_name> --keyring-backend file --algo eth_secp256k1
```

Replace `<key_name>` with the desired key name. Retrieve your wallet address:

```bash
MY_ADDRESS=$(nobled keys show <key_name> -a --keyring-backend file)
echo $MY_ADDRESS
```

### 3. Fund Your Wallet

we need to ensure the wallet has sufficient funds to cover the staking amount and transaction fees. we can get testnet token from [circle](https://faucet.circle.com/)

### 4. Create the Validator

Generate the validator public key:

```bash
nobled tendermint show-validator
```

Create a JSON file (e.g., `validator.json`) with the following content:

```json
{
    "pubkey": {
        "@type": "/cosmos.crypto.ed25519.PubKey",
        "key": "<your-validator-pubkey>"
    },
    "amount": "1000000utoken",
    "moniker": "my-validator",
    "identity": "",
    "website": "https://example.com",
    "security": "security@example.com",
    "details": "A highly reliable validator.",
    "commission-rate": "0.10",
    "commission-max-rate": "0.20",
    "commission-max-change-rate": "0.01",
    "min-self-delegation": "1"
}
```

Replace `<the-validator-pubkey>` with the output from the previous command and adjust other fields as needed.

Submit the create-validator transaction:

```bash
nobled tx staking create-validator validator.json --from=<key_name> --chain-id=noble-1 --fees=1000utoken --gas=auto --keyring-backend file
```

Replace `<key_name>` with the key's name.

### 5. Verify Your Validator

Check if the validator has been successfully added to the validator set:

```bash
nobled query tendermint-validator-set
```
---

## High Availability Considerations

### 1. Noble Node High Availability
- **Multiple Sentry Nodes**:
  - Deploy multiple sentry nodes in different regions/availability zones
  - Sentry nodes protect validator from DDoS attacks
  - Each sentry node maintains its own peer connections

- **State Snapshots**:
  - Regular automated snapshots of blockchain state
  - Quick recovery in case of node failure
  - Backup snapshots to secure storage (e.g., S3)
  - Example: Daily snapshots with 7-day retention

### 2. Horcrux High Availability
- **Threshold Signing Setup**:
  - Deploy multiple Horcrux signers (e.g., 3-of-4 setup)
  - Distribute signers across different regions
  - Each signer holds a key share
  - Continues operating if minority of signers fail

- **Geographical Distribution**:
  - Place signers in different data centers
  - Independent network paths
  - Different cloud providers for better resilience

