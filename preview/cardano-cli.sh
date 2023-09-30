
cardano_cli () {
    docker run --rm -w /node -v ./:/node cardano-node-preview-bp cardano-cli $@
}
cardano_cli $@