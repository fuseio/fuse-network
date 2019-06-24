pragma solidity ^0.4.24;

import "../../contracts/Consensus.sol";

contract ConsensusMock is Consensus {
  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[SYSTEM_ADDRESS] = _newAddress;
  }

  function setNewValidatorSetMock(address[] _newSet) public {
    addressArrayStorage[NEW_VALIDATOR_SET] = _newSet;
  }

  function setSnapshotMock(uint256 _snapshotId, address[] _addresses) public {
    addressArrayStorage[keccak256(abi.encodePacked("snapshot", _snapshotId))] = _addresses;
  }

  function setSnapshotsPerCycleMock(uint256 _snapshotsPerCycle) public {
    uintStorage[SNAPSHOTS_PER_CYCLE] = _snapshotsPerCycle;
  }

  function setFinalizedMock(bool _status) public {
    boolStorage[IS_FINALIZED] = _status;
  }
}
