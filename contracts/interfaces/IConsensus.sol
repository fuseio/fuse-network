pragma solidity ^0.4.24;

interface IConsensus {
    function currentValidatorsLength() external view returns(uint256);
    function currentValidatorsAtPosition(uint256 _p) external view returns(address);
    function getCycleDurationBlocks() external view returns(uint256);
    function getCurrentCycleEndBlock() external view returns(uint256);
    function cycle() external;
    function isValidator(address _address) external view returns(bool);
    function getDelegatorsForRewardDistribution(address _validator) external view returns(address[], uint256[]);
}
