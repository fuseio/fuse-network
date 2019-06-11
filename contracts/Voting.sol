pragma solidity ^0.4.24;

import "./abstracts/VotingBase.sol";
import "./interfaces/IConsensus.sol";
import "./interfaces/IVoting.sol";
import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract handling vote to change implementations network contracts
*/
contract Voting is EternalStorage, VotingBase, IVoting {
  using SafeMath for uint256;

  uint256 public constant DECIMALS = 10 ** 18;

  bytes32 constant OWNER = keccak256(abi.encodePacked("owner"));
  bytes32 constant NEXT_BALLOT_ID = keccak256(abi.encodePacked("nextBallotId"));
  bytes32 constant MIN_BALLOT_DURATION_CYCLES = keccak256(abi.encodePacked("minBallotDurationCycles"));
  bytes32 constant ACTIVE_BALLOTS = keccak256(abi.encodePacked("activeBallots"));
  bytes32 constant PROXY_STORAGE = keccak256(abi.encodePacked("proxyStorage"));

  /**
  * @dev This modifier verifies that msg.sender is the owner of the contract
  */
  modifier onlyOwner() {
    require(msg.sender == addressStorage[OWNER]);
    _;
  }

  /**
  * @dev This modifier verifies the duration of the ballot is valid
  */
  modifier onlyValidDuration(uint256 _startAfterNumberOfCycles, uint256 _cyclesDuration) {
    require(_startAfterNumberOfCycles > 0);
    require (_cyclesDuration > 0);
    require(_cyclesDuration >= getMinBallotDurationCycles());
    require(_cyclesDuration <= getMaxBallotDurationCycles());
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
  * @dev This modifier verifies that msg.sender is the consensus contract
  */
  modifier onlyConsensus() {
    require (msg.sender == ProxyStorage(getProxyStorage()).getConsensus());
    _;
  }

  /**
  * @dev Function to be called on contract initialization
  * @param _minBallotDurationCycles minimum number of cycles a ballot can be open before finalization
  */
  function initialize(uint256 _minBallotDurationCycles) external onlyOwner {
    require(!isInitialized());
    require(_minBallotDurationCycles < getMaxBallotDurationCycles());
    setMinBallotDurationCycles(_minBallotDurationCycles);
    setInitialized(true);
  }

  /**
  * @dev Function to create a new ballot
  * @param _startAfterNumberOfCycles number of cycles after which the ballot should open for voting
  * @param _cyclesDuration number of cycles the ballot will remain open for voting
  * @param _contractType contract type to change its address (See ProxyStorage.ContractTypes)
  * @param _proposedValue proposed address for the contract type
  * @param _description ballot text description
  */
  function newBallot(uint256 _startAfterNumberOfCycles, uint256 _cyclesDuration, uint256 _contractType, address _proposedValue, string _description) external onlyValidVotingKey(msg.sender) onlyValidDuration(_startAfterNumberOfCycles, _cyclesDuration) returns(uint256) {
    require(_proposedValue != address(0));
    require(validContractType(_contractType));
    uint256 ballotId = createBallot(_startAfterNumberOfCycles, _cyclesDuration, _description);
    setProposedValue(ballotId, _proposedValue);
    setContractType(ballotId, _contractType);
    return ballotId;
  }

  /**
  * @dev Function to get specific ballot info along with voters involvment on it
  * @param _id ballot id to get info of
  * @param _key voter key to get if voted already
  */
  function getBallotInfo(uint256 _id, address _key) external view returns(uint256 startBlock, uint256 endBlock, uint256 totalVoters, bool isFinalized, address proposedValue, uint256 contractType, address creator, string description, bool canBeFinalizedNow, bool alreadyVoted) {
    startBlock = getStartBlock(_id);
    endBlock = getEndBlock(_id);
    totalVoters = getTotalVoters(_id);
    isFinalized = getIsFinalized(_id);
    proposedValue = getProposedValue(_id);
    contractType = getContractType(_id);
    creator = getCreator(_id);
    description = getDescription(_id);
    canBeFinalizedNow = canBeFinalized(_id);
    alreadyVoted = hasAlreadyVoted(_id, _key);

    return (startBlock, endBlock, totalVoters, isFinalized, proposedValue, contractType, creator, description, canBeFinalizedNow, alreadyVoted);
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
    IConsensus consensus = IConsensus(ProxyStorage(getProxyStorage()).getConsensus());
    for (uint256 i; i < consensus.currentValidatorsLength(); i++) {
      address validator = consensus.currentValidatorsAtPosition(i);
      if (validator == _address) {
        valid = true;
      }
    }
    return valid;
  }

  /**
  * @dev Function to get the max number of "open" (active) ballots can be at the same time
  */
  function getMaxLimitOfBallots() public pure returns(uint256) {
    return 100;
  }

  /**
  * @dev Function to get the number of "open" (active) ballots each validator (someone with voting rights) can have at the same time
  */
  function getBallotLimitPerValidator() public view returns(uint256) {
    uint256 validatorsCount = getTotalNumberOfValidators();
    if (validatorsCount == 0) {
      return getMaxLimitOfBallots();
    }
    uint256 limit = getMaxLimitOfBallots().div(validatorsCount);
    if (limit == 0) {
      limit = 1;
    }
    return limit;
  }

  /**
  * @dev This function is used to create a ballot
  * @param _startAfterNumberOfCycles number of cycles after which the ballot should open for voting
  * @param _cyclesDuration number of cycles the ballot will remain open for voting
  * @param _description ballot text description
  */
  function createBallot(uint256 _startAfterNumberOfCycles, uint256 _cyclesDuration, string _description) private returns(uint256) {
    require(isInitialized());
    address creator = msg.sender;
    require(withinLimit(creator));
    uint256 ballotId = getNextBallotId();
    setNextBallotId(ballotId.add(1));
    setStartBlock(ballotId, _startAfterNumberOfCycles);
    setEndBlock(ballotId, _cyclesDuration);
    setIsFinalized(ballotId, false);
    setQuorumState(ballotId, uint256(QuorumStates.InProgress));
    setCreator(ballotId, creator);
    setDescription(ballotId, _description);
    setTotalVoters(ballotId, 0);
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
    return getVoterChoice(_id, _key) != 0;
  }

  /**
  * @dev This function is used to vote on a ballot
  * @param _id ballot id to vote on
  * @param _choice voting decision on the ballot (see VotingBase.ActionChoices)
  */
  function vote(uint256 _id, uint256 _choice) external {
    require(!getIsFinalized(_id));
    address voter = msg.sender;
    require(isActiveBallot(_id));
    require(!hasAlreadyVoted(_id, voter));
    require(_choice == uint(ActionChoices.Accept) || _choice == uint(ActionChoices.Reject));
    setVoterChoice(_id, voter, _choice);
    setTotalVoters(_id, getTotalVoters(_id).add(1));
    emit Vote(_id, _choice, voter);
  }

  /**
  * @dev This function is used to check if a ballot can be finalized
  * @param _id ballot id to check
  */
  function canBeFinalized(uint256 _id) public view returns(bool) {
    if (_id >= getNextBallotId()) return false;
    if (getStartBlock(_id) > block.number) return false;
    if (getIsFinalized(_id)) return false;

    return block.number > getEndBlock(_id);
  }

  /**
  * @dev Function to be called by the consensus contract when a cycles ends
  * In this function, all active ballots votes will be counted and updated according to the current validators
  */
  function onCycleEnd(address[] validators) external onlyConsensus {
    uint256 numOfValidators = validators.length;
    if (numOfValidators == 0) {
      return;
    }
    uint[] memory ballots = activeBallots();
    for (uint256 i = 0; i < ballots.length; i++) {
      uint256 ballotId = ballots[i];
      if (getStartBlock(ballotId) < block.number && !getFinalizeCalled(ballotId)) {
        uint256 accepts = 0;
        uint256 rejects = 0;
        for (uint256 j = 0; j < numOfValidators; j++) {
          uint256 choice = getVoterChoice(ballotId, validators[j]);
          if (choice == uint(ActionChoices.Accept)) {
            accepts = accepts.add(1);
          } else if (choice == uint256(ActionChoices.Reject)) {
            rejects = rejects.add(1);
          }
        }
        accepts = accepts.mul(DECIMALS).div(numOfValidators);
        rejects = rejects.mul(DECIMALS).div(numOfValidators);
        setAccepted(ballotId, getAccepted(ballotId).add(accepts));
        setRejected(ballotId, getRejected(ballotId).add(rejects));

        if (canBeFinalized(ballotId)) {
          finalize(ballotId);
        }
      }
    }
  }

  function finalize(uint256 _id) private {
    if (!getFinalizeCalled(_id)) {
      decreaseValidatorLimit(_id);
      setFinalizeCalled(_id);
    }

    if (getAccepted(_id) > getRejected(_id)) {
      if (finalizeBallot(_id)) {
        setQuorumState(_id, uint256(QuorumStates.Accepted));
      } else {
        return;
      }
    } else {
      setQuorumState(_id, uint256(QuorumStates.Rejected));
    }

    deactivateBallot(_id);
    setIsFinalized(_id, true);
    emit BallotFinalized(_id);
  }

  function deactivateBallot(uint256 _id) private {
    uint256 removedIndex = getIndex(_id);
    uint256 lastIndex = activeBallotsLength() - 1;
    uint256 lastBallotId = activeBallotsAtIndex(lastIndex);

    // Override the removed ballot with the last one.
    activeBallotsSet(removedIndex, lastBallotId);

    // Update the index of the last validator.
    setIndex(lastBallotId, removedIndex);
    activeBallotsSet(lastIndex, 0);
    activeBallotsDecreaseLength();
  }

  function finalizeBallot(uint256 _id) private returns(bool) {
    return ProxyStorage(getProxyStorage()).setContractAddress(getContractType(_id), getProposedValue(_id));
  }

  function isActiveBallot(uint256 _id) public view returns(bool) {
    return getStartBlock(_id) < block.number && block.number < getEndBlock(_id);
  }

  function getQuorumState(uint256 _id) external view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))];
  }

  function setQuorumState(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))] = _value;
  }

  function getNextBallotId() public view returns(uint256) {
    return uintStorage[NEXT_BALLOT_ID];
  }

  function setNextBallotId(uint256 _id) private {
    uintStorage[NEXT_BALLOT_ID] = _id;
  }

  function getMinBallotDurationCycles() public view returns(uint256) {
    return uintStorage[MIN_BALLOT_DURATION_CYCLES];
  }

  function setMinBallotDurationCycles(uint256 _value) private {
    uintStorage[MIN_BALLOT_DURATION_CYCLES] = _value;
  }

  function getMaxBallotDurationCycles() public pure returns(uint256) {
    return 14;
  }

  function getStartBlock(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "startBlock"))];
  }

  function setStartBlock(uint256 _id, uint256 _startAfterNumberOfCycles) private {
    IConsensus consensus = IConsensus(ProxyStorage(getProxyStorage()).getConsensus());
    uint256 cycleDurationBlocks = consensus.getCycleDurationBlocks();
    uint256 currentCycleEndBlock = consensus.getCurrentCycleEndBlock();
    uint256 startBlock = currentCycleEndBlock.add(_startAfterNumberOfCycles.mul(cycleDurationBlocks));
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "startBlock"))] = startBlock;
  }

  function getEndBlock(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "endBlock"))];
  }

  function setEndBlock(uint256 _id, uint256 _cyclesDuration) private {
    uint256 cycleDurationBlocks = IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).getCycleDurationBlocks();
    uint256 startBlock = getStartBlock(_id);
    uint256 endBlock = startBlock.add(_cyclesDuration.mul(cycleDurationBlocks));
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "endBlock"))] = endBlock;
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

  function getIndex(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "index"))];
  }

  function setIndex(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "index"))] = _value;
  }

  function activeBallots() public view returns(uint[]) {
    return uintArrayStorage[ACTIVE_BALLOTS];
  }

  function activeBallotsAtIndex(uint256 _index) public view returns(uint256) {
    return uintArrayStorage[ACTIVE_BALLOTS][_index];
  }

  function activeBallotsLength() public view returns(uint256) {
    return uintArrayStorage[ACTIVE_BALLOTS].length;
  }

  function activeBallotsAdd(uint256 _id) private {
    uintArrayStorage[ACTIVE_BALLOTS].push(_id);
  }

  function activeBallotsClear() private {
    delete uintArrayStorage[ACTIVE_BALLOTS];
  }

  function activeBallotsDecreaseLength() private {
    if (activeBallotsLength() > 0) {
      uintArrayStorage[ACTIVE_BALLOTS].length--;
    }
  }

  function activeBallotsSet(uint256 _index, uint256 _id) private {
    uintArrayStorage[ACTIVE_BALLOTS][_index] = _id;
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
    return addressStorage[PROXY_STORAGE];
  }

  function getTotalNumberOfValidators() private view returns(uint256) {
    return IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).currentValidatorsLength();
  }

  function setVoterChoice(uint256 _id, address _key, uint256 _choice) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "voters", _key))] = _choice;
  }

  function getVoterChoice(uint256 _id, address _key) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "voters", _key))];
  }

  function withinLimit(address _key) private view returns(bool) {
    return validatorActiveBallots(_key) < getBallotLimitPerValidator();
  }

  function getAccepted(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "accepted"))];
  }

  function setAccepted(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "accepted"))] = _value;
  }

  function getRejected(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "rejected"))];
  }

  function setRejected(uint256 _id, uint256 _value) private {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "rejected"))] = _value;
  }
}
