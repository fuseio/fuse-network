
// File: contracts/interfaces/IBlockReward.sol

pragma solidity ^0.4.24;

interface IBlockReward {
    function onCycleEnd() external;
}

// File: contracts/interfaces/IVoting.sol

pragma solidity ^0.4.24;

interface IVoting {
    function onCycleEnd(address[] validators) external;
}

// File: contracts/abstracts/ValidatorSet.sol

pragma solidity ^0.4.24;

/**
 * @title Interface to be implemented by consensus contract
 * @author LiorRabin
 * @dev abstract contract
 */
contract ValidatorSet {
    /// Issue this log event to signal a desired change in validator set.
    /// This will not lead to a change in active validator set until finalizeChange is called.
    ///
    /// Only the last log event of any block can take effect.
    /// If a signal is issued while another is being finalized it may never take effect.
    ///
    /// parentHash here should be the parent block hash, or the signal will not be recognized.
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);

    /// Get current validator set (last enacted or initial if no changes ever made)
    function getValidators() external view returns(address[]);

    /// Called when an initiated change reaches finality and is activated.
    /// Only valid when msg.sender == SYSTEM_ADDRESS (EIP96, 2**160 - 2)
    ///
    /// Also called when the contract is first enabled for consensus.
    /// In this case, the "change" finalized is the activation of the initial set.
    function finalizeChange() external;
}

// File: contracts/eternal-storage/EternalStorage.sol

pragma solidity ^0.4.24;


/**
 * @title EternalStorage
 * @author LiorRabin
 * @dev This contract holds all the necessary state variables to carry out the storage of any contract and to support the upgrade functionality.
 */
contract EternalStorage {
    // Version number of the current implementation
    uint256 internal version;

    // Address of the current implementation
    address internal implementation;

    // Storage mappings
    mapping(bytes32 => uint256) internal uintStorage;
    mapping(bytes32 => string) internal stringStorage;
    mapping(bytes32 => address) internal addressStorage;
    mapping(bytes32 => bytes) internal bytesStorage;
    mapping(bytes32 => bool) internal boolStorage;
    mapping(bytes32 => int256) internal intStorage;

    mapping(bytes32 => uint256[]) internal uintArrayStorage;
    mapping(bytes32 => string[]) internal stringArrayStorage;
    mapping(bytes32 => address[]) internal addressArrayStorage;
    mapping(bytes32 => bytes[]) internal bytesArrayStorage;
    mapping(bytes32 => bool[]) internal boolArrayStorage;
    mapping(bytes32 => int256[]) internal intArrayStorage;
    mapping(bytes32 => bytes32[]) internal bytes32ArrayStorage;

    function isInitialized() public view returns(bool) {
      return boolStorage[keccak256(abi.encodePacked("isInitialized"))];
    }

    function setInitialized(bool _status) internal {
      boolStorage[keccak256(abi.encodePacked("isInitialized"))] = _status;
    }
}

// File: contracts/eternal-storage/EternalStorageProxy.sol

pragma solidity ^0.4.24;


/**
 * @title EternalStorageProxy
 * @author LiorRabin
 * @dev This proxy holds the storage of the token contract and delegates every call to the current implementation set.
 * Besides, it allows to upgrade the token's behaviour towards further implementations, and provides authorization control functionalities
 */
