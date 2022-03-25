pragma solidity ^0.8.0;

interface IConsensus {
    function isValidator(address) external returns (bool);
}
