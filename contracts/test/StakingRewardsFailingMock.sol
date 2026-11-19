// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
* @dev Staking rewards contract whose recordBlockReward always fails, by reverting or by using up all its gas
*/
contract StakingRewardsFailingMock {
  bool public burnGas;
  uint256 private counter;

  constructor(bool _burnGas) {
    burnGas = _burnGas;
  }

  function recordBlockReward(uint256, address[] calldata, uint256[] calldata) external {
    if (!burnGas) revert("recording failed");
    while (true) {
      counter++;
    }
  }
}
