# Block producer node instructions

## Before building

### Add new user to remote server

```
useradd -m -s /bin/bash cardano
```
```
passwd cardano
```
```
usermod -aG sudo cardano
```


### Copy ed25519 public keys from local to remote server 

```
ssh-copy-id -i $HOME/.ssh/<keyname>.pub cardano@server.public.ip.address

```
### Update sshd_config file

```
sed -i '/ChallengeResponseAuthentication/d' /etc/ssh/sshd_config
sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config
sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config
sed -i '/PermitEmptyPasswords/d' /etc/ssh/sshd_config

echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
```

### Validate sshd config
```
sudo sshd -t
```

### Restart sshd service
```
sudo systemctl restart sshd
```

Remember to save the pool keys in ./node/pool-keys

## Build cardano node docker image

* replace `<relay-ip-address>` with the IP Address of the relay node
* replace `<relay-port>` with the Port number of the relay node

### 1 Relay
```
docker compose -f ./mainnet/docker-compose.yaml build \
    --build-arg RELAY1_IP=<relay-ip-address> \
    --build-arg RELAY1_PORT=<relay-port>
```
 
### 2 Relays
```
docker compose -f ./mainnet/docker-compose.yaml build \
    --build-arg RELAY1_IP=<relay-ip-address> \
    --build-arg RELAY1_PORT=<relay-port> \
    --build-arg RELAY2_IP=<relay-ip-address> \
    --build-arg RELAY2_PORT=<relay-port>
```

## Run container
```
docker compose up -d
```


## Upgrade Node

```
docker compose down
```
```
docker compose -f ./mainnet/docker-compose.yaml build \
    --no-cache \
    --build-arg RELAY1_IP=<relay-ip-address> \
    --build-arg RELAY1_PORT=<relay-port>
```

## Mithril Client

# Preprod settings

```
export MITHRIL_IMAGE_ID=latest
export NETWORK=preprod
export AGGREGATOR_ENDPOINT=https://aggregator.release-preprod.api.mithril.network/aggregator
export GENESIS_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/genesis.vkey)
export SNAPSHOT_DIGEST=latest
```

# Preview settings
```
export MITHRIL_IMAGE_ID=latest
export NETWORK=preview
export AGGREGATOR_ENDPOINT=https://aggregator.pre-release-preview.api.mithril.network/aggregator
export GENESIS_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preview/genesis.vkey)
export SNAPSHOT_DIGEST=latest
```

```
./mithril-client.sh --version
```
