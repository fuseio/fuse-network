pragma solidity ^0.4.24;

import "../../contracts/ProxyStorage.sol";

contract ProxyStorageMock is ProxyStorage {
  function setVotingToChangeBlockReward(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("votingToChangeBlockReward"))] = _newAddress;
  }

  function setVotingToChangeMinStake(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("votingToChangeMinStake"))] = _newAddress;
  }

  function setVotingToChangeMinThreshold(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("votingToChangeMinThreshold"))] = _newAddress;
  }

  function setVotingToChangeProxyAddress(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("votingToChangeProxy"))] = _newAddress;
  }

  function setConsensusMock(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("consensus"))] = _newAddress;
  }

  function setBlockRewardMock(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("blockReward"))] = _newAddress;
  }
}
