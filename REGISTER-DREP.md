## Step 1: Accessing the Cardano Node
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
## Generate a DRep key pair
```
cardano-cli conway governance drep key-gen \
    --verification-key-file ${POOL_KEYS}/drep.vkey \
    --signing-key-file ${POOL_KEYS}/drep.skey
```

## Generate a SanchoNet DRep ID
```
cardano-cli conway governance drep id \
    --drep-verification-key-file ${POOL_KEYS}/drep.vkey \
    --out-file ${POOL_KEYS}/drep.id
```

## Create a SanchoNet DRep registration certificate
`Using the drep.vkey file`
```
cardano-cli conway governance drep registration-certificate \
    --drep-verification-key-file ${POOL_KEYS}/drep.vkey \
    --key-reg-deposit-amt 0 \
    --out-file ${POOL_KEYS}/drep-register.cert
```

## Submit the SanchoNet DRep registration certificate in a transaction
```
cardano-cli transaction build \
    --conway-era \
    ${NETWORK} \
    --witness-override 2 \
    --tx-in $(cardano-cli query utxo --address $(cat ${POOL_KEYS}/payment.addr) ${NETWORK} --out-file  /dev/stdout | jq -r 'keys[0]') \
    --change-address $(cat ${POOL_KEYS}/payment.addr) \
    --certificate-file ${POOL_KEYS}/drep-register.cert \
    --out-file ${DATA}/tx.raw
```
```
cardano-cli transaction sign \
    --tx-body-file ${DATA}/tx.raw \
    --signing-key-file ${POOL_KEYS}/payment.skey \
    --signing-key-file ${POOL_KEYS}/drep.skey \
    ${NETWORK} \
    --out-file ${DATA}/tx.signed
```
```
cardano-cli transaction submit \
    ${NETWORK} \
    --tx-file ${DATA}/tx.signed
```