// SPDX-License-Identifier: MIT
pragma solidity ^0.4.24;

interface IStakingRewards {
    function recordBlockReward(
        uint256 cycle, 
        address[] validators, 
        uint256[] weights
    ) external;
}
