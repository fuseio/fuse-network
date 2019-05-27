#!/usr/bin/env bash

if [ -d flats ]; then
  rm -rf flats
fi

mkdir flats

./node_modules/.bin/truffle-flattener contracts/eternal-storage/EternalStorageProxy.sol > flats/EternalStorageProxy_flat.sol
./node_modules/.bin/truffle-flattener contracts/Consensus.sol > flats/Consensus_flat.sol
./node_modules/.bin/truffle-flattener contracts/BallotsStorage.sol > flats/BallotsStorage_flat.sol
./node_modules/.bin/truffle-flattener contracts/BlockReward.sol > flats/BlockReward_flat.sol
./node_modules/.bin/truffle-flattener contracts/ProxyStorage.sol > flats/ProxyStorage_flat.sol
./node_modules/.bin/truffle-flattener contracts/VotingToChangeBlockReward.sol > flats/VotingToChangeBlockReward_flat.sol
./node_modules/.bin/truffle-flattener contracts/VotingToChangeMinStake.sol > flats/VotingToChangeMinStake_flat.sol
./node_modules/.bin/truffle-flattener contracts/VotingToChangeMinThreshold.sol > flats/VotingToChangeMinThreshold_flat.sol
./node_modules/.bin/truffle-flattener contracts/VotingToChangeProxyAddress.sol > flats/VotingToChangeProxyAddress_flat.sol

