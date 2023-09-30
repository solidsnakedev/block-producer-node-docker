
```
./cardano-cli.sh node key-gen-KES \
    --verification-key-file kes.vkey \
    --signing-key-file kes.skey
```

```
./cardano-cli.sh node key-gen-VRF \
    --verification-key-file vrf.vkey \
    --signing-key-file vrf.skey
```

```
./cardano-cli.sh node key-gen \
    --cold-verification-key-file node.vkey \
    --cold-signing-key-file node.skey \
    --operational-certificate-issue-counter node.counter
```

```
./cardano-cli.sh node issue-op-cert \
    --kes-verification-key-file kes.vkey \
    --cold-signing-key-file node.skey \
    --operational-certificate-issue-counter node.counter \
    --kes-period 555 \
    --out-file node.cert
```
