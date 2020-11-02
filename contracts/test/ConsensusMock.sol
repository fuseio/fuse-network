pragma solidity ^0.4.24;

import "../Consensus.sol";

contract ConsensusMock is Consensus {
  uint256 currentValidatorsLengthMock = 0;
  uint256 private blockTest = 120;

  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function getSystemAddress() public view returns(address) {
    return addressStorage[SYSTEM_ADDRESS];
  }

  function hasCycleEnded() public view returns(bool) {
    return _hasCycleEnded();
  }

  // function shouldTakeSnapshot() public view returns(bool) {
  //   return _shouldTakeSnapshot();
  // }

  function getRandom(uint256 _from, uint256 _to) public view returns(uint256) {
    return _getRandom(_from, _to);
  }

  // function getBlocksToSnapshot() public pure returns(uint256) {
  //   return _getBlocksToSnapshot();
  // }

  function setNewValidatorSetMock(address[] _newSet) public {
    addressArrayStorage[NEW_VALIDATOR_SET] = _newSet;
  }

  function setFinalizedMock(bool _status) public {
    boolStorage[IS_FINALIZED] = _status;
  }

  function setShouldEmitInitiateChangeMock(bool _status) public {
    boolStorage[SHOULD_EMIT_INITIATE_CHANGE] = _status;
  }

  function getMinStake() public pure returns(uint256) {
    return 1e22;
  }

  function getMaxStake() public pure returns(uint256) {
    return 5e22;
  }

  function getCycleDurationBlocks() public view returns(uint256) {
    return blockTest == 0 ? 120 : blockTest;
  }

  function setCycleDurationBlocks(uint256 _block) public {
    blockTest = _block;
  }

  function setCurrentCycleEndBlock(uint256 _value) public {
    uintStorage[CURRENT_CYCLE_END_BLOCK] = _value;
  }

  function getSnapshotsPerCycle() public pure returns(uint256) {
    return 10;
  }

  function setCurrentValidatorsLengthMock(uint256 _currentValidatorsLengthMock) external {
    currentValidatorsLengthMock = _currentValidatorsLengthMock;
  }

  function currentValidatorsLength() public view returns(uint256) {
    if (currentValidatorsLengthMock != 0) {
      return currentValidatorsLengthMock;
    }
    return super.currentValidatorsLength();
  }

  function setValidatorFeeMock(uint256 _amount) external {
    require (_amount <= 1 * DECIMALS);
    _setValidatorFee(msg.sender, _amount);
  }

  function setTotalStakeAmountMock(uint256 _totalStake) public {
    _setTotalStakeAmount(_totalStake);
  }
}
