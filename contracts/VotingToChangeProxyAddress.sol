pragma solidity ^0.4.24;

import "./Voting.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract VotingToChangeProxyAddress is Voting {

  function initialize(uint256 _minBallotDuration) public {
    init(_minBallotDuration);
  }

  function newBallot(uint256 _startTime, uint256 _endTime, uint256 _contractType, address _proposedValue, string _description) public {
    require(_proposedValue != address(0));
    require(validContractType(_contractType));
    uint256 ballotId = super.createBallot(uint256(BallotTypes.ProxyAddress), _startTime, _endTime, _description);
    setProposedValue(ballotId, _proposedValue);
    setContractType(ballotId, _contractType);
  }

  function getBallotInfo(uint256 _id, address _key) public view returns(uint256 startTime, uint256 endTime, uint256 totalVoters, int256 progress, bool isFinalized, address proposedValue, uint256 contractType, address creator, string description, bool canBeFinalizedNow, bool alreadyVoted) {
    startTime = getStartTime(_id);
    endTime = getEndTime(_id);
    totalVoters = getTotalVoters(_id);
    progress = getProgress(_id);
    isFinalized = getIsFinalized(_id);
    proposedValue = getProposedValue(_id);
    contractType = getContractType(_id);
    creator = getCreator(_id);
    description = getDescription(_id);
    canBeFinalizedNow = canBeFinalized(_id);
    alreadyVoted = hasAlreadyVoted(_id, _key);
  }

  function finalizeBallotInner(uint256 _id) internal returns(bool) {
    return ProxyStorage(getProxyStorage()).setContractAddress(getContractType(_id), getProposedValue(_id));
  }

  function validContractType(uint256 _contractType) internal view returns(bool) {
    return ProxyStorage(getProxyStorage()).isValidContractType(_contractType);
  }

  function getProposedValue(uint256 _id) internal view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))];
  }

  function setProposedValue(uint256 _id, address _value) private {
    addressStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))] = _value;
  }

  function getContractType(uint256 _id) internal view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "contractType"))];
  }

  function setContractType(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "contractType"))] = _value;
  }
}
