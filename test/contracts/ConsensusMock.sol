pragma solidity 0.4.24;

import "../../contracts/Consensus.sol";

contract ConsensusMock is Consensus {
  function setSystemAddress(address _newAddress) public onlyOwner {
    addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = _newAddress;
  }
}
