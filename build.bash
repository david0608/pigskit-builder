#!/bin/bash

YELLOW="\x1B[1;33m"
GREEN_FLASH="\x1B[1;5;32m"
REST="\x1B[0m"

rm -rf output && mkdir -p output

echo -e "\n${YELLOW}Building PIKIT service release...${REST}\n"

RESTFUL_SERVER="pikit-restful-server"
make build repo=$RESTFUL_SERVER
cp $RESTFUL_SERVER/target/release/$RESTFUL_SERVER output/$RESTFUL_SERVER

GRAPHQL_SERVER="pikit-graphql-server"
make build repo=$GRAPHQL_SERVER
cp $GRAPHQL_SERVER/target/release/$GRAPHQL_SERVER output/$GRAPHQL_SERVER

echo -e "\n${GREEN_FLASH}Successfully builded.${REST}\n"
