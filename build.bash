#!/bin/bash

YELLOW="\x1B[1;33m"
GREEN_FLASH="\x1B[1;5;32m"
REST="\x1B[0m"

function build-rust-repo() {
    make build-rust repo=$1
    mkdir -p pigskit/app/$1
    cp src/$1/target/release/$1 pigskit/app/$1
}

function build-node-repo() {
    make build-node repo=$1
    mkdir -p pigskit/app/$1
    cp -r src/$1/dist/* pigskit/app/$1
}

rm -rf pigskit && mkdir pigskit
cp -r src/deploy/* pigskit

echo -e "\n${YELLOW}Building Pigskit service release...${REST}\n"

build-rust-repo pigskit-restful-server
build-rust-repo pigskit-graphql-server
build-node-repo pigskit-web

echo -e "\n${GREEN_FLASH}Successfully builded.${REST}\n"
