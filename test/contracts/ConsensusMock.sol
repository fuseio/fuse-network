pragma solidity 0.4.24;

import "../../contracts/Consensus.sol";

contract ConsensusMock is Consensus {
  constructor (uint256 _minStake, address _initialValidator) public Consensus(_minStake, _initialValidator) {}

  function setSystemAddress(address _newAddress) public onlyOwner {
    SYSTEM_ADDRESS = _newAddress;
  }
}
