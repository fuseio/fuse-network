
// File: contracts/abstracts/BlockRewardBase.sol

pragma solidity ^0.4.24;

/**
 * @title Interface to be implemented by block reward contract
 * @author LiorRabin
 * @dev abstract contract
 */
contract BlockRewardBase {
    // Produce rewards for the given benefactors, with corresponding reward codes.
    // Only valid when msg.sender == SYSTEM_ADDRESS (EIP96, 2**160 - 2)
    function reward(address[] benefactors, uint16[] kind) external returns (address[], uint256[]);
}

// File: contracts/interfaces/IConsensus.sol

pragma solidity ^0.4.24;

interface IConsensus {
    function currentValidatorsLength() external view returns(uint256);
    function currentValidatorsAtPosition(uint256 _p) external view returns(address);
    function getCycleDurationBlocks() external view returns(uint256);
    function getCurrentCycleEndBlock() external view returns(uint256);
    function cycle() external;
    function isValidator(address _address) external view returns(bool);
    function getDelegatorsForRewardDistribution(address _validator, uint256 _rewardAmount) external view returns(address[], uint256[]);
    function isFinalized() external view returns(bool);
    function stakeAmount(address _address) external view returns(uint256);
    function totalStakeAmount() external view returns(uint256);
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

// File: contracts/BlockReward.sol

pragma solidity ^0.4.24;






/**
* @title Contract handling block reward logic
* @author LiorRabin
*/
contract BlockReward is EternalStorage, BlockRewardBase {
  using SafeMath for uint256;

  uint256 public constant DECIMALS = 10 ** 18;
  uint256 public constant INFLATION = 5;
  uint256 public constant BLOCKS_PER_YEAR = 6307200;

  /**
  * @dev This event will be emitted every block, describing the rewards given
  * @param receivers array of addresses to reward
  * @param rewards array of balance increases corresponding to the receivers array
  */
  event Rewarded(address[] receivers, uint256[] rewards);

  /**
  * @dev This event will be emitted on cycle end, describing the amount of rewards distributed on the cycle
  * @param amount total rewards distributed on this cycle
  */
  event RewardedOnCycle(uint256 amount);

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
  * @dev This modifier verifies that msg.sender is the consensus contract
  */
  modifier onlyConsensus() {
    require(msg.sender == ProxyStorage(getProxyStorage()).getConsensus());
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is a validator
  */
  modifier onlyValidator() {
    require(IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).isValidator(msg.sender));
    _;
  }

  /**
  * @dev Function to be called on contract initialization
  */
  function initialize(uint256 _supply) external onlyOwner {
    require(!isInitialized());
    _setSystemAddress(0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
    _setTotalSupply(_supply);
    _initRewardedOnCycle();
    _setBlockRewardAmount();
    setInitialized(true);
  }

  /**
  * @dev Function called to produce the reward on each block
  * @param benefactors array of addresses representing benefectors to be considered for reward
  * @param kind array of reward types. We support only arrays with one item and type = 0 (Author - Reward attributed to the block author)
  * See https://wiki.parity.io/Block-Reward-Contract.html
  */
  function reward(address[] benefactors, uint16[] kind) external onlySystem returns (address[], uint256[]) {
    require(benefactors.length == kind.length);
    require(benefactors.length == 1);
    require(kind[0] == 0);

    uint256 blockRewardAmount = getBlockRewardAmountPerValidator(benefactors[0]);

    (address[] memory _delegators, uint256[] memory _rewards) = IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).getDelegatorsForRewardDistribution(benefactors[0], blockRewardAmount);

    address[] memory receivers = new address[](_delegators.length + 1);
    uint256[] memory rewards = new uint256[](receivers.length);

    receivers[0] = benefactors[0];
    rewards[0] = blockRewardAmount;
    for (uint256 i = 1; i <= _delegators.length; i++) {
      receivers[i] = _delegators[i - 1];
      rewards[i] = _rewards[i - 1];
      rewards[0] = rewards[0].sub(rewards[i]);
    }

    _setRewardedOnCycle(getRewardedOnCycle().add(blockRewardAmount));
    _setTotalSupply(getTotalSupply().add(blockRewardAmount));

    if ((block.number).mod(getBlocksPerYear()) == 0) {
      _setBlockRewardAmount();
    }

    IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).cycle();

    emit Rewarded(receivers, rewards);
    return (receivers, rewards);
  }

