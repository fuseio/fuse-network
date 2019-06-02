pragma solidity ^0.4.24;

/**
 * @title Interface to be implemented by voting contract
 * @dev abstract contract
 */
contract VotingBase {

  /**
  * @dev This event will be emitted every time a new ballot is created
  * @param id ballot id
  * @param ballotType ballot type (see VotingEnums.BallotTypes)
  * @param creator address of ballot creator
  */
  event BallotCreated(uint256 indexed id, uint256 indexed ballotType, address indexed creator);

  /**
  * @dev This event will be emitted when a ballot if finalized
  * @param id ballot id
  * @param voter address of the ballot "finalizer"
  */
  event BallotFinalized(uint256 indexed id, address indexed voter);

  /**
  * @dev This event will be emitted on each vote
  * @param id ballot id
  * @param decision voter decision (see VotingEnums.ActionChoice)
  * @param voter address of the voter
  * @param time time of the vote
  */
  event Vote(uint256 indexed id, uint256 decision, address indexed voter, uint256 time);

  /**
  * @dev Function to be called when voting on a ballot
  * @param _id ballot id
  * @param _choice voter decision on the ballot (see VotingEnums.ActionChoice)
  */
  function vote(uint256 _id, uint256 _choice) external;

  /**
  * @dev Function to be called when finalizing a ballot
  * @param _id ballot id
  */
  function finalize(uint256 _id) external;
}
