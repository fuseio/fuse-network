pragma solidity ^0.4.24;

import "./abstracts/ValidatorSet.sol";
import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Consensus utility contract
*/
contract ConsensusUtils is EternalStorage, ValidatorSet {
  using SafeMath for uint256;

  uint256 public constant DECIMALS = 10 ** 18;
  uint256 public constant VALIDATOR_SLOTS = 100;

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
    require(msg.sender == getSystemAddress());
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

  bytes32 internal constant OWNER = keccak256(abi.encodePacked("owner"));
  bytes32 internal constant SYSTEM_ADDRESS = keccak256(abi.encodePacked("SYSTEM_ADDRESS"));
  bytes32 internal constant IS_FINALIZED = keccak256(abi.encodePacked("isFinalized"));
  bytes32 internal constant MIN_STAKE = keccak256(abi.encodePacked("minStake"));
  bytes32 internal constant CYCLE_DURATION_BLOCKS = keccak256(abi.encodePacked("cycleDurationBlocks"));
  bytes32 internal constant CURRENT_CYCLE_START_BLOCK = keccak256(abi.encodePacked("currentCycleStartBlock"));
  bytes32 internal constant CURRENT_CYCLE_END_BLOCK = keccak256(abi.encodePacked("currentCycleEndBlock"));
  bytes32 internal constant SNAPSHOTS_PER_CYCLE = keccak256(abi.encodePacked("snapshotsPerCycle"));
  bytes32 internal constant LAST_SNAPSHOT_TAKEN_AT_BLOCK = keccak256(abi.encodePacked("lastSnapshotTakenAtBlock"));
  bytes32 internal constant NEXT_SNAPSHOT_ID = keccak256(abi.encodePacked("nextSnapshotId"));
  bytes32 internal constant CURRENT_VALIDATORS = keccak256(abi.encodePacked("currentValidators"));
  bytes32 internal constant PENDING_VALIDATORS = keccak256(abi.encodePacked("pendingValidators"));
  bytes32 internal constant PROXY_STORAGE = keccak256(abi.encodePacked("proxyStorage"));
  bytes32 internal constant WAS_PROXY_STORAGE_SET = keccak256(abi.encodePacked("wasProxyStorageSet"));
  bytes32 internal constant NEW_VALIDATOR_SET = keccak256(abi.encodePacked("newValidatorSet"));
  bytes32 internal constant SHOULD_EMIT_INITIATE_CHANGE = keccak256(abi.encodePacked("shouldEmitInitiateChange"));

  function _stake(address _staker, uint256 _amount) internal {
    require(_staker != address(0));
    require(_amount != 0);

    _stakeAmountAdd(_staker, _amount);

    if (stakeAmount(_staker) >= getMinStake() && !isPendingValidator(_staker)) {
      _pendingValidatorsAdd(_staker);
    }
  }

  function _delegate(address _staker, uint256 _amount, address _validator) internal {
    require(_staker != address(0));
    require(_amount != 0);
    require(_validator != address(0));

    _delegatedAmountAdd(_staker, _validator, _amount);
    _stakeAmountAdd(_validator, _amount);

    if (stakeAmount(_validator) >= getMinStake() && !isPendingValidator(_validator)) {
      _pendingValidatorsAdd(_validator);
    }
  }

  function getValidatorSetFromSnapshot(uint256 _snapshotId) public view returns(address[]) {
    address[] memory addresses = getSnapshotAddresses(_snapshotId);
    if (addresses.length == 0) {
      return new address[](0);
    }

    uint256[] memory stakeAmounts = new uint256[](addresses.length);
    uint256 totalStakeAmount;
    for (uint256 i = 0; i < addresses.length; i++) {
      stakeAmounts[i] = getSnapshotStakeAmountForAddress(_snapshotId, addresses[i]);
      totalStakeAmount = totalStakeAmount.add(stakeAmounts[i]);
    }
    if (totalStakeAmount == 0) {
      return new address[](0);
    }

    uint256 slotAmount = (VALIDATOR_SLOTS.mul(DECIMALS.mul(DECIMALS))).div(totalStakeAmount);
    uint256[] memory slots = new uint256[](addresses.length);
    address[] memory result = new address[](VALIDATOR_SLOTS);
    uint256 index = 0;
    for (uint256 j = 0; j < addresses.length; j++) {
      slots[j] = (slotAmount.mul(stakeAmounts[j])).div(DECIMALS.mul(DECIMALS));
      for (uint256 k = 0; k < slots[j]; k++) {
        if (index.mod(addresses.length) == 0) {
          result[index] = addresses[j];
        } else {
          result[VALIDATOR_SLOTS.sub(index).sub(1)] = addresses[j];
        }
        index++;
      }
    }
    delete index;
    for (uint256 l = 0; l < VALIDATOR_SLOTS; l++) {
      if (result[l] == address(0)) {
        if (addresses.length == 1) {
          result[l] = addresses[0];
        } else {
          result[l] = addresses[getRandom(0, addresses.length - 1)];
        }
      }
    }
    return result;
  }

  function _setSystemAddress(address _newAddress) internal {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function getSystemAddress() public view returns(address) {
    return addressStorage[SYSTEM_ADDRESS];
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

  function _setMinStake(uint256 _minStake) internal {
    require(_minStake > 0);
    uintStorage[MIN_STAKE] = _minStake;
  }

  function getMinStake() public view returns(uint256) {
    return uintStorage[MIN_STAKE];
  }

  function _setCycleDurationBlocks(uint256 _cycleDurationBlocks) internal {
    require(_cycleDurationBlocks > 0);
    uintStorage[CYCLE_DURATION_BLOCKS] = _cycleDurationBlocks;
  }

  function getCycleDurationBlocks() public view returns(uint256) {
    return uintStorage[CYCLE_DURATION_BLOCKS];
  }

  function _setCurrentCycle() internal {
    uintStorage[CURRENT_CYCLE_START_BLOCK] = block.number;
    uintStorage[CURRENT_CYCLE_END_BLOCK] = block.number + getCycleDurationBlocks();
  }

  function getCurrentCycleStartBlock() external view returns(uint256) {
    return uintStorage[CURRENT_CYCLE_START_BLOCK];
  }

  function getCurrentCycleEndBlock() public view returns(uint256) {
    return uintStorage[CURRENT_CYCLE_END_BLOCK];
  }

  function _setSnapshotsPerCycle(uint256 _snapshotsPerCycle) internal {
    require(_snapshotsPerCycle > 0);
    uintStorage[SNAPSHOTS_PER_CYCLE] = _snapshotsPerCycle;
  }

  function getSnapshotsPerCycle() public view returns(uint256) {
    return uintStorage[SNAPSHOTS_PER_CYCLE];
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
    _setSnapshotAddresses(_snapshotId, _addresses);
    for (uint256 i; i < _addresses.length; i++) {
      _setSnapshotStakeAmountForAddress(_snapshotId, _addresses[i]);
    }
  }

  function _setSnapshotAddresses(uint256 _snapshotId, address[] _addresses) internal {
    addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId, "addresses"))] = _addresses;
  }

  function getSnapshotAddressesLength(uint256 _snapshotId) public view returns(uint256) {
    return addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId, "addresses"))].length;
  }

  function getSnapshotAddresses(uint256 _snapshotId) public view returns(address[]) {
    return addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId, "addresses"))];
  }

  function _setSnapshotStakeAmountForAddress(uint256 _snapshotId, address _address) internal {
    uintStorage[keccak256(abi.encodePacked("snapshot", _snapshotId, "address", _address, "stakeAmount"))] = stakeAmount(_address);
  }

  function getSnapshotStakeAmountForAddress(uint256 _snapshotId, address _address) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("snapshot", _snapshotId, "address", _address, "stakeAmount"))];
  }

  function currentValidators() public view returns(address[]) {
    return addressArrayStorage[CURRENT_VALIDATORS];
  }

  function currentValidatorsLength() public view returns(uint256) {
    return addressArrayStorage[CURRENT_VALIDATORS].length;
  }

  function currentValidatorsAtPosition(uint256 _p) public view returns(address) {
    return addressArrayStorage[CURRENT_VALIDATORS][_p];
  }

  function isValidator(address _address) public view returns(bool) {
    for (uint256 i; i < currentValidatorsLength(); i++) {
      if (_address == currentValidatorsAtPosition(i)) {
        return true;
      }
    }
    return false;
  }

  function _currentValidatorsAdd(address _address) internal {
      addressArrayStorage[CURRENT_VALIDATORS].push(_address);
  }

  function _setCurrentValidators(address[] _currentValidators) internal {
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

  function isPendingValidator(address _address) public view returns(bool) {
    for (uint256 i; i < pendingValidatorsLength(); i++) {
      if (_address == pendingValidatorsAtPosition(i)) {
        return true;
      }
    }
    return false;
  }

  function _setPendingValidatorsAtPosition(uint256 _p, address _address) internal {
    addressArrayStorage[PENDING_VALIDATORS][_p] = _address;
  }

  function _pendingValidatorsAdd(address _address) internal {
    addressArrayStorage[PENDING_VALIDATORS].push(_address);
  }

  function _pendingValidatorsRemove(address _address) internal {
    uint256 removeIndex;
    for (uint256 i; i < pendingValidatorsLength(); i++) {
      if (_address == pendingValidatorsAtPosition(i)) {
        removeIndex = i;
      }
    }
    uint256 lastIndex = pendingValidatorsLength() - 1;
    address lastValidator = pendingValidatorsAtPosition(lastIndex);
    if (lastValidator != address(0)) {
      _setPendingValidatorsAtPosition(removeIndex, lastValidator);
    }
    delete addressArrayStorage[PENDING_VALIDATORS][lastIndex];
    addressArrayStorage[PENDING_VALIDATORS].length--;
  }

  function stakeAmount(address _address) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))];
  }

  function _stakeAmountAdd(address _address, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))].add(_amount);
  }

  function _stakeAmountSub(address _address, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))].sub(_amount);
  }

  function delegatedAmount(address _address, address _validator) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))];
  }

  function _delegatedAmountAdd(address _address, address _validator, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] = uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))].add(_amount);
  }

  function _delegatedAmountSub(address _address, address _validator, uint256 _amount) internal {
    uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))] = uintStorage[keccak256(abi.encodePacked("delegatedAmount", _address, _validator))].sub(_amount);
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

  function shouldEmitInitiateChange() public view returns(bool) {
    return boolStorage[SHOULD_EMIT_INITIATE_CHANGE];
  }

  function _setShouldEmitInitiateChange(bool _status) internal {
    boolStorage[SHOULD_EMIT_INITIATE_CHANGE] = _status;
  }

  function getBlocksToSnapshot() public view returns(uint256) {
    return getCycleDurationBlocks().div(getSnapshotsPerCycle());
  }

  function shouldTakeSnapshot() public view returns(bool) {
    return (block.number - getLastSnapshotTakenAtBlock() >= getBlocksToSnapshot());
  }

  function hasCycleEnded() public view returns(bool) {
    return (block.number > getCurrentCycleEndBlock());
  }

  function getRandom(uint256 _from, uint256 _to) public view returns(uint256) {
    return uint256(keccak256(abi.encodePacked(blockhash(block.number - 1)))).mod(_to).add(_from);
  }
}
