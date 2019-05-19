pragma solidity ^0.4.24;

import "../../contracts/Reward.sol";

contract RewardMock is Reward {
  function setSystemAddress(address _newAddress) public onlyOwner {
    addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = _newAddress;
  }
}
