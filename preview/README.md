
# Generate all the keys and certificates

## Bootstrap cardano node as STAND-ALONE mode

`node/pool-keys` must be empty

```
docker compose up -d
```
cardano node must be sync at 100%


```
docker exec -it cardano-node-preview-bp bash
```

```
NODE_HOME=/node
POOL_KEYS=${NODE_HOME}/pool-keys
DATA=${POOL_KEYS}/data
CONFIGURATION=${NODE_HOME}/configuration
```

```
cardano-cli node key-gen-KES \
    --verification-key-file ${POOL_KEYS}/kes.vkey \
    --signing-key-file ${POOL_KEYS}/kes.skey
```

```
cardano-cli node key-gen-VRF \
    --verification-key-file ${POOL_KEYS}/vrf.vkey \
    --signing-key-file ${POOL_KEYS}/vrf.skey
```

```
cardano-cli node key-gen \
    --cold-verification-key-file ${POOL_KEYS}/node.vkey \
    --cold-signing-key-file ${POOL_KEYS}/node.skey \
    --operational-certificate-issue-counter ${POOL_KEYS}/node.counter
```
```
slotsPerKESPeriod=$(cat ${CONFIGURATION}/shelley-genesis.json | jq -r '.slotsPerKESPeriod')
echo slotsPerKESPeriod: ${slotsPerKESPeriod}
```

```
slotNo=$(cardano-cli query tip --testnet-magic 2 | jq -r '.slot')
```

```
kesPeriod=$((${slotNo} / ${slotsPerKESPeriod}))
echo kesPeriod: ${kesPeriod}
startKesPeriod=${kesPeriod}
echo startKesPeriod: ${startKesPeriod}
```

```
cardano-cli node issue-op-cert \
    --kes-verification-key-file ${POOL_KEYS}/kes.vkey \
    --cold-signing-key-file ${POOL_KEYS}/node.skey \
    --operational-certificate-issue-counter ${POOL_KEYS}/node.counter \
    --kes-period ${startKesPeriod} \
    --out-file ${POOL_KEYS}/node.cert
```

```
cardano-cli address key-gen \
    --verification-key-file ${POOL_KEYS}/payment.vkey \
    --signing-key-file ${POOL_KEYS}/payment.skey
```

```
cardano-cli stake-address key-gen \
    --verification-key-file ${POOL_KEYS}/stake.vkey \
    --signing-key-file ${POOL_KEYS}/stake.skey
```

```
cardano-cli stake-address build  \
    --stake-verification-key-file ${POOL_KEYS}/stake.vkey \
    --out-file ${POOL_KEYS}/stake.addr \
    --testnet-magic 2
```

```
cardano-cli address build \
    --payment-verification-key-file ${POOL_KEYS}/payment.vkey \
    --stake-verification-key-file ${POOL_KEYS}/stake.vkey \
    --out-file ${POOL_KEYS}/payment.addr \
    --testnet-magic 2
```

```
cardano-cli stake-address registration-certificate \
    --stake-verification-key-file ${POOL_KEYS}/stake.vkey \
    --out-file ${POOL_KEYS}/stake.cert
```