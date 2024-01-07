# syntax=docker/dockerfile:1
FROM builder

# Install Cardano dependencies and tools
RUN apt-get update -y && \
  apt-get install automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf liblmdb-dev -y && \
  apt-get install curl vim -y

RUN mkdir src

# Install libsodium
RUN cd src && \
  git clone https://github.com/input-output-hk/libsodium && \
  cd libsodium && \
  git checkout dbb48cc && \
  ./autogen.sh && \
  ./configure && \
  make && \
  make install

# Update PATH
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

# Install BLST
RUN cd src && \
  git clone https://github.com/supranational/blst && \
  cd blst && \
  git checkout v0.3.10 && \
  ./build.sh
RUN cat <<EOF > src/blst/libblst.pc 
  prefix=/usr/local
  exec_prefix=\${prefix}
  libdir=\${exec_prefix}/lib
  includedir=\${prefix}/include

  Name: libblst
  Description: Multilingual BLS12-381 signature library
  URL: https://github.com/supranational/blst
  Version: 0.3.10
  Cflags: -I\${includedir}
  Libs: -L\${libdir} -lblst
EOF
RUN cd src/blst && \
  cp libblst.pc /usr/local/lib/pkgconfig/ && \
  cp bindings/blst_aux.h bindings/blst.h bindings/blst.hpp  /usr/local/include/ && \
  cp libblst.a /usr/local/lib

# Set path location
ENV NODE_HOME=/node
ENV POOL_KEYS=${NODE_HOME}/pool-keys
ENV DATA=${NODE_HOME}/data
ENV CONFIGURATION=${NODE_HOME}/configuration

# Set node socket evironment for cardano-cli
ENV CARDANO_NODE_SOCKET_PATH="/node/ipc/node.socket"

# Create keys, ipc, data, scripts, logs folders
RUN mkdir -p /node/ipc /node/logs /node/pool-keys /node/configuration