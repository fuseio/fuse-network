pragma solidity ^0.4.24;

import "../../contracts/BlockReward.sol";

contract BlockRewardMock is BlockReward {
  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function getSystemAddress() public view returns(address) {
    return addressStorage[SYSTEM_ADDRESS];
  }

  function initializeMock(uint256 _supply, uint256 _blocksPerYear, uint256 _inflation) public {
    uintStorage[TOTAL_SUPPLY] = _supply;
    uintStorage[BLOCKS_PER_YEAR] = _blocksPerYear;
    uintStorage[INFLATION] = _inflation;
    uintStorage[BLOCK_REWARD_AMOUNT] = (getTotalSupply().mul(getInflation().mul(DECIMALS).div(100))).div(getBlocksPerYear()).div(DECIMALS);
  }

  function setShouldEmitRewardedOnCycleMock(bool _status) public {
    boolStorage[SHOULD_EMIT_REWARDED_ON_CYCLE] = _status;
  }
}
