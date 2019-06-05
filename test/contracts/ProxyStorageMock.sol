pragma solidity ^0.4.24;

import "../../contracts/ProxyStorage.sol";

contract ProxyStorageMock is ProxyStorage {
  function setBlockRewardMock(address _newAddress) public {
    addressStorage[keccak256(abi.encodePacked("blockReward"))] = _newAddress;
  }
}
