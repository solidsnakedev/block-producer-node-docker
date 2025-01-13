#!/usr/bin/env bash

slotNo=$(docker exec cardano-node-bp-mainnet \
  cardano-cli query tip \
  --mainnet | jq -r '.slot')

echo "Current slot: $slotNo"

slotsPerKESPeriod=$(cat $(pwd)/node/configuration/shelley-genesis.json | jq -r '.slotsPerKESPeriod')

echo "Slots per KES period: $slotsPerKESPeriod"

kesPeriod=$((${slotNo} / ${slotsPerKESPeriod}))
startKesPeriod=${kesPeriod}
echo startKesPeriod: ${startKesPeriod}

docker exec cardano-node-bp-mainnet \
  cardano-cli node key-gen-KES \
  --verification-key-file /node/pool-keys/kes.vkey \
  --signing-key-file /node/pool-keys/kes.skey

docker exec cardano-node-bp-mainnet \
  cardano-cli node issue-op-cert \
  --kes-verification-key-file /node/pool-keys/kes.vkey \
  --cold-signing-key-file /node/pool-keys/cold.skey \
  --operational-certificate-issue-counter /node/pool-keys/cold.counter \
  --kes-period ${startKesPeriod} \
  --out-file /node/pool-keys/node.cert
