pragma solidity ^0.4.24;

import "./abstracts/VotingBase.sol";
import "./VotingStorage.sol";
import "./ProxyStorage.sol";
import "./Consensus.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Voting is VotingStorage, VotingBase {
  using SafeMath for uint256;

  modifier onlyValidTime(uint256 _startTime, uint256 _endTime) {
    require(_startTime > 0 && _endTime > 0);
    require(_endTime > _startTime && _startTime > getTime());
    uint256 diffTime = _endTime.sub(_startTime);
    require(diffTime > getMinBallotDuration());
    require(diffTime <= getMaxBallotDuration());
    _;
  }

  modifier onlyValidVotingKey(address _address) {
    require (isValidVotingKey(_address));
    _;
  }

  function init(uint256 _minBallotDuration) internal {
    require(!isInitialized());
    require(_minBallotDuration < getMaxBallotDuration());
    setMinBallotDuration(_minBallotDuration);
    setInitialized(true);
  }

  function isValidVotingKey(address _address) public view returns(bool) {
    bool valid = false;
    Consensus consensus = Consensus(ProxyStorage(getProxyStorage()).getConsensus());
    for (uint256 i = 0; i < consensus.currentValidatorsLength(); i++) {
      address validator = consensus.currentValidatorsAtPosition(i);
      if (validator == _address) {
        valid = true;
      }
    }
    return valid;
  }

  function createBallot(uint256 _ballotType, uint256 _startTime, uint256 _endTime, string _description) internal onlyValidVotingKey(msg.sender) onlyValidTime(_startTime, _endTime) returns(uint256) {
    address creator = msg.sender;
    require(withinLimit(creator));
    uint256 ballotId = super.createBallot(_startTime, _endTime, _description, uint256(QuorumStates.InProgress), creator);
    setTotalVoters(ballotId, 0);
    setProgress(ballotId, 0);
    setIndex(ballotId, activeBallotsLength());
    activeBallotsAdd(ballotId);
    increaseValidatorLimit(creator);
    emit BallotCreated(ballotId, _ballotType, creator);
    return ballotId;
  }

  function vote(uint256 _id, uint256 _choice) external onlyValidVotingKey(msg.sender) {
    require(!getIsFinalized(_id));
    address voter = msg.sender;
    require(isValidVote(_id, voter));
    if (_choice == uint(ActionChoice.Accept)) {
      setProgress(_id, getProgress(_id) + 1);
    } else if (_choice == uint(ActionChoice.Reject)) {
      setProgress(_id, getProgress(_id) - 1);
    } else {
      revert();
    }
    votersAdd(_id, voter);
    setTotalVoters(_id, getTotalVoters(_id).add(1));
    emit Vote(_id, _choice, voter, getTime());
  }

  function finalize(uint256 _id) external onlyValidVotingKey(msg.sender) {
    require(canBeFinalizedInner(_id));
    finalizeBallot(_id);
  }

  function canBeFinalized(uint256 _id) public view returns(bool) {
    return canBeFinalizedInner(_id);
  }

  function canBeFinalizedInner(uint256 _id) internal view returns(bool) {
    uint256 currentTime = getTime();
    uint256 startTime = getStartTime(_id);

    if (_id >= getNextBallotId()) return false;
    if (startTime > currentTime) return false;
    if (getIsFinalized(_id)) return false;

    uint256 validatorsLength = Consensus(ProxyStorage(getProxyStorage()).getConsensus()).currentValidatorsLength();

    if (validatorsLength == 0) {
      return false;
    }

    if (getTotalVoters(_id) < validatorsLength) {
      return !isActiveBallot(_id);
    }

    uint256 diffTime = currentTime.sub(startTime);
    return diffTime > getMinBallotDuration();
  }

  function deactivateBallot(uint256 _id) internal {
    uint256 removedIndex = getIndex(_id);
    uint256 lastIndex = activeBallotsLength() - 1;
    uint256 lastBallotId = activeBallots(lastIndex);

    // Override the removed ballot with the last one.
    activeBallotsSet(removedIndex, lastBallotId);

    // Update the index of the last validator.
    setIndex(lastBallotId, removedIndex);
    activeBallotsSet(lastIndex, 0);
    activeBallotsDecreaseLength();
  }

  function finalizeBallot(uint256 _id) internal {
    if (!getFinalizeCalled(_id)) {
      decreaseValidatorLimit(_id);
      setFinalizeCalled(_id);
    }

    if (getProgress(_id) > 0 && getTotalVoters(_id) >= getMinThresholdOfVoters(_id)) {
      if (finalizeBallotInner(_id)) {
        setQuorumState(_id, uint256(QuorumStates.Accepted));
      } else {
        return;
      }
    } else {
      setQuorumState(_id, uint256(QuorumStates.Rejected));
    }

    deactivateBallot(_id);
    setIsFinalized(_id, true);
    emit BallotFinalized(_id, msg.sender);
  }

  function finalizeBallotInner(uint256 _id) internal returns(bool);
}