  function onCycleEnd() external onlyConsensus {
    _setShouldEmitRewardedOnCycle(true);
  }

  /**
  * @dev Function to be called by validators only to emit RewardedOnCycle event (only if `shouldEmitRewardedOnCycle` returns true)
  */
  function emitRewardedOnCycle() external onlyValidator {
    require(shouldEmitRewardedOnCycle());
    emit RewardedOnCycle(getRewardedOnCycle());
    _setShouldEmitRewardedOnCycle(false);
    _setRewardedOnCycle(0);
  }

  bytes32 internal constant OWNER = keccak256(abi.encodePacked("owner"));
  bytes32 internal constant SYSTEM_ADDRESS = keccak256(abi.encodePacked("SYSTEM_ADDRESS"));
  bytes32 internal constant PROXY_STORAGE = keccak256(abi.encodePacked("proxyStorage"));
  bytes32 internal constant TOTAL_SUPPLY = keccak256(abi.encodePacked("totalSupply"));
  bytes32 internal constant REWARDED_THIS_CYCLE = keccak256(abi.encodePacked("rewardedOnCycle"));
  bytes32 internal constant BLOCK_REWARD_AMOUNT = keccak256(abi.encodePacked("blockRewardAmount"));
  bytes32 internal constant SHOULD_EMIT_REWARDED_ON_CYCLE = keccak256(abi.encodePacked("shouldEmitRewardedOnCycle"));

  function _setSystemAddress(address _newAddress) private {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function _setTotalSupply(uint256 _supply) private {
    require(_supply >= 0);
    uintStorage[TOTAL_SUPPLY] = _supply;
  }

  function getTotalSupply() public view returns(uint256) {
    return uintStorage[TOTAL_SUPPLY];
  }

  function _initRewardedOnCycle() private {
    _setRewardedOnCycle(0);
  }

  function _setRewardedOnCycle(uint256 _amount) private {
    require(_amount >= 0);
    uintStorage[REWARDED_THIS_CYCLE] = _amount;
  }

  function getRewardedOnCycle() public view returns(uint256) {
    return uintStorage[REWARDED_THIS_CYCLE];
  }

  /**
  * returns yearly inflation rate (percentage)
  */
  function getInflation() public pure returns(uint256) {
    return INFLATION;
  }

  /**
  * returns blocks per year (block time is 5 seconds)
  */
  function getBlocksPerYear() public pure returns(uint256) {
    return BLOCKS_PER_YEAR;
  }

  function _setBlockRewardAmount() private {
    uintStorage[BLOCK_REWARD_AMOUNT] = (getTotalSupply().mul(getInflation().mul(DECIMALS).div(100))).div(getBlocksPerYear()).div(DECIMALS);
  }

  function getBlockRewardAmount() public view returns(uint256) {
    return uintStorage[BLOCK_REWARD_AMOUNT];
  }

  function getBlockRewardAmountPerValidator(address _validator) public view returns(uint256) {
    IConsensus consensus = IConsensus(ProxyStorage(getProxyStorage()).getConsensus());
    uint256 stakeAmount = consensus.stakeAmount(_validator);
    uint256 totalStakeAmount = consensus.totalStakeAmount();
    uint256 currentValidatorsLength = consensus.currentValidatorsLength();
    // this may arise in peculiar cases when the consensus totalStakeAmount wasn't calculated yet
    // for example at the first blocks after the contract was deployed
    if (totalStakeAmount == 0) {
      return getBlockRewardAmount();
    }
    return getBlockRewardAmount().mul(stakeAmount).mul(currentValidatorsLength).div(totalStakeAmount);
  }


  function getProxyStorage() public view returns(address) {
    return addressStorage[PROXY_STORAGE];
  }

  function shouldEmitRewardedOnCycle() public view returns(bool) {
    return IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).isFinalized() && boolStorage[SHOULD_EMIT_REWARDED_ON_CYCLE];
  }

  function _setShouldEmitRewardedOnCycle(bool _status) internal {
    boolStorage[SHOULD_EMIT_REWARDED_ON_CYCLE] = _status;
  }
}
