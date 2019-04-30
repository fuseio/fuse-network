#!/usr/bin/env bash

if [ -d flats ]; then
  rm -rf flats
fi

mkdir flats

./node_modules/.bin/truffle-flattener contracts/Consensus.sol > flats/Consensus_flat.sol
