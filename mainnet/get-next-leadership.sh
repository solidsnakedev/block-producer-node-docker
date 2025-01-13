#!/usr/bin/env bash

docker exec cardano-node-bp-mainnet \
  cardano-cli query leadership-schedule \
  --mainnet \
  --genesis /node/configuration/shelley-genesis.json \
  --stake-pool-id pool19ut4284xy9p82dd0cglzxweddfqw73yennkjk6mmp650chnr6lz \
  --vrf-signing-key-file /node/pool-keys/vrf.skey \
  --next
