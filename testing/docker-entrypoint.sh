#!/usr/bin/env bash

# Default values
MONIKER="${MONIKER:-testnet-noble-node}"
CHAIN_ID="${CHAIN_ID:-grand-1}"
GENESIS_URL="${GENESIS_URL:-https://raw.githubusercontent.com/strangelove-ventures/noble-networks/main/testnet/grand-1/genesis.json}"
SNAPSHOT_URL="https://snapshots.polkachu.com/testnet-snapshots/noble/noble_21243717.tar.lz4"

# Install lz4 if not already installed
apt-get update && apt-get install -y lz4 wget

# If config doesn't exist, run init steps
if [ ! -f "$HOME/.noble/config/genesis.json" ]; then
    echo "Config not found. Initializing..."
    
    # Initialize the node
    nobled init "$MONIKER" --chain-id grand-1
    
    # Download genesis file
    curl -sSL "$GENESIS_URL" -o "$HOME/.noble/config/genesis.json"
    
    # Set required genesis parameters for tokenfactory
    GENESIS_FILE="$HOME/.noble/config/genesis.json"
    CONFIG_FILE="$HOME/.noble/config/config.toml"
    
    # Update the genesis file with required tokenfactory configuration
    jq '.app_state."fiat-tokenfactory" = {
        "blacklistedList": [],
        "paused": {
            "paused": false
        },
        "masterMinter": {
            "address": "noble1x8rynykqla7cnc0tf2f3xn0wa822ztt70y39vn"
        },
        "mintersList": [],
        "pauser": {
            "address": "noble1g3v4qdc83h6m5wdz3x92vfu0tjtt7e6y48qqrz"
        },
        "blacklister": {
            "address": "noble159leclhhuhhcmedu2n8nfjjedxjyrtkee8l4v2"
        },
        "owner": {
            "address": "noble153eyy4uufmrak2swgrn4fjtyslg256ecdngyve"
        },
        "minterControllerList": [],
        "mintingDenom": {
            "denom": "ulove"
        }
    }' "$GENESIS_FILE" > "$GENESIS_FILE.tmp" && mv "$GENESIS_FILE.tmp" "$GENESIS_FILE"
    
    # Fix IBC channel timeout parameter
    jq '.app_state.ibc.channel_genesis.params.upgrade_timeout = {
        "height": {
            "revision_number": "0",
            "revision_height": "0"
        },
        "timestamp": "9223372036854775808"
    }' "$GENESIS_FILE" > "$GENESIS_FILE.tmp" && mv "$GENESIS_FILE.tmp" "$GENESIS_FILE"

    SEEDS="ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@testnet-seeds.polkachu.com:21556"
    
    sed -i.bak -E "s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"$SEEDS\"|" "$CONFIG_FILE"

    sed -i.bak \
    's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' \
    "$CONFIG_FILE"

    # Set pruning configuration
    APP_CONFIG="$HOME/.noble/config/app.toml"
    sed -i.bak \
        -e 's|^pruning *=.*|pruning = "custom"|' \
        -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
        -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
        -e 's|^pruning-interval *=.*|pruning-interval = "10"|' \
        "$APP_CONFIG"
    
    # Clean up backup files
    rm -f "$CONFIG_FILE.bak" "$APP_CONFIG.bak"

    # Reset the node state
    nobled tendermint unsafe-reset-all --home $HOME/.noble --keep-addr-book

    echo "Downloading and applying snapshot..."
    cd $HOME
    wget -O noble_snapshot.tar.lz4 $SNAPSHOT_URL --inet4-only
    lz4 -c -d noble_snapshot.tar.lz4 | tar -x -C $HOME/.noble
    rm noble_snapshot.tar.lz4
fi

# Execute the main process
exec "$@"
