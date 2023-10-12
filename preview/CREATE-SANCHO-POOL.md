
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

- For `Sanchonet`
    ```
    docker exec -it cardano-node-bp-sanchonet cardano-cli query tip --testnet-magic 4
    ```

## Step 2: Accessing the Cardano Node
Once the Cardano node is fully synchronized, you can access it using the following command:

- For `Sanchonet`
    ```
    docker exec -it cardano-node-bp-sanchonet bash
    ```

## Set node PATH variables
```
NODE_HOME=/node
POOL_KEYS=${NODE_HOME}/pool-keys
DATA=${NODE_HOME}/data
CONFIGURATION=${NODE_HOME}/configuration
```

## Set `cardano-cli` Network
- For `Sanchonet`
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
cardano-cli conway node key-gen \
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
cardano-cli conway node issue-op-cert \
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
cardano-cli conway stake-address registration-certificate \
    --stake-verification-key-file ${POOL_KEYS}/stake.vkey \
    --key-reg-deposit-amt 2000000 \
    --out-file ${POOL_KEYS}/stake.cert
```

### Generate -> `pool id`
```
cardano-cli stake-pool id \
    --cold-verification-key-file ${POOL_KEYS}/node.vkey \
    --output-format bech32 \
    --out-file ${POOL_KEYS}/pool.id
```

## Step 4: Funding wallet
Send at least 1000 ADA to your pool payment address
```
echo $(cat ${POOL_KEYS}/payment.addr)
```

### Check wallet funds
```
cardano-cli query utxo \
    --address $(cat ${POOL_KEYS}/payment.addr) \
    ${NETWORK}
```


## Step 5: Registering Stake Address

```
cardano-cli transaction build \
    --conway-era \
    ${NETWORK} \
    --witness-override 2 \
    --tx-in $(cardano-cli query utxo --address $(cat ${POOL_KEYS}/payment.addr) ${NETWORK} --out-file  /dev/stdout | jq -r 'keys[0]') \
    --change-address $(cat ${POOL_KEYS}/payment.addr) \
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
PORT=6004
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

### Build the transaction. 
```
cardano-cli conway transaction build \
    ${NETWORK} \
    --witness-override 3 \
    --tx-in $(cardano-cli query utxo --address $(cat ${POOL_KEYS}/payment.addr) ${NETWORK} --out-file  /dev/stdout | jq -r 'keys[0]') \
    --change-address $(cat ${POOL_KEYS}/payment.addr) \
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

# Request stake delegation from faucet

https://sancho.network/faucet/

```
echo $(cat ${POOL_KEYS}/pool.id)

```
## Query stake delegated 
```
cardano-cli query stake-snapshot \
    ${NETWORK} \
    --stake-pool-id $(cat ${POOL_KEYS}/pool.id)
```
