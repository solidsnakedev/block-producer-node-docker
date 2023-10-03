
# Create Stake Pool Keys and Certificates
This section outlines the steps to create stake pool keys and certificates while bootstrapping the Cardano node in STAND-ALONE mode.

## Prerequisites
Ensure that the node/pool-keys directory is empty before proceeding with the following steps.

## Step 1: Bootstrapping the Cardano Node

```
docker compose up -d
```
This command launches the Cardano node in detached mode.

**It will take some time for the node to sync with the network, and it must reach a synchronization level of 100% before proceeding to the next steps.**


You can check the synchronization status with the following command:

- For `Mainnet`

    ```
    docker exec -it cardano-node-bp-mainnet cardano-cli query tip --mainnet
    ```
- For `Preprod`
    ```
    docker exec -it cardano-node-bp-preprod cardano-cli query tip --testnet-magic 1
    ```
- For `Preview`
    ```
    docker exec -it cardano-node-bp-preview cardano-cli query tip ${NETWORK}
    ```
- For `Sanchonet`
    ```
    docker exec -it cardano-node-bp-sanchonet cardano-cli query tip --testnet-magic 4
    ```

## Step 2: Accessing the Cardano Node
Once the Cardano node is fully synchronized, you can access it using the following command:

- For `Mainnet`

    ```
    docker exec -it cardano-node-bp-mainnet bash
    ```
- For `Preprod`
    ```
    docker exec -it cardano-node-bp-preprod bash
    ```
- For `Preview`
    ```
    docker exec -it cardano-node-bp-preview bash
    ```
- For `Sanchonet`
    ```
    docker exec -it cardano-node-bp-sanchonet bash
    ```

### Set node PATH variables
```
NODE_HOME=/node
POOL_KEYS=${NODE_HOME}/pool-keys
DATA=${NODE_HOME}/data
CONFIGURATION=${NODE_HOME}/configuration
```

## Set `cardano-cli` Network
1. For `Mainnet`
    ```
    NETWORK="--mainnet"
    ```
2. For `Preprod`
    ```
    NETWORK="--testnet-magic 1"
    ```
3. For `Preview`
    ```
    NETWORK="${NETWORK}"
    ```
4. For `Sanchonet`
    ```
    NETWORK="--testnet-magic 4"
    ```

## Step 3: Generating keys and certificates
When generating keys and certificates for your Cardano stake pool, it's crucial to prioritize security. 

You have two options for the environment in which you generate these keys: 
1. Using an air-gapped computer without internet access
2. Taking high security measures on your current machine.

**Whichever option you choose, make sure these keys are stored securely in a safe location.**

**The most critical keys are the `*.skey` files, as they are used for signing transactions in your air-gapped node.**

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

### Generate -> `node certificate` 
```
slotsPerKESPeriod=$(cat ${CONFIGURATION}/shelley-genesis.json | jq -r '.slotsPerKESPeriod')
echo slotsPerKESPeriod: ${slotsPerKESPeriod}
```

```
slotNo=$(cardano-cli query tip ${NETWORK} | jq -r '.slot')
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
    ${NETWORK}
```

### Generate -> `payment address`
```
cardano-cli address build \
    --payment-verification-key-file ${POOL_KEYS}/payment.vkey \
    --stake-verification-key-file ${POOL_KEYS}/stake.vkey \
    --out-file ${POOL_KEYS}/payment.addr \
    ${NETWORK}
```

### Generate -> `stake certificate`
```
cardano-cli stake-address registration-certificate \
    --stake-verification-key-file ${POOL_KEYS}/stake.vkey \
    --out-file ${POOL_KEYS}/stake.cert
```

## Step 4: Funding wallet
Send at least 1000 ADA to your pool payment address
```
cat ${POOL_KEYS}/payment.addr
```

### Check wallet funds
```
cardano-cli query utxo \
    --address $(cat ${POOL_KEYS}/payment.addr) \
    ${NETWORK}
```


## Step 5: Registering Stake Address

```
currentSlot=$(cardano-cli query tip ${NETWORK} | jq -r '.slot')
echo Current Slot: $currentSlot
```

```
cardano-cli query utxo \
    --address $(cat ${POOL_KEYS}/payment.addr) \
    ${NETWORK} > ${DATA}/fullUtxo.out

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
  ${NETWORK} \
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
    ${NETWORK} \
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
    ${NETWORK} \
    --out-file ${DATA}/tx.signed
```

***
### Block producer node
```
cardano-cli transaction submit \
    --tx-file ${DATA}/tx.signed \
    ${NETWORK}
```

## Step 6: Registering Stake Pool
### - Set environment variables

```
NODE_HOME=/node
POOL_KEYS=${NODE_HOME}/pool-keys
DATA=${NODE_HOME}/data
CONFIGURATION=${NODE_HOME}/configuration
```

### - Download `pool metadata`
```
URL_METADATA=https://solidsnakedev.github.io/poolMetadata.json
```

```
wget ${URL_METADATA} -O ${DATA}/pool_Metadata.json
```

### - Calculate the hash of your metadata file
```
cardano-cli stake-pool metadata-hash --pool-metadata-file ${DATA}/pool_Metadata.json > ${DATA}/pool_MetadataHash.txt
```

### Set environment variables
```
PLEDGE=<enter-lovelace-pledge>
COST=340000000
MARGIN=0.019
RELAY=<enter-ip-address>
PORT=6002
```

### Create pool registration (1 relay)
```
cardano-cli stake-pool registration-certificate \
--cold-verification-key-file ${POOL_KEYS}/node.vkey \
--vrf-verification-key-file ${POOL_KEYS}/vrf.vkey \
--pool-pledge ${PLEDGE} \
--pool-cost ${COST} \
--pool-margin ${MARGIN} \
--pool-reward-account-verification-key-file ${POOL_KEYS}/stake.vkey \
--pool-owner-stake-verification-key-file ${POOL_KEYS}/stake.vkey \
${NETWORK} \
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

### Find the tip of the blockchain
```
currentSlot=$(cardano-cli query tip ${NETWORK} | jq -r '.slot')
echo Current Slot: $currentSlot
```

### Find your balance and UTXOs.
```
cardano-cli query utxo \
    --address $(cat ${POOL_KEYS}/payment.addr) \
    ${NETWORK} > ${DATA}/fullUtxo.out

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
  ${NETWORK} \
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
    ${NETWORK} \
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
    ${NETWORK} \
    --out-file ${DATA}/tx.signed
```

***
## Block producer node

### Send the transaction.
```
cardano-cli transaction submit \
    --tx-file ${DATA}/tx.signed \
    ${NETWORK}
```
