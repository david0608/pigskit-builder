#!/bin/bash

YELLOW="\x1B[1;33m"
GREEN_FLASH="\x1B[1;5;32m"
REST="\x1B[0m"

function build-rust-repo() {
    make build-rust repo=$1
    mkdir -p pikit/app/$1
    cp src/$1/target/release/$1 pikit/app/$1
}

function build-node-repo() {
    make build-node repo=$1
    mkdir -p pikit/app/$1
    cp -r src/$1/dist/* pikit/app/$1
}

rm -rf pikit && mkdir pikit
cp -r src/deploy/* pikit

echo -e "\n${YELLOW}Building PIKIT service release...${REST}\n"

build-rust-repo pikit-restful-server
build-rust-repo pikit-graphql-server
build-node-repo pikit-web

echo -e "\n${GREEN_FLASH}Successfully builded.${REST}\n"
