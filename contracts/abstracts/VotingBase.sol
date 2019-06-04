pragma solidity ^0.4.24;

/**
 * @title Interface to be implemented by voting contract
 * @dev abstract contract
 */
contract VotingBase {

  /**
  * @dev Possible states of quorum
  * @param InProgress - state while a ballot has not been finalized yet
  * @param Accepted - state after finalizing the ballot and majority have voted ActionChoices.Accept
  * @param Rejected - state after finalizing the ballot and majority have voted ActionChoices.Reject
  */
  enum QuorumStates {
    Invalid,
    InProgress,
    Accepted,
    Rejected
  }

  /**
  * @dev Possible choices for a ballot
  */
  enum ActionChoices {
    Invalid,
    Accept,
    Reject
  }

  /**
  * @dev This event will be emitted every time a new ballot is created
  * @param id ballot id
  * @param creator address of ballot creator
  */
  event BallotCreated(uint256 indexed id, address indexed creator);

  /**
  * @dev This event will be emitted when a ballot if finalized
  * @param id ballot id
  * @param finalizer address of the ballot finalizer
  */
  event BallotFinalized(uint256 indexed id, address indexed finalizer);

  /**
  * @dev This event will be emitted on each vote
  * @param id ballot id
  * @param decision voter decision (see VotingBase.ActionChoices)
  * @param voter address of the voter
  * @param time time of the vote
  */
  event Vote(uint256 indexed id, uint256 decision, address indexed voter, uint256 time);

  /**
  * @dev Function to be called when voting on a ballot
  * @param _id ballot id
  * @param _choice voter decision on the ballot (see VotingBase.ActionChoices)
  */
  function vote(uint256 _id, uint256 _choice) external;

  /**
  * @dev Function to be called when finalizing a ballot
  * @param _id ballot id
  */
  function finalize(uint256 _id) external;
}
