pragma solidity ^0.4.24;

import "../../contracts/Consensus.sol";

contract ConsensusMock is Consensus {
  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function setNewValidatorSetMock(address[] _newSet) public {
    addressArrayStorage[NEW_VALIDATOR_SET] = _newSet;
  }

  function setSnapshotMock(uint256 _snapshotId, address[] _addresses, uint256[] _amounts) public {
    _setSnapshotAddresses(_snapshotId, _addresses);
    for (uint256 i; i < _addresses.length; i++) {
      uintStorage[keccak256(abi.encodePacked("stakeAmount", _addresses[i]))] = _amounts[i];
      _setSnapshotStakeAmountForAddress(_snapshotId, _addresses[i]);
    }
  }

  function setSnapshotsPerCycleMock(uint256 _snapshotsPerCycle) public {
    uintStorage[SNAPSHOTS_PER_CYCLE] = _snapshotsPerCycle;
  }

  function setFinalizedMock(bool _status) public {
    boolStorage[IS_FINALIZED] = _status;
  }

  function setShouldEmitInitiateChangeMock(bool _status) public {
    boolStorage[SHOULD_EMIT_INITIATE_CHANGE] = _status;
  }
}
