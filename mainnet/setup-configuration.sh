#!/usr/bin/env bash

set -e

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}$(date +'%Y-%m-%d %H:%M:%S') - $1${NC}"
}

error_exit() {
    echo -e "${RED}$(date +'%Y-%m-%d %H:%M:%S') - ERROR: $1${NC}" >&2
    exit 1
}

log "Removing existing node/configuration directory"
rm -rf $(pwd)/node/configuration || error_exit "Failed to remove existing node/configuration directory"

log "Creating node/configuration directory"
mkdir -p $(pwd)/node/configuration || error_exit "Failed to create node/configuration directory"

log "Downloading latest config files"
wget -q -P $(pwd)/node/configuration \
    https://book.world.dev.cardano.org/environments/mainnet/byron-genesis.json \
    https://book.world.dev.cardano.org/environments/mainnet/shelley-genesis.json \
    https://book.world.dev.cardano.org/environments/mainnet/alonzo-genesis.json \
    https://book.world.dev.cardano.org/environments/mainnet/conway-genesis.json \
    https://book.world.dev.cardano.org/environments/mainnet/config-bp.json || error_exit "Failed to download config files"

log "Renaming config-bp.json to config.json"
mv $(pwd)/node/configuration/config-bp.json $(pwd)/node/configuration/config.json || error_exit "Failed to rename config-bp.json to config.json"

sed -i 's/\"TraceBlockFetchDecisions\": false/\"TraceBlockFetchDecisions\": true/' $(pwd)/node/configuration/config.json &&
    sed -i 's/\"127.0.0.1\"/\"0.0.0.0\"/' $(pwd)/node/configuration/config.json || error_exit "Failed to modify config.json"

log "Enabling TraceMempool in config.json"
jq '.TraceMempool=true' $(pwd)/node/configuration/config.json > $(pwd)/node/configuration/config.json.tmp && 
    mv $(pwd)/node/configuration/config.json.tmp $(pwd)/node/configuration/config.json || error_exit "Failed to enable TraceMempool in config.json"

log "Setting topology"

RELAY1_IP=$1
RELAY1_PORT=$2
RELAY2_IP=$3
RELAY2_PORT=$4

if [ -n "${RELAY1_IP}" ] && [ -n "${RELAY1_PORT}" ] && [ -n "${RELAY2_IP}" ] && [ -n "${RELAY2_PORT}" ]; then
    jq -n --arg relay1_ip "$RELAY1_IP" --arg relay1_port "$RELAY1_PORT" --arg relay2_ip "$RELAY2_IP" --arg relay2_port "$RELAY2_PORT" '{
        "bootstrapPeers": [],
        "localRoots": [
            {
                "accessPoints": [
                    {"address": $relay1_ip, "port": ($relay1_port | tonumber)},
                    {"address": $relay2_ip, "port": ($relay2_port | tonumber)}
                ],
                "advertise": false,
                "trustable": true,
                "valency": 2
            }
        ],
        "publicRoots": [{"accessPoints": [], "advertise": false}],
        "useLedgerAfterSlot": -1
    }' >$(pwd)/node/configuration/topology.json || error_exit "Failed to set topology with two relays"
elif [ -n "${RELAY1_IP}" ] && [ -n "${RELAY1_PORT}" ]; then
    jq -n --arg relay1_ip "$RELAY1_IP" --arg relay1_port "$RELAY1_PORT" '{
        "bootstrapPeers": [],
        "localRoots": [
            {
                "accessPoints": [{"address": $relay1_ip, "port": ($relay1_port | tonumber)}],
                "advertise": false,
                "trustable": true,
                "valency": 1
            }
        ],
        "publicRoots": [{"accessPoints": [], "advertise": false}],
        "useLedgerAfterSlot": -1
    }' >$(pwd)/node/configuration/topology.json || error_exit "Failed to set topology with one relay"
else
    jq -n '{
        "bootstrapPeers": [],
        "localRoots": [
            {"accessPoints": [], "advertise": false, "valency": 1}
        ],
        "publicRoots": [
            {"accessPoints": [
                {"address": "backbone.cardano-mainnet.iohk.io", "port": 3001},
                {"address": "backbone.cardano.iog.io", "port": 3001},
                {"address": "backbone.mainnet.emurgornd.com", "port": 3001}
            ], "advertise": false}
        ],
        "useLedgerAfterSlot": 110332824
    }' >$(pwd)/node/configuration/topology.json || error_exit "Failed to set default topology"
fi

log "Setup completed successfully"
