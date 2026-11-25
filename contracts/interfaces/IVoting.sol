
pragma solidity ^0.8.0;

interface IVoting {
    function onCycleEnd(address[] calldata validators) external;
}
