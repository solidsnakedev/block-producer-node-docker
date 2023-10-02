
# Create Stake Pool Keys and Certificates

## Bootstrap cardano node as STAND-ALONE mode

`node/pool-keys` must be empty

```
docker compose up -d
```
cardano node must be sync at 100%


```
docker exec -it cardano-node-preview-bp bash
```

### Set environment variables
```
NODE_HOME=/node
POOL_KEYS=${NODE_HOME}/pool-keys
DATA=${NODE_HOME}/data
CONFIGURATION=${NODE_HOME}/configuration
```

### Generate -> `kes keys`

```
cardano-cli node key-gen-KES \
    --verification-key-file ${POOL_KEYS}/kes.vkey \
    --signing-key-file ${POOL_KEYS}/kes.skey
```

### Generate -> `vrf keys`
```
cardano-cli node key-gen-VRF \
    --verification-key-file ${POOL_KEYS}/vrf.vkey \
    --signing-key-file ${POOL_KEYS}/vrf.skey
```

### Generate -> `node keys`
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
### Generate -> `node certificate` 
```
cardano-cli node issue-op-cert \
    --kes-verification-key-file ${POOL_KEYS}/kes.vkey \
    --cold-signing-key-file ${POOL_KEYS}/node.skey \
    --operational-certificate-issue-counter ${POOL_KEYS}/node.counter \
    --kes-period ${startKesPeriod} \
    --out-file ${POOL_KEYS}/node.cert
```
### Generate -> `payment keys`
```
cardano-cli address key-gen \
    --verification-key-file ${POOL_KEYS}/payment.vkey \
    --signing-key-file ${POOL_KEYS}/payment.skey
```

### Generate -> `stake keys`
```
cardano-cli stake-address key-gen \
    --verification-key-file ${POOL_KEYS}/stake.vkey \
    --signing-key-file ${POOL_KEYS}/stake.skey
```

### Generate -> `stake address`
```
cardano-cli stake-address build  \
    --stake-verification-key-file ${POOL_KEYS}/stake.vkey \
    --out-file ${POOL_KEYS}/stake.addr \
    --testnet-magic 2
```

### Generate -> `payment address`
```
cardano-cli address build \
    --payment-verification-key-file ${POOL_KEYS}/payment.vkey \
    --stake-verification-key-file ${POOL_KEYS}/stake.vkey \
    --out-file ${POOL_KEYS}/payment.addr \
    --testnet-magic 2
```

### Generate -> `stake certificate`
```
cardano-cli stake-address registration-certificate \
    --stake-verification-key-file ${POOL_KEYS}/stake.vkey \
    --out-file ${POOL_KEYS}/stake.cert
```

## Fund wallet
```
cat ${POOL_KEYS}/payment.addr
```

## Check wallet funds
```
cardano-cli query utxo \
    --address $(cat ${POOL_KEYS}/payment.addr) \
    --testnet-magic 2
```

# Run Stake Pool

* Backup all the keys from `node/pool-keys` except for `kes.skey` `vrf.skey` `node.cert`

```
docker compose up -d
```

# Register Stake Address

```
currentSlot=$(cardano-cli query tip --testnet-magic 2 | jq -r '.slot')
echo Current Slot: $currentSlot
```

```
cardano-cli query utxo \
    --address $(cat ${POOL_KEYS}/payment.addr) \
    --testnet-magic 2 > ${DATA}/fullUtxo.out

tail -n +3 ${DATA}/fullUtxo.out | sort -k3 -nr > ${DATA}/balance.out

cat ${DATA}/balance.out

tx_in=""
total_balance=0
while read -r utxo; do
    type=$(awk '{ print $6 }' <<< "${utxo}")
    if [[ ${type} == 'TxOutDatumNone' ]]
    then
        in_addr=$(awk '{ print $1 }' <<< "${utxo}")
        idx=$(awk '{ print $2 }' <<< "${utxo}")
        utxo_balance=$(awk '{ print $3 }' <<< "${utxo}")
        total_balance=$((${total_balance}+${utxo_balance}))
        echo TxHash: ${in_addr}#${idx}
        echo ADA: ${utxo_balance}
        tx_in="${tx_in} --tx-in ${in_addr}#${idx}"
    fi
done < ${DATA}/balance.out
txcnt=$(cat ${DATA}/balance.out | wc -l)
echo Total available ADA balance: ${total_balance}
echo Number of UTXOs: ${txcnt}
```

