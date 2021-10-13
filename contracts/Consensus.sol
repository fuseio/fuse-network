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
    _withdraw(msg.sender, _amount, msg.sender);
  }

  /**
  * @dev Function to be called when a delegator whishes to withdraw some of his staked funds for a validator
  * @param _validator the address of the validator msg.sender has delegating to
  * @param _amount the amount msg.sender wishes to withdraw from the contract
  */
  function withdraw(address _validator, uint256 _amount) external {
    _withdraw(msg.sender, _amount, _validator);
  }

  /**
  * @dev Function to be called by the block reward contract each block to handle cycles and snapshots logic
  */
  function cycle(address _validator) external onlyBlockReward {
    _incBlockCounter(_validator);
    if (_hasCycleEnded()) {
      IVoting(ProxyStorage(getProxyStorage()).getVoting()).onCycleEnd(currentValidators());
      _setCurrentCycle();
      _checkJail(currentValidators());
      address[] memory newSet = pendingValidators();
      if (newSet.length > 0) {
        _setNewValidatorSet(newSet);
      }
      if (newValidatorSetLength() > 0) {
        _setFinalized(false);
        _setShouldEmitInitiateChange(true);
        emit ShouldEmitInitiateChange();
      }
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


  /**
  * @dev Function to be called by validators to update the validator fee, that's the fee cut the validator takes from his delegatots.
  * @param _amount fee percentage when 1e18 represents 100%.
  */
  function setValidatorFee(uint256 _amount) external onlyValidator {
    require (_amount <= 1 * DECIMALS);
    require(_amount >= getMinValidatorFee());
    _setValidatorFee(msg.sender, _amount);
  }

  function unJail() external onlyJailedValidator {
    require(getReleaseBlock(msg.sender) <= getCurrentCycleEndBlock());

    _removeFromJail(msg.sender);
  }
}
