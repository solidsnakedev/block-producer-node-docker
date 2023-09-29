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

```
docker compose -f ./mainnet/Dockerfile build \
    --build-arg RELAY1_IPj=<relay-ip-address> \
    --build-arg RELAY1_PORT=<relay-port>
```

## Run container
```
docker compose up -d
```


## Upgrade Node

```
$ docker compose down
```
```
$ DOCKER_BUILDKIT=1 docker compose build \
    --no-cache \
    --build-arg RELAY_IP=<relay-ip-address> \
    --build-arg RELAY_PORT=<relay-port>
```
