
cardano_cli () {
    docker run --rm -w /node/pool-keys -v ./node/ipc:/node/ipc -v ./node/pool-keys:/node/pool-keys cardano-node-preview-bp cardano-cli $@
}
cardano_cli $@