pragma solidity ^0.4.24;

import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract ConsensusStorage is EternalStorage {
    using SafeMath for uint256;

    /**
    * @dev This modifier verifies that msg.sender is the owner of the contract (using the storage mapping)
    */
    modifier onlyOwner() {
      require(msg.sender == addressStorage[keccak256(abi.encodePacked("owner"))]);
      _;
    }

    /**
    * @dev This modifier verifies that msg.sender is the owner of the contract or the voting to change min stake contract (using the storage mapping)
    */
    modifier onlyOwnerOrVotingToChange() {
      require(msg.sender == addressStorage[keccak256(abi.encodePacked("owner"))] || msg.sender == ProxyStorage(getProxyStorage()).getVotingToChangeMinStake());
      _;
    }

    function getTime() public view returns(uint256) {
      return now;
    }

    function systemAddress() public view returns(address) {
      return addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))];
    }

    function setSystemAddress(address _newAddress) internal {
      addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = _newAddress;
    }

    function setFinalized(bool _status) internal {
      boolStorage[keccak256(abi.encodePacked("isFinalized"))] = _status;
    }

    function isFinalized() public view returns(bool) {
      return boolStorage[keccak256(abi.encodePacked("isFinalized"))];
    }

    function setInitialized(bool _status) internal {
      boolStorage[keccak256(abi.encodePacked("isInitialized"))] = _status;
    }

    function isInitialized() public view returns(bool) {
      return boolStorage[keccak256(abi.encodePacked("isInitialized"))];
    }

    function setMinStake(uint256 _minStake) public onlyOwnerOrVotingToChange {
      require(_minStake > 0);
      uintStorage[keccak256(abi.encodePacked("minStake"))] = _minStake;
    }

    function getMinStake() public view returns(uint256) {
      return uintStorage[keccak256(abi.encodePacked("minStake"))];
    }

    function setCycleDuration(uint256 _cycleDuration) public onlyOwner {
      require(_cycleDuration > 0);
      uintStorage[keccak256(abi.encodePacked("cycleDuration"))] = _cycleDuration;
    }

    function getCycleDuration() public view returns(uint256) {
      return uintStorage[keccak256(abi.encodePacked("cycleDuration"))];
    }

    function setCurrentCycleTimeframe() internal {
      setCurrentCycleStartTime(getTime());
      setCurrentCycleEndTime(getTime() + getCycleDuration());
    }

    function setCurrentCycleStartTime(uint256 _time) private {
      uintStorage[keccak256(abi.encodePacked("currentCycleStartTime"))] = _time;
    }

    function getCurrentCycleStartTime() public view returns(uint256) {
      return uintStorage[keccak256(abi.encodePacked("currentCycleStartTime"))];
    }

    function setCurrentCycleEndTime(uint256 _time) private {
      uintStorage[keccak256(abi.encodePacked("currentCycleEndTime"))] = _time;
    }

    function getCurrentCycleEndTime() public view returns(uint256) {
      return uintStorage[keccak256(abi.encodePacked("currentCycleEndTime"))];
    }

    function hasCycleEnded() public view returns(bool) {
      return (getTime() >= getCurrentCycleEndTime());
    }

    function setSnapshotsPerCycle(uint256 _snapshotsPerCycle) public onlyOwner {
      require(_snapshotsPerCycle > 0);
      uintStorage[keccak256(abi.encodePacked("snapshotsPerCycle"))] = _snapshotsPerCycle;
    }

    function getSnapshotsPerCycle() public view returns(uint256) {
      return uintStorage[keccak256(abi.encodePacked("snapshotsPerCycle"))];
    }

    function setLastSnapshotTakenTime(uint256 _time) internal {
      uintStorage[keccak256(abi.encodePacked("lastSnapshotTakenTime"))] = _time;
    }

    function getLastSnapshotTakenTime() public view returns(uint256) {
      return uintStorage[keccak256(abi.encodePacked("lastSnapshotTakenTime"))];
    }

    function getNextSnapshotId() public view returns(uint256) {
      return uintStorage[keccak256(abi.encodePacked("nextSnapshotId"))];
    }

    function setNextSnapshotId(uint256 _id) internal {
      uintStorage[keccak256(abi.encodePacked("nextSnapshotId"))] = _id;
    }

    function addToSnapshot(address _address, uint256 _snapshotId) internal {
        addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId))].push(_address);
    }

    function getSnapshot(uint256 _snapshotId) public view returns(address[]) {
       return addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId))];
    }

    function getTimeToSnapshot() public view returns(uint256) {
      return getCycleDuration().div(getSnapshotsPerCycle());
    }

    function shouldTakeSnapshot() public view returns(bool) {
      return (getTime() - getLastSnapshotTakenTime() >= getTimeToSnapshot());
    }

    function getRandom(uint256 _from, uint256 _to) public view returns(uint256) {
      return uint256(keccak256(abi.encodePacked(blockhash(block.number - 1)))).mod(_to).add(_from);
    }

    function currentValidators() public view returns(address[]) {
      return addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))];
    }

    function currentValidatorsLength() public view returns(uint256) {
      return addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))].length;
    }

    function currentValidatorsAtPosition(uint256 _p) public view returns(address) {
      return addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))][_p];
    }

    function currentValidatorsAdd(address _address) internal {
        addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))].push(_address);
    }

    function setCurrentValidators(address[] _currentValidators) internal {
      addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))] = _currentValidators;
    }

    function pendingValidators() public view returns(address[]) {
      return addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))];
    }

    function pendingValidatorsLength() public view returns(uint256) {
      return addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))].length;
    }

    function pendingValidatorsAtPosition(uint256 _p) public view returns(address) {
      return addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))][_p];
    }

    function setPendingValidatorsAtPosition(uint256 _p, address _address) internal {
      addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))][_p] = _address;
    }

    function pendingValidatorsAdd(address _address) internal {
      addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))].push(_address);
    }

    function pendingValidatorsRemove(uint256 _index) internal {
      delete addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))][_index];
      addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))].length--;
    }

    function setPendingValidators(address[] _pendingValidators) internal {
      addressArrayStorage[keccak256(abi.encodePacked("pendingValidators"))] = _pendingValidators;
    }

    function stakeAmount(address _address) public view returns(uint256) {
      return uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))];
    }

    function stakeAmountAdd(address _address, uint256 _amount) internal {
      uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))].add(_amount);
    }

    function stakeAmountSub(address _address, uint256 _amount) internal {
      uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))].sub(_amount);
    }

    function setStakeAmount(address _address, uint256 _amount) internal {
      uintStorage[keccak256(abi.encodePacked("stakeAmount", _address))] = _amount;
    }

    function isValidator(address _address) public view returns(bool) {
      return boolStorage[keccak256(abi.encodePacked("isValidator", _address))];
    }

    function setIsValidator(address _address, bool _status) internal {
      boolStorage[keccak256(abi.encodePacked("isValidator", _address))] = _status;
    }

    function validatorIndexes(address _address) public view returns(uint256[]) {
      return uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))];
    }

    function validatorIndexesLength(address _address) public view returns(uint256) {
      return uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))].length;
    }

    function validatorIndexesAtPosition(address _address, uint256 _p) public view returns(uint256) {
      return uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))][_p];
    }

    function setValidatorIndexesAtPosition(address _address, uint256 _p, uint256 _i) internal {
      uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))][_p] = _i;
    }

    function deleteValidatorIndexesAtPosition(address _address, uint256 _p) internal {
      delete uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))][_p];
      uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))].length--;
    }

    function validatorIndexexPush(address _address, uint256 _i) internal {
      uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))].push(_i);
    }

    function setValidatorIndexes(address _address, uint256[] _indexes) internal {
      uintArrayStorage[keccak256(abi.encodePacked("validatorIndexes", _address))] = _indexes;
    }

    function getProxyStorage() public view returns(address) {
      return addressStorage[keccak256(abi.encodePacked("proxyStorage"))];
    }

    function setProxyStorage(address _newAddress) public onlyOwner {
      require(!boolStorage[keccak256(abi.encodePacked("wasProxyStorageSet"))]);
      require(_newAddress != address(0));
      addressStorage[keccak256(abi.encodePacked("proxyStorage"))] = _newAddress;
      boolStorage[keccak256(abi.encodePacked("wasProxyStorageSet"))] = true;
    }

    function newValidatorSet() public view returns(address[]) {
      return addressArrayStorage[keccak256(abi.encodePacked("newValidatorSet"))];
    }

    function newValidatorSetLength() public view returns(uint256) {
      return addressArrayStorage[keccak256(abi.encodePacked("newValidatorSet"))].length;
    }

    function setNewValidatorSet(address[] _newSet) internal {
      addressArrayStorage[keccak256(abi.encodePacked("newValidatorSet"))] = _newSet;
    }
}
