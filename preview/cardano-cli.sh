
cardano_cli () {
    docker run --rm -w /node -v ./node:/node cardano-node-preview-bp cardano-cli $@
}
cardano_cli $@