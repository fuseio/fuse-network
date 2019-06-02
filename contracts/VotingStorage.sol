pragma solidity ^0.4.24;

import "./abstracts/VotingEnums.sol";
import "./eternal-storage/EternalStorage.sol";
import "./BallotsStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract VotingStorage is EternalStorage, VotingEnums {
  using SafeMath for uint256;

  function getTime() public view returns(uint256) {
    return now;
  }

  function setInitialized(bool _value) internal {
    boolStorage[keccak256(abi.encodePacked("isInitialized"))] = _value;
  }

  function isInitialized() public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("isInitialized"))];
  }

  function isActiveBallot(uint256 _id) public view returns(bool) {
    return getStartTime(_id) <= getTime() && getTime() <= getEndTime(_id);
  }

  function getMinThresholdOfVoters(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "minThresholdOfVoters"))];
  }

  function setMinThresholdOfVoters(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "minThresholdOfVoters"))] = _value;
  }

  function getQuorumState(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))];
  }

  function setQuorumState(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))] = _value;
  }

  function getNextBallotId() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("nextBallotId"))];
  }

  function setNextBallotId(uint256 _id) internal {
    uintStorage[keccak256(abi.encodePacked("nextBallotId"))] = _id;
  }

  function getMinBallotDuration() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("minBallotDuration"))];
  }

  function setMinBallotDuration(uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("minBallotDuration"))] = _value;
  }

  function getMaxBallotDuration() public pure returns(uint256) {
    return 14 days;
  }

  function getStartTime(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "startTime"))];
  }

  function setStartTime(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "startTime"))] = _value;
  }

  function getEndTime(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "endTime"))];
  }

  function setEndTime(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "endTime"))] = _value;
  }

  function getIsFinalized(uint256 _id) public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("votingState", _id, "isFinalized"))];
  }

  function setIsFinalized(uint256 _id, bool _value) internal {
    boolStorage[keccak256(abi.encodePacked("votingState", _id, "isFinalized"))] = _value;
  }

  function getDescription(uint256 _id) public view returns(string) {
    return stringStorage[keccak256(abi.encodePacked("votingState", _id, "description"))];
  }

  function setDescription(uint256 _id, string _value) internal {
    stringStorage[keccak256(abi.encodePacked("votingState", _id, "description"))] = _value;
  }

  function getCreator(uint256 _id) public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("votingState", _id, "creator"))];
  }

  function setCreator(uint256 _id, address _value) internal {
    addressStorage[keccak256(abi.encodePacked("votingState", _id, "creator"))] = _value;
  }

  function getTotalVoters(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "totalVoters"))];
  }

  function setTotalVoters(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "totalVoters"))] = _value;
  }

  function getProgress(uint256 _id) public view returns(int256) {
    return intStorage[keccak256(abi.encodePacked("votingState", _id, "progress"))];
  }

  function setProgress(uint256 _id, int256 _value) internal {
    intStorage[keccak256(abi.encodePacked("votingState", _id, "progress"))] = _value;
  }

  function getIndex(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "index"))];
  }

  function setIndex(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "index"))] = _value;
  }

  function activeBallots(uint256 _index) public view returns(uint256) {
    return uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))][_index];
  }

  function activeBallotsLength() public view returns(uint256) {
    return uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))].length;
  }

  function activeBallotsAdd(uint256 _id) internal {
    uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))].push(_id);
  }

  function activeBallotsClear() internal {
    delete uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))];
  }

  function activeBallotsDecreaseLength() internal {
    if (activeBallotsLength() > 0) {
      uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))].length--;
    }
  }

  function activeBallotsSet(uint256 _index, uint256 _id) internal {
    uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))][_index] = _id;
  }

  function validatorActiveBallots(address _key) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("validatorActiveBallots", _key))];
  }

  function setValidatorActiveBallots(address _key, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("validatorActiveBallots", _key))] = _value;
  }

  function increaseValidatorLimit(address _key) internal {
    setValidatorActiveBallots(_key, validatorActiveBallots(_key).add(1));
  }

  function decreaseValidatorLimit(uint256 _id) internal {
    address key = getCreator(_id);
    uint256 ballotsCount = validatorActiveBallots(key);
    if (ballotsCount > 0) {
      setValidatorActiveBallots(key, ballotsCount - 1);
    }
  }

  function getFinalizeCalled(uint256 _id) public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("finalizeCalled", _id))];
  }

  function setFinalizeCalled(uint256 _id) internal {
    boolStorage[keccak256(abi.encodePacked("finalizeCalled", _id))] = true;
  }

  function getProxyStorage() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("proxyStorage"))];
  }

  function getBallotsStorage() internal view returns(BallotsStorage) {
    return BallotsStorage(ProxyStorage(getProxyStorage()).getBallotsStorage());
  }

  function getBallotLimitPerValidator() public view returns(uint256) {
    return getBallotsStorage().getBallotLimitPerValidator();
  }

  function getGlobalMinThresholdOfVoters() public view returns(uint256) {
    return getBallotsStorage().getBallotThreshold(uint256(ThresholdTypes.Voters));
  }

  function getGlobalBlockReward() public view returns(uint256) {
    return getBallotsStorage().getBallotThreshold(uint256(ThresholdTypes.BlockReward));
  }

  function getGlobalMinStake() public view returns(uint256) {
    return getBallotsStorage().getBallotThreshold(uint256(ThresholdTypes.MinStake));
  }

  function votersAdd(uint256 _id, address _key) internal {
    boolStorage[keccak256(abi.encodePacked("votingState", _id, "voters", _key))] = true;
  }

  /**
  * @dev Function used to check if a voting key has voted on a specific ballot
  * @param _id ballot id to get info of
  * @param _key voter key to get if voted already
  */
  function hasAlreadyVoted(uint256 _id, address _key) public view returns(bool) {
    if (_key == address(0)) {
      return false;
    }
    return boolStorage[keccak256(abi.encodePacked("votingState", _id, "voters", _key))];
  }

  /**
  * @dev Function checking if a voting key is valid for a specific ballot (ballot is active and key has not voted yet)
  * @param _id ballot id to get info of
  * @param _key voter key to check
  */
  function isValidVote(uint256 _id, address _key) public view returns(bool) {
    bool isActive = isActiveBallot(_id);
    bool hasVoted = hasAlreadyVoted(_id, _key);
    return isActive && !hasVoted;
  }

  function withinLimit(address _key) internal view returns(bool) {
    return validatorActiveBallots(_key) < getBallotLimitPerValidator();
  }

  function createBallot(uint256 _startTime, uint256 _endTime, string _description, uint256 _quorumState, address _creatorKey) internal returns(uint256) {
    require(isInitialized());
    uint256 ballotId = getNextBallotId();
    setNextBallotId(ballotId.add(1));
    setStartTime(ballotId, _startTime);
    setEndTime(ballotId, _endTime);
    setIsFinalized(ballotId, false);
    setQuorumState(ballotId, _quorumState);
    setMinThresholdOfVoters(ballotId, getGlobalMinThresholdOfVoters());
    setCreator(ballotId, _creatorKey);
    setDescription(ballotId, _description);
    return ballotId;
  }
}
