
pragma solidity ^0.8.0;

import "./abstracts/ValidatorSet.sol";
import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";

/**
* @title Consensus utility contract
* @author LiorRabin
*/
abstract contract ConsensusUtils is EternalStorage, ValidatorSet {
  uint256 public constant DECIMALS = 10 ** 18;
  uint256 public constant MAX_VALIDATORS = 100;
  uint256 public constant MIN_STAKE = 1e23; // 100,000
  uint256 public constant MAX_STAKE = 25e24; // 25,000,000
  uint256 public constant CYCLE_DURATION_BLOCKS = 34560; // 48 hours [48*60*60/5]
  uint256 public constant SNAPSHOTS_PER_CYCLE = 0; // snapshot each 288 minutes [34560/10/60*5]
  uint256 public constant DEFAULT_VALIDATOR_FEE = 15e16; // 15%
  uint256 public constant VALIDATOR_PRODUCTIVITY_BP = 3000; // 30%
  uint256 public constant MAX_STRIKE_COUNT = 5;
  uint256 public constant STRIKE_RESET = 50; // reset strikes after 50 clean cycles
  uint256 public constant UPGRADE_QUORUM_BP = 6600; // node version jailing only kicks in once more than 66% of validators have upgraded

  /**
  * @dev This event will be emitted after a change to the validator set has been finalized
  * @param newSet array of addresses which represent the new validator set
  */
  event ChangeFinalized(address[] newSet);

  /**
  * @dev This event will be emitted on cycle end to indicate the `emitInitiateChange` function needs to be called to apply a new validator set
  */
  event ShouldEmitInitiateChange();

  /**
  * @dev This event will be emitted when a validator reports the node version it is running
  * @param validator the reporting validator
  * @param version the reported version (encoded as major * 1e6 + minor * 1e3 + patch)
  */
  event NodeVersionReported(address indexed validator, uint256 version);

  /**
  * @dev This event will be emitted when a network upgrade is scheduled
  * @param version minimum node version required for the upgrade (0 means the scheduled upgrade was cleared)
  * @param activationBlock block at which the new spec activates
  */
  event RequiredNodeVersionSet(uint256 version, uint256 activationBlock);

  /**
  * @dev This event will be emitted when the node version check has run on the last cycle boundary before an upgrade
  * @param requiredVersion minimum node version required
  * @param upgradedCount number of current validators which reported the required version (or higher)
  * @param totalCount total number of current validators
  * @param quorumReached whether more than 66% of validators have upgraded (outdated validators only get jailed if true)
  */
  event NodeVersionCheckExecuted(uint256 requiredVersion, uint256 upgradedCount, uint256 totalCount, bool quorumReached);

  /**
  * @dev This modifier verifies that the change initiated has not been finalized yet
  */
  modifier notFinalized() {
    require(!isFinalized());
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the system address (EIP96)
  */
  modifier onlySystem() {
    require(msg.sender == addressStorage[SYSTEM_ADDRESS]);
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the owner of the contract
  */
  modifier onlyOwner() {
    require(msg.sender == addressStorage[OWNER]);
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the block reward contract
  */
  modifier onlyBlockReward() {
    require(msg.sender == ProxyStorage(getProxyStorage()).getBlockReward());
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the voting contract
  */
  modifier onlyVoting() {
    require(msg.sender == ProxyStorage(getProxyStorage()).getVoting());
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is a validator
  */
  modifier onlyValidator() {
    require(isValidator(msg.sender));
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is currently jailed
  */
  modifier onlyJailedValidator() {
    require(isJailed(msg.sender));
    _;
  }

  bytes32 internal constant OWNER = keccak256(abi.encodePacked("owner"));
  bytes32 internal constant SYSTEM_ADDRESS = keccak256(abi.encodePacked("SYSTEM_ADDRESS"));
  bytes32 internal constant IS_FINALIZED = keccak256(abi.encodePacked("isFinalized"));
  bytes32 internal constant CURRENT_CYCLE_START_BLOCK = keccak256(abi.encodePacked("currentCycleStartBlock"));
  bytes32 internal constant CURRENT_CYCLE_END_BLOCK = keccak256(abi.encodePacked("currentCycleEndBlock"));
  bytes32 internal constant LAST_SNAPSHOT_TAKEN_AT_BLOCK = keccak256(abi.encodePacked("lastSnapshotTakenAtBlock"));
  bytes32 internal constant NEXT_SNAPSHOT_ID = keccak256(abi.encodePacked("nextSnapshotId"));
  bytes32 internal constant CURRENT_VALIDATORS = keccak256(abi.encodePacked("currentValidators"));
  bytes32 internal constant PENDING_VALIDATORS = keccak256(abi.encodePacked("pendingValidators"));
  bytes32 internal constant PROXY_STORAGE = keccak256(abi.encodePacked("proxyStorage"));
  bytes32 internal constant WAS_PROXY_STORAGE_SET = keccak256(abi.encodePacked("wasProxyStorageSet"));
  bytes32 internal constant NEW_VALIDATOR_SET = keccak256(abi.encodePacked("newValidatorSet"));
  bytes32 internal constant SHOULD_EMIT_INITIATE_CHANGE = keccak256(abi.encodePacked("shouldEmitInitiateChange"));
  bytes32 internal constant TOTAL_STAKE_AMOUNT = keccak256(abi.encodePacked("totalStakeAmount"));
  bytes32 internal constant JAILED_VALIDATORS = keccak256(abi.encodePacked("jailedValidators"));
  bytes32 internal constant REQUIRED_NODE_VERSION = keccak256(abi.encodePacked("requiredNodeVersion"));
  bytes32 internal constant NODE_VERSION_ACTIVATION_BLOCK = keccak256(abi.encodePacked("nodeVersionActivationBlock"));
  bytes32 internal constant NODE_VERSION_CHECK_EXECUTED = keccak256(abi.encodePacked("nodeVersionCheckExecuted"));

  function _delegate(address _staker, uint256 _amount, address _validator) internal {
    require(_staker != address(0));
    require(_amount != 0);
    require(_validator != address(0));

    _delegatedAmountAdd(_staker, _validator, _amount);
    _stakeAmountAdd(_validator, _amount);

    // stake amount of the validator isn't greater than the max stake
    require(stakeAmount(_validator) <= getMaxStake());

    // the validator must stake himselft the minimum stake
    if (stakeAmount(_validator) >= getMinStake() && !isPendingValidator(_validator)) {
      _pendingValidatorsAdd(_validator);
      _setValidatorFee(_validator, DEFAULT_VALIDATOR_FEE);
    }

    // if _validator is one of the current validators
    if (isValidator(_validator)) {
      // the total stake needs to be adjusted for the block reward formula
      _totalStakeAmountAdd(_amount);
    }
  }

  function _withdraw(address _staker, uint256 _amount, address _validator) internal {
    require(_validator != address(0));
    require(_amount > 0);
    require(_amount <= stakeAmount(_validator));
    require(_amount <= delegatedAmount(_staker, _validator));

    bool _isValidator = isValidator(_validator);

    // if new stake amount is lesser than minStake and the validator is one of the current validators
    if (stakeAmount(_validator) - _amount < getMinStake() && _isValidator) {
      // do not withdaw the amount until the validator is in current set
      _pendingValidatorsRemove(_validator);
      return;
    }


    _delegatedAmountSub(_staker, _validator, _amount);
    _stakeAmountSub(_validator, _amount);

    // if _validator is one of the current validators
    if (_isValidator) {
      // the total stake needs to be adjusted for the block reward formula
      _totalStakeAmountSub(_amount);
    }

    // if validator is needed to be removed from pending, but not current
    if (stakeAmount(_validator) < getMinStake()) {
      _pendingValidatorsRemove(_validator);
    }
    payable(_staker).transfer(_amount);
  }

  function _setSystemAddress(address _newAddress) internal {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function setProxyStorage(address _newAddress) external onlyOwner {
    require(_newAddress != address(0));
    require(!boolStorage[WAS_PROXY_STORAGE_SET]);
    addressStorage[PROXY_STORAGE] = _newAddress;
    boolStorage[WAS_PROXY_STORAGE_SET] = true;
  }

  function getProxyStorage() public view returns(address) {
    return addressStorage[PROXY_STORAGE];
  }

  function _setFinalized(bool _status) internal {
    boolStorage[IS_FINALIZED] = _status;
  }

  function isFinalized() public view returns(bool) {
    return boolStorage[IS_FINALIZED];
  }

  /**
  * returns maximum possible validators number
  */
  function getMaxValidators() public pure returns(uint256) {
    return MAX_VALIDATORS;
  }

  /**
  * returns minimum stake (wei) needed to become a validator
  */
  function getMinStake() public pure virtual returns(uint256) {
    return MIN_STAKE;
  }

  /**
  * returns maximum stake (wei) for a validator
  */
  function getMaxStake() public pure virtual returns(uint256) {
    return MAX_STAKE;
  }

  /**
  * @dev Function returns the minimum validator fee amount in wei
    While 100% is 1e18
  */
  function getMinValidatorFee() public pure returns(uint256) {
    return DEFAULT_VALIDATOR_FEE;
  }



  /**
  * returns number of blocks per cycle (block time is 5 seconds)
  */
  function getCycleDurationBlocks() public pure virtual returns(uint256) {
    return CYCLE_DURATION_BLOCKS;
  }

  function _setCurrentCycle() internal {
    uintStorage[CURRENT_CYCLE_START_BLOCK] = block.number;
    uintStorage[CURRENT_CYCLE_END_BLOCK] = block.number + getCycleDurationBlocks();
  }

  function _checkJail(address[] memory _validatorSet) internal {
    uint256 expectedNumberOfBlocks = getCycleDurationBlocks() * VALIDATOR_PRODUCTIVITY_BP / _validatorSet.length / 10000;
    for (uint i = 0; i < _validatorSet.length; i++) {
      if(blockCounter(_validatorSet[i]) < expectedNumberOfBlocks) {
        // Validator hasn't met the desired uptime jail them and remove them from the next cycle
        _jailValidator(_validatorSet[i]);
      } else if (getStrikes(_validatorSet[i]) != 0) {
        // Validator has met desired uptime and has strikes, inc the strike reset
        _incStrikeReset(_validatorSet[i]);
      }
      //reset the block counter
      _resetBlockCounter(_validatorSet[i]);
    }
  }

  function _removeFromJail(address _validator) internal {
    _jailedValidatorRemove(_validator);
    if (stakeAmount(_validator) >= getMinStake() && !isPendingValidator(_validator)) {
      _pendingValidatorsAdd(_validator);
    }
  }

  /**
  * @dev Function to be called by validators (their node app) to report the node/spec version they are running
  * @param _version the version encoded as major * 1e6 + minor * 1e3 + patch (e.g. 6.0.3 => 6000003)
  */
  function reportNodeVersion(uint256 _version) external {
    require(_version != 0);
    uintStorage[keccak256(abi.encodePacked("nodeVersion", msg.sender))] = _version;
    emit NodeVersionReported(msg.sender, _version);
  }

  function getNodeVersion(address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("nodeVersion", _validator))];
  }

  /**
  * @dev Function to be called by the voting contract (on an accepted node version ballot) to schedule
  * a network upgrade. On the last cycle boundary before _activationBlock, current validators which
  * have not reported at least _version are jailed, provided more than 66% of the current validator
  * set has upgraded.
  * Should be scheduled at least 2 cycles before the new spec activates.
  * Calling with _version == 0 clears a scheduled upgrade.
  * @param _version minimum required node version (encoded as major * 1e6 + minor * 1e3 + patch)
  * @param _activationBlock block at which the new spec activates
  */
  function setRequiredNodeVersion(uint256 _version, uint256 _activationBlock) external onlyVoting {
    _setRequiredNodeVersion(_version, _activationBlock);
  }

  function _setRequiredNodeVersion(uint256 _version, uint256 _activationBlock) internal {
    if (_version != 0) {
      require(_activationBlock > block.number);
      uintStorage[REQUIRED_NODE_VERSION] = _version;
      uintStorage[NODE_VERSION_ACTIVATION_BLOCK] = _activationBlock;
    } else {
      uintStorage[REQUIRED_NODE_VERSION] = 0;
      uintStorage[NODE_VERSION_ACTIVATION_BLOCK] = 0;
    }
    boolStorage[NODE_VERSION_CHECK_EXECUTED] = false;
    emit RequiredNodeVersionSet(_version, _activationBlock);
  }

  function getRequiredNodeVersion() public view returns(uint256) {
    return uintStorage[REQUIRED_NODE_VERSION];
  }

  function getNodeVersionActivationBlock() public view returns(uint256) {
    return uintStorage[NODE_VERSION_ACTIVATION_BLOCK];
  }

  function isNodeVersionCheckExecuted() public view returns(bool) {
    return boolStorage[NODE_VERSION_CHECK_EXECUTED];
  }

  /**
  * Internal function called on cycle end (after _setCurrentCycle), so getCurrentCycleEndBlock() is the
  * end of the upcoming cycle. The check fires once, on the last cycle boundary before the scheduled
  * activation block, so outdated validators are excluded from the validator set which is active when
  * the new spec comes in.
  */
  function _checkNodeVersions(address[] memory _validatorSet) internal {
    uint256 required = uintStorage[REQUIRED_NODE_VERSION];
    if (required == 0 || boolStorage[NODE_VERSION_CHECK_EXECUTED]) {
      return;
    }
    if (getCurrentCycleEndBlock() < uintStorage[NODE_VERSION_ACTIVATION_BLOCK]) {
      // the upcoming cycle ends before the upgrade activates - too early to check
      return;
    }

    uint256 upgradedCount = 0;
    for (uint256 i = 0; i < _validatorSet.length; i++) {
      if (getNodeVersion(_validatorSet[i]) >= required) {
        upgradedCount++;
      }
    }

    bool quorumReached = upgradedCount * 10000 > _validatorSet.length * UPGRADE_QUORUM_BP;
    if (quorumReached) {
      for (uint256 i = 0; i < _validatorSet.length; i++) {
        if (getNodeVersion(_validatorSet[i]) < required) {
          _jailValidator(_validatorSet[i]);
        }
      }
    }
    boolStorage[NODE_VERSION_CHECK_EXECUTED] = true;
    emit NodeVersionCheckExecuted(required, upgradedCount, _validatorSet.length, quorumReached);
  }

  function getCurrentCycleStartBlock() external view returns(uint256) {
    return uintStorage[CURRENT_CYCLE_START_BLOCK];
  }

  function getCurrentCycleEndBlock() public view returns(uint256) {
    return uintStorage[CURRENT_CYCLE_END_BLOCK];
  }

  function getReleaseBlock(address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("releaseBlock", _validator))];
  }

  /**
  * returns number of pending validator snapshots to be saved each cycle
  */
  function getSnapshotsPerCycle() public pure virtual returns(uint256) {
    return SNAPSHOTS_PER_CYCLE;
  }

  function _setLastSnapshotTakenAtBlock(uint256 _block) internal {
    uintStorage[LAST_SNAPSHOT_TAKEN_AT_BLOCK] = _block;
  }

  function getLastSnapshotTakenAtBlock() public view returns(uint256) {
    return uintStorage[LAST_SNAPSHOT_TAKEN_AT_BLOCK];
  }

  function _setNextSnapshotId(uint256 _id) internal {
    uintStorage[NEXT_SNAPSHOT_ID] = _id;
  }

  function getNextSnapshotId() public view returns(uint256) {
    return uintStorage[NEXT_SNAPSHOT_ID];
  }

  function _setSnapshot(uint256 _snapshotId, address[] memory _addresses) internal {
    uint256 len = _addresses.length;
    uint256 n = _min(getMaxValidators(), len);
    address[] memory _result = new address[](n);
    uint256 rand = _getSeed();
    for (uint256 i = 0; i < n; i++) {
      uint256 j = rand % len;
      _result[i] = _addresses[j];
      _addresses[j] = _addresses[len - 1];
      delete _addresses[len - 1];
      len--;
      rand = uint256(keccak256(abi.encodePacked(rand)));
    }
    _setSnapshotAddresses(_snapshotId, _result);
  }

  function _setSnapshotAddresses(uint256 _snapshotId, address[] memory _addresses) internal {
    addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId, "addresses"))] = _addresses;
  }

  function getSnapshotAddresses(uint256 _snapshotId) public view returns(address[] memory) {
    return addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId, "addresses"))];
  }

  function currentValidators() public view returns(address[] memory) {
    return addressArrayStorage[CURRENT_VALIDATORS];
  }

  function currentValidatorsLength() public view virtual returns(uint256) {
    return addressArrayStorage[CURRENT_VALIDATORS].length;
  }

  function jailedValidatorsLength() public view returns(uint256) {
    return addressArrayStorage[JAILED_VALIDATORS].length;
  }

  function currentValidatorsAtPosition(uint256 _p) public view returns(address) {
    return addressArrayStorage[CURRENT_VALIDATORS][_p];
  }

  function jailedValidatorsAtPosition(uint256 _p) public view returns(address) {
    return addressArrayStorage[JAILED_VALIDATORS][_p];
  }

  function isValidator(address _address) public view returns(bool) {
    for (uint256 i; i < currentValidatorsLength(); i++) {
      if (_address == currentValidatorsAtPosition(i)) {
        return true;
      }
    }
    return false;
  }

  function isJailed(address _address) public view returns(bool) {
    for (uint256 i; i < jailedValidatorsLength(); i++) {
      if (_address == jailedValidatorsAtPosition(i)) {
        return true;
      }
    }
    return false;
  }

  function requiredSignatures() public view returns(uint256) {
    return currentValidatorsLength() / 2 + 1;
  }

  function _currentValidatorsAdd(address _address) internal {
    addressArrayStorage[CURRENT_VALIDATORS].push(_address);
  }

  function _setCurrentValidators(address[] memory _currentValidators) internal {
    uint256 totalStake = 0;
    for (uint i = 0; i < _currentValidators.length; i++) {
      uint256 stakedAmount = stakeAmount(_currentValidators[i]);
      totalStake = totalStake + stakedAmount;

      // setting fee on all active validators to at least minimum fee
      // needs to run only once for the existing validators
      uint _validatorFee = validatorFee(_currentValidators[i]);
      if (_validatorFee < getMinValidatorFee()) {
        _setValidatorFee(_currentValidators[i],  getMinValidatorFee());
      }
    }
    _setTotalStakeAmount(totalStake);
    addressArrayStorage[CURRENT_VALIDATORS] = _currentValidators;
  }

  function pendingValidators() public view returns(address[] memory) {
    return addressArrayStorage[PENDING_VALIDATORS];
  }

  function pendingValidatorsLength() public view returns(uint256) {
    return addressArrayStorage[PENDING_VALIDATORS].length;
  }

  function pendingValidatorsAtPosition(uint256 _p) public view returns(address) {
    return addressArrayStorage[PENDING_VALIDATORS][_p];
  }

  function jailedValidators() public view returns(address[] memory) {
    return addressArrayStorage[JAILED_VALIDATORS];
  }

  function isPendingValidator(address _address) public view returns(bool) {
    for (uint256 i; i < pendingValidatorsLength(); i++) {
      if (_address == pendingValidatorsAtPosition(i)) {
        return true;
      }
    }
    return false;
  }

  function _jailValidator(address _address) internal {
    if(!isJailed(_address))
    {
      _pendingValidatorsRemove(_address);
      _addJailedValidator(_address);
      _setJailRelease(_address);
      _resetStrikeReset(_address);
    }
  }

  function _maintenance(address _address) internal {
    _pendingValidatorsRemove(_address);
    _addJailedValidator(_address);
  }

  function _setPendingValidatorsAtPosition(uint256 _p, address _address) internal {
    addressArrayStorage[PENDING_VALIDATORS][_p] = _address;
  }

  function _setJailedValidatorsAtPosition(uint256 _p, address _address) internal {
    addressArrayStorage[JAILED_VALIDATORS][_p] = _address;
  }

  function _pendingValidatorsAdd(address _address) internal {
    require(isJailed(_address) == false);
    addressArrayStorage[PENDING_VALIDATORS].push(_address);
  }

  function _addJailedValidator(address _address) internal {
    addressArrayStorage[JAILED_VALIDATORS].push(_address);
  }

  function _jailedValidatorRemove(address _address) internal {
    bool found = false;
    uint256 removeIndex;
    do {
      found = false;
      for (uint256 i; i < jailedValidatorsLength(); i++) {
        if (_address == jailedValidatorsAtPosition(i)) {
          removeIndex = i;
          found = true;
          break;
        }
      }
      if (found) {
        uint256 lastIndex = jailedValidatorsLength() - 1;
        address lastValidator = jailedValidatorsAtPosition(lastIndex);
        if (lastValidator != address(0)) {
          _setJailedValidatorsAtPosition(removeIndex, lastValidator);
        }
        addressArrayStorage[JAILED_VALIDATORS].pop();
        // if the validator in on of the current validators
      }
    }
    while (found == true);
  }

  function _pendingValidatorsRemove(address _address) internal {
    bool found = false;
    uint256 removeIndex;
    for (uint256 i; i < pendingValidatorsLength(); i++) {
      if (_address == pendingValidatorsAtPosition(i)) {
        removeIndex = i;
        found = true;
        break;
      }
    }
    if (found) {
      uint256 lastIndex = pendingValidatorsLength() - 1;
      address lastValidator = pendingValidatorsAtPosition(lastIndex);
      if (lastValidator != address(0)) {
        _setPendingValidatorsAtPosition(removeIndex, lastValidator);
      }
      addressArrayStorage[PENDING_VALIDATORS].pop();
      // if the validator in on of the current validators
    }
  }

  function stakeAmount(address _address) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))];
  }

  function totalStakeAmount() public view returns(uint256) {
    return uintStorage[TOTAL_STAKE_AMOUNT];
  }

  function _stakeAmountAdd(address _address, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] + _amount;
  }

  function _stakeAmountSub(address _address, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] - _amount;
  }

  function _setJailRelease(address _address) internal {
    uint256 strike = uintStorage[keccak256(abi.encodePacked("strikeCount", _address))];
    // release block scales based on strikes, strikes get reset after undergoing STRIKE_RESET jail free cycles
    // subract one so they can flag to be released on start of the next cycle
    uintStorage[keccak256(abi.encodePacked("releaseBlock", _address))] = getCurrentCycleEndBlock() + getCycleDurationBlocks() * strike - 1;
    if (strike <= MAX_STRIKE_COUNT) {
      uintStorage[keccak256(abi.encodePacked("strikeCount", _address))] = strike + 1;
    }
  }

  function _resetStrikes(address _address) internal {
    uintStorage[keccak256(abi.encodePacked("strikeCount", _address))] = 0;
  }

  function delegatedAmount(address _address, address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))];
  }

  function _delegatedAmountAdd(address _address, address _validator, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] = uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] + _amount;
    if (_address != _validator && !isDelegator(_validator, _address)) {
      _delegatorsAdd(_address, _validator);
    }
  }

  function _delegatedAmountSub(address _address, address _validator, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] = uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] - _amount;
    if (uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] == 0) {
      _delegatorsRemove(_address, _validator);
    }
  }

  function delegators(address _validator) public view returns(address[] memory) {
    return addressArrayStorage[keccak256(abi.encodePacked("delegators", _validator))];
  }

  function delegatorsLength(address _validator) public view returns(uint256) {
    return addressArrayStorage[keccak256(abi.encodePacked("delegators", _validator))].length;
  }

  function delegatorsAtPosition(address _validator, uint256 _p) public view returns(address) {
    return addressArrayStorage[keccak256(abi.encodePacked("delegators", _validator))][_p];
  }

  function blockCounter(address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("blockCounter", _validator))];
  }

  function isDelegator(address _validator, address _address) public view returns(bool) {
    for (uint256 i; i < delegatorsLength(_validator); i++) {
      if (_address == delegatorsAtPosition(_validator, i)) {
        return true;
      }
    }
    return false;
  }

  function _setDelegatorsAtPosition(address _validator, uint256 _p, address _address) internal {
    addressArrayStorage[keccak256(abi.encodePacked("delegators", _validator))][_p] = _address;
  }

  function _delegatorsAdd(address _address, address _validator) internal {
    addressArrayStorage[keccak256(abi.encodePacked("delegators", _validator))].push(_address);
  }

  function _delegatorsRemove(address _address, address _validator) internal {
    bool found = false;
    uint256 removeIndex;
    for (uint256 i; i < delegatorsLength(_validator); i++) {
      if (_address == delegatorsAtPosition(_validator, i)) {
        removeIndex = i;
        found = true;
        break;
      }
    }
    if (found) {
      uint256 lastIndex = delegatorsLength(_validator) - 1;
      address lastDelegator = delegatorsAtPosition(_validator, lastIndex);
      if (lastDelegator != address(0)) {
        _setDelegatorsAtPosition(_validator, removeIndex, lastDelegator);
      }
      addressArrayStorage[keccak256(abi.encodePacked("delegators", _validator))].pop();
    }
  }

  function getDelegatorsForRewardDistribution(address _validator, uint256 _rewardAmount) public view returns(address[] memory, uint256[] memory) {
    address[] memory _delegators = delegators(_validator);
    uint256[] memory _rewards = new uint256[](_delegators.length);
    uint256 divider = _max(getMinStake(), stakeAmount(_validator));

    for (uint256 i; i < _delegators.length; i++) {
      uint256 _amount = delegatedAmount(delegatorsAtPosition(_validator, i), _validator);
      _rewards[i] = _rewardAmount * _amount / divider * (DECIMALS - validatorFee(_validator)) / DECIMALS;
    }

    return (_delegators, _rewards);
  }

  function newValidatorSet() public view returns(address[] memory) {
    return addressArrayStorage[NEW_VALIDATOR_SET];
  }

  function newValidatorSetLength() public view returns(uint256) {
    return addressArrayStorage[NEW_VALIDATOR_SET].length;
  }

  function _setNewValidatorSet(address[] memory _newSet) internal {
    addressArrayStorage[NEW_VALIDATOR_SET] = _newSet;
  }

  function _setTotalStakeAmount(uint256 _totalStake) internal {
    uintStorage[TOTAL_STAKE_AMOUNT] = _totalStake;
  }

  function _totalStakeAmountAdd(uint256 _stakeAmount) internal {
    uintStorage[TOTAL_STAKE_AMOUNT] = uintStorage[TOTAL_STAKE_AMOUNT] + _stakeAmount;
  }

  function _totalStakeAmountSub(uint256 _stakeAmount) internal {
    uintStorage[TOTAL_STAKE_AMOUNT] = uintStorage[TOTAL_STAKE_AMOUNT] - _stakeAmount;
  }

  function shouldEmitInitiateChange() public view returns(bool) {
    return boolStorage[SHOULD_EMIT_INITIATE_CHANGE];
  }

  function _setShouldEmitInitiateChange(bool _status) internal {
    boolStorage[SHOULD_EMIT_INITIATE_CHANGE] = _status;
  }

  function _hasCycleEnded() internal view returns(bool) {
    return (block.number >= getCurrentCycleEndBlock());
  }

  function _getSeed() internal view returns(uint256) {
    return uint256(keccak256(abi.encodePacked(blockhash(block.number - 1))));
  }

  function _getRandom(uint256 _from, uint256 _to) internal view returns(uint256) {
    return _getSeed() % (_to - _from) + _from;
  }

  function validatorFee(address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("validatorFee", _validator))];
  }

  function _setValidatorFee(address _validator, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("validatorFee", _validator))] = _amount;
  }

  /**
  * Internal function to be called from cycle() to increment the block counter for this validator.
  * block counter is used to assess the validators uptime in a given cycle. It is zeroed at the start of each cycle.
  */
  function _incBlockCounter(address _validator) internal {
    uintStorage[keccak256(abi.encodePacked("blockCounter", _validator))] = uintStorage[keccak256(abi.encodePacked("blockCounter", _validator))] + 1;
  }

  /**
  * Internal function to be called on cycle end to reset the block counter for a validator so we are ready for the new cycle
  */
  function _resetBlockCounter(address _validator) internal {
    uintStorage[keccak256(abi.encodePacked("blockCounter", _validator))] = 0;
  }

  /**
  * Internal function to be called each time a validator has had a clean cycle. the strike reset counter is used to reset a validator strike count
  * if it exceeds the reset threshold
  */
  function _incStrikeReset(address _validator) internal {
    uintStorage[keccak256(abi.encodePacked("strikeReset", _validator))] = uintStorage[keccak256(abi.encodePacked("strikeReset", _validator))] + 1;
    if (uintStorage[keccak256(abi.encodePacked("strikeReset", _validator))] > STRIKE_RESET)
    {
      // Strike count exceeds the reset criteria, reset the strike and reset counters back to zero.
      _resetStrikeReset(_validator);
      _resetStrikes(_validator);
    }
  }

  /**
  * Internal function to be called after a validator has had STRIKE_RESET clean cycles.
  */
  function _resetStrikeReset(address _validator) internal {
    uintStorage[keccak256(abi.encodePacked("strikeReset", _validator))] = 0;
  }

  function getStrikeReset(address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("strikeReset", _validator))];
  }

  function getStrikes(address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("strikeCount", _validator))];
  }

  function _min(uint256 a, uint256 b) internal pure returns(uint256) {
    return a < b ? a : b;
  }

  function _max(uint256 a, uint256 b) internal pure returns(uint256) {
    return a > b ? a : b;
  }
}
