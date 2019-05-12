pragma solidity 0.4.24;

import "./upgradeability/EternalStorage.sol";
import "./EternalOwnable.sol";
import "./ValidatorSet.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract BasicConsensus is EternalStorage, EternalOwnable, ValidatorSet {
    using SafeMath for uint256;

    function getConsensusVersion() public pure returns(uint64 major, uint64 minor, uint64 patch) {
      return (0, 0, 1);
    }

    function systemAddress() public view returns(address) {
      return addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))];
    }

    function setSystemAddress() internal {
      addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
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

    function setMinStake(uint256 _minStake) public onlyOwner {
      require(_minStake > 0);
      uintStorage[keccak256(abi.encodePacked("minStake"))] = _minStake;
    }

    function minStake() public view returns(uint256) {
      return uintStorage[keccak256(abi.encodePacked("minStake"))];
    }

    function currentValidators() public view returns(address[]) {
      return addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))];
    }

    function currentValidatorsLength() public view returns(uint256) {
      return addressArrayStorage[keccak256(abi.encodePacked("currentValidators"))].length;
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
}
