pragma solidity ^0.4.24;

import "../../contracts/ProxyStorage.sol";

contract ProxyStorageMock is ProxyStorage {
  function setVoting(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("voting"))] = _newAddress;
  }

  function setConsensusMock(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("consensus"))] = _newAddress;
  }

  function setBlockRewardMock(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("blockReward"))] = _newAddress;
  }
}
