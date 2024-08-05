
// File: contracts/abstracts/VotingBase.sol

pragma solidity ^0.4.24;

/**
 * @title Interface to be implemented by voting contract
 * @author LiorRabin
 * @dev abstract contract
 */
contract VotingBase {

  /**
  * @dev Possible states of quorum
  * @param InProgress - state while a ballot has not been finalized yet
  * @param Accepted - state after finalizing the ballot and majority have voted ActionChoices.Accept
  * @param Rejected - state after finalizing the ballot and majority have voted ActionChoices.Reject
  */
  enum QuorumStates {
    Invalid,
    InProgress,
    Accepted,
    Rejected
  }

  /**
  * @dev Possible choices for a ballot
  */
  enum ActionChoices {
    Invalid,
    Accept,
    Reject
  }

  /**
  * @dev This event will be emitted every time a new ballot is created
  * @param id ballot id
  * @param creator address of ballot creator
  */
  event BallotCreated(uint256 indexed id, address indexed creator);

  /**
  * @dev This event will be emitted when a ballot if finalized
  * @param id ballot id
  */
  event BallotFinalized(uint256 indexed id);

  /**
  * @dev This event will be emitted on each vote
  * @param id ballot id
  * @param decision voter decision (see VotingBase.ActionChoices)
  * @param voter address of the voter
  */
  event Vote(uint256 indexed id, uint256 decision, address indexed voter);

  /**
  * @dev Function to be called when voting on a ballot
  * @param _id ballot id
  * @param _choice voter decision on the ballot (see VotingBase.ActionChoices)
  */
  function vote(uint256 _id, uint256 _choice) external;
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

// File: contracts/VotingUtils.sol

pragma solidity ^0.4.24;






/**
* @title Voting utility contract
* @author LiorRabin
*/
contract VotingUtils is EternalStorage, VotingBase {
  using SafeMath for uint256;

  uint256 public constant DECIMALS = 10 ** 18;
  uint256 public constant MAX_LIMIT_OF_BALLOTS = 100;
  uint256 public constant MIN_BALLOT_DURATION_CYCLES = 2;
  uint256 public constant MAX_BALLOT_DURATION_CYCLES = 14;

  /**
  * @dev This modifier verifies that msg.sender is the owner of the contract
  */
  modifier onlyOwner() {
    require(msg.sender == addressStorage[OWNER]);
    _;
  }

  /**
  * @dev This modifier verifies the duration of the ballot is valid
  */
  modifier onlyValidDuration(uint256 _startAfterNumberOfCycles, uint256 _cyclesDuration) {
    require(_startAfterNumberOfCycles > 0);
    require(_cyclesDuration > 0);
    require(_cyclesDuration >= getMinBallotDurationCycles());
    require(_cyclesDuration <= getMaxBallotDurationCycles());
    _;
  }

  /**
  * @dev This modifier verifies an address is valid for voting
  */
  modifier onlyValidVotingKey(address _address) {
    require(isValidVotingKey(_address));
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the consensus contract
  */
  modifier onlyConsensus() {
    require(msg.sender == ProxyStorage(getProxyStorage()).getConsensus());
    _;
  }

  bytes32 internal constant OWNER = keccak256(abi.encodePacked("owner"));
  bytes32 internal constant NEXT_BALLOT_ID = keccak256(abi.encodePacked("nextBallotId"));
  bytes32 internal constant ACTIVE_BALLOTS = keccak256(abi.encodePacked("activeBallots"));
  bytes32 internal constant PROXY_STORAGE = keccak256(abi.encodePacked("proxyStorage"));

  /**
  * @dev Function to check if a contract type is a valid network contract
  * @param _contractType contract type to check (See ProxyStorage.ContractTypes)
  */
  function validContractType(uint256 _contractType) public view returns(bool) {
    return ProxyStorage(getProxyStorage()).isValidContractType(_contractType);
  }

  /**
  * @dev This function checks if an address is valid for voting (is a validator)
  * @param _address the address to check if valid for voting
  */
  function isValidVotingKey(address _address) public view returns(bool) {
    bool valid = false;
    IConsensus consensus = IConsensus(ProxyStorage(getProxyStorage()).getConsensus());
    for (uint256 i; i < consensus.currentValidatorsLength(); i++) {
      address validator = consensus.currentValidatorsAtPosition(i);
      if (validator == _address) {
        valid = true;
      }
    }
    return valid;
  }

  /**
  * @dev Function to get the number of "open" (active) ballots each validator (someone with voting rights) can have at the same time
  */
  function getBallotLimitPerValidator() public view returns(uint256) {
    uint256 validatorsCount = getTotalNumberOfValidators();
    if (validatorsCount == 0) {
      return MAX_LIMIT_OF_BALLOTS;
    }
    uint256 limit = MAX_LIMIT_OF_BALLOTS.div(validatorsCount);
    if (limit == 0) {
      limit = 1;
    }
    return limit;
  }

  /**
  * @dev Function used to check if a voting key has voted on a specific ballot
  * @param _id ballot id to get info of
  * @param _key voter key to get if voted already
  */
  function hasAlreadyVoted(uint256 _id, address _key) public view returns(bool) {
    if (_key == address(0)) {
      return false;
    }
    return getVoterChoice(_id, _key) != 0;
  }

  /**
  * @dev This function is used to check if a ballot can be finalized
  * @param _id ballot id to check
  */
  function canBeFinalized(uint256 _id) public view returns(bool) {
    if (_id >= getNextBallotId()) return false;
    if (getStartBlock(_id) > block.number) return false;
    if (getIsFinalized(_id)) return false;

    return block.number > getEndBlock(_id);
  }

  function getProposedValue(uint256 _id) public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))];
  }

  function _setProposedValue(uint256 _id, address _value) internal {
    addressStorage[keccak256(abi.encodePacked("votingState", _id, "proposedValue"))] = _value;
  }

  function getContractType(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "contractType"))];
  }

  function _setContractType(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "contractType"))] = _value;
  }

  /**
  * @dev This function is used to create a ballot
  * @param _startAfterNumberOfCycles number of cycles after which the ballot should open for voting
  * @param _cyclesDuration number of cycles the ballot will remain open for voting
  * @param _description ballot text description
  */
  function _createBallot(uint256 _startAfterNumberOfCycles, uint256 _cyclesDuration, string _description) internal returns(uint256) {
    require(isInitialized());
    address creator = msg.sender;
    require(withinLimit(creator));
    uint256 ballotId = getNextBallotId();
    _setNextBallotId(ballotId.add(1));
    _setStartBlock(ballotId, _startAfterNumberOfCycles);
    _setEndBlock(ballotId, _cyclesDuration);
    _setIsFinalized(ballotId, false);
    _setQuorumState(ballotId, uint256(QuorumStates.InProgress));
    _setCreator(ballotId, creator);
    _setDescription(ballotId, _description);
    _setIndex(ballotId, activeBallotsLength());
    _activeBallotsAdd(ballotId);
    _increaseValidatorLimit(creator);
    emit BallotCreated(ballotId, creator);
    return ballotId;
  }

  function _finalize(uint256 _id) internal {
    if (!getFinalizeCalled(_id)) {
      _decreaseValidatorLimit(_id);
      _setFinalizeCalled(_id);
    }

    if (getAccepted(_id) > getRejected(_id)) {
      if (_finalizeBallot(_id)) {
        _setQuorumState(_id, uint256(QuorumStates.Accepted));
      } else {
        return;
      }
    } else {
      _setQuorumState(_id, uint256(QuorumStates.Rejected));
    }

    _deactivateBallot(_id);
    _setIsFinalized(_id, true);
    emit BallotFinalized(_id);
  }

  function _deactivateBallot(uint256 _id) internal {
    uint256 removedIndex = getIndex(_id);
    uint256 lastIndex = activeBallotsLength() - 1;
    uint256 lastBallotId = activeBallotsAtIndex(lastIndex);

    // Override the removed ballot with the last one.
    _activeBallotsSet(removedIndex, lastBallotId);

    // Update the index of the last validator.
    _setIndex(lastBallotId, removedIndex);
    _activeBallotsSet(lastIndex, 0);
    _activeBallotsDecreaseLength();
  }

  function _finalizeBallot(uint256 _id) internal returns(bool) {
    return ProxyStorage(getProxyStorage()).setContractAddress(getContractType(_id), getProposedValue(_id));
  }

  function isActiveBallot(uint256 _id) public view returns(bool) {
    return getStartBlock(_id) < block.number && block.number < getEndBlock(_id);
  }

  function getQuorumState(uint256 _id) external view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))];
  }

  function _setQuorumState(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "quorumState"))] = _value;
  }

  function getNextBallotId() public view returns(uint256) {
    return uintStorage[NEXT_BALLOT_ID];
  }

  function _setNextBallotId(uint256 _id) internal {
    uintStorage[NEXT_BALLOT_ID] = _id;
  }

  /**
  * returns minimum number of cycles a ballot can be open before finalization
  */
  function getMinBallotDurationCycles() public pure returns(uint256) {
    return MIN_BALLOT_DURATION_CYCLES;
  }

  /**
  * returns maximum number of cycles a ballot can be open before finalization
  */
  function getMaxBallotDurationCycles() public pure returns(uint256) {
    return MAX_BALLOT_DURATION_CYCLES;
  }

  function getStartBlock(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "startBlock"))];
  }

  function _setStartBlock(uint256 _id, uint256 _startAfterNumberOfCycles) internal {
    IConsensus consensus = IConsensus(ProxyStorage(getProxyStorage()).getConsensus());
    uint256 cycleDurationBlocks = consensus.getCycleDurationBlocks();
    uint256 currentCycleEndBlock = consensus.getCurrentCycleEndBlock();
    uint256 startBlock = currentCycleEndBlock.add(_startAfterNumberOfCycles.mul(cycleDurationBlocks));
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "startBlock"))] = startBlock;
  }

  function getEndBlock(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "endBlock"))];
  }

  function _setEndBlock(uint256 _id, uint256 _cyclesDuration) internal {
    uint256 cycleDurationBlocks = IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).getCycleDurationBlocks();
    uint256 startBlock = getStartBlock(_id);
    uint256 endBlock = startBlock.add(_cyclesDuration.mul(cycleDurationBlocks));
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "endBlock"))] = endBlock;
  }

  function getIsFinalized(uint256 _id) public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("votingState", _id, "isFinalized"))];
  }

  function _setIsFinalized(uint256 _id, bool _value) internal {
    boolStorage[keccak256(abi.encodePacked("votingState", _id, "isFinalized"))] = _value;
  }

  function getDescription(uint256 _id) public view returns(string) {
    return stringStorage[keccak256(abi.encodePacked("votingState", _id, "description"))];
  }

  function _setDescription(uint256 _id, string _value) internal {
    stringStorage[keccak256(abi.encodePacked("votingState", _id, "description"))] = _value;
  }

  function getCreator(uint256 _id) public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("votingState", _id, "creator"))];
  }

  function _setCreator(uint256 _id, address _value) internal {
    addressStorage[keccak256(abi.encodePacked("votingState", _id, "creator"))] = _value;
  }

  function getIndex(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "index"))];
  }

  function _setIndex(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "index"))] = _value;
  }

  function activeBallots() public view returns(uint[]) {
    return uintArrayStorage[ACTIVE_BALLOTS];
  }

  function activeBallotsAtIndex(uint256 _index) public view returns(uint256) {
    return uintArrayStorage[ACTIVE_BALLOTS][_index];
  }

  function activeBallotsLength() public view returns(uint256) {
    return uintArrayStorage[ACTIVE_BALLOTS].length;
  }

  function _activeBallotsAdd(uint256 _id) internal {
    uintArrayStorage[ACTIVE_BALLOTS].push(_id);
  }

  function _activeBallotsDecreaseLength() internal {
    if (activeBallotsLength() > 0) {
      uintArrayStorage[ACTIVE_BALLOTS].length--;
    }
  }

  function _activeBallotsSet(uint256 _index, uint256 _id) internal {
    uintArrayStorage[ACTIVE_BALLOTS][_index] = _id;
  }

  function validatorActiveBallots(address _key) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("validatorActiveBallots", _key))];
  }

  function _setValidatorActiveBallots(address _key, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("validatorActiveBallots", _key))] = _value;
  }

  function _increaseValidatorLimit(address _key) internal {
    _setValidatorActiveBallots(_key, validatorActiveBallots(_key).add(1));
  }

  function _decreaseValidatorLimit(uint256 _id) internal {
    address key = getCreator(_id);
    uint256 ballotsCount = validatorActiveBallots(key);
    if (ballotsCount > 0) {
      _setValidatorActiveBallots(key, ballotsCount - 1);
    }
  }

  function getFinalizeCalled(uint256 _id) public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("finalizeCalled", _id))];
  }

  function _setFinalizeCalled(uint256 _id) internal {
    boolStorage[keccak256(abi.encodePacked("finalizeCalled", _id))] = true;
  }

  function getProxyStorage() public view returns(address) {
    return addressStorage[PROXY_STORAGE];
  }

  function getTotalNumberOfValidators() internal view returns(uint256) {
    return IConsensus(ProxyStorage(getProxyStorage()).getConsensus()).currentValidatorsLength();
  }

  function _setVoterChoice(uint256 _id, address _key, uint256 _choice) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "voters", _key))] = _choice;
  }

  function getVoterChoice(uint256 _id, address _key) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "voters", _key))];
  }

  function withinLimit(address _key) internal view returns(bool) {
    return validatorActiveBallots(_key) < getBallotLimitPerValidator();
  }

  function getAccepted(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "accepted"))];
  }

  function _setAccepted(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "accepted"))] = _value;
  }

  function getRejected(uint256 _id) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("votingState", _id, "rejected"))];
  }

  function _setRejected(uint256 _id, uint256 _value) internal {
    uintStorage[keccak256(abi.encodePacked("votingState", _id, "rejected"))] = _value;
  }
}

