# syntax=docker/dockerfile:1
FROM node

# Get latest config files
RUN wget -P /node/configuration \
  https://raw.githubusercontent.com/input-output-hk/cardano-playground/main/static/book.play.dev.cardano.org/environments/mainnet/byron-genesis.json \
  https://raw.githubusercontent.com/input-output-hk/cardano-playground/main/static/book.play.dev.cardano.org/environments/mainnet/shelley-genesis.json \
  https://raw.githubusercontent.com/input-output-hk/cardano-playground/main/static/book.play.dev.cardano.org/environments/mainnet/alonzo-genesis.json \
  https://raw.githubusercontent.com/input-output-hk/cardano-playground/main/static/book.play.dev.cardano.org/environments/mainnet/conway-genesis.json \
  https://raw.githubusercontent.com/input-output-hk/cardano-playground/main/static/book.play.dev.cardano.org/environments/mainnet/config.json


# TODO: add jq
# Change config to save them in /node/log/node.log file instead of stdout
RUN sed -i 's/StdoutSK/FileSK/' /node/configuration/config.json && \
  sed -i 's/stdout/\/node\/logs\/node.log/' /node/configuration/config.json && \
  sed -i 's/\"TraceBlockFetchDecisions\": false/\"TraceBlockFetchDecisions\": true/' /node/configuration/config.json && \
  sed -i 's/\"127.0.0.1\"/\"0.0.0.0\"/' /node/configuration/config.json

RUN echo $(jq '.TraceMempool|=true' /node/configuration/config.json) > /node/configuration/config.json

ARG RELAY1_IP
ARG RELAY1_PORT

ARG RELAY2_IP
ARG RELAY2_PORT

RUN <<EOT
    if [ -n "${RELAY1_IP}" ] && [ -n "${RELAY1_PORT}" ] && [ -n "${RELAY2_IP}" ] && [ -n "${RELAY2_PORT}" ] ; then \
        jq -n \
        --arg relay1_ip "$RELAY1_IP" \
        --arg relay1_port "$RELAY1_PORT" \
        --arg relay2_ip "$RELAY2_IP" \
        --arg relay2_port "$RELAY2_PORT" \
        '{
          "bootstrapPeers": [],
          "localRoots": [
            {
              "accessPoints": [
                {"address": $relay1_ip, "port": $relay1_port | tonumber },
                {"address": $relay2_ip, "port": $relay2_port | tonumber }
              ],
              "advertise": false,
              "trustable": true,
              "valency": 2
            }
          ],
          "publicRoots": [
            {
              "accessPoints": [],
              "advertise": false
            }
          ],
          "useLedgerAfterSlot": -1
        }' > /node/configuration/topology.json
    elif [ -n "${RELAY1_IP}" ] && [ -n "${RELAY1_PORT}" ] ; then \
        jq -n \
        --arg relay1_ip "$RELAY1_IP" \
        --arg relay1_port "$RELAY1_PORT" \
        '{
          "bootstrapPeers": [],
          "localRoots": [
            {
              "accessPoints": [
                {"address": $relay1_ip, "port": $relay1_port | tonumber }
              ],
              "advertise": false,
              "trustable": true,
              "valency": 1
            }
          ],
          "publicRoots": [
            {
              "accessPoints": [],
              "advertise": false
            }
          ],
          "useLedgerAfterSlot": -1
        }' > /node/configuration/topology.json
    else 
      jq -n \
        '{
          "localRoots": [
            {
              "accessPoints": [],
              "advertise": false,
              "valency": 1
            }
          ],
          "publicRoots": [
            {
              "accessPoints": [
                {
                  "address": "backbone.cardano-mainnet.iohk.io",
                  "port": 3001
                },
                {
                  "address": "backbone.cardano.iog.io",
                  "port": 3001
                },
                {
                  "address": "backbone.mainnet.emurgornd.com",
                  "port": 3001
                }
              ],
              "advertise": false
            }
          ],
          "useLedgerAfterSlot": 110332824
        }' > /node/configuration/topology.json 
    fi
EOT

# Set network for cardano-cli commands
ENV NETWORK="--mainnet"

# Set mainnet magic number
ENV MAGIC_NUMBER=764824073

# Copy scripts
COPY cardano-scripts/ /usr/local/bin

# Set executable permits
RUN /bin/bash -c "chmod +x /usr/local/bin/*.sh"

ARG CNCLI_POOL_NAME
ARG CNCLI_API_KEY 
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

# Run cardano-node at the startup
CMD [ "/usr/local/bin/run-cardano-node.sh" ]