contract EternalStorageProxy is EternalStorage {
    /**
    * @dev This event will be emitted every time the implementation gets upgraded
    * @param version representing the version number of the upgraded implementation
    * @param implementation representing the address of the upgraded implementation
    */
    event Upgraded(uint256 version, address indexed implementation);

    /**
    * @dev This event will be emitted when ownership is renounces
    * @param previousOwner address which is renounced from ownership
    */
    event OwnershipRenounced(address indexed previousOwner);

    /**
    * @dev This event will be emitted when ownership is transferred
    * @param previousOwner address which represents the previous owner
    * @param newOwner address which represents the new owner
    */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
    * @dev This modifier verifies that msg.sender is the ProxyStorage contract
    */
    modifier onlyProxyStorage() {
      require(msg.sender == getProxyStorage());
      _;
    }

    /**
    * @dev This modifier verifies that msg.sender is the owner of the contract
    */
    modifier onlyOwner() {
      require(msg.sender == getOwner());
      _;
    }

    /**
    * @dev Constructor
    * @param _proxyStorage address representing the ProxyStorage contract
    * @param _implementation address representing the implementation contract
    */
    constructor(address _proxyStorage, address _implementation) public {
      require(_implementation != address(0));
      if (_proxyStorage != address(0)) {
        _setProxyStorage(_proxyStorage);
      } else {
        _setProxyStorage(address(this));
      }
      _setImplementation(_implementation);
      _setOwner(msg.sender);
    }

    /**
    * @dev Fallback function allowing to perform a delegatecall to the given implementation.
    * This function will return whatever the implementation call returns
    */
    // solhint-disable no-complex-fallback, no-inline-assembly
    function() payable public {
      address _impl = getImplementation();
      require(_impl != address(0));

      assembly {
        // Copy msg.data. We take full control of memory in this inline assembly
        // block because it will not return to Solidity code. We overwrite the
        // Solidity scratch pad at memory position 0
        calldatacopy(0, 0, calldatasize)

        // Call the implementation.
        // out and outsize are 0 because we don't know the size yet
        let result := delegatecall(gas, _impl, 0, calldatasize, 0, 0)

        // Copy the returned data
        returndatacopy(0, 0, returndatasize)

        switch result
        // delegatecall returns 0 on error
        case 0 { revert(0, returndatasize) }
        default { return(0, returndatasize) }
      }
    }
    // solhint-enable no-complex-fallback, no-inline-assembly

    /**
     * @dev Allows ProxyStorage contract (only) to upgrade the current implementation.
     * @param _newImplementation representing the address of the new implementation to be set.
     */
    function upgradeTo(address _newImplementation) public onlyProxyStorage returns(bool) {
      if (_newImplementation == address(0)) return false;
      if (getImplementation() == _newImplementation) return false;
      uint256 _newVersion = getVersion() + 1;
      _setVersion(_newVersion);
      _setImplementation(_newImplementation);
      emit Upgraded(_newVersion, _newImplementation);
      return true;
    }

    /**
     * @dev Allows the current owner to relinquish ownership.
     */
    function renounceOwnership() public onlyOwner {
      emit OwnershipRenounced(getOwner());
      _setOwner(address(0));
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a _newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function transferOwnership(address _newOwner) public onlyOwner {
      require(_newOwner != address(0));
      emit OwnershipTransferred(getOwner(), _newOwner);
      _setOwner(_newOwner);
    }

    function getOwner() public view returns(address) {
      return addressStorage[keccak256(abi.encodePacked("owner"))];
    }

    function _setOwner(address _owner) private {
      addressStorage[keccak256(abi.encodePacked("owner"))] = _owner;
    }

    function getVersion() public view returns(uint256) {
      return version;
    }

    function _setVersion(uint256 _newVersion) private {
      version = _newVersion;
    }

    function getImplementation() public view returns(address) {
      return implementation;
    }

    function _setImplementation(address _newImplementation) private {
      implementation = _newImplementation;
    }

    function getProxyStorage() public view returns(address) {
      return addressStorage[keccak256(abi.encodePacked("proxyStorage"))];
    }

    function _setProxyStorage(address _proxyStorage) private {
      addressStorage[keccak256(abi.encodePacked("proxyStorage"))] = _proxyStorage;
    }
}

// File: openzeppelin-solidity/contracts/math/SafeMath.sol

pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {
    int256 constant private INT256_MIN = -2**255;

    /**
    * @dev Multiplies two unsigned integers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Multiplies two signed integers, reverts on overflow.
    */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == INT256_MIN)); // This is the only case of overflow not detected by the check below

        int256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Integer division of two signed integers truncating the quotient, reverts on division by zero.
    */
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0); // Solidity only automatically asserts when dividing by 0
        require(!(b == -1 && a == INT256_MIN)); // This is the only case of overflow

        int256 c = a / b;

        return c;
    }

    /**
    * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Subtracts two signed integers, reverts on overflow.
    */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a));

        return c;
    }

    /**
    * @dev Adds two unsigned integers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Adds two signed integers, reverts on overflow.
    */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));

        return c;
    }

    /**
    * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

// File: contracts/ProxyStorage.sol

pragma solidity ^0.4.24;




/**
* @title Contract used for access and upgradeability to all network contracts
* @author LiorRabin
*/
contract ProxyStorage is EternalStorage {
  using SafeMath for uint256;

  /**
  * @dev Available contract types on the network
  */
  enum ContractTypes {
    Invalid,
    Consensus,
    BlockReward,
    ProxyStorage,
    Voting
  }

  /**
  * @dev This event will be emitted when all contract addresses have been initialized by the contract owner
  */
  event ProxyInitialized(
    address consensus,
    address blockReward,
    address voting
  );

  /**
  * @dev This event will be emitted each time a contract address is updated
  * @param contractType contract type (See ContractTypes enum)
  * @param contractAddress contract address set for the contract type
  */
  event AddressSet(uint256 contractType, address contractAddress);

  /**
  * @dev This modifier verifies that msg.sender is the owner of the contract
  */
  modifier onlyOwner() {
    require(msg.sender == addressStorage[OWNER]);
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the voting contract which implement proxy address change
  */
  modifier onlyVoting() {
    require(msg.sender == getVoting());
    _;
  }

  /**
  * @dev Function to be called on contract initialization
  * @param _consensus address of the network consensus contract
  */
  function initialize(address _consensus) external onlyOwner {
    require(!isInitialized());
    require(_consensus != address(0));
    require(_consensus != address(this));
    _setConsensus(_consensus);
    setInitialized(true);
  }

  /**
  * @dev Function to be called to initialize all available contract types addresses
  */
  function initializeAddresses(address _blockReward, address _voting) external onlyOwner {
    require(!boolStorage[PROXY_STORAGE_ADDRESSES_INITIALIZED]);

    addressStorage[BLOCK_REWARD] = _blockReward;
    addressStorage[VOTING] = _voting;

    boolStorage[PROXY_STORAGE_ADDRESSES_INITIALIZED] = true;

    emit ProxyInitialized(
      getConsensus(),
      _blockReward,
      _voting
    );
  }

  /**
  * @dev Function to be called to set specific contract type address
  * @param _contractType contract type (See ContractTypes enum)
  * @param _contractAddress contract address set for the contract type
  */
  function setContractAddress(uint256 _contractType, address _contractAddress) external onlyVoting returns(bool) {
    if (!isInitialized()) return false;
    if (_contractAddress == address(0)) return false;

    bool success = false;

    if (_contractType == uint256(ContractTypes.Consensus)) {
      success = EternalStorageProxy(getConsensus()).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.BlockReward)) {
      success = EternalStorageProxy(getBlockReward()).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.ProxyStorage)) {
      success = EternalStorageProxy(this).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.Voting)) {
      success = EternalStorageProxy(getVoting()).upgradeTo(_contractAddress);
    }

    if (success) {
      emit AddressSet(_contractType, _contractAddress);
    }
    return success;
  }

  /**
  * @dev Function checking if a contract type is valid one for proxy usage
  * @param _contractType contract type to check if valid
  */
  function isValidContractType(uint256 _contractType) external pure returns(bool) {
    return
      _contractType == uint256(ContractTypes.Consensus) ||
      _contractType == uint256(ContractTypes.BlockReward) ||
      _contractType == uint256(ContractTypes.ProxyStorage) ||
      _contractType == uint256(ContractTypes.Voting);
  }

  bytes32 internal constant OWNER = keccak256(abi.encodePacked("owner"));
  bytes32 internal constant CONSENSUS = keccak256(abi.encodePacked("consensus"));
  bytes32 internal constant BLOCK_REWARD = keccak256(abi.encodePacked("blockReward"));
  bytes32 internal constant VOTING = keccak256(abi.encodePacked("voting"));
  bytes32 internal constant PROXY_STORAGE_ADDRESSES_INITIALIZED = keccak256(abi.encodePacked("proxyStorageAddressesInitialized"));

  function _setConsensus(address _consensus) private {
    addressStorage[CONSENSUS] = _consensus;
  }

  function getConsensus() public view returns(address){
    return addressStorage[CONSENSUS];
  }

  function getBlockReward() public view returns(address){
    return addressStorage[BLOCK_REWARD];
  }

  function getVoting() public view returns(address){
    return addressStorage[VOTING];
  }
}

// File: openzeppelin-solidity/contracts/math/Math.sol

pragma solidity ^0.4.24;

/**
 * @title Math
 * @dev Assorted math operations
 */
library Math {
    /**
    * @dev Returns the largest of two numbers.
    */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
    * @dev Returns the smallest of two numbers.
    */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
    * @dev Calculates the average of two numbers. Since these are integers,
    * averages of an even and odd number cannot be represented, and will be
    * rounded down.
    */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

// File: contracts/ConsensusUtils.sol

pragma solidity ^0.4.24;






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

  function getCurrentCycleStartBlock() external view returns(uint256) {
    return uintStorage[CURRENT_CYCLE_START_BLOCK];
  }

  function getCurrentCycleEndBlock() public view returns(uint256) {
    return uintStorage[CURRENT_CYCLE_END_BLOCK];
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
    _setValidatorFee(_address, DEFAULT_VALIDATOR_FEE);
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
}

// File: contracts/Consensus.sol

pragma solidity ^0.4.24;




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
  function cycle() external onlyBlockReward {
    if (_hasCycleEnded()) {
      IVoting(ProxyStorage(getProxyStorage()).getVoting()).onCycleEnd(currentValidators());
      _setCurrentCycle();
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
}
