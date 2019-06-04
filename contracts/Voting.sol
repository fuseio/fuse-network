pragma solidity ^0.4.24;

import "./abstracts/VotingBase.sol";
import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";
import "./Consensus.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract handling vote to change implementations network contracts
*/
contract Voting is EternalStorage, VotingBase {
  using SafeMath for uint256;

  /**
  * @dev This modifier verifies that msg.sender is the owner of the contract
  */
  modifier onlyOwner() {
    require(msg.sender == addressStorage[keccak256(abi.encodePacked("owner"))]);
    _;
  }

  /**
  * @dev This modifier verifies times are valid
  */
  modifier onlyValidTime(uint256 _startTime, uint256 _endTime) {
    require(_startTime > 0 && _endTime > 0);
    require(_endTime > _startTime && _startTime > getTime());
    uint256 diffTime = _endTime.sub(_startTime);
    require(diffTime > getMinBallotDuration());
    require(diffTime <= getMaxBallotDuration());
    _;
  }

  /**
  * @dev This modifier verifies an address is valid for voting
  */
  modifier onlyValidVotingKey(address _address) {
    require (isValidVotingKey(_address));
    _;
  }

  /**
  * @dev Function to be called on contract initialization
  * @param _minBallotDuration minimum time (in seconds) a ballot can be open before finalization
  */
  function initialize(uint256 _minBallotDuration) public onlyOwner {
    require(!isInitialized());
    require(_minBallotDuration < getMaxBallotDuration());
    setMinBallotDuration(_minBallotDuration);
    setInitialized(true);
  }

  /**
  * @dev Function to create a new ballot
  * @param _startTime unix timestamp representing ballot start time (open for voting)
  * @param _endTime unix timestamp representing ballot end time (closed for voting and can be finalized)
  * @param _contractType contract type to change its address (See ProxyStorage.ContractTypes)
  * @param _proposedValue proposed address for the contract type
  * @param _description ballot text description
  */
  function newBallot(uint256 _startTime, uint256 _endTime, uint256 _contractType, address _proposedValue, string _description) public returns(uint256) {
    require(_proposedValue != address(0));
    require(validContractType(_contractType));
    uint256 ballotId = createBallot(_startTime, _endTime, _description);
    setProposedValue(ballotId, _proposedValue);
    setContractType(ballotId, _contractType);
    return ballotId;
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

  /**
  * @dev Function to check if a contract type is a valid network contract
  * @param _contractType contract type to check (See ProxyStorage.ContractTypes)
  */
  function validContractType(uint256 _contractType) public view returns(bool) {
    return ProxyStorage(getProxyStorage()).isValidContractType(_contractType);
  }

  function getProposedValue(uint256 _id) public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))];
  }

  function setProposedValue(uint256 _id, address _value) private {
    addressStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))] = _value;
  }

  function getContractType(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "contractType"))];
  }

  function setContractType(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "contractType"))] = _value;
  }

  /**
  * @dev This function checks if an address is valid for voting (is a validator)
  * @param _address the address to check if valid for voting
  */
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

  /**
  * @dev Function to get the number of "open" (active) ballots each validator (someone with voting rights) can have at the same time
  */
  function getBallotLimitPerValidator() public view returns(uint256) {
    uint256 validatorsCount = getTotalNumberOfValidators();
    if (validatorsCount == 0) {
      return getMaxLimitBallot();
    }
    uint256 limit = getMaxLimitBallot().div(validatorsCount);
    if (limit == 0) {
      limit = 1;
    }
    return limit;
  }

  /**
  * @dev This function is used to create a ballot
  * @param _startTime unix timestamp representing ballot start time (open for voting)
  * @param _endTime unix timestamp representing ballot end time (closed for voting and can be finalized)
  * @param _description ballot text description
  */
  function createBallot(uint256 _startTime, uint256 _endTime, string _description) private onlyValidVotingKey(msg.sender) onlyValidTime(_startTime, _endTime) returns(uint256) {
    require(isInitialized());
    address creator = msg.sender;
    require(withinLimit(creator));
    uint256 ballotId = getNextBallotId();
    setNextBallotId(ballotId.add(1));
    setStartTime(ballotId, _startTime);
    setEndTime(ballotId, _endTime);
    setIsFinalized(ballotId, false);
    setQuorumState(ballotId, uint256(QuorumStates.InProgress));
    setCreator(ballotId, creator);
    setDescription(ballotId, _description);
    setTotalVoters(ballotId, 0);
    setProgress(ballotId, 0);
    setIndex(ballotId, activeBallotsLength());
    activeBallotsAdd(ballotId);
    increaseValidatorLimit(creator);
    emit BallotCreated(ballotId, creator);
    return ballotId;
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

  /**
  * @dev This function is used to vote on a ballot
  * @param _id ballot id to vote on
  * @param _choice voting decision on the ballot (see VotingBase.ActionChoices)
  */
  function vote(uint256 _id, uint256 _choice) external onlyValidVotingKey(msg.sender) {
    require(!getIsFinalized(_id));
    address voter = msg.sender;
    require(isValidVote(_id, voter));
    if (_choice == uint(ActionChoices.Accept)) {
      setProgress(_id, getProgress(_id) + 1);
    } else if (_choice == uint(ActionChoices.Reject)) {
      setProgress(_id, getProgress(_id) - 1);
    } else {
      revert();
    }
    votersAdd(_id, voter);
    setTotalVoters(_id, getTotalVoters(_id).add(1));
    emit Vote(_id, _choice, voter, getTime());
  }

  /**
  * @dev This function is used to finalize an open ballot
  * @param _id ballot id to be finalized
  */
  function finalize(uint256 _id) external onlyValidVotingKey(msg.sender) {
    require(canBeFinalized(_id));
    finalizeBallot(_id);
  }

  /**
  * @dev This function is used to check if a ballot can be finalized
  * @param _id ballot id to check
  * A ballot can be finalized if all possible voters have voted and minimum ballot duration has passed or if end time has passed
  */
  function canBeFinalized(uint256 _id) public view returns(bool) {
    uint256 currentTime = getTime();
    uint256 startTime = getStartTime(_id);

    if (_id >= getNextBallotId()) return false;
    if (startTime > currentTime) return false;
    if (getIsFinalized(_id)) return false;

    uint256 validatorsLength = getTotalNumberOfValidators();

    if (validatorsLength == 0) {
      return false;
    }

    if (getTotalVoters(_id) < validatorsLength) {
      return !isActiveBallot(_id);
    }

    uint256 diffTime = currentTime.sub(startTime);
    return diffTime > getMinBallotDuration();
  }

  function deactivateBallot(uint256 _id) private {
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

  function finalizeBallot(uint256 _id) private {
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

  function finalizeBallotInner(uint256 _id) private returns(bool) {
    return ProxyStorage(getProxyStorage()).setContractAddress(getContractType(_id), getProposedValue(_id));
  }

  /// storage functions ///
  function getTime() public view returns(uint256) {
    return now;
  }

  function isActiveBallot(uint256 _id) public view returns(bool) {
    return getStartTime(_id) <= getTime() && getTime() <= getEndTime(_id);
  }

  function getMinThresholdOfVoters(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "minThresholdOfVoters"))];
  }

  function setMinThresholdOfVoters(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "minThresholdOfVoters"))] = _value;
  }

  function getQuorumState(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))];
  }

  function setQuorumState(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))] = _value;
  }

  function getNextBallotId() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("nextBallotId"))];
  }

  function setNextBallotId(uint256 _id) private {
    uintStorage[keccak256(abi.encodePacked("nextBallotId"))] = _id;
  }

  function getMinBallotDuration() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("minBallotDuration"))];
  }

  function setMinBallotDuration(uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("minBallotDuration"))] = _value;
  }

  function getMaxBallotDuration() public pure returns(uint256) {
    return 14 days;
  }

  function getStartTime(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "startTime"))];
  }

  function setStartTime(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "startTime"))] = _value;
  }

  function getEndTime(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "endTime"))];
  }

  function setEndTime(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "endTime"))] = _value;
  }

  function getIsFinalized(uint256 _id) public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("votingState", _id, "isFinalized"))];
  }

  function setIsFinalized(uint256 _id, bool _value) private {
    boolStorage[keccak256(abi.encodePacked("votingState", _id, "isFinalized"))] = _value;
  }

  function getDescription(uint256 _id) public view returns(string) {
    return stringStorage[keccak256(abi.encodePacked("votingState", _id, "description"))];
  }

  function setDescription(uint256 _id, string _value) private {
    stringStorage[keccak256(abi.encodePacked("votingState", _id, "description"))] = _value;
  }

  function getCreator(uint256 _id) public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("votingState", _id, "creator"))];
  }

  function setCreator(uint256 _id, address _value) private {
    addressStorage[keccak256(abi.encodePacked("votingState", _id, "creator"))] = _value;
  }

  function getTotalVoters(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "totalVoters"))];
  }

  function setTotalVoters(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "totalVoters"))] = _value;
  }

  function getProgress(uint256 _id) public view returns(int256) {
    return intStorage[keccak256(abi.encodePacked("votingState", _id, "progress"))];
  }

  function setProgress(uint256 _id, int256 _value) private {
    intStorage[keccak256(abi.encodePacked("votingState", _id, "progress"))] = _value;
  }

  function getIndex(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "index"))];
  }

  function setIndex(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "index"))] = _value;
  }

  function activeBallots(uint256 _index) public view returns(uint256) {
    return uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))][_index];
  }

  function activeBallotsLength() public view returns(uint256) {
    return uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))].length;
  }

  function activeBallotsAdd(uint256 _id) private {
    uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))].push(_id);
  }

  function activeBallotsClear() private {
    delete uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))];
  }

  function activeBallotsDecreaseLength() private {
    if (activeBallotsLength() > 0) {
      uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))].length--;
    }
  }

  function activeBallotsSet(uint256 _index, uint256 _id) private {
    uintArrayStorage[keccak256(abi.encodePacked("activeBallots"))][_index] = _id;
  }

  function validatorActiveBallots(address _key) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("validatorActiveBallots", _key))];
  }

  function setValidatorActiveBallots(address _key, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("validatorActiveBallots", _key))] = _value;
  }

  function increaseValidatorLimit(address _key) private {
    setValidatorActiveBallots(_key, validatorActiveBallots(_key).add(1));
  }

  function decreaseValidatorLimit(uint256 _id) private {
    address key = getCreator(_id);
    uint256 ballotsCount = validatorActiveBallots(key);
    if (ballotsCount > 0) {
      setValidatorActiveBallots(key, ballotsCount - 1);
    }
  }

  function getFinalizeCalled(uint256 _id) public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("finalizeCalled", _id))];
  }

  function setFinalizeCalled(uint256 _id) private {
    boolStorage[keccak256(abi.encodePacked("finalizeCalled", _id))] = true;
  }

  function getProxyStorage() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("proxyStorage"))];
  }

  function getTotalNumberOfValidators() private view returns(uint256) {
    return Consensus(ProxyStorage(getProxyStorage()).getConsensus()).currentValidatorsLength();
  }

  function votersAdd(uint256 _id, address _key) private {
    boolStorage[keccak256(abi.encodePacked("votingState", _id, "voters", _key))] = true;
  }

  function withinLimit(address _key) private view returns(bool) {
    return validatorActiveBallots(_key) < getBallotLimitPerValidator();
  }

  /**
  * @dev Function to get the max number of "open" (active) ballots can be at the same time
  */
  function getMaxLimitBallot() public pure returns(uint256) {
    return 100;
  }
}
