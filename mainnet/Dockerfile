# syntax=docker/dockerfile:1
FROM ubuntu:latest

# Install Cardano dependencies
RUN apt-get update -y && \
    apt-get install automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf liblmdb-dev curl vim -y

RUN mkdir src

ARG TAG

RUN <<EOT
    [ -z ${TAG} ] \
    && URL=$(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | jq -r '.assets[] | select(.name | contains("linux")) | .browser_download_url') \
    || URL=$( curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/tags/${TAG} | jq -r '.assets[] | select(.name | contains("linux")) | .browser_download_url')

    cd src && \
    wget -cO - ${URL} > cardano-node.tar.gz && \
    tar -xvf cardano-node.tar.gz &&
    mv cardano-node /usr/local/bin &&
    mv cardano-cli /usr/local/bin
EOT

RUN <<EOT
    URL=$(curl -s https://api.github.com/repos/cardano-community/cncli/releases/latest | jq -r '.assets[] | select(.name | contains("linux")) | .browser_download_url')
    cd src && \
    wget -cO - ${URL} > cncli.tar.gz && \
    tar xzvf cncli.tar.gz && \
    mv cncli /usr/local/bin
EOT

# Install libsodium
RUN cd src && \
    git clone https://github.com/input-output-hk/libsodium && \
    cd libsodium && \
    git checkout dbb48cc && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

# Update libsodium PATH
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

#Install libsecp256k1
RUN cd src && \
    git clone https://github.com/bitcoin-core/secp256k1 && \
    cd secp256k1 && \
    git checkout ac83be33 && \
    ./autogen.sh && \
    ./configure --enable-module-schnorrsig --enable-experimental && \
    make && \
    make install

# Delete src folder
RUN rm -r /src

# Get latest config files
RUN wget -P /node/configuration \
    https://raw.githubusercontent.com/input-output-hk/cardano-world/master/docs/environments/mainnet/byron-genesis.json \
    https://raw.githubusercontent.com/input-output-hk/cardano-world/master/docs/environments/mainnet/shelley-genesis.json \
    https://raw.githubusercontent.com/input-output-hk/cardano-world/master/docs/environments/mainnet/alonzo-genesis.json \
    https://raw.githubusercontent.com/input-output-hk/cardano-world/master/docs/environments/mainnet/conway-genesis.json

# Keep it until mainnet config has P2P enabled
COPY config.json /node/configuration

# Change config to save them in /node/log/node.log file instead of stdout
RUN sed -i 's/StdoutSK/FileSK/' /node/configuration/config.json && \
    sed -i 's/stdout/\/node\/logs\/node.log/' /node/configuration/config.json && \
    sed -i 's/\"TraceBlockFetchDecisions\": false/\"TraceBlockFetchDecisions\": true/' /node/configuration/config.json && \
    sed -i 's/\"127.0.0.1\"/\"0.0.0.0\"/' /node/configuration/config.json

ARG RELAY1_IP
ARG RELAY1_PORT

ARG RELAY2_IP
ARG RELAY2_PORT

RUN \
    if [ -n "${RELAY1_IP}" ] && [ -n "${RELAY1_PORT}" ] && [ -n "${RELAY2_IP}" ] && [ -n "${RELAY2_PORT}" ] ; then \
    echo  "{\n" \
    "   \"localRoots\": [\n" \
    "         {\n" \
    "           \"accessPoints\": [\n" \
    "               { \"address\": \"${RELAY1_IP}\", \"port\": ${RELAY1_PORT} }, \n" \
    "               { \"address\": \"${RELAY2_IP}\", \"port\": ${RELAY2_PORT} }\n" \
    "             ],\n" \
    "           \"advertise\": false,\n" \
    "           \"valency\": 1\n" \
    "         }\n" \
    "     ],\n" \
    "   \"publicRoots\": [\n" \
    "     ],\n" \
    "   \"useLedgerAfterSlot\": -1\n" \
    "}\n" \
    > /node/configuration/topology.json ; \
    elif [ -n "${RELAY1_IP}" ] && [ -n "${RELAY1_PORT}" ] ; then \
    echo  "{\n" \
    "   \"localRoots\": [\n" \
    "         {\n" \
    "           \"accessPoints\": [\n" \
    "               { \"address\": \"${RELAY1_IP}\", \"port\": ${RELAY1_PORT} }\n" \
    "             ],\n" \
    "           \"advertise\": false,\n" \
    "           \"valency\": 1\n" \
    "         }\n" \
    "     ],\n" \
    "   \"publicRoots\": [\n" \
    "     ],\n" \
    "   \"useLedgerAfterSlot\": -1\n" \
    "}\n" \
    > /node/configuration/topology.json ; \
    else echo " *** Incorrect Setting ***" ; \
    fi

ARG CNCLI_API_KEY 
ARG CNCLI_POOL_NAME
ARG CNCLI_POOL_ID
ARG CNCLI_HOST
ARG CNCLI_PORT

RUN <<EOT
    jq -n \
        --arg api_key "$CNCLI_API_KEY" \
        --arg pool_name "$CNCLI_POOL_NAME" \
        --arg pool_id "$CNCLI_POOL_ID" \
        --arg host "$CNCLI_HOST" \
        --arg port "$CNCLI_PORT" \
        '{
            api_key: $api_key, 
            pools: [
                { 
                    name: $pool_name,
                    pool_id: $pool_id,
                    host : $host,
                    port: $port,
                }
            ]
        }' \
        > /node/configuration/cncli-config.json
EOT

# Set path location
ENV NODE_HOME=/node
ENV POOL_KEYS=${NODE_HOME}/pool-keys
ENV DATA=${NODE_HOME}/data
ENV CONFIGURATION=${NODE_HOME}/configuration

# Set network for cardano-cli commands
ENV NETWORK="--mainnet"

# Set node socket evironment for cardano-cli
ENV CARDANO_NODE_SOCKET_PATH="/node/ipc/node.socket"

# Set mainnet magic number
ENV MAGIC_NUMBER=764824073

# Create keys, ipc, data, scripts, logs folders
RUN mkdir -p /node/ipc /node/logs /node/pool-keys

# Copy scripts
COPY cardano-scripts/ /usr/local/bin

# Set executable permits
RUN /bin/bash -c "chmod +x /usr/local/bin/*.sh"

# Run cardano-node at the startup
CMD [ "/usr/local/bin/run-cardano-node.sh" ]
