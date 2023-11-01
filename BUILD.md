docker compose build \
        --build-arg RELAY1_IP=194.163.164.5 \
        --build-arg RELAY1_PORT=6000 \
        --build-arg RELAY2_IP=elemt.spo.nodemesh.cc \
        --build-arg RELAY2_PORT=6000 \
        --build-arg CNCLI_API_KEY=test \
        --build-arg CNCLI_POOL_NAME=ELEMT \
        --build-arg CNCLI_POOL_ID=2f17551ea621427535afc23e233b2d6a40ef44999ced2b6b7b0ea8fc \
        --build-arg CNCLI_HOST=127.0.0.1 \
        --build-arg CNCLI_PORT=6000