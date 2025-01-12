# Noble-Horcrux
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
ansible-playbook -i hosts.ini playbooks/setup-docker.yml
```

### 3. Setup Horcrux Signer
Deploy Horcrux on the signer node:
```bash
ansible-playbook -i hosts.ini playbooks/run-horcrux.yaml
```

Key configurations:
- Uses single-signer mode for testnet
- Connects to Noble node at port 1234
- Stores validator key as `grand-1_priv_validator_key.json`

### 4. Setup Noble Node
Deploy the Noble node:
```bash
ansible-playbook -i hosts.ini playbooks/run-noble.yml
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
priv_validator_key_file = ""
priv_validator_state_file = ""
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

## Monitoring Recommendations

1. Node Health Metrics:
- Block height and sync status
- Peer count and network connectivity
- System resources (CPU, memory, disk)

2. Signing Operations:
- Successful/failed signing attempts
- Horcrux-Noble connection status
- Signing latency

## High Availability Considerations

1. Noble Node:
- Deploy multiple sentries
- Use load balancer for RPC endpoints
- Regular state snapshots

2. Horcrux:
- Multiple signing nodes (threshold setup)
- Geographical distribution
- Redundant network paths

## Future Improvements

1. Security Enhancements:
- Implement key rotation procedures
- HSM integration for key storage
- Network segregation and VPC setup

2. Operational Improvements:
- Automated backup procedures
- Enhanced monitoring stack
- Disaster recovery procedures