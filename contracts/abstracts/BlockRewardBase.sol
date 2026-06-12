
pragma solidity ^0.8.0;

/**
 * @title Interface to be implemented by block reward contract
 * @author LiorRabin
 * @dev abstract contract
 */
abstract contract BlockRewardBase {
    // Produce rewards for the given benefactors, with corresponding reward codes.
    // Only valid when msg.sender == SYSTEM_ADDRESS (EIP96, 2**160 - 2)
    function reward(address[] calldata benefactors, uint16[] calldata kind) external virtual returns (address[] memory, uint256[] memory);
}
