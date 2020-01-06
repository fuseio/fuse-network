pragma solidity ^0.4.24;

import "../../contracts/Consensus.sol";

contract ConsensusMock is Consensus {
  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function getSystemAddress() public view returns(address) {
    return addressStorage[SYSTEM_ADDRESS];
  }

  function hasCycleEnded() public view returns(bool) {
    return _hasCycleEnded();
  }

  function shouldTakeSnapshot() public view returns(bool) {
    return _shouldTakeSnapshot();
  }

  function getRandom(uint256 _from, uint256 _to) public view returns(uint256) {
    return _getRandom(_from, _to);
  }

  function getBlocksToSnapshot() public pure returns(uint256) {
    return _getBlocksToSnapshot();
  }

  function setNewValidatorSetMock(address[] _newSet) public {
    addressArrayStorage[NEW_VALIDATOR_SET] = _newSet;
  }

  function setFinalizedMock(bool _status) public {
    boolStorage[IS_FINALIZED] = _status;
  }

  function setShouldEmitInitiateChangeMock(bool _status) public {
    boolStorage[SHOULD_EMIT_INITIATE_CHANGE] = _status;
  }

  function getMaxValidators() public pure returns(uint256) {
    return 3;
  }

  function getMinStake() public pure returns(uint256) {
    return 1e22;
  }

  function getCycleDurationBlocks() public pure returns(uint256) {
    return 120;
  }

  function getSnapshotsPerCycle() public pure returns(uint256) {
    return 10;
  }

  function setValidatorFeeMock(uint256 _amount) external {
    require (_amount <= 1 * DECIMALS);
    _setValidatorFee(msg.sender, _amount);
  }
}
