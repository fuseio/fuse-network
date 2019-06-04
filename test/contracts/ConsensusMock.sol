pragma solidity ^0.4.24;

import "../../contracts/Consensus.sol";

contract ConsensusMock is Consensus {
  function setSystemAddressMock(address _newAddress) public onlyOwner {
    addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = _newAddress;
  }

  function setTime(uint256 _newTime) public {
    uintStorage[keccak256(abi.encodePacked("mockTime"))] = _newTime;
  }

  function getTime() public view returns(uint256) {
    uint256 time = uintStorage[keccak256(abi.encodePacked("mockTime"))];
    if (time == 0) {
      return now;
    } else {
      return time;
    }
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
}
