pragma solidity ^0.4.24;

import "./abstracts/VotingBase.sol";
import "./eternal-storage/EternalStorage.sol";
import "./interfaces/IConsensus.sol";
import "./ProxyStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Voting utility contract
* @author LiorRabin
*/
contract VotingUtils is EternalStorage, VotingBase {
  using SafeMath for uint256;

  uint256 public constant DECIMALS = 10 ** 18;
  uint256 public constant MAX_LIMIT_OF_BALLOTS = 100;
  uint256 public constant MIN_BALLOT_DURATION_CYCLES = 2;
  uint256 public constant MAX_BALLOT_DURATION_CYCLES = 14;
  uint256 public constant MINIMUM_TURNOUT_BP = 2000; //20%

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
    require(_cyclesDuration > 0);
    require(_cyclesDuration >= getMinBallotDurationCycles());
    require(_cyclesDuration <= getMaxBallotDurationCycles());
    _;
  }

  /**
  * @dev This modifier verifies an address is valid for voting
  */
  modifier onlyValidVotingKey(address _address) {
    require(isValidVotingKey(_address));
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the consensus contract
  */
  modifier onlyConsensus() {
    require(msg.sender == ProxyStorage(getProxyStorage()).getConsensus());
    _;
  }

  bytes32 internal constant OWNER = keccak256(abi.encodePacked("owner"));
  bytes32 internal constant NEXT_BALLOT_ID = keccak256(abi.encodePacked("nextBallotId"));
  bytes32 internal constant ACTIVE_BALLOTS = keccak256(abi.encodePacked("activeBallots"));
  bytes32 internal constant PROXY_STORAGE = keccak256(abi.encodePacked("proxyStorage"));

  /**
  * @dev Function to check if a contract type is a valid network contract
  * @param _contractType contract type to check (See ProxyStorage.ContractTypes)
  */
  function validContractType(uint256 _contractType) public view returns(bool) {
    return ProxyStorage(getProxyStorage()).isValidContractType(_contractType);
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
  * @dev Function to get the number of "open" (active) ballots each validator (someone with voting rights) can have at the same time
  */
  function getBallotLimitPerValidator() public view returns(uint256) {
    uint256 validatorsCount = getTotalNumberOfValidators();
    if (validatorsCount == 0) {
      return MAX_LIMIT_OF_BALLOTS;
    }
    uint256 limit = MAX_LIMIT_OF_BALLOTS.div(validatorsCount);
    if (limit == 0) {
      limit = 1;
    }
    return limit;
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
  * @dev This function is used to check if a ballot can be finalized
  * @param _id ballot id to check
  */
  function canBeFinalized(uint256 _id) public view returns(bool) {
    if (_id >= getNextBallotId()) return false;
    if (getStartBlock(_id) > block.number) return false;
    if (getIsFinalized(_id)) return false;

    return block.number >= getEndBlock(_id);
  }

  function getProposedValue(uint256 _id) public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))];
  }

  function _setProposedValue(uint256 _id, address _value) internal {
    addressStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))] = _value;
  }

  function getContractType(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "contractType"))];
  }

  function _setContractType(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "contractType"))] = _value;
  }

  /**
  * @dev This function is used to create a ballot
  * @param _startAfterNumberOfCycles number of cycles after which the ballot should open for voting
  * @param _cyclesDuration number of cycles the ballot will remain open for voting
  * @param _description ballot text description
  */
  function _createBallot(uint256 _startAfterNumberOfCycles, uint256 _cyclesDuration, string _description) internal returns(uint256) {
    require(isInitialized());
    address creator = msg.sender;
    require(withinLimit(creator));
    uint256 ballotId = getNextBallotId();
    _setNextBallotId(ballotId.add(1));
    _setStartBlock(ballotId, _startAfterNumberOfCycles);
    _setEndBlock(ballotId, _cyclesDuration);
    _setIsFinalized(ballotId, false);
    _setQuorumState(ballotId, uint256(QuorumStates.InProgress));
    _setCreator(ballotId, creator);
    _setDescription(ballotId, _description);
    _setIndex(ballotId, activeBallotsLength());
    _setBelowTurnOut(ballotId, false);
    _activeBallotsAdd(ballotId);
    _increaseValidatorLimit(creator);
    emit BallotCreated(ballotId, creator);
    return ballotId;
  }

  function _finalize(uint256 _id) internal {
    if (!getFinalizeCalled(_id)) {
      _decreaseValidatorLimit(_id);
      _setFinalizeCalled(_id);
    }

    // check the turnout
    if (_checkTurnout(_id)) {
      if (getAccepted(_id) > getRejected(_id)) {
        if (_finalizeBallot(_id)) {
          _setQuorumState(_id, uint256(QuorumStates.Accepted));
        } else {
          return;
        }
      } else {
        _setQuorumState(_id, uint256(QuorumStates.Rejected));
      }
      _setBelowTurnOut(_id, false);
    } else {
      // didn't meet the turn out
      _setBelowTurnOut(_id, true);
      _setQuorumState(_id, uint256(QuorumStates.Rejected));
    }
    
    _deactivateBallot(_id);
    _setIsFinalized(_id, true);
    emit BallotFinalized(_id);
  }

  function _deactivateBallot(uint256 _id) internal {
    uint256 removedIndex = getIndex(_id);
    uint256 lastIndex = activeBallotsLength() - 1;
    uint256 lastBallotId = activeBallotsAtIndex(lastIndex);

    // Override the removed ballot with the last one.
    _activeBallotsSet(removedIndex, lastBallotId);

    // Update the index of the last validator.
    _setIndex(lastBallotId, removedIndex);
    _activeBallotsSet(lastIndex, 0);
    _activeBallotsDecreaseLength();
  }

  function _finalizeBallot(uint256 _id) internal returns(bool) {
    return ProxyStorage(getProxyStorage()).setContractAddress(getContractType(_id), getProposedValue(_id));
  }

  function isActiveBallot(uint256 _id) public view returns(bool) {
    return getStartBlock(_id) < block.number && block.number < getEndBlock(_id);
  }

  function getQuorumState(uint256 _id) external view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))];
  }

  function _setQuorumState(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))] = _value;
  }

  function getNextBallotId() public view returns(uint256) {
    return uintStorage[NEXT_BALLOT_ID];
  }

  function _setNextBallotId(uint256 _id) internal {
    uintStorage[NEXT_BALLOT_ID] = _id;
  }

  /**
  * returns minimum number of cycles a ballot can be open before finalization
  */
  function getMinBallotDurationCycles() public pure returns(uint256) {
    return MIN_BALLOT_DURATION_CYCLES;
  }

  /**
  * returns maximum number of cycles a ballot can be open before finalization
  */
  function getMaxBallotDurationCycles() public pure returns(uint256) {
    return MAX_BALLOT_DURATION_CYCLES;
  }

  function getStartBlock(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "startBlock"))];
  }

  function _setStartBlock(uint256 _id, uint256 _startAfterNumberOfCycles) internal {
    IConsensus consensus = IConsensus(ProxyStorage(getProxyStorage()).getConsensus());
    uint256 cycleDurationBlocks = consensus.getCycleDurationBlocks();
    uint256 currentCycleEndBlock = consensus.getCurrentCycleEndBlock();
    uint256 startBlock = currentCycleEndBlock.add(_startAfterNumberOfCycles.mul(cycleDurationBlocks));
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "startBlock"))] = startBlock;
  }

  function getEndBlock(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "endBlock"))];
  }

  function _setEndBlock(uint256 _id, uint256 _cyclesDuration) internal {
    uint256 cycleDurationBlocks = IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).getCycleDurationBlocks();
    uint256 startBlock = getStartBlock(_id);
    uint256 endBlock = startBlock.add(_cyclesDuration.mul(cycleDurationBlocks));
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "endBlock"))] = endBlock;
  }

  function getIsFinalized(uint256 _id) public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("votingState", _id, "isFinalized"))];
  }

  function _setIsFinalized(uint256 _id, bool _value) internal {
    boolStorage[keccak256(abi.encodePacked("votingState", _id, "isFinalized"))] = _value;
  }

  function getBelowTurnOut(uint256 _id) public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("votingState", _id, "belowTurnOut"))];
  }

  function _setBelowTurnOut(uint256 _id, bool _value) internal {
    boolStorage[keccak256(abi.encodePacked("votingState", _id, "belowTurnOut"))] = _value;
  }

  function getDescription(uint256 _id) public view returns(string) {
    return stringStorage[keccak256(abi.encodePacked("votingState", _id, "description"))];
  }

  function _setDescription(uint256 _id, string _value) internal {
    stringStorage[keccak256(abi.encodePacked("votingState", _id, "description"))] = _value;
  }

  function getCreator(uint256 _id) public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("votingState", _id, "creator"))];
  }

  function _setCreator(uint256 _id, address _value) internal {
    addressStorage[keccak256(abi.encodePacked("votingState", _id, "creator"))] = _value;
  }

  function getIndex(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "index"))];
  }

  function _setIndex(uint256 _id, uint256 _value) internal {
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

  function _activeBallotsAdd(uint256 _id) internal {
    uintArrayStorage[ACTIVE_BALLOTS].push(_id);
  }

  function _activeBallotsDecreaseLength() internal {
    if (activeBallotsLength() > 0) {
      uintArrayStorage[ACTIVE_BALLOTS].length--;
    }
  }

  function _activeBallotsSet(uint256 _index, uint256 _id) internal {
    uintArrayStorage[ACTIVE_BALLOTS][_index] = _id;
  }

  function validatorActiveBallots(address _key) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("validatorActiveBallots", _key))];
  }

  function _setValidatorActiveBallots(address _key, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("validatorActiveBallots", _key))] = _value;
  }

  function _increaseValidatorLimit(address _key) internal {
    _setValidatorActiveBallots(_key, validatorActiveBallots(_key).add(1));
  }

  function _decreaseValidatorLimit(uint256 _id) internal {
    address key = getCreator(_id);
    uint256 ballotsCount = validatorActiveBallots(key);
    if (ballotsCount > 0) {
      _setValidatorActiveBallots(key, ballotsCount - 1);
    }
  }

  function getFinalizeCalled(uint256 _id) public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("finalizeCalled", _id))];
  }

  function _setFinalizeCalled(uint256 _id) internal {
    boolStorage[keccak256(abi.encodePacked("finalizeCalled", _id))] = true;
  }

  function getProxyStorage() public view returns(address) {
    return addressStorage[PROXY_STORAGE];
  }

  function getTotalNumberOfValidators() internal view returns(uint256) {
    return IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).currentValidatorsLength();
  }

  function getStake(address _key) internal view returns(uint256) {
    return IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).stakeAmount(_key);
  }

  function _setVoterChoice(uint256 _id, address _key, uint256 _choice) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "voters", _key))] = _choice;
  }

  function getVoterChoice(uint256 _id, address _key) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "voters", _key))];
  }

  function withinLimit(address _key) internal view returns(bool) {
    return validatorActiveBallots(_key) < getBallotLimitPerValidator();
  }

  function getAccepted(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "accepted"))];
  }

  function _setAccepted(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "accepted"))] = _value;
  }

  function getRejected(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "rejected"))];
  }

  function _setRejected(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "rejected"))] = _value;
  }

  function getTotalStake(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "totalStake"))];
  }

  function _setTotalStake(uint256 _id) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "totalStake"))] = IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).totalStakeAmount();
  }

  function _checkTurnout(uint256 _id) internal view returns(bool) {
    uint256 stake = getTotalStake(_id);
    uint256 minTurnout = stake * MINIMUM_TURNOUT_BP / 10000;

    uint256 totalVotedFor = getAccepted(_id);

    return totalVotedFor > minTurnout;
  }
}
