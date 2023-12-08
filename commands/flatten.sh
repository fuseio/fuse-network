#!/usr/bin/env bash

if [ -d flats ]; then
  rm -rf flats
fi

mkdir flats

npx hardhat flatten contracts/eternal-storage/EternalStorageProxy.sol > flats/EternalStorageProxy_flat.sol
npx hardhat flatten contracts/Consensus.sol > flats/Consensus_flat.sol
npx hardhat flatten contracts/BlockReward.sol > flats/BlockReward_flat.sol
npx hardhat flatten contracts/ProxyStorage.sol > flats/ProxyStorage_flat.sol
npx hardhat flatten contracts/Voting.sol > flats/Voting_flat.sol
