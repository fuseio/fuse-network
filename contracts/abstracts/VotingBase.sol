
pragma solidity ^0.8.0;

/**
 * @title Interface to be implemented by voting contract
 * @author LiorRabin
 * @dev abstract contract
 */
abstract contract VotingBase {

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
  * @dev Possible ballot types
  * @param ContractAddress - ballot to change a network contract implementation (see ProxyStorage.ContractTypes)
  * @param NodeVersion - ballot to schedule a network upgrade (required node version + activation block)
  * Note: ballots created before ballot types were introduced have type Invalid (0) and are treated as ContractAddress
  */
  enum BallotTypes {
    Invalid,
    ContractAddress,
    NodeVersion
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
  */
  event BallotFinalized(uint256 indexed id);

  /**
  * @dev This event will be emitted on each vote
  * @param id ballot id
  * @param decision voter decision (see VotingBase.ActionChoices)
  * @param voter address of the voter
  */
  event Vote(uint256 indexed id, uint256 decision, address indexed voter);

  /**
  * @dev Function to be called when voting on a ballot
  * @param _id ballot id
  * @param _choice voter decision on the ballot (see VotingBase.ActionChoices)
  */
  function vote(uint256 _id, uint256 _choice) external virtual;
}
