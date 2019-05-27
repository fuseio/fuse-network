pragma solidity ^0.4.24;

/**
 * @title Interface to be implemented by voting contract
 * @dev abstract contract
 */
contract VotingBase {

  event BallotCreated(uint256 indexed id, uint256 indexed ballotType, address indexed creator);
  event BallotFinalized(uint256 indexed id, address indexed voter);
  event Vote(uint256 indexed id, uint256 decision, address indexed voter, uint256 time);

  function vote(uint256 _id, uint256 _choice) external;
  function finalize(uint256 _id) external;
}
