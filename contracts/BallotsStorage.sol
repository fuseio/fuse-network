pragma solidity ^0.4.24;

import "./abstracts/VotingEnums.sol";
import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";
import "./Consensus.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract handling ballots logic and storage
*/
contract BallotsStorage is EternalStorage, VotingEnums {
  using SafeMath for uint256;

  /**
  * @dev This event will be emitted on threshold change (most likely on ballot finalization)
  * @param thresholdType type of threshold changed (see VotingEnums.hresholdTypes)
  * @param newValue new value of the threshold changed
  */
  event ThresholdChanged(uint256 indexed thresholdType, uint256 newValue);

  /**
  * @dev This modifier verifies that msg.sender is the owner of the contract (using the storage mapping)
  */
  modifier onlyOwner() {
    require(msg.sender == addressStorage[keccak256(abi.encodePacked("owner"))]);
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is one of the voting contracts which implement threshold changes
  */
  modifier onlyVotingToChangeThreshold() {
    bool isVotingToChangeBlockReward = msg.sender == getVotingToChangeBlockReward();
    bool isVotingToChangeMinStake = msg.sender == getVotingToChangeMinStake();
    bool isVotingToChangeMinThreshold = msg.sender == getVotingToChangeMinThreshold();
    require(isVotingToChangeBlockReward || isVotingToChangeMinStake || isVotingToChangeMinThreshold);
    _;
  }

  /**
  * @dev Function to be called on contract initialization
  * @param _thresholds array of initial threshold values (ordered by VotingEnums.ThresholdTypes)
  */
  function initialize(uint256[] _thresholds) public onlyOwner {
    require(!isInitialized());
    require(_thresholds.length == uint256(ThresholdTypes.MinStake));
    uint256 thresholdType = uint256(ThresholdTypes.Voters);
    for (; thresholdType <= _thresholds.length; thresholdType++) {
      uint256 thresholdValue = _thresholds[thresholdType - uint256(ThresholdTypes.Voters)];
      if (!setThreshold(thresholdValue, thresholdType)) {
        revert();
      }
    }
    setInitialized(true);
  }

  /**
  * @dev Function to get the number of "open" (active) ballots each validator (someone with voting rights) can have at the same time.
  */
  function getBallotLimitPerValidator() public view returns(uint256) {
    uint256 validatorsCount = getTotalNumberOfValidators();
    if (validatorsCount == 0) {
      return getMaxLimitBallot();
    }
    uint256 limit = getMaxLimitBallot().div(validatorsCount);
    if (limit == 0) {
      limit = 1;
    }
    return limit;
  }

  function setInitialized(bool _value) internal {
    boolStorage[keccak256(abi.encodePacked("isInitialized"))] = _value;
  }

  function isInitialized() public view returns(bool) {
    return boolStorage[keccak256(abi.encodePacked("isInitialized"))];
  }

  /**
  * @dev Function to set the value of a ballot threshold. Can only be called by voting contracts to change thresholds.
  * @param _value new threshold value
  * @param _thresholdType type of threshold to set its value (see VotingEnums.hresholdTypes)
  */
  function setBallotThreshold(uint256 _value, uint256 _thresholdType) public onlyVotingToChangeThreshold returns(bool) {
    if (_value == getBallotThreshold(_thresholdType)) return false;
    if (!setThreshold(_value, _thresholdType)) return false;
    emit ThresholdChanged(_thresholdType, _value);
    return true;
  }

  function setThreshold(uint256 _value, uint256 _thresholdType) internal returns(bool) {
    if (_value < 0) return false;
    if (_thresholdType == uint256(ThresholdTypes.Invalid)) return false;
    if (_thresholdType > uint256(ThresholdTypes.MinStake)) return false;
    if (_thresholdType == uint256(ThresholdTypes.Voters)) {
      if (_value == 0) return false;
    }
    uintStorage[keccak256(abi.encodePacked("ballotThresholds", _thresholdType))] = _value;
    return true;
  }

  function getBallotThreshold(uint256 _ballotType) public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("ballotThresholds", _ballotType))];
  }

  function getProxyStorage() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("proxyStorage"))];
  }

  function getVotingToChangeBlockReward() public view returns(address) {
    return ProxyStorage(getProxyStorage()).getVotingToChangeBlockReward();
  }

  function getVotingToChangeMinStake() public view returns(address) {
    return ProxyStorage(getProxyStorage()).getVotingToChangeMinStake();
  }

  function getVotingToChangeMinThreshold() public view returns(address) {
    return ProxyStorage(getProxyStorage()).getVotingToChangeMinThreshold();
  }

  function getTotalNumberOfValidators() internal view returns(uint256) {
    return Consensus(ProxyStorage(getProxyStorage()).getConsensus()).currentValidatorsLength();
  }

  function getProxyThreshold() public view returns(uint256) {
    return getTotalNumberOfValidators().div(2).add(1);
  }

  function getMaxLimitBallot() public pure returns(uint256) {
    return 100;
  }
}
