// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IStakingRewards.sol";

/**
* @dev Stands in for BlockReward, ProxyStorage and Consensus when unit testing StakingRewards:
* it forwards recordBlockReward calls and answers the cycle lookups StakingRewards makes
*/
contract StakingRewardsHostMock {
  uint256 public currentCycleStartBlock;
  uint256 public lastRecordGasUsed;

  function getProxyStorage() external view returns(address) {
    return address(this);
  }

  function getConsensus() external view returns(address) {
    return address(this);
  }

  function getCurrentCycleStartBlock() external view returns(uint256) {
    return currentCycleStartBlock;
  }

  function setCurrentCycleStartBlock(uint256 _block) external {
    currentCycleStartBlock = _block;
  }

  function record(address _staking, uint256 _cycle, address[] calldata _receivers, uint256[] calldata _weights) external {
    uint256 gasBefore = gasleft();
    IStakingRewards(_staking).recordBlockReward(_cycle, _receivers, _weights);
    lastRecordGasUsed = gasBefore - gasleft();
  }
}
