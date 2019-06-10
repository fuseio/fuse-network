pragma solidity ^0.4.24;

import "../../contracts/ProxyStorage.sol";

contract ProxyStorageMock is ProxyStorage {
  function setBlockRewardMock(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("blockReward"))] = _newAddress;
  }

  function setConsensusMock(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("consensus"))] = _newAddress;
  }

  function upgradeBlockRewardMock(address _implementation) public {
    EternalStorageProxy(getBlockReward()).upgradeTo(_implementation);
  }

  function upgradeConsensusMock(address _implementation) public {
    EternalStorageProxy(getConsensus()).upgradeTo(_implementation);
  }
}
