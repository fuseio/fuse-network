pragma solidity ^0.4.24;

import "../../contracts/Consensus.sol";

contract ConsensusMock is Consensus {
  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = _newAddress;
  }

  function setNewValidatorSetMock(address[] _newSet) public {
    addressArrayStorage[keccak256(abi.encodePacked("newValidatorSet"))] = _newSet;
  }

  function addToSnapshotMock(address _address, uint256 _snapshotId) public {
    addToSnapshot(_address, _snapshotId);
  }

  function setSnapshotsPerCycleMock(uint256 _snapshotsPerCycle) public {
    setSnapshotsPerCycle(_snapshotsPerCycle);
  }

  function setFinalizedMock(bool _status) public {
    boolStorage[keccak256(abi.encodePacked("isFinalized"))] = _status;
  }
}
