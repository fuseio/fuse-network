pragma solidity ^0.4.24;

import "./eternal-storage/EternalStorageProxy.sol";
import "./eternal-storage/EternalStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract used for access and upgradeability to all network contracts
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
    BallotsStorage,
    ProxyStorage,
    VotingToChangeBlockReward,
    VotingToChangeMinStake,
    VotingToChangeMinThreshold,
    VotingToChangeProxy
  }

  /**
  * @dev This event will be emitted when all contract addresses have been initialized by the contract owner
  */
  event ProxyInitialized(
    address consensus,
    address blockReward,
    address ballotsStorage,
    address votingToChangeBlockReward,
    address votingToChangeMinStake,
    address votingToChangeMinThreshold,
    address votingToChangeProxy
  );

  /**
  * @dev This event will be emitted each time a contract address is updated
  * @param contractType contract type (See ContractTypes enum)
  * @param contractAddress contract address set for the contract type
  */
  event AddressSet(uint256 contractType, address contractAddress);

  /**
  * @dev This modifier verifies that msg.sender is the owner of the contract (using the storage mapping)
  */
  modifier onlyOwner() {
    require(msg.sender == addressStorage[keccak256(abi.encodePacked("owner"))]);
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the voting contract which implement proxy address change
  */
  modifier onlyVotingToChangeProxy() {
    require(msg.sender == getVotingToChangeProxy());
    _;
  }

  /**
  * @dev Function to be called on contract initialization
  * @param _consensus address of the network consensus contract
  */
  function initialize(address _consensus) public onlyOwner returns(bool) {
    require(!isInitialized());
    require(_consensus != address(0));
    require(_consensus != address(this));
    setConsensus(_consensus);
    setInitialized(true);
    return isInitialized();
  }

  /**
  * @dev Function to be called to initialize all available contract types addresses
  */
  function initializeAddresses(address _blockReward, address _ballotsStorage, address _votingToChangeBlockReward, address _votingToChangeMinStake, address _votingToChangeMinThreshold, address _votingToChangeProxy) public onlyOwner {
    require (!boolStorage[keccak256(abi.encodePacked("proxyStorageAddressesInitialized"))]);

    addressStorage[keccak256(abi.encodePacked("blockReward"))] = _blockReward;
    addressStorage[keccak256(abi.encodePacked("ballotsStorage"))] = _ballotsStorage;
    addressStorage[keccak256(abi.encodePacked("votingToChangeBlockReward"))] = _votingToChangeBlockReward;
    addressStorage[keccak256(abi.encodePacked("votingToChangeMinStake"))] = _votingToChangeMinStake;
    addressStorage[keccak256(abi.encodePacked("votingToChangeMinThreshold"))] = _votingToChangeMinThreshold;
    addressStorage[keccak256(abi.encodePacked("votingToChangeProxy"))] = _votingToChangeProxy;

    boolStorage[keccak256(abi.encodePacked("proxyStorageAddressesInitialized"))] = true;

    emit ProxyInitialized(
      getConsensus(),
      _blockReward,
      _ballotsStorage,
      _votingToChangeBlockReward,
      _votingToChangeMinStake,
      _votingToChangeMinThreshold,
      _votingToChangeProxy
    );
  }

  /**
  * @dev Function to be called to set specific contract type address
  * @param _contractType contract type (See ContractTypes enum)
  * @param _contractAddress contract address set for the contract type
  */
  function setContractAddress(uint256 _contractType, address _contractAddress) public onlyVotingToChangeProxy returns(bool) {
    if (!isInitialized()) return false;
    if (_contractAddress == address(0)) return false;

    bool success = false;

    if (_contractType == uint256(ContractTypes.Consensus)) {
      success = EternalStorageProxy(getConsensus()).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.BlockReward)) {
      success = EternalStorageProxy(getBlockReward()).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.BallotsStorage)) {
      success = EternalStorageProxy(getBallotsStorage()).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.ProxyStorage)) {
      success = EternalStorageProxy(this).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.VotingToChangeBlockReward)) {
      success = EternalStorageProxy(getVotingToChangeBlockReward()).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.VotingToChangeMinStake)) {
      success = EternalStorageProxy(getVotingToChangeMinStake()).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.VotingToChangeMinThreshold)) {
      success = EternalStorageProxy(getVotingToChangeMinThreshold()).upgradeTo(_contractAddress);
    } else if (_contractType == uint256(ContractTypes.VotingToChangeProxy)) {
      success = EternalStorageProxy(getVotingToChangeProxy()).upgradeTo(_contractAddress);
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
  function isValidContractType(uint256 _contractType) public pure returns(bool) {
    return
      _contractType == uint256(ContractTypes.Consensus) ||
      _contractType == uint256(ContractTypes.BlockReward) ||
      _contractType == uint256(ContractTypes.BallotsStorage) ||
      _contractType == uint256(ContractTypes.ProxyStorage) ||
      _contractType == uint256(ContractTypes.VotingToChangeBlockReward) ||
      _contractType == uint256(ContractTypes.VotingToChangeMinStake) ||
      _contractType == uint256(ContractTypes.VotingToChangeMinThreshold) ||
      _contractType == uint256(ContractTypes.VotingToChangeProxy);
  }

  function setInitialized(bool _value) internal {
    boolStorage[keccak256(abi.encodePacked("isInitialized"))] = _value;
  }

  function isInitialized() public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("isInitialized"))];
  }

  function setConsensus(address _consensus) private {
    addressStorage[keccak256(abi.encodePacked("consensus"))] = _consensus;
  }

  function getConsensus() public view returns(address){
    return addressStorage[keccak256(abi.encodePacked("consensus"))];
  }

  function getBlockReward() public view returns(address){
    return addressStorage[keccak256(abi.encodePacked("blockReward"))];
  }

  function getBallotsStorage() public view returns(address){
    return addressStorage[keccak256(abi.encodePacked("ballotsStorage"))];
  }

  function getVotingToChangeBlockReward() public view returns(address){
    return addressStorage[keccak256(abi.encodePacked("votingToChangeBlockReward"))];
  }

  function getVotingToChangeMinStake() public view returns(address){
    return addressStorage[keccak256(abi.encodePacked("votingToChangeMinStake"))];
  }

  function getVotingToChangeMinThreshold() public view returns(address){
    return addressStorage[keccak256(abi.encodePacked("votingToChangeMinThreshold"))];
  }

  function getVotingToChangeProxy() public view returns(address){
    return addressStorage[keccak256(abi.encodePacked("votingToChangeProxy"))];
  }
}
