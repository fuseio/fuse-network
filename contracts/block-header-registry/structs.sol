pragma solidity ^0.8.0;

struct Signature {
    bytes32 r;
    bytes32 vs;
}

struct SignedBlock {
    address creator;
    bytes[] signatures;
    // Just for fuse
    uint256 cycleEnd;
    address[] validators;
}

struct BlockHeader {
    bytes32 parentHash;
    bytes32 uncleHash;
    address coinbase;
    bytes32 root;
    bytes32 txHash;
    bytes32 receiptHash;
    bytes32[8] bloom;
    uint256 difficulty;
    uint256 number;
    uint256 gasLimit;
    uint256 gasUsed;
    uint256 time;
    bytes32 mixDigest;
    uint256 nonce;
    uint256 baseFee;
    bytes extra;
}

struct Block {
    bytes rlpHeader;
    Signature signature;
    uint256 blockchainId;
    bytes32 blockHash;
    uint256 cycleEnd;
    address[] validators;
}
