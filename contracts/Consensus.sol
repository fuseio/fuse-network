pragma solidity ^0.4.24;

import "./interfaces/IBlockReward.sol";
import "./interfaces/IVoting.sol";
import "./ConsensusUtils.sol";

/**
* @title Contract handling consensus logic
* @author LiorRabin
*/
contract Consensus is ConsensusUtils {
  /**
  * @dev Function to be called on contract initialization
  * @param _initialValidator address of the initial validator. If not set - msg.sender will be the initial validator
  */
  function initialize(address _initialValidator) external onlyOwner {
    require(!isInitialized());
    _setSystemAddress(0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
    _setCurrentCycle();
    if (_initialValidator == address(0)) {
      _currentValidatorsAdd(msg.sender);
    } else {
      _currentValidatorsAdd(_initialValidator);
    }
    _setFinalized(true);
    setInitialized(true);
  }

  /**
  * @dev Function which returns the current validator addresses
  */
  function getValidators() external view returns(address[]) {
    return currentValidators();
  }

  /**
  * @dev See ValidatorSet.finalizeChange
  */
  function finalizeChange() external onlySystem notFinalized {
    if (newValidatorSetLength() > 0) {
      _setCurrentValidators(newValidatorSet());
      emit ChangeFinalized(currentValidators());
    }
    _setFinalized(true);
  }

  /**
  * @dev Fallback function allowing to pay to this contract. Whoever sends funds is considered as "staking" and wanting to become a validator.
  */
  function () external payable {
    _delegate(msg.sender, msg.value, msg.sender);
  }

  /**
  * @dev stake to become a validator.
  */
  function stake() external payable {
    _delegate(msg.sender, msg.value, msg.sender);
  }

  /**
  * @dev delegate to a validator
  * @param _validator the address of the validator msg.sender is delegating to
  */
  function delegate(address _validator) external payable {
    _delegate(msg.sender, msg.value, _validator);
  }

  /**
  * @dev Function to be called when a staker whishes to withdraw some of his staked funds
  * @param _amount the amount msg.sender wishes to withdraw from the contract
  */
  function withdraw(uint256 _amount) external {
    require(_amount > 0);
    require(_amount <= stakeAmount(msg.sender));
    require(_amount <= delegatedAmount(msg.sender, msg.sender));

    _delegatedAmountSub(msg.sender, msg.sender, _amount);
    _stakeAmountSub(msg.sender, _amount);
    if (stakeAmount(msg.sender) < getMinStake()) {
      _pendingValidatorsRemove(msg.sender);
    }

    msg.sender.transfer(_amount);
  }

  /**
  * @dev Function to be called when a delegator whishes to withdraw some of his staked funds for a validator
  * @param _validator the address of the validator msg.sender has delegating to
  * @param _amount the amount msg.sender wishes to withdraw from the contract
  */
  function withdraw(address _validator, uint256 _amount) external {
    require(_validator != address(0));
    require(_amount > 0);
    require(_amount <= stakeAmount(_validator));
    require(_amount <= delegatedAmount(msg.sender, _validator));

    _delegatedAmountSub(msg.sender, _validator, _amount);
    _stakeAmountSub(_validator, _amount);
    if (stakeAmount(_validator) < getMinStake()) {
      _pendingValidatorsRemove(_validator);
    }

    msg.sender.transfer(_amount);
  }

  /**
  * @dev Function to be called by the block reward contract each block to handle cycles and snapshots logic
  */
  function cycle() external onlyBlockReward {
    if (_shouldTakeSnapshot()) {
      uint256 snapshotId = getNextSnapshotId();
      if (snapshotId == getSnapshotsPerCycle().sub(1)) {
        _setNextSnapshotId(0);
      } else {
        _setNextSnapshotId(snapshotId.add(1));
      }
      _setSnapshot(snapshotId, pendingValidators());
      _setLastSnapshotTakenAtBlock(block.number);
      delete snapshotId;
    }
    if (_hasCycleEnded()) {
      IVoting(ProxyStorage(getProxyStorage()).getVoting()).onCycleEnd(currentValidators());
      _setCurrentCycle();
      uint256 randomSnapshotId = _getRandom(0, getSnapshotsPerCycle() - 1);
      address[] memory newSet = getSnapshotAddresses(randomSnapshotId);
      if (newSet.length > 0) {
        _setNewValidatorSet(newSet);
      }
      if (newValidatorSetLength() > 0) {
        _setFinalized(false);
        _setShouldEmitInitiateChange(true);
        emit ShouldEmitInitiateChange();
      }
      delete randomSnapshotId;
      IBlockReward(ProxyStorage(getProxyStorage()).getBlockReward()).onCycleEnd();
    }
  }

  /**
  * @dev Function to be called by validators only to emit InitiateChange event (only if `shouldEmitInitiateChange` returns true)
  */
  function emitInitiateChange() external onlyValidator {
    require(shouldEmitInitiateChange());
    require(newValidatorSetLength() > 0);
    emit InitiateChange(blockhash(block.number - 1), newValidatorSet());
    _setShouldEmitInitiateChange(false);
  }

  function setValidatorFee(uint256 _amount) external onlyValidator {
    require (_amount <= 1 * DECIMALS);
    _setValidatorFee(msg.sender, _amount);
  }
}
