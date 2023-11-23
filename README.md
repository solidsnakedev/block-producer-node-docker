
# Build Cardano Node Docker Image
This guide will help you build a Cardano node Docker image for your network setup. Before proceeding, ensure you have the necessary information:

- `<relay-ip-address>` : Replace this with the IP Address of the relay node.

- `<relay-port>`: Replace this with the Port number of the relay node.

## Navigate to the Network Directory
Choose the appropriate directory (mainnet, preprod, or preview) based on your network configuration and navigate to it using the cd command

## Option 1: Build Node with 1 Relay
To build a Cardano node with one relay, use the following command:

```
docker compose build \
    --build-arg RELAY1_IP=<relay-ip-address> \
    --build-arg RELAY1_PORT=<relay-port>
```
This command builds a Docker image for a Cardano node with a single relay.

## Option 2: Build Node with 2 Relays
To build a Cardano node with two relays, use the following command:

```
docker compose build \
    --build-arg RELAY1_IP=<relay-ip-address> \
    --build-arg RELAY1_PORT=<relay-port> \
    --build-arg RELAY2_IP=<relay-ip-address> \
    --build-arg RELAY2_PORT=<relay-port>
```

## Option 3: Build Node/Relay (Node and Relay Combined)
If you want to build a Cardano node and relay together, use the following command:

```
docker compose build
```
This command builds a block producer with direct connection to other nodes in the network

Once the build process is complete, you can proceed with configuring and running your Cardano node according to your specific requirements.

## Running the node
Bootstrapping the Cardano node in STAND-ALONE mode
```
docker compose up -d
```
This command launches the Cardano node in detached mode.

**It will take some time for the node to sync with the network, and it must reach a synchronization level of 100% before proceeding to the next steps.**

You can check the synchronization status with the following command:
```
docker exec -it cardano-node-mainnet-bp cardano-cli query tip --mainnet
```

# Upgrade Node

```
docker compose down
```
```
docker compose build \
    --no-cache \
    --build-arg RELAY1_IP=<relay-ip-address> \
    --build-arg RELAY1_PORT=<relay-port>
```
