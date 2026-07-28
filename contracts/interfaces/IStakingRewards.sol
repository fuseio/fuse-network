// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingRewards {
    function recordBlockReward(
        uint256 cycle, 
        address[] calldata validators, 
        uint256[] calldata weights
    ) external;
}
