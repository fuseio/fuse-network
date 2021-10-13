pragma solidity ^0.4.24;

import "./abstracts/ValidatorSet.sol";
import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/math/Math.sol";

/**
* @title Consensus utility contract
* @author LiorRabin
*/
contract ConsensusUtils is EternalStorage, ValidatorSet {
  using SafeMath for uint256;

  uint256 public constant DECIMALS = 10 ** 18;
  uint256 public constant MAX_VALIDATORS = 100;
  uint256 public constant MIN_STAKE = 1e23; // 100,000
  uint256 public constant MAX_STAKE = 5e24; // 5,000,000
  uint256 public constant CYCLE_DURATION_BLOCKS = 34560; // 48 hours [48*60*60/5]
  uint256 public constant SNAPSHOTS_PER_CYCLE = 0; // snapshot each 288 minutes [34560/10/60*5]
  uint256 public constant DEFAULT_VALIDATOR_FEE = 15e16; // 15%
  uint256 public constant VALIDATOR_PRODUCTIVITY_BP = 3000; // 30%
  uint256 public constant MAX_STRIKE_COUNT = 5;
  uint256 public constant STRIKE_RESET = 50; // reset strikes after 50 clean cycles

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
    if (stakeAmount(_validator).sub(_amount) < getMinStake() && _isValidator) {
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
    _staker.transfer(_amount);
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
  function getMinStake() public pure returns(uint256) {
    return MIN_STAKE;
  }

  /**
  * returns maximum stake (wei) for a validator
  */
  function getMaxStake() public pure returns(uint256) {
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
  function getCycleDurationBlocks() public pure returns(uint256) {
    return CYCLE_DURATION_BLOCKS;
  }

  function _setCurrentCycle() internal {
    uintStorage[CURRENT_CYCLE_START_BLOCK] = block.number;
    uintStorage[CURRENT_CYCLE_END_BLOCK] = block.number + getCycleDurationBlocks();
  }

  function _checkJail(address[] _validatorSet) internal {
    uint256 expectedNumberOfBlocks = CYCLE_DURATION_BLOCKS.mul(VALIDATOR_PRODUCTIVITY_BP).div(_validatorSet.length).div(10000);
    for (uint i = 0; i < _validatorSet.length; i++) {
      if(blockCounter(_validatorSet[i]) < expectedNumberOfBlocks) {
        _jailVal(_validatorSet[i]);
      } else if (getStrikes(_validatorSet[i]) != 0) {
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
  function getSnapshotsPerCycle() public pure returns(uint256) {
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

  function _setSnapshot(uint256 _snapshotId, address[] _addresses) internal {
    uint256 len = _addresses.length;
    uint256 n = Math.min(getMaxValidators(), len);
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

  function _setSnapshotAddresses(uint256 _snapshotId, address[] _addresses) internal {
    addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId, "addresses"))] = _addresses;
  }

  function getSnapshotAddresses(uint256 _snapshotId) public view returns(address[]) {
    return addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId, "addresses"))];
  }

  function currentValidators() public view returns(address[]) {
    return addressArrayStorage[CURRENT_VALIDATORS];
  }

  function currentValidatorsLength() public view returns(uint256) {
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
    return currentValidatorsLength().div(2).add(1);
  }

  function _currentValidatorsAdd(address _address) internal {
    addressArrayStorage[CURRENT_VALIDATORS].push(_address);
  }

  function _setCurrentValidators(address[] _currentValidators) internal {
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

  function pendingValidators() public view returns(address[]) {
    return addressArrayStorage[PENDING_VALIDATORS];
  }

  function pendingValidatorsLength() public view returns(uint256) {
    return addressArrayStorage[PENDING_VALIDATORS].length;
  }

  function pendingValidatorsAtPosition(uint256 _p) public view returns(address) {
    return addressArrayStorage[PENDING_VALIDATORS][_p];
  }

  function jailedValidators() public view returns(address[]) {
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

  function _jailVal(address _address) internal {
    _pendingValidatorsRemove(_address);
    _addJailedVal(_address);
    _setJailRelease(_address);
    _resetStrikeReset(_address);
  }

  function _maintenance(address _address) internal {
    _pendingValidatorsRemove(_address);
    _addJailedVal(_address);
  }

  function _setPendingValidatorsAtPosition(uint256 _p, address _address) internal {
    addressArrayStorage[PENDING_VALIDATORS][_p] = _address;
  }

  function _setJailedValidatorsAtPosition(uint256 _p, address _address) internal {
    addressArrayStorage[JAILED_VALIDATORS][_p] = _address;
  }

  function _pendingValidatorsAdd(address _address) internal {
    addressArrayStorage[PENDING_VALIDATORS].push(_address);
  }

  function _addJailedVal(address _address) internal {
    addressArrayStorage[JAILED_VALIDATORS].push(_address);
  }

  function _jailedValidatorRemove(address _address) internal {
    bool found = false;
    uint256 removeIndex;
    for (uint256 i; i < jailedValidatorsLength(); i++) {
      if (_address == jailedValidatorsAtPosition(i)) {
        removeIndex = i;
        found = true;
      }
    }
    if (found) {
      uint256 lastIndex = jailedValidatorsLength() - 1;
      address lastValidator = jailedValidatorsAtPosition(lastIndex);
      if (lastValidator != address(0)) {
        _setJailedValidatorsAtPosition(removeIndex, lastValidator);
      }
      delete addressArrayStorage[JAILED_VALIDATORS][lastIndex];
      addressArrayStorage[JAILED_VALIDATORS].length--;
      // if the validator in on of the current validators
    }
  }

  function _pendingValidatorsRemove(address _address) internal {
    bool found = false;
    uint256 removeIndex;
    for (uint256 i; i < pendingValidatorsLength(); i++) {
      if (_address == pendingValidatorsAtPosition(i)) {
        removeIndex = i;
        found = true;
      }
    }
    if (found) {
      uint256 lastIndex = pendingValidatorsLength() - 1;
      address lastValidator = pendingValidatorsAtPosition(lastIndex);
      if (lastValidator != address(0)) {
        _setPendingValidatorsAtPosition(removeIndex, lastValidator);
      }
      delete addressArrayStorage[PENDING_VALIDATORS][lastIndex];
      addressArrayStorage[PENDING_VALIDATORS].length--;
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
    uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))].add(_amount);
  }

  function _stakeAmountSub(address _address, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))].sub(_amount);
  }

  function _setJailRelease(address _address) internal {
    uint256 strike = uintStorage[keccak256(abi.encodePacked("strikeCount", _address))];
    uintStorage[keccak256(abi.encodePacked("releaseBlock", _address))] = uintStorage[keccak256(abi.encodePacked("releaseBlock", _address))].add(getCurrentCycleEndBlock() + (CYCLE_DURATION_BLOCKS * strike) - 1);
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
    uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] = uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))].add(_amount);
    if (_address != _validator && !isDelegator(_validator, _address)) {
      _delegatorsAdd(_address, _validator);
    }
  }

  function _delegatedAmountSub(address _address, address _validator, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] = uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))].sub(_amount);
    if (uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] == 0) {
      _delegatorsRemove(_address, _validator);
    }
  }

  function delegators(address _validator) public view returns(address[]) {
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
      }
    }
    if (found) {
      uint256 lastIndex = delegatorsLength(_validator) - 1;
      address lastDelegator = delegatorsAtPosition(_validator, lastIndex);
      if (lastDelegator != address(0)) {
        _setDelegatorsAtPosition(_validator, removeIndex, lastDelegator);
      }
      delete addressArrayStorage[keccak256(abi.encodePacked("delegators", _validator))][lastIndex];
      addressArrayStorage[keccak256(abi.encodePacked("delegators", _validator))].length--;
    }
  }

  function getDelegatorsForRewardDistribution(address _validator, uint256 _rewardAmount) public view returns(address[], uint256[]) {
    address[] memory _delegators = delegators(_validator);
    uint256[] memory _rewards = new uint256[](_delegators.length);
    uint256 divider = Math.max(getMinStake(), stakeAmount(_validator));

    for (uint256 i; i < _delegators.length; i++) {
      uint256 _amount = delegatedAmount(delegatorsAtPosition(_validator, i), _validator);
      _rewards[i] = _rewardAmount.mul(_amount).div(divider).mul(DECIMALS - validatorFee(_validator)).div(DECIMALS);
    }

    return (_delegators, _rewards);
  }

  function newValidatorSet() public view returns(address[]) {
    return addressArrayStorage[NEW_VALIDATOR_SET];
  }

  function newValidatorSetLength() public view returns(uint256) {
    return addressArrayStorage[NEW_VALIDATOR_SET].length;
  }

  function _setNewValidatorSet(address[] _newSet) internal {
    addressArrayStorage[NEW_VALIDATOR_SET] = _newSet;
  }

  function _setTotalStakeAmount(uint256 _totalStake) internal {
    uintStorage[TOTAL_STAKE_AMOUNT] = _totalStake;
  }

  function _totalStakeAmountAdd(uint256 _stakeAmount) internal {
    uintStorage[TOTAL_STAKE_AMOUNT] = uintStorage[TOTAL_STAKE_AMOUNT].add(_stakeAmount);
  }

  function _totalStakeAmountSub(uint256 _stakeAmount) internal {
    uintStorage[TOTAL_STAKE_AMOUNT] = uintStorage[TOTAL_STAKE_AMOUNT].sub(_stakeAmount);
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
    return _getSeed().mod(_to.sub(_from)).add(_from);
  }

  function validatorFee(address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("validatorFee", _validator))];
  }

  function _setValidatorFee(address _validator, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("validatorFee", _validator))] = _amount;
  }

  function _incBlockCounter(address _validator) internal {
    uintStorage[keccak256(abi.encodePacked("blockCounter", _validator))] = uintStorage[keccak256(abi.encodePacked("blockCounter", _validator))] + 1;
  }

  function _resetBlockCounter(address _validator) internal {
    uintStorage[keccak256(abi.encodePacked("blockCounter", _validator))] = 0;
  }

  function _incStrikeReset(address _validator) internal {
    uintStorage[keccak256(abi.encodePacked("strikeReset", _validator))] = uintStorage[keccak256(abi.encodePacked("strikeReset", _validator))] + 1;
    if (uintStorage[keccak256(abi.encodePacked("strikeReset", _validator))] > STRIKE_RESET)
    {
      _resetStrikeReset(_validator);
      _resetStrikes(_validator);
    }
  }

  function _resetStrikeReset(address _validator) internal {
    uintStorage[keccak256(abi.encodePacked("strikeReset", _validator))] = 0;
  }

  function getStrikes(address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("strikeCount", _validator))];
  }
}