```
cardano-cli query protocol-parameters \
  --testnet-magic 2 \
  --out-file ${DATA}/protocol.json
```

```
stakeAddressDeposit=$(cat ${DATA}/protocol.json | jq -r '.stakeAddressDeposit')
echo stakeAddressDeposit : $stakeAddressDeposit
```
```
cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat ${POOL_KEYS}/payment.addr)+0 \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee 0 \
    --out-file ${DATA}/tx.tmp \
    --certificate ${POOL_KEYS}/stake.cert
```

```
fee=$(cardano-cli transaction calculate-min-fee \
    --tx-body-file ${DATA}/tx.tmp \
    --tx-in-count ${txcnt} \
    --tx-out-count 1 \
    --testnet-magic 2 \
    --witness-count 2 \
    --byron-witness-count 0 \
    --protocol-params-file ${DATA}/protocol.json | awk '{ print $1 }')
echo fee: $fee
```

```
fee=$((fee + 100000))
echo fee: $fee
```

```
txOut=$((${total_balance}-${stakeAddressDeposit}-${fee}))
echo Change Output: ${txOut}
```

```
cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat ${POOL_KEYS}/payment.addr)+${txOut} \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee ${fee} \
    --certificate-file ${POOL_KEYS}/stake.cert \
    --out-file ${DATA}/tx.raw
```
***
### Air gapped node

```
cardano-cli transaction sign \
    --tx-body-file ${DATA}/tx.raw \
    --signing-key-file ${POOL_KEYS}/payment.skey \
    --signing-key-file ${POOL_KEYS}/stake.skey \
    --testnet-magic 2 \
    --out-file ${DATA}/tx.signed
```

***
### Block producer node
```
cardano-cli transaction submit \
    --tx-file ${DATA}/tx.signed \
    --testnet-magic 2
```

# Register Stake Pool
### Set environment variables

```
NODE_HOME=/node
POOL_KEYS=${NODE_HOME}/pool-keys
DATA=${NODE_HOME}/data
CONFIGURATION=${NODE_HOME}/configuration
```

### Download `pool metadata`
```
URL_METADATA=https://solidsnakedev.github.io/poolMetadata.json
```

```
wget ${URL_METADATA} -O ${DATA}/pool_Metadata.json
```

### Calculate the hash of your metadata file
```
cardano-cli stake-pool metadata-hash --pool-metadata-file ${DATA}/pool_Metadata.json > ${DATA}/pool_MetadataHash.txt
```

***

### Air-gapped node
### Set environment variables
```
PLEDGE=<enter-lovelace-pledge>
COST=340000000
MARGIN=0.019
RELAY=<enter-ip-address>
PORT=6002
```
### Create pool registration
```
cardano-cli stake-pool registration-certificate \
--cold-verification-key-file ${POOL_KEYS}/node.vkey \
--vrf-verification-key-file ${POOL_KEYS}/vrf.vkey \
--pool-pledge ${PLEDGE} \
--pool-cost ${COST} \
--pool-margin ${MARGIN} \
--pool-reward-account-verification-key-file ${POOL_KEYS}/stake.vkey \
--pool-owner-stake-verification-key-file ${POOL_KEYS}/stake.vkey \
--testnet-magic 2 \
--pool-relay-ipv4 ${RELAY} \
--pool-relay-port ${PORT} \
--metadata-url ${URL_METADATA} \
--metadata-hash $(cat ${DATA}/pool_MetadataHash.txt) \
--out-file ${DATA}/pool-registration.cert
```

