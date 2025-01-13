#!/usr/bin/env bash

docker exec cardano-node-bp-mainnet \
  cardano-cli query kes-period-info --mainnet  --op-cert-file /node/pool-keys/node.cert