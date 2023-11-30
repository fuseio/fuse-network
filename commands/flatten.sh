#!/usr/bin/env bash

if [ -d flats ]; then
  rm -rf flats
fi

mkdir flats

./node_modules/.bin/truffle-flattener contracts/eternal-storage/EternalStorageProxy.sol > flats/EternalStorageProxy_flat.sol
./node_modules/.bin/truffle-flattener contracts/Consensus.sol > flats/Consensus_flat.sol
./node_modules/.bin/truffle-flattener contracts/BlockReward.sol > flats/BlockReward_flat.sol
./node_modules/.bin/truffle-flattener contracts/ProxyStorage.sol > flats/ProxyStorage_flat.sol
./node_modules/.bin/truffle-flattener contracts/Voting.sol > flats/Voting_flat.sol