### Create a delegation certificate:
```
cardano-cli stake-address delegation-certificate \
--stake-verification-key-file ${POOL_KEYS}/stake.vkey \
--cold-verification-key-file ${POOL_KEYS}/node.vkey \
--out-file ${DATA}/delegation.cert
```
***

## Block producer node
### Find the tip of the blockchain
```
currentSlot=$(cardano-cli query tip --testnet-magic 2 | jq -r '.slot')
echo Current Slot: $currentSlot
```

### Find your balance and UTXOs.
```
cardano-cli query utxo \
    --address $(cat ${POOL_KEYS}/payment.addr) \
    --testnet-magic 2 > ${DATA}/fullUtxo.out

tail -n +3 ${DATA}/fullUtxo.out | sort -k3 -nr > ${DATA}/balance.out

cat ${DATA}/balance.out

tx_in=""
total_balance=0
while read -r utxo; do
    type=$(awk '{ print $6 }' <<< "${utxo}")
    if [[ ${type} == 'TxOutDatumNone' ]]
    then
        in_addr=$(awk '{ print $1 }' <<< "${utxo}")
        idx=$(awk '{ print $2 }' <<< "${utxo}")
        utxo_balance=$(awk '{ print $3 }' <<< "${utxo}")
        total_balance=$((${total_balance}+${utxo_balance}))
        echo TxHash: ${in_addr}#${idx}
        echo ADA: ${utxo_balance}
        tx_in="${tx_in} --tx-in ${in_addr}#${idx}"
    fi
done < ${DATA}/balance.out
txcnt=$(cat ${DATA}/balance.out | wc -l)
echo Total available ADA balance: ${total_balance}
echo Number of UTXOs: ${txcnt}
```

### Get protocol parameters
```
cardano-cli query protocol-parameters \
  --testnet-magic 2 \
  --out-file ${DATA}/protocol.json
```

```
stakePoolDeposit=$(cat ${DATA}/protocol.json | jq -r '.stakePoolDeposit')
echo stakePoolDeposit: $stakePoolDeposit
```

### Draft the transaction
```
cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat ${POOL_KEYS}/payment.addr)+$(( ${total_balance} - ${stakePoolDeposit}))  \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee 0 \
    --certificate-file ${DATA}/pool-registration.cert \
    --certificate-file ${DATA}/delegation.cert \
    --out-file ${DATA}/tx.tmp
```



### Calculate the minimum fee:
```
fee=$(cardano-cli transaction calculate-min-fee \
    --tx-body-file ${DATA}/tx.tmp \
    --tx-in-count ${txcnt} \
    --tx-out-count 1 \
    --testnet-magic 2 \
    --witness-count 3 \
    --byron-witness-count 0 \
    --protocol-params-file ${DATA}/protocol.json | awk '{ print $1 }')
echo fee: $fee
```
### Add extra fee

```
fee=$((fee + 100000))
echo fee: $fee
```

### Calculate your change output.
```
txOut=$((${total_balance}-${stakePoolDeposit}-${fee}))
echo txOut: ${txOut}
```

### Build the transaction. 
```
cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat ${POOL_KEYS}/payment.addr)+${txOut} \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee ${fee} \
    --certificate-file ${DATA}/pool-registration.cert \
    --certificate-file ${DATA}/delegation.cert \
    --out-file ${DATA}/tx.raw
```

***

## Air-gapped node
### Sign the transaction.
```
cardano-cli transaction sign \
    --tx-body-file ${DATA}/tx.raw \
    --signing-key-file ${POOL_KEYS}/payment.skey \
    --signing-key-file ${POOL_KEYS}/stake.skey \
    --signing-key-file ${POOL_KEYS}/node.skey \
    --testnet-magic 2 \
    --out-file ${DATA}/tx.signed
```

***
## Block producer node

### Send the transaction.
```
cardano-cli transaction submit \
    --tx-file ${DATA}/tx.signed \
    --testnet-magic 2
```
