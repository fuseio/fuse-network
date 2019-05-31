pragma solidity ^0.4.24;

import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract ConsensusStorage is EternalStorage {
    using SafeMath for uint256;

    modifier onlyOwner() {
      require(msg.sender == addressStorage[keccak256(abi.encodePacked("owner"))]);
      _;
    }

    modifier onlyOwnerOrVotingToChange() {
      require(msg.sender == addressStorage[keccak256(abi.encodePacked("owner"))] || msg.sender == ProxyStorage(getProxyStorage()).getVotingToChangeMinStake());
      _;
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

    function isValidatorFinalized(address _address) public view returns(bool) {
      return boolStorage[keccak256(abi.encodePacked("isValidatorFinalized", _address))];
    }

    function setIsValidatorFinalized(address _address, bool _status) internal {
      boolStorage[keccak256(abi.encodePacked("isValidatorFinalized", _address))] = _status;
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
}
