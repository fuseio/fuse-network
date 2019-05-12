pragma solidity ^0.4.24;

import "./BasicConsensus.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Consensus is BasicConsensus {
  using SafeMath for uint256;

  event ChangeFinalized(address[] newSet);

  modifier notFinalized() {
    require (!isFinalized());
    _;
  }

  modifier onlySystem() {
    require(msg.sender == systemAddress());
    _;
  }

  function initialize(uint256 _minStake, address _initialValidator, address _owner) public returns(bool){
    require(!isInitialized());
    require(_owner != address(0));
    setSystemAddress();
    setOwner(_owner);
    setMinStake(_minStake);
    if (_initialValidator == address(0)) {
      currentValidatorsAdd(_owner);
    } else {
      currentValidatorsAdd(_initialValidator);
    }
    setInitialized(true);
    return isInitialized();
  }

  function getValidators() public view returns(address[]) {
    return currentValidators();
  }

  function getPendingValidators() public view returns(address[]) {
    return pendingValidators();
  }

  function finalizeChange() public onlySystem notFinalized {
    setFinalized(true);

    for (uint256 i = 0; i < pendingValidatorsLength(); i++) {
      address pendingValidator = pendingValidatorsAtPosition(i);
      if (!isValidatorFinalized(pendingValidator)) {
        setIsValidatorFinalized(pendingValidator, true);
      }
    }

    if (pendingValidatorsLength() > 0) {
      setCurrentValidators(pendingValidators());
    }

    emit ChangeFinalized(getValidators());
  }

  function () external payable {
    _stake(msg.sender, msg.value);
  }

  function withdraw(uint256 _amount) external {
    require (_amount > 0);
    require (_amount <= stakeAmount(msg.sender));

    stakeAmountSub(msg.sender, _amount);

    _removeValidator(msg.sender);

    msg.sender.transfer(_amount);
  }


  function getValidatorState(address _someone) public view returns(bool, bool, uint256[]) {
    return (isValidator(_someone), isValidatorFinalized(_someone), validatorIndexes(_someone));
  }

  function _stake(address _staker, uint256 _amount) internal {
    require(_staker != address(0));
    require(_amount != 0);

    stakeAmountAdd(_staker, _amount);

    if (stakeAmount(_staker) >= minStake()) {
      _addValidator(_staker);
    }
  }

  function _addValidator(address _validator) internal {
    require(_validator != address(0));

    setIsValidator(_validator, true);
    setIsValidatorFinalized(_validator, false);

    uint256 stakeMultiplier = stakeAmount(_validator).div(minStake());
    uint256 currentAppearances = validatorIndexesLength(_validator);
    uint256 appearencesToAdd = stakeMultiplier.sub(currentAppearances);

    for (uint256 i = 0; i < appearencesToAdd; i++) {
      validatorIndexexPush(_validator, pendingValidatorsLength());
      pendingValidatorsAdd(_validator);
    }

    setFinalized(false);

    emit InitiateChange(blockhash(block.number - 1), pendingValidators());
  }

  function _removeValidator(address _validator) internal {
    require (_validator != address(0));

    uint256 stakeMultiplier = stakeAmount(_validator).div(minStake());
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

    require(pendingValidatorsLength() > 0);

    setFinalized(false);

    emit InitiateChange(blockhash(block.number - 1), pendingValidators());
  }
}
