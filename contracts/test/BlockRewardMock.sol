pragma solidity ^0.4.24;

import "../BlockReward.sol";

contract BlockRewardMock is BlockReward {
  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function getSystemAddress() public view returns(address) {
    return addressStorage[SYSTEM_ADDRESS];
  }

  function getBlocksPerYear() public pure returns(uint256) {
    return 100;
  }

  function setShouldEmitRewardedOnCycleMock(bool _status) public {
    boolStorage[SHOULD_EMIT_REWARDED_ON_CYCLE] = _status;
  }

  function cycleMock() public {
    IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).cycle();
  }
}
