pragma solidity ^0.8.0;

interface IBlockHeaderRegistry {
    function addBlockchain(uint256, string memory) external;
}

contract VotingMock {
    function addBlockchain(
        address registry,
        uint256 blockchainid,
        string memory rpc
    ) external {
        IBlockHeaderRegistry(registry).addBlockchain(blockchainid, rpc);
    }
}
