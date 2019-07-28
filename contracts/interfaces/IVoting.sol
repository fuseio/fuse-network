pragma solidity ^0.4.24;

interface IVoting {
    function onCycleEnd(address[] validators) external;
}
