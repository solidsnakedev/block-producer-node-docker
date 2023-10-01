#!/bin/bash

HOSTADDR="0.0.0.0"
PORT="6002"
TOPOLOGY="/node/configuration/topology.json"
CONFIG="/node/configuration/config.json"
DBPATH="/node/db"
SOCKETPATH="/node/ipc/node.socket"
KESKEY="/node/pool-keys/kes.skey"
VRFKEY="/node/pool-keys/vrf.skey"
NODECERT="/node/pool-keys/node.cert"

if [ -f ${KESKEY} ] && [ -f ${VRFKEY} ] && [ -f ${NODECERT} ]; then
        echo -e "RUNNING with \n ${KESKEY} \n ${VRFKEY} \n ${NODECERT}"
        /usr/local/bin/cardano-node run \
                --topology ${TOPOLOGY} \
                --database-path ${DBPATH} \
                --socket-path ${SOCKETPATH} \
                --host-addr ${HOSTADDR} \
                --port ${PORT} \
                --config ${CONFIG} \
                --shelley-kes-key ${KESKEY} \
                --shelley-vrf-key ${VRFKEY} \
                --shelley-operational-certificate ${NODECERT}
else
        echo "RUNNING STAND-ALONE"
        /usr/local/bin/cardano-node run \
                --topology ${TOPOLOGY} \
                --database-path ${DBPATH} \
                --socket-path ${SOCKETPATH} \
                --host-addr ${HOSTADDR} \
                --port ${PORT} \
                --config ${CONFIG}
fi
