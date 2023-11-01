# Run Stake Pool

## Step 1: Important Keys
Before starting the stake pool, make sure the following keys are in the `node/pool-keys` directory, as they are crucial to operate your pool.

- kes.skey
- vrf.skey
- node.cert

## Step 2: Start the Stake Pool
To start the stake pool, execute the following command:

```
docker compose up -d
```
This command will launch the stake pool services in detached mode, allowing them to run in the background.