# syntax=docker/dockerfile:1
FROM ubuntu:latest AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install Cardano dependencies and tools
RUN apt-get update -y && \
    apt-get install automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf liblmdb-dev -y && \
    apt-get install curl vim -y

# Install GHC and Cabal
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_MINIMAL=1 sh
ENV PATH="/root/.ghcup/bin:${PATH}"
RUN ghcup upgrade && \
    ghcup install ghc 8.10.7 && \
    ghcup install cabal 3.8.1.0 && \
    ghcup set ghc 8.10.7 && \
    ghcup set cabal 3.8.1.0

# Create src folder for installations
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

ARG TAG

# Clone Cardano Node and checkout to latest version
RUN <<EOT 
    [ -z ${TAG} ] \
    && TAG=$(curl -s https://api.github.com/repos/IntersectMBO/cardano-node/releases/latest | jq -r .tag_name)

    echo $TAG && \
    cd src && \
    git clone https://github.com/IntersectMBO/cardano-node.git && \
    cd cardano-node && \
    git fetch --all --recurse-submodules --tags && \
    git tag | sort -V && \
    git checkout tags/${TAG}
EOT

# Build cardano-node & cardano-cli
RUN cd src/cardano-node && \
    cabal update && \
    cabal build cardano-node cardano-cli

# Find and copy binaries to ~/.local/bin
RUN cp $(find /src/cardano-node/dist-newstyle/build -type f -name "cardano-cli") /usr/local/bin/cardano-cli
RUN cp $(find /src/cardano-node/dist-newstyle/build -type f -name "cardano-node") /usr/local/bin/cardano-node

FROM ubuntu:latest
COPY --from=builder /usr/local/bin/cardano-cli /usr/local/bin
COPY --from=builder /usr/local/bin/cardano-node /usr/local/bin
