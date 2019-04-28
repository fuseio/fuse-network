pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Consensus {
  using SafeMath for uint256;

  event InitiateChange(bytes32 indexed parentHash, address[] newSet);
  event ChangeFinalized(address[] newSet);

  struct ValidatorState {
    // Is this a validator.
    bool isValidator;
    // Is a validator finalized.
    bool isValidatorFinalized;
    // Index in the currentValidators.
    uint256 index;
  }

  address public SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

  bool public finalized = false;
  address public owner;
  uint256 public minStake;

  address[] public currentValidators;
  address[] public pendingValidators;
  mapping(address => ValidatorState) public validatorsState;

  mapping (address => uint256) public stakeAmount;

  modifier onlySystem() {
    require(msg.sender == SYSTEM_ADDRESS);
    _;
  }

  modifier onlyOwner() {
    require (msg.sender == owner);
    _;
  }

  modifier notFinalized() {
    require (!finalized);
    _;
  }

  constructor(uint256 _minStake) public {
    owner = msg.sender;
    require (_minStake > 0);
    setMinStake(_minStake);
  }

  function setMinStake(uint256 _minStake) public onlyOwner {
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

  function getStakeAmount(address _staker) public view returns(uint256) {
    return stakeAmount[_staker];
  }

  function isValidator(address _someone) public view returns(bool) {
    return validatorsState[_someone].isValidator;
  }

  function isValidatorFinalized(address _someone) public view returns(bool) {
    return validatorsState[_someone].isValidator && validatorsState[_someone].isValidatorFinalized;
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
    require(!isValidator(_validator));

    validatorsState[_validator] = ValidatorState({
      isValidator: true,
      isValidatorFinalized: false,
      index: pendingValidators.length
    });
    pendingValidators.push(_validator);
    finalized = false;
    emit InitiateChange(blockhash(block.number - 1), pendingValidators);
  }
}
