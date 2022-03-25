pragma solidity ^0.8.0;

import "../fuse/IConsensus.sol";

contract ConsensusMock is IConsensus {
    mapping(address => bool) public override isValidator;

    constructor(address[] memory signers) {
        for (uint8 i = 0; i < signers.length; i++)
            isValidator[signers[i]] = true;
    }
}
