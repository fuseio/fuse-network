pragma solidity ^0.4.24;

import "../../contracts/BlockReward.sol";

contract BlockRewardMock is BlockReward {
  function setSystemAddress(address _newAddress) public onlyOwner {
    addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = _newAddress;
  }
}
