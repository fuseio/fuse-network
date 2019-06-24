pragma solidity ^0.4.24;

interface IConsensus {
    function getValidators() external view returns(address[]);
    function getPendingValidators() external view returns(address[]);

    function currentValidatorsLength() external view returns(uint256);
    function currentValidatorsAtPosition(uint256 _p) external view returns(address);
    function getCycleDurationBlocks() external view returns(uint256);
    function getCurrentCycleEndBlock() external view returns(uint256);
    function cycle() external;
}
