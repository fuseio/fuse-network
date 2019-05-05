pragma solidity 0.4.24;

import "./IValidatorSet.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract Consensus is IValidatorSet, Ownable {
  using SafeMath for uint256;

  event ChangeFinalized(address[] newSet);

  struct ValidatorState {
    // Is this a validator.
    bool isValidator;
    // Is a validator finalized.
    bool isValidatorFinalized;
    // Indexes in the currentValidators.
    uint256[] indexes;
  }

  bool public finalized = false;
  uint256 public minStake;

  address[] public currentValidators;
  address[] public pendingValidators;
  mapping(address => ValidatorState) public validatorsState;

  mapping (address => uint256) public stakeAmount;

  modifier notFinalized() {
    require (!finalized);
    _;
  }

  constructor(uint256 _minStake) Ownable() public {
    setMinStake(_minStake);
  }

  function setMinStake(uint256 _minStake) public onlyOwner {
    require (_minStake > 0);
    minStake = _minStake;
  }

  function getValidators() public view returns(address[]) {
    return currentValidators;
  }

  function getPendingValidators() public view returns(address[]) {
    return pendingValidators;
  }

  function finalizeChange() public onlySystem notFinalized {
    finalized = true;

    for (uint256 i = 0; i < pendingValidators.length; i++) {
      ValidatorState storage state = validatorsState[pendingValidators[i]];
      if (!state.isValidatorFinalized) {
          state.isValidatorFinalized = true;
      }
    }

    currentValidators = pendingValidators;

    emit ChangeFinalized(getValidators());
  }

  function () external payable {
    _stake(msg.sender, msg.value);
  }

  function withdraw(uint256 _amount) external {
    require (_amount > 0);
    require (_amount <= stakeAmount[msg.sender]);

    stakeAmount[msg.sender] = stakeAmount[msg.sender].sub(_amount);

    _removeValidator(msg.sender);

    msg.sender.transfer(_amount);
  }

  function getStakeAmount(address _staker) public view returns(uint256) {
    return stakeAmount[_staker];
  }

  function isValidator(address _someone) public view returns(bool) {
    return validatorsState[_someone].isValidator;
  }

  function isValidatorFinalized(address _someone) public view returns(bool) {
    return validatorsState[_someone].isValidator && validatorsState[_someone].isValidatorFinalized;
  }

  function getValidatorState(address _someone) public view returns(bool, bool, uint256[]) {
    return (validatorsState[_someone].isValidator, validatorsState[_someone].isValidatorFinalized, validatorsState[_someone].indexes);
  }

  function currentValidatorsLength() public view returns(uint256) {
    return currentValidators.length;
  }

  function _stake(address _staker, uint256 _amount) internal {
    require(_staker != address(0));
    require(_amount != 0);

    stakeAmount[_staker] = stakeAmount[_staker].add(_amount);

    if (stakeAmount[_staker] >= minStake) {
      _addValidator(_staker);
    }
  }

  function _addValidator(address _validator) internal {
    require(_validator != address(0));

    ValidatorState storage state = validatorsState[_validator];
    state.isValidator = true;
    state.isValidatorFinalized = false;

    uint256 stakeMultiplier = stakeAmount[_validator].div(minStake);
    uint256 currentAppearances = state.indexes.length;
    uint256 appearencesToAdd = stakeMultiplier.sub(currentAppearances);

    for (uint256 i = 0; i < appearencesToAdd; i++) {
      state.indexes.push(pendingValidators.length);
      pendingValidators.push(_validator);
    }
    finalized = false;

    emit InitiateChange(blockhash(block.number - 1), pendingValidators);
  }

  function _removeValidator(address _validator) internal {
    require (_validator != address(0));

    ValidatorState storage state = validatorsState[_validator];
    uint256 stakeMultiplier = stakeAmount[_validator].div(minStake);
    uint256 currentAppearances = state.indexes.length;
    uint256 appearencesToRemove = currentAppearances.sub(stakeMultiplier);

    for (uint256 i = 0; i < appearencesToRemove; i++) {
      uint256 removeIndex = state.indexes[state.indexes.length - 1];
      uint256 lastIndex = pendingValidators.length - 1;
      address lastValidator = pendingValidators[lastIndex];
      if (lastValidator != address(0)) {
        pendingValidators[removeIndex] = lastValidator;
      } else {
        delete pendingValidators[removeIndex];
        pendingValidators.length--;
      }
      for (uint256 j = 0; j < validatorsState[lastValidator].indexes.length; j++) {
        if (validatorsState[lastValidator].indexes[j] == lastIndex) {
          validatorsState[lastValidator].indexes[j] = removeIndex;
        }
      }
      delete pendingValidators[lastIndex];
      pendingValidators.length--;
      delete state.indexes[state.indexes.length - 1];
      state.indexes.length--;
    }
    finalized = false;

    emit InitiateChange(blockhash(block.number - 1), pendingValidators);
  }
}
