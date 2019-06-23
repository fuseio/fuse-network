pragma solidity ^0.4.24;

import "../../contracts/Consensus.sol";

contract ConsensusMock is Consensus {
  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = _newAddress;
  }

  function setNewValidatorSetMock(address[] _newSet) public {
    addressArrayStorage[keccak256(abi.encodePacked("newValidatorSet"))] = _newSet;
  }

  function setSnapshotMock(uint256 _snapshotId, address[] _addresses) public {
    setSnapshot(_snapshotId, _addresses);
  }

  function setSnapshotsPerCycleMock(uint256 _snapshotsPerCycle) public {
    setSnapshotsPerCycle(_snapshotsPerCycle);
  }
}
