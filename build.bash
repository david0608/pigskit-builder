#!/bin/bash
set -e

YELLOW="\x1B[1;33m"
GREEN_FLASH="\x1B[1;5;32m"
REST="\x1B[0m"

function build-rust-repo() {
    make build-rust repo=$1
    mkdir pigskit/app/$1
    cp src/$1/target/release/$1 pigskit/app/$1
}

function build-node-repo() {
    make build-node repo=$1
    mkdir pigskit/app/$1
    cp -r src/$1/dist/* pigskit/app/$1
}

declare -a pigskit
pigskit=(
    app
    docker
    sql
    storage
)

rm -rf pigskit
mkdir pigskit

for (( i = 0; i < ${#pigskit[*]}; i++ ))
do
    rm -rf pigskit/${pigskit[i]}
    mkdir pigskit/${pigskit[i]}

    if [ -d ./src/deploy/${pigskit[i]} ]; then
        cp -r ./src/deploy/${pigskit[i]}/* ./pigskit/${pigskit[i]}
    fi
done

echo -e "\n${YELLOW}Building Pigskit service release...${REST}\n"

build-rust-repo pigskit-restful-server
build-rust-repo pigskit-graphql-server
build-node-repo pigskit-web

echo -e "\n${GREEN_FLASH}Successfully builded.${REST}\n"