// File: contracts/Voting.sol

pragma solidity ^0.4.24;


/**
* @title Contract handling vote to change implementations network contracts
* @author LiorRabin
*/
contract Voting is VotingUtils {
  /**
  * @dev Function to be called on contract initialization
  */
  function initialize() external onlyOwner {
    require(!isInitialized());
    setInitialized(true);
  }

  /**
  * @dev Function to create a new ballot
  * @param _startAfterNumberOfCycles number of cycles after which the ballot should open for voting
  * @param _cyclesDuration number of cycles the ballot will remain open for voting
  * @param _contractType contract type to change its address (See ProxyStorage.ContractTypes)
  * @param _proposedValue proposed address for the contract type
  * @param _description ballot text description
  */
  function newBallot(uint256 _startAfterNumberOfCycles, uint256 _cyclesDuration, uint256 _contractType, address _proposedValue, string _description) external onlyValidVotingKey(msg.sender) onlyValidDuration(_startAfterNumberOfCycles, _cyclesDuration) returns(uint256) {
    require(_proposedValue != address(0));
    require(validContractType(_contractType));
    uint256 ballotId = _createBallot(_startAfterNumberOfCycles, _cyclesDuration, _description);
    _setProposedValue(ballotId, _proposedValue);
    _setContractType(ballotId, _contractType);
    return ballotId;
  }

  /**
  * @dev Function to get specific ballot info along with voters involvment on it
  * @param _id ballot id to get info of
  * @param _key voter key to get if voted already
  */
  function getBallotInfo(uint256 _id, address _key) external view returns(uint256 startBlock, uint256 endBlock, bool isFinalized, address proposedValue, uint256 contractType, address creator, string description, bool canBeFinalizedNow, bool alreadyVoted) {
    startBlock = getStartBlock(_id);
    endBlock = getEndBlock(_id);
    isFinalized = getIsFinalized(_id);
    proposedValue = getProposedValue(_id);
    contractType = getContractType(_id);
    creator = getCreator(_id);
    description = getDescription(_id);
    canBeFinalizedNow = canBeFinalized(_id);
    alreadyVoted = hasAlreadyVoted(_id, _key);

    return (startBlock, endBlock, isFinalized, proposedValue, contractType, creator, description, canBeFinalizedNow, alreadyVoted);
  }

  /**
  * @dev This function is used to vote on a ballot
  * @param _id ballot id to vote on
  * @param _choice voting decision on the ballot (see VotingBase.ActionChoices)
  */
  function vote(uint256 _id, uint256 _choice) external {
    require(!getIsFinalized(_id));
    address voter = msg.sender;
    require(isActiveBallot(_id));
    require(!hasAlreadyVoted(_id, voter));
    require(_choice == uint(ActionChoices.Accept) || _choice == uint(ActionChoices.Reject));
    _setVoterChoice(_id, voter, _choice);
    emit Vote(_id, _choice, voter);
  }

  /**
  * @dev Function to be called by the consensus contract when a cycles ends
  * In this function, all active ballots votes will be counted and updated according to the current validators
  */
  function onCycleEnd(address[] validators) external onlyConsensus {
    uint256 numOfValidators = validators.length;
    if (numOfValidators == 0) {
      return;
    }
    uint[] memory ballots = activeBallots();
    for (uint256 i = 0; i < ballots.length; i++) {
      uint256 ballotId = ballots[i];
      if (getStartBlock(ballotId) < block.number && !getFinalizeCalled(ballotId)) {
        uint256 accepts = 0;
        uint256 rejects = 0;
        for (uint256 j = 0; j < numOfValidators; j++) {
          uint256 choice = getVoterChoice(ballotId, validators[j]);
          if (choice == uint(ActionChoices.Accept)) {
            accepts = accepts.add(1);
          } else if (choice == uint256(ActionChoices.Reject)) {
            rejects = rejects.add(1);
          }
        }
        accepts = accepts.mul(DECIMALS).div(numOfValidators);
        rejects = rejects.mul(DECIMALS).div(numOfValidators);
        _setAccepted(ballotId, getAccepted(ballotId).add(accepts));
        _setRejected(ballotId, getRejected(ballotId).add(rejects));

        if (canBeFinalized(ballotId)) {
          _finalize(ballotId);
        }
      }
    }
  }
}
