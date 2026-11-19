// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../eternal-storage/EternalStorage.sol";

/**
* @dev ProxyStorage as deployed before the staking rewards contract existed (no getStaking)
*/
contract LegacyProxyStorageMock is EternalStorage {
  function getConsensus() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("consensus"))];
  }

  function getBlockReward() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("blockReward"))];
  }

  function getVoting() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("voting"))];
  }
}
