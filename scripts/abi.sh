#!/usr/bin/env bash

if [ -d abis ]; then
  rm -rf abis
fi

mkdir abis

./node_modules/node-jq/bin/jq '.abi' build/contracts/EternalStorageProxy.json > abis/EternalStorageProxy_abi.json
./node_modules/node-jq/bin/jq '.abi' build/contracts/Consensus.json > abis/Consensus_abi.json
./node_modules/node-jq/bin/jq '.abi' build/contracts/BlockReward.json > abis/BlockReward_abi.json
./node_modules/node-jq/bin/jq '.abi' build/contracts/ProxyStorage.json > abis/ProxyStorage_abi.json
./node_modules/node-jq/bin/jq '.abi' build/contracts/Voting.json > abis/Voting_abi.json
