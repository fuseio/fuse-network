pragma solidity ^0.4.24;

import "./Voting.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract handling vote to change a proxy address of a network contract
*/
contract VotingToChangeProxyAddress is Voting {

  /**
  * @dev Function to be called on contract initialization
  * @param _minBallotDuration minimum time (in seconds) a ballot can be open before finalization
  */
  function initialize(uint256 _minBallotDuration) public {
    init(_minBallotDuration);
  }

  /**
  * @dev Function to create a new ballot
  * @param _startTime unix timestamp representing ballot start time (open for voting)
  * @param _endTime unix timestamp representing ballot end time (closed for voting and can be finalized)
  * @param _contractType contract type to change its address (See ProxyStorage.ContractTypes)
  * @param _proposedValue proposed address for the contract type
  * @param _description ballot text description
  */
  function newBallot(uint256 _startTime, uint256 _endTime, uint256 _contractType, address _proposedValue, string _description) public {
    require(_proposedValue != address(0));
    require(validContractType(_contractType));
    uint256 ballotId = super.createBallot(uint256(BallotTypes.ProxyAddress), _startTime, _endTime, _description);
    setProposedValue(ballotId, _proposedValue);
    setContractType(ballotId, _contractType);
  }

  /**
  * @dev Function to get specific ballot info along with voters involvment on it
  * @param _id ballot id to get info of
  * @param _key voter key to get if voted already
  */
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
