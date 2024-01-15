#!/bin/bash

cardano-cli query leadership-schedule \
${NETWORK} \
--genesis $CONFIGURATION/shelley-genesis.json \
--stake-pool-id $1 \
--vrf-signing-key-file $POOL_KEYS/vrf.skey \
$2

