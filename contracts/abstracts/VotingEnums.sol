pragma solidity ^0.4.24;

/**
 * @title Enums used in voting contracts
 * @dev abstract contract
 */
contract VotingEnums {

  /**
  * @dev Available ballot types (subjects which can be voted on)
  * @param MinThreshold - vote on number of voters needed for a ballot to be accepted
  * @param MinStake - vote on minimum stake needed to become a validator
  * @param BlockReward - vote on amount to be received as reward for mining a block
  * @param ProxyAddress - vote on changing the address of a network contract addresses
  */
  enum BallotTypes {
    Invalid,
    MinThreshold,
    MinStake,
    BlockReward,
    ProxyAddress
  }

  /**
  * @dev Available threshold types (consists with BallotTypes)
  * @param voters - see BallotTypes.MinThreshold
  * @param BlockReward - see BallotTypes.BlockReward
  * @param MinStake - see BallotTypes.MinStake
  */
  enum ThresholdTypes {
    Invalid,
    Voters,
    BlockReward,
    MinStake
  }

  /**
  * @dev Possible states of quorum
  * @param InProgress - state while a ballot has not been finalized yet
  * @param Accepted - state after finalizing the ballot and more than ThresholdTypes.Voters have voted ActionChoice.Accept
  * @param Rejected - state after finalizing the ballot and more than ThresholdTypes.Voters have voted ActionChoice.Reject
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
  enum ActionChoice {
    Invalid,
    Accept,
    Reject
  }
}