#!/usr/bin/env bash

if [ -d abis ]; then
  rm -rf abis
fi

mkdir abis

cat build/contracts/EternalStorageProxy.json | jq '.abi' > abis/EternalStorageProxy_abi.json
cat build/contracts/Consensus.json | jq '.abi' > abis/Consensus_abi.json
cat build/contracts/BlockReward.json | jq '.abi' > abis/BlockReward_abi.json
cat build/contracts/ProxyStorage.json | jq '.abi' > abis/ProxyStorage_abi.json
cat build/contracts/Voting.json | jq '.abi' > abis/Voting_abi.json
