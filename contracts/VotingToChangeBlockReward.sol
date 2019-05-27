pragma solidity ^0.4.24;

import "./Voting.sol";
import "./BlockReward.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract VotingToChangeBlockReward is Voting {

  function initialize(uint256 _minBallotDuration, uint256 _minPossibleBlockReward) public {
    require(_minPossibleBlockReward >= 0);
    init(_minBallotDuration);
    setMinPossibleBlockReward(_minPossibleBlockReward);
  }

  function newBallot(uint256 _startTime, uint256 _endTime, uint256 _proposedValue, string _description) public {
    require(_proposedValue >= getMinPossibleBlockReward());
    require(_proposedValue != getGlobalBlockReward());
    uint256 ballotId = super.createBallot(uint256(BallotTypes.BlockReward), _startTime, _endTime, _description);
    setProposedValue(ballotId, _proposedValue);
  }

  function getBallotInfo(uint256 _id, address _key) public view returns(uint256 startTime, uint256 endTime, uint256 totalVoters, int256 progress, bool isFinalized, uint256 proposedValue, address creator, string description, bool canBeFinalizedNow, bool alreadyVoted) {
    startTime = getStartTime(_id);
    endTime = getEndTime(_id);
    totalVoters = getTotalVoters(_id);
    progress = getProgress(_id);
    isFinalized = getIsFinalized(_id);
    proposedValue = getProposedValue(_id);
    creator = getCreator(_id);
    description = getDescription(_id);
    canBeFinalizedNow = canBeFinalized(_id);
    alreadyVoted = hasAlreadyVoted(_id, _key);
  }

  function finalizeBallotInner(uint256 _id) internal returns(bool) {
    uint256 proposedValue = getProposedValue(_id);
    BlockReward(ProxyStorage(getProxyStorage()).getBlockReward()).setReward(proposedValue);
    return getBallotsStorage().setBallotThreshold(proposedValue, uint256(ThresholdTypes.BlockReward));
  }

  function getMinPossibleBlockReward() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("minPossibleBlockReward"))];
  }

  function setMinPossibleBlockReward(uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("minPossibleBlockReward"))] = _value;
  }

  function getProposedValue(uint256 _id) internal view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))];
  }

  function setProposedValue(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))] = _value;
  }
}
