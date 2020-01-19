pragma solidity ^0.4.24;

import "./eternal-storage/EternalStorageProxy.sol";
import "./eternal-storage/EternalStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

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
    Voting,
    HomeBridge,
    ForeignBridge
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
  * @dev This event will be emitted to bootstrap bridge related contracts update flow (see https://github.com/fuseio/FIPs/blob/master/FIPS/fip-6.md)
  * @param contractType contract type (See ContractTypes enum)
  * @param contractAddress contract address set for the contract type
  */
  event UpgradeBridge(uint256 contractType, address contractAddress);

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
    } else if (_contractType == uint256(ContractTypes.HomeBridge) || _contractType == uint256(ContractTypes.ForeignBridge)) {
      emit UpgradeBridge(_contractType, _contractAddress);
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
      _contractType == uint256(ContractTypes.Voting) ||
      _contractType == uint256(ContractTypes.HomeBridge) ||
      _contractType == uint256(ContractTypes.ForeignBridge);
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
