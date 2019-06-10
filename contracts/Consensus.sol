pragma solidity ^0.4.24;

import "./abstracts/ValidatorSet.sol";
import "./interfaces/IConsensus.sol";
import "./interfaces/IVoting.sol";
import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract handling PoS consensus logic
*/
contract Consensus is EternalStorage, ValidatorSet, IConsensus {
  using SafeMath for uint256;

  /**
  * @dev This event will be emitted after a change to the validator set has been finalized
  * @param newSet array of addresses which represent the new validator set
  */
  event ChangeFinalized(address[] newSet);

  /**
  * @dev This modifier verifies that the change initiated has not been finalized yet
  */
  modifier notFinalized() {
    require (!isFinalized());
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
    require(msg.sender == addressStorage[keccak256(abi.encodePacked("owner"))]);
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the block reward contract
  */
  modifier onlyBlockReward() {
    require (msg.sender == ProxyStorage(getProxyStorage()).getBlockReward());
    _;
  }

  /**
  * @dev Function to be called on contract initialization
  * @param _minStake minimum stake needed to become a validator
  * @param _cycleDurationBlocks number of blocks per cycle, on the end of each cycle a new validator set will be selected
  * @param _snapshotsPerCycle number of pending validator snapshots to be saved each cycle
  * @param _initialValidator address of the initial validator. If not set - msg.sender will be the initial validator
  */
  function initialize(uint256 _minStake, uint256 _cycleDurationBlocks, uint256 _snapshotsPerCycle, address _initialValidator) public onlyOwner {
    require(!isInitialized());
    setSystemAddress(0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
    setMinStake(_minStake);
    setCycleDurationBlocks(_cycleDurationBlocks);
    setCurrentCycle();
    setSnapshotsPerCycle(_snapshotsPerCycle);
    if (_initialValidator == address(0)) {
      currentValidatorsAdd(msg.sender);
    } else {
      currentValidatorsAdd(_initialValidator);
    }
    setInitialized(true);
  }

  /**
  * @dev Function which returns the current validator addresses
  */
  function getValidators() public view returns(address[]) {
    return currentValidators();
  }

  /**
  * @dev Function which returns the pending validator addresses (candidates for becoming validators)
  */
  function getPendingValidators() public view returns(address[]) {
    return pendingValidators();
  }

  /**
  * @dev See ValidatorSet.finalizeChange
  */
  function finalizeChange() public onlySystem notFinalized {
    if (newValidatorSetLength() > 0) {
      setCurrentValidators(newValidatorSet());
    }

    setFinalized(true);

    emit ChangeFinalized(getValidators());
  }

  /**
  * @dev Fallback function allowing to pay to this contract. Whoever sends funds is considered as "staking" and wanting to become a validator.
  */
  function () external payable {
    _stake(msg.sender, msg.value);
  }

  /**
  * @dev Function to be called when a staker whishes to withdraw some of his staked funds
  * @param _amount the amount msg.sender wishes to withdraw from the contract
  */
  function withdraw(uint256 _amount) external {
    require (_amount > 0);
    require (_amount <= stakeAmount(msg.sender));

    stakeAmountSub(msg.sender, _amount);

    _removeValidator(msg.sender);

    msg.sender.transfer(_amount);
  }

  /**
  * @dev Function to get the validator state of an address
  * @param _someone address to check its validator state
  */
  function getValidatorState(address _someone) public view returns(bool, uint256[]) {
    return (isValidator(_someone), validatorIndexes(_someone));
  }

  /**
  * @dev Function to be called by the block reward contract each block to handle cycles and snapshots logic
  */
  function cycle() external onlyBlockReward {
    if (hasCycleEnded()) {
      IVoting(ProxyStorage(getProxyStorage()).getVoting()).onCycleEnd(currentValidators());
      uint256 randomSnapshotId = getRandom(0, getSnapshotsPerCycle() - 1);
      setNewValidatorSet(getSnapshot(randomSnapshotId));
      setFinalized(false);
      emit InitiateChange(blockhash(block.number - 1), newValidatorSet());
      setCurrentCycle();
    } else if (shouldTakeSnapshot()) {
      uint256 snapshotId = getNextSnapshotId();
      if (snapshotId < getSnapshotsPerCycle()) {
        setNextSnapshotId(snapshotId.add(1));
      } else {
        setNextSnapshotId(0);
      }
      for (uint256 i = 0; i < pendingValidatorsLength(); i++) {
        addToSnapshot(pendingValidatorsAtPosition(i), snapshotId);
      }
      setLastSnapshotTakenAtBlock(getCurrentBlockNumber());
    }
  }

  function _stake(address _staker, uint256 _amount) private {
    require(_staker != address(0));
    require(_amount != 0);

    stakeAmountAdd(_staker, _amount);

    if (stakeAmount(_staker) >= getMinStake()) {
      _addValidator(_staker);
    }
  }

  function _addValidator(address _validator) private {
    require(_validator != address(0));

    uint256 stakeMultiplier = stakeAmount(_validator).div(getMinStake());
    uint256 currentAppearances = validatorIndexesLength(_validator);
    uint256 appearencesToAdd = stakeMultiplier.sub(currentAppearances);

    for (uint256 i = 0; i < appearencesToAdd; i++) {
      validatorIndexexPush(_validator, pendingValidatorsLength());
      pendingValidatorsAdd(_validator);
    }
  }

  function _removeValidator(address _validator) private {
    require (_validator != address(0));

    uint256 stakeMultiplier = stakeAmount(_validator).div(getMinStake());
    uint256 currentAppearances = validatorIndexesLength(_validator);
    uint256 appearencesToRemove = currentAppearances.sub(stakeMultiplier);

    for (uint256 i = 0; i < appearencesToRemove; i++) {
      uint256 removeIndex = validatorIndexesAtPosition(_validator, validatorIndexesLength(_validator) - 1);
      uint256 lastIndex = pendingValidatorsLength() - 1;
      address lastValidator = pendingValidatorsAtPosition(lastIndex);
      if (lastValidator != address(0)) {
        setPendingValidatorsAtPosition(removeIndex, lastValidator);
      } else {
        pendingValidatorsRemove(removeIndex);
      }
      for (uint256 j = 0; j < validatorIndexesLength(lastValidator); j++) {
        if (validatorIndexesAtPosition(lastValidator, j) == lastIndex) {
          setValidatorIndexesAtPosition(lastValidator, j, removeIndex);
        }
      }
      pendingValidatorsRemove(lastIndex);
      deleteValidatorIndexesAtPosition(_validator, validatorIndexesLength(_validator) - 1);
    }
  }

  function getCurrentBlockNumber() public view returns(uint256) {
    return block.number;
  }

  function setSystemAddress(address _newAddress) private {
    addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = _newAddress;
  }

  function getSystemAddress() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))];
  }

  function setFinalized(bool _status) private {
    boolStorage[keccak256(abi.encodePacked("isFinalized"))] = _status;
  }

  function isFinalized() public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("isFinalized"))];
  }

  function setMinStake(uint256 _minStake) private {
    require(_minStake > 0);
    uintStorage[keccak256(abi.encodePacked("minStake"))] = _minStake;
  }

  function getMinStake() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("minStake"))];
  }

  function setCycleDurationBlocks(uint256 _cycleDurationBlocks) private {
    require(_cycleDurationBlocks > 0);
    uintStorage[keccak256(abi.encodePacked("cycleDurationBlocks"))] = _cycleDurationBlocks;
  }

  function getCycleDurationBlocks() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("cycleDurationBlocks"))];
  }

  function setCurrentCycle() private {
    setCurrentCycleStartBlock(getCurrentBlockNumber());
    setCurrentCycleEndBlock(getCurrentBlockNumber() + getCycleDurationBlocks());
  }

  function setCurrentCycleStartBlock(uint256 _block) private {
    uintStorage[keccak256(abi.encodePacked("currentCycleStartBlock"))] = _block;
  }

  function getCurrentCycleStartBlock() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("currentCycleStartBlock"))];
  }

  function setCurrentCycleEndBlock(uint256 _block) private {
    uintStorage[keccak256(abi.encodePacked("currentCycleEndBlock"))] = _block;
  }

  function getCurrentCycleEndBlock() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("currentCycleEndBlock"))];
  }

  function hasCycleEnded() public view returns(bool) {
    return (getCurrentBlockNumber() >= getCurrentCycleEndBlock());
  }

  function setSnapshotsPerCycle(uint256 _snapshotsPerCycle) internal {
    require(_snapshotsPerCycle > 0);
    uintStorage[keccak256(abi.encodePacked("snapshotsPerCycle"))] = _snapshotsPerCycle;
  }

  function getSnapshotsPerCycle() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("snapshotsPerCycle"))];
  }

  function setLastSnapshotTakenAtBlock(uint256 _block) private {
    uintStorage[keccak256(abi.encodePacked("lastSnapshotTakenAtBlock"))] = _block;
  }

  function getLastSnapshotTakenAtBlock() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("lastSnapshotTakenAtBlock"))];
  }

  function setNextSnapshotId(uint256 _id) private {
    uintStorage[keccak256(abi.encodePacked("nextSnapshotId"))] = _id;
  }

  function getNextSnapshotId() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("nextSnapshotId"))];
  }

  function addToSnapshot(address _address, uint256 _snapshotId) internal {
    addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId))].push(_address);
  }

  function getSnapshot(uint256 _snapshotId) public view returns(address[]) {
    return addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId))];
  }

  function getBlocksToSnapshot() public view returns(uint256) {
    return getCycleDurationBlocks().div(getSnapshotsPerCycle());
  }

  function shouldTakeSnapshot() public view returns(bool) {
    return (getCurrentBlockNumber() - getLastSnapshotTakenAtBlock() >= getBlocksToSnapshot());
  }

  function getRandom(uint256 _from, uint256 _to) public view returns(uint256) {
    return uint256(keccak256(abi.encodePacked(blockhash(block.number - 1)))).mod(_to).add(_from);
  }

  function currentValidators() public view returns(address[]) {
    return addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))];
  }

  function currentValidatorsLength() public view returns(uint256) {
    return addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))].length;
  }

  function currentValidatorsAtPosition(uint256 _p) public view returns(address) {
    return addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))][_p];
  }

  function currentValidatorsAdd(address _address) private {
      addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))].push(_address);
  }

  function setCurrentValidators(address[] _currentValidators) private {
    addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))] = _currentValidators;
  }

  function pendingValidators() public view returns(address[]) {
    return addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))];
  }

  function pendingValidatorsLength() public view returns(uint256) {
    return addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))].length;
  }

  function pendingValidatorsAtPosition(uint256 _p) public view returns(address) {
    return addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))][_p];
  }

  function setPendingValidatorsAtPosition(uint256 _p, address _address) private {
    addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))][_p] = _address;
  }

  function pendingValidatorsAdd(address _address) private {
    addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))].push(_address);
  }

  function pendingValidatorsRemove(uint256 _index) private {
    delete addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))][_index];
    addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))].length--;
  }

  function setPendingValidators(address[] _pendingValidators) private {
    addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))] = _pendingValidators;
  }

  function stakeAmount(address _address) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))];
  }

  function stakeAmountAdd(address _address, uint256 _amount) private {
    uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))].add(_amount);
  }

  function stakeAmountSub(address _address, uint256 _amount) private {
    uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))].sub(_amount);
  }

  function setStakeAmount(address _address, uint256 _amount) private {
    uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = _amount;
  }

  function isValidator(address _address) public view returns(bool) {
    for (uint256 i = 0; i < currentValidatorsLength(); i++) {
      if (_address == currentValidatorsAtPosition(i)) {
        return true;
      }
    }
    return false;
  }

  function validatorIndexes(address _address) public view returns(uint256[]) {
    return uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))];
  }

  function validatorIndexesLength(address _address) public view returns(uint256) {
    return uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))].length;
  }

  function validatorIndexesAtPosition(address _address, uint256 _p) public view returns(uint256) {
    return uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))][_p];
  }

  function setValidatorIndexesAtPosition(address _address, uint256 _p, uint256 _i) private {
    uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))][_p] = _i;
  }

  function deleteValidatorIndexesAtPosition(address _address, uint256 _p) private {
    delete uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))][_p];
    uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))].length--;
  }

  function validatorIndexexPush(address _address, uint256 _i) private {
    uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))].push(_i);
  }

  function setValidatorIndexes(address _address, uint256[] _indexes) private {
    uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))] = _indexes;
  }

  function getProxyStorage() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("proxyStorage"))];
  }

  function setProxyStorage(address _newAddress) public onlyOwner {
    require(_newAddress != address(0));
    require(!boolStorage[keccak256(abi.encodePacked("wasProxyStorageSet"))]);
    addressStorage[keccak256(abi.encodePacked("proxyStorage"))] = _newAddress;
    boolStorage[keccak256(abi.encodePacked("wasProxyStorageSet"))] = true;
  }

  function newValidatorSet() public view returns(address[]) {
    return addressArrayStorage[keccak256(abi.encodePacked("newValidatorSet"))];
  }

  function newValidatorSetLength() public view returns(uint256) {
    return addressArrayStorage[keccak256(abi.encodePacked("newValidatorSet"))].length;
  }

  function setNewValidatorSet(address[] _newSet) private {
    addressArrayStorage[keccak256(abi.encodePacked("newValidatorSet"))] = _newSet;
  }
}
