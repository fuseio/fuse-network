pragma solidity ^0.4.24;

import "./abstracts/ValidatorSet.sol";
import "./ConsensusStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract handling PoS consensus logic
*/
contract Consensus is ConsensusStorage, ValidatorSet {
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
    require(msg.sender == systemAddress());
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
  * @param _cycleDuration time in seconds of cycle, on the end of each cycle a new validator set will be selected
  * @param _snapshotsPerCycle number of pending validator snapshots to be saved each cycle
  * @param _initialValidator address of the initial validator. If not set - msg.sender will be the initial validator
  */
  function initialize(uint256 _minStake, uint256 _cycleDuration, uint256 _snapshotsPerCycle, address _initialValidator) public returns(bool) {
    require(!isInitialized());
    setSystemAddress(0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
    setMinStake(_minStake);
    setCycleDuration(_cycleDuration);
    setCurrentCycleTimeframe();
    setSnapshotsPerCycle(_snapshotsPerCycle);
    if (_initialValidator == address(0)) {
      currentValidatorsAdd(msg.sender);
    } else {
      currentValidatorsAdd(_initialValidator);
    }
    setInitialized(true);
    return isInitialized();
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

  function _stake(address _staker, uint256 _amount) internal {
    require(_staker != address(0));
    require(_amount != 0);

    stakeAmountAdd(_staker, _amount);

    if (stakeAmount(_staker) >= getMinStake()) {
      _addValidator(_staker);
    }
  }

  function _addValidator(address _validator) internal {
    require(_validator != address(0));

    setIsValidator(_validator, true);

    uint256 stakeMultiplier = stakeAmount(_validator).div(getMinStake());
    uint256 currentAppearances = validatorIndexesLength(_validator);
    uint256 appearencesToAdd = stakeMultiplier.sub(currentAppearances);

    for (uint256 i = 0; i < appearencesToAdd; i++) {
      validatorIndexexPush(_validator, pendingValidatorsLength());
      pendingValidatorsAdd(_validator);
    }
  }

  function _removeValidator(address _validator) internal {
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

  /**
  * @dev Function to be called by the block reward contract each block to handle cycles and snapshots logic
  */
  function cycle() public onlyBlockReward {
    if (hasCycleEnded()) {
      uint randomSnapshotId = getRandom(0, getSnapshotsPerCycle() - 1);
      setNewValidatorSet(getSnapshot(randomSnapshotId));
      setFinalized(false);
      emit InitiateChange(blockhash(block.number - 1), newValidatorSet());
      setCurrentCycleTimeframe();
    } else if (shouldTakeSnapshot()) {
      uint256 snapshotId = getNextSnapshotId();
      if (snapshotId < getSnapshotsPerCycle()) {
        setNextSnapshotId(snapshotId.add(1));
      } else {
        setNextSnapshotId(0);
      }
      // TODO shuffle pending validators
      for (uint i = 0; i < pendingValidatorsLength(); i++) {
        addToSnapshot(pendingValidatorsAtPosition(i), snapshotId);
      }
      setLastSnapshotTakenTime(getTime());
    }
  }
}
