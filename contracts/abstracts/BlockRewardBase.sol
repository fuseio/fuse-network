pragma solidity ^0.4.24;

/**
 * @title Interface to be implemented by block reward contract
 * @dev abstract contract
 */
contract BlockRewardBase {
    // Produce rewards for the given benefactors, with corresponding reward codes.
    // Only valid when msg.sender == SUPER_USER (EIP96, 2**160 - 2)
    function reward(address[] benefactors, uint16[] kind) external returns (address[], uint256[]);
}
