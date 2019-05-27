pragma solidity ^0.4.24;

contract VotingEnums {

  enum BallotTypes {
    Invalid,
    MinThreshold,
    MinStake,
    BlockReward,
    ProxyAddress
  }

  enum ThresholdTypes {
    Invalid,
    Voters,
    BlockReward,
    MinStake
  }

  enum QuorumStates {
    Invalid,
    InProgress,
    Accepted,
    Rejected
  }

  enum ActionChoice {
    Invalid,
    Accept,
    Reject
  }
}