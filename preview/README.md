
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

# Register Stake Address

```
currentSlot=$(cardano-cli query tip --testnet-magic 2 | jq -r '.slot')
echo Current Slot: $currentSlot
```

```
cardano-cli query utxo \
    --address $(cat ${POOL_KEYS}/payment.addr) \
    --mainnet > ${DATA}/fullUtxo.out

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
  --mainnet \
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
    --mainnet \
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
### AIR GAPPED NODE

```
cardano-cli transaction sign \
    --tx-body-file ${DATA}/tx.raw \
    --signing-key-file ${POOL_KEYS}/payment.skey \
    --signing-key-file ${POOL_KEYS}/stake.skey \
    --mainnet \
    --out-file ${DATA}/tx.signed
```

### BP NODE
```
cardano-cli transaction submit \
    --tx-file ${DATA}/tx.signed \
    --testnet-magic 2
```
