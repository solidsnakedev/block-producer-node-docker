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
